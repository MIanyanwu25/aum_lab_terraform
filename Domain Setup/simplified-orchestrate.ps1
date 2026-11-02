# Lab 3: Simplified Orchestration Script
# Purpose: Orchestrate complete domain setup and configuration
# Runs Steps: 1=Promote DC, 2=OUs, 2b=Groups, 3=Join WS01, 4=Join WS02
# Run this from your local PC

$ResourceGroupName = "rg-aumlab"
$DC01Name = "DC01"
$WS01Name = "WS01"
$WS02Name = "WS02"
$DomainName = "aum.local"
$DomainPassword = "MichaelI#2026"
$SafeModePassword = "TempPass123!@#"

# Color output function
function Write-Step {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host ">>> $Message" -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

# Helper function to invoke remote scripts
function Invoke-RemoteScript {
    param(
        [string]$VMName,
        [string]$ScriptContent,
        [string]$StepName
    )
    
    Write-Step "Running: $StepName on $VMName"
    
    try {
        $result = az vm run-command invoke `
            --resource-group $ResourceGroupName `
            --name $VMName `
            --command-id RunPowerShellScript `
            --scripts $ScriptContent `
            --query 'value[0]' -o json | ConvertFrom-Json
        
        # Check for errors in stderr
        if ($result.code -eq "ComponentStatus/StdErr/succeeded" -and $result.message) {
            if ($result.message -notmatch "Success|already" -and $result.message.length -gt 0) {
                Write-Error-Custom "$StepName failed with: $($result.message)"
                return $false
            }
        }
        
        Write-Success "$StepName completed"
        if ($result.message -and $result.message.length -gt 100) {
            Write-Host $result.message | Select-Object -First 5
        }
        return $true
    } catch {
        Write-Error-Custom "Exception during $StepName : $_"
        return $false
    }
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Lab 3: Domain Setup Orchestration"
Write-Host "Domain: $DomainName"
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Promote DC01
Write-Host "STEP 1: DC01 Promotion" -ForegroundColor Yellow
Write-Host "-----------------------------------"

$step1 = @"
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
Install-ADDSForest -DomainName aum.local -SafeModeAdministratorPassword (ConvertTo-SecureString -AsPlainText -Force 'TempPass123!@#') -Force
Restart-Computer -Force
"@

Invoke-RemoteScript -VMName $DC01Name -ScriptContent $step1 -StepName "DC01 Promotion"
Write-Host "Waiting 180 seconds for DC01 to restart and stabilize..." -ForegroundColor Yellow
Start-Sleep -Seconds 180

# Step 2: Create OUs
Write-Host ""
Write-Host "STEP 2: Create Organizational Units" -ForegroundColor Yellow
Write-Host "-----------------------------------"

$scriptPath = "C:\Users\mikes\repos\aum-lab-terraform\Domain Setup\02-create-ous.ps1"
$scriptContent = @"
`$domainDN = \"dc=aum,dc=local\"
New-ADOrganizationalUnit -Name \"Computers\" -Path `$domainDN -ErrorAction SilentlyContinue
New-ADOrganizationalUnit -Name \"Workstations\" -Path \"ou=Computers,`$domainDN\" -ErrorAction SilentlyContinue
New-ADOrganizationalUnit -Name \"Servers\" -Path \"ou=Computers,`$domainDN\" -ErrorAction SilentlyContinue
New-ADOrganizationalUnit -Name \"Users\" -Path `$domainDN -ErrorAction SilentlyContinue
New-ADOrganizationalUnit -Name \"IT\" -Path \"ou=Users,`$domainDN\" -ErrorAction SilentlyContinue
New-ADOrganizationalUnit -Name \"Sales\" -Path \"ou=Users,`$domainDN\" -ErrorAction SilentlyContinue
New-ADOrganizationalUnit -Name \"HR\" -Path \"ou=Users,`$domainDN\" -ErrorAction SilentlyContinue
New-ADOrganizationalUnit -Name \"Groups\" -Path `$domainDN -ErrorAction SilentlyContinue
Write-Host 'OUs created'
"@

Set-Content -Path $scriptPath -Value $scriptContent
$scriptText = Get-Content -Path $scriptPath -Raw
Invoke-RemoteScript -VMName $DC01Name -ScriptContent $scriptText -StepName "Create OUs"
Start-Sleep -Seconds 30

# Step 2b: Create Groups
Write-Host ""
Write-Host "STEP 2b: Create Security Groups" -ForegroundColor Yellow
Write-Host "-----------------------------------"

$scriptPath2 = "C:\Users\mikes\repos\aum-lab-terraform\Domain Setup\03-create-groups.ps1"
$scriptContent2 = @"
`$groupPath = \"ou=Groups,dc=aum,dc=local\"
New-ADGroup -Name \"IT_Staff\" -SamAccountName IT_Staff -GroupCategory Security -GroupScope Global -Path `$groupPath -ErrorAction SilentlyContinue
New-ADGroup -Name \"Sales_Team\" -SamAccountName Sales_Team -GroupCategory Security -GroupScope Global -Path `$groupPath -ErrorAction SilentlyContinue
New-ADGroup -Name \"HR_Staff\" -SamAccountName HR_Staff -GroupCategory Security -GroupScope Global -Path `$groupPath -ErrorAction SilentlyContinue
New-ADGroup -Name \"Workstation_Admins\" -SamAccountName Workstation_Admins -GroupCategory Security -GroupScope Global -Path `$groupPath -ErrorAction SilentlyContinue
Write-Host 'Groups created'
"@

Set-Content -Path $scriptPath2 -Value $scriptContent2
$scriptText2 = Get-Content -Path $scriptPath2 -Raw
Invoke-RemoteScript -VMName $DC01Name -ScriptContent $scriptText2 -StepName "Create Security Groups"
Start-Sleep -Seconds 30

# Step 3: Join WS01 with retry logic
Write-Host ""
Write-Host "STEP 3: Join WS01 to Domain" -ForegroundColor Yellow
Write-Host "-----------------------------------"

$step3 = @"
`$cred = New-Object System.Management.Automation.PSCredential('labadmin', (ConvertTo-SecureString -AsPlainText -Force 'MichaelI#2026'))
`$retries = 0
`$maxRetries = 3

while (`$retries -lt `$maxRetries) {
    try {
        Add-Computer -DomainName aum.local -Credential `$cred -Force -ErrorAction Stop
        Write-Host 'WS01 domain join successful'
        break
    } catch {
        `$retries++
        Write-Host "Attempt `$retries failed: `$_"
        if (`$retries -lt `$maxRetries) {
            Start-Sleep -Seconds 10
        }
    }
}

if (`$retries -eq `$maxRetries) {
    Write-Host 'ERROR: Domain join failed after 3 attempts'
    exit 1
}

Restart-Computer -Force
"@

Invoke-RemoteScript -VMName $WS01Name -ScriptContent $step3 -StepName "Join WS01 to Domain"
Write-Host "Waiting 120 seconds for WS01 to restart..." -ForegroundColor Yellow
Start-Sleep -Seconds 120

# Step 4: Join WS02 with retry logic
Write-Host ""
Write-Host "STEP 4: Join WS02 to Domain" -ForegroundColor Yellow
Write-Host "-----------------------------------"

$step4 = @"
`$cred = New-Object System.Management.Automation.PSCredential('labadmin', (ConvertTo-SecureString -AsPlainText -Force 'MichaelI#2026'))
`$retries = 0
`$maxRetries = 3

while (`$retries -lt `$maxRetries) {
    try {
        Add-Computer -DomainName aum.local -Credential `$cred -Force -ErrorAction Stop
        Write-Host 'WS02 domain join successful'
        break
    } catch {
        `$retries++
        Write-Host "Attempt `$retries failed: `$_"
        if (`$retries -lt `$maxRetries) {
            Start-Sleep -Seconds 10
        }
    }
}

if (`$retries -eq `$maxRetries) {
    Write-Host 'ERROR: Domain join failed after 3 attempts'
    exit 1
}

Restart-Computer -Force
"@

Invoke-RemoteScript -VMName $WS02Name -ScriptContent $step4 -StepName "Join WS02 to Domain"
Write-Host "Waiting 120 seconds for WS02 to restart..." -ForegroundColor Yellow
Start-Sleep -Seconds 120

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "✓ Domain Configuration Complete!"
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Run: .\verify-all.ps1 (verify domain setup)"
Write-Host "2. Run: .\04-create-users.ps1 (create test users)"
Write-Host "3. Run: .\05-add-rdp-users.ps1 (enable RDP access)"
Write-Host "4. Run: .\configure-update-manager.ps1 (setup patching)"
Write-Host ""