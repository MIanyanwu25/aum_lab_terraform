# Lab 3: Master Orchestration Script (Local - uses Azure VM Run Command)
# Purpose: Configure domain setup on all VMs from your local machine
# Usage: .\orchestrate-lab3-setup.ps1

param(
    [string]$ResourceGroup = "rg-aumlab",
    [string]$DomainName = "aum.local",
    [string]$NetBIOSName = "AUM",
    [string]$DomainAdminUser = "labadmin"
)

# Colors
$colors = @{
    Title   = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "White"
}

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor $colors.Title
    Write-Host $Message -ForegroundColor $colors.Title
    Write-Host "========================================" -ForegroundColor $colors.Title
}

function Write-Step {
    param([string]$Message, [string]$Color = $colors.Info)
    Write-Host "* $Message" -ForegroundColor $Color
}

function Invoke-RemoteScript {
    param(
        [string]$VMName,
        [string]$ScriptContent,
        [hashtable]$Parameters = @{}
    )
    
    Write-Step "Executing script on $VMName..."
    
    # Build parameter string
    $paramString = ""
    foreach ($key in $Parameters.Keys) {
        $value = $Parameters[$key]
        if ($value -is [securestring]) {
            $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($value))
            $paramString += "-$key (ConvertTo-SecureString '$plainText' -AsPlainText -Force) "
        }
        else {
            $paramString += "-$key '$value' "
        }
    }
    
    # Combine script with parameter invocation
    $fullScript = @"
`$params = @{
$(foreach ($key in $Parameters.Keys) {
    if ($Parameters[$key] -is [securestring]) {
        $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($Parameters[$key]))
        "    '$key' = (ConvertTo-SecureString '$plainText' -AsPlainText -Force);"
    }
    else {
        "    '$key' = '$($Parameters[$key])';"
    }
})
}

$scriptBlock = {
$ScriptContent
}

& `$scriptBlock @params
"@
    
    try {
        $result = az vm run-command invoke `
            --resource-group $ResourceGroup `
            --name $VMName `
            --command-id RunPowerShellScript `
            --scripts $fullScript `
            --query "value[0].message" `
            -o tsv
        
        Write-Host $result
        Write-Step "Successfully executed on $VMName" $colors.Success
        return $true
    }
    catch {
        Write-Step "Error executing on $VMName : $_" $colors.Error
        return $false
    }
}

function Wait-ForVMReady {
    param([string]$VMName, [int]$DelaySeconds = 120)
    
    Write-Step "Waiting $DelaySeconds seconds for $VMName to restart..." $colors.Warning
    Start-Sleep -Seconds $DelaySeconds
    
    # Poll VM status
    $maxAttempts = 30
    $attempt = 0
    while ($attempt -lt $maxAttempts) {
        try {
            $status = az vm get-instance-view --resource-group $ResourceGroup --name $VMName --query "instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus" -o tsv
            if ($status -like "*running*") {
                Write-Step "$VMName is back online" $colors.Success
                Start-Sleep -Seconds 30  # Extra delay for services to start
                return $true
            }
        }
        catch { }
        
        $attempt++
        if ($attempt -lt $maxAttempts) {
            Start-Sleep -Seconds 10
        }
    }
    
    Write-Step "Timeout waiting for $VMName" $colors.Warning
    return $false
}

# ==================== SCRIPTS ====================

$scriptPromoteDC = @'
param([string]$DomainName, [securestring]$SafeModeAdminPassword)

Write-Host "Promoting DC01 to domain controller for $DomainName..." -ForegroundColor Cyan

# Check if already promoted
if ((Get-WmiObject Win32_ComputerSystem).PartOfDomain) {
    Write-Host "Already a domain member. Skipping promotion." -ForegroundColor Green
    exit 0
}

# Install AD DS
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools -Restart:$false -ErrorAction Stop

# Install Forest
Install-ADDSForest `
    -DomainName $DomainName `
    -DomainNetBIOSName ($DomainName.Split('.')[0]).ToUpper() `
    -SafeModeAdministratorPassword $SafeModeAdminPassword `
    -Force `
    -Confirm:$false `
    -NoRebootOnCompletion

Write-Host "DC promotion complete. Restart required." -ForegroundColor Green
'@

$scriptCreateOUsGroupsUsers = @'
param([string]$DomainName)

Write-Host "Creating OUs, groups, and users for $DomainName..." -ForegroundColor Cyan

$domainDN = "DC=" + ($DomainName -split '\.' | ForEach-Object { "DC=$_" } | Join-String -Separator ",")

# Create OUs
@("OU=Computers,$domainDN", "OU=Users,$domainDN", "OU=Groups,$domainDN") | ForEach-Object {
    $ouName = $_.Split(',')[0].Replace('OU=', '')
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ouName -Path $domainDN -Confirm:$false
    }
}

# Create sub-OUs
@("OU=Workstations,OU=Computers,$domainDN", "OU=Servers,OU=Computers,$domainDN") | ForEach-Object {
    $ouName = $_.Split(',')[0].Replace('OU=', '')
    $parentPath = ($_ -split ',', 2)[1]
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -SearchBase $parentPath -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ouName -Path $parentPath -Confirm:$false
    }
}

@("OU=IT,OU=Users,$domainDN", "OU=Sales,OU=Users,$domainDN", "OU=HR,OU=Users,$domainDN") | ForEach-Object {
    $ouName = $_.Split(',')[0].Replace('OU=', '')
    $parentPath = ($_ -split ',', 2)[1]
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -SearchBase $parentPath -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ouName -Path $parentPath -Confirm:$false
    }
}

# Create groups
@("IT_Staff", "Sales_Team", "HR_Staff", "Workstation_Admins") | ForEach-Object {
    if (-not (Get-ADGroup -Filter "Name -eq '$_'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $_ -SamAccountName $_ -GroupCategory Security -GroupScope Global -Path "OU=Groups,$domainDN" -Confirm:$false
    }
}

# Create users
$users = @(
    @("john.smith", "John Smith", "IT"),
    @("jane.doe", "Jane Doe", "Sales"),
    @("bob.johnson", "Bob Johnson", "HR"),
    @("alice.williams", "Alice Williams", "IT")
)

$password = ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force

foreach ($user in $users) {
    $sam = $user[0]
    $displayName = $user[1]
    $dept = $user[2]
    $depPath = "OU=$dept,OU=Users,$domainDN"
    
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue)) {
        New-ADUser -SamAccountName $sam -UserPrincipalName "$sam@$DomainName" -Name $displayName -DisplayName $displayName `
            -GivenName ($displayName.Split()[0]) -Surname ($displayName.Split()[-1]) -Department $dept `
            -Path $depPath -AccountPassword $password -Enabled $true -Confirm:$false
    }
}

# Add users to groups
$groupMappings = @(
    @("john.smith", "IT_Staff"),
    @("alice.williams", "IT_Staff"),
    @("jane.doe", "Sales_Team"),
    @("bob.johnson", "HR_Staff")
)

foreach ($mapping in $groupMappings) {
    $user = Get-ADUser -Filter "SamAccountName -eq '$($mapping[0])'" -ErrorAction SilentlyContinue
    $group = Get-ADGroup -Filter "Name -eq '$($mapping[1])'" -ErrorAction SilentlyContinue
    if ($user -and $group) {
        Add-ADGroupMember -Identity $group -Members $user -Confirm:$false -ErrorAction SilentlyContinue
    }
}

Write-Host "OUs, groups, and users created successfully!" -ForegroundColor Green
'@

$scriptJoinDomain = @'
param([string]$DomainName, [string]$DomainAdminUser, [string]$DomainPassword)

Write-Host "Joining $env:COMPUTERNAME to $DomainName..." -ForegroundColor Cyan

# Check if already joined
if ((Get-WmiObject Win32_ComputerSystem).PartOfDomain) {
    Write-Host "Already domain-joined. Skipping." -ForegroundColor Green
    exit 0
}

$cred = New-Object System.Management.Automation.PSCredential("$DomainName\$DomainAdminUser", (ConvertTo-SecureString $DomainPassword -AsPlainText -Force))
Add-Computer -DomainName $DomainName -Credential $cred -Restart -Force -Confirm:$false

Write-Host "Domain join initiated. Restart required." -ForegroundColor Green
'@

$scriptAddRDPUsers = @'
param([string]$DomainName)

Write-Host "Configuring RDP for $env:COMPUTERNAME..." -ForegroundColor Cyan

# Add IT_Staff to RDP
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "$DomainName\IT_Staff" -ErrorAction SilentlyContinue

# Enable RDP
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0 -Confirm:$false

# Enable firewall rule
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue

Write-Host "RDP configured successfully!" -ForegroundColor Green
'@

# ==================== MAIN ====================

Write-Header "Lab 3: Azure Update Manager - Remote Domain Setup"
Write-Step "Resource Group: $ResourceGroup" $colors.Info
Write-Step "Domain: $DomainName" $colors.Info
Write-Step "Admin User: $DomainAdminUser" $colors.Info
Write-Host ""

# Get passwords
Write-Host "Enter credentials:" -ForegroundColor $colors.Warning
$safeModePassword = Read-Host "Safe Mode Administrator Password" -AsSecureString
$domainPassword = Read-Host "Domain Admin Password" -AsSecureString
$domainPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($domainPassword))

# Confirm
$confirm = Read-Host "Proceed with remote setup? (y/N)"
if ($confirm -ne "y") {
    Write-Step "Cancelled." $colors.Warning
    exit 0
}

# ==================== DC01 ====================

Write-Header "Phase 1: DC01 Domain Promotion"

Invoke-RemoteScript -VMName "DC01" -ScriptContent $scriptPromoteDC -Parameters @{
    DomainName = $DomainName
    SafeModeAdminPassword = $safeModePassword
}

Write-Step "Waiting for DC01 to restart..." $colors.Warning
Wait-ForVMReady -VMName "DC01"

Write-Header "Phase 2: DC01 - Create OUs, Groups, Users"

Invoke-RemoteScript -VMName "DC01" -ScriptContent $scriptCreateOUsGroupsUsers -Parameters @{
    DomainName = $DomainName
}

# ==================== WS01 ====================

Write-Header "Phase 3: WS01 Domain Join"

Invoke-RemoteScript -VMName "WS01" -ScriptContent $scriptJoinDomain -Parameters @{
    DomainName = $DomainName
    DomainAdminUser = $DomainAdminUser
    DomainPassword = $domainPasswordPlain
}

Write-Step "Waiting for WS01 to restart..." $colors.Warning
Wait-ForVMReady -VMName "WS01"

Write-Header "Phase 4: WS01 - Configure RDP"

Invoke-RemoteScript -VMName "WS01" -ScriptContent $scriptAddRDPUsers -Parameters @{
    DomainName = $DomainName
}

# ==================== WS02 ====================

Write-Header "Phase 5: WS02 Domain Join"

Invoke-RemoteScript -VMName "WS02" -ScriptContent $scriptJoinDomain -Parameters @{
    DomainName = $DomainName
    DomainAdminUser = $DomainAdminUser
    DomainPassword = $domainPasswordPlain
}

Write-Step "Waiting for WS02 to restart..." $colors.Warning
Wait-ForVMReady -VMName "WS02"

Write-Header "Phase 6: WS02 - Configure RDP"

Invoke-RemoteScript -VMName "WS02" -ScriptContent $scriptAddRDPUsers -Parameters @{
    DomainName = $DomainName
}

# ==================== COMPLETE ====================

Write-Header "Lab 3 Domain Setup Complete!"
Write-Step "DC01, WS01, and WS02 are configured" $colors.Success
Write-Step "Next: Configure Azure Update Manager" $colors.Info
Write-Host ""