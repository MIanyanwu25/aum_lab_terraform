# Lab 3: Create Security Groups
# Purpose: Create security groups on DC01
# RECOMMENDED: Run directly on DC01 via RDP as Administrator
# Remote execution via Azure CLI may not produce output reliably
# NOTE: Run 02-create-ous.ps1 FIRST - Groups OU must exist before running this script

# =============================================
# OPTION A: Run directly on DC01 via RDP
# =============================================
# 1. RDP into DC01 as labadmin
# 2. Open PowerShell as Administrator
# 3. Run the commands below directly

$groupPath = "OU=Groups,DC=aum,DC=local"

New-ADGroup -Name "IT_Staff" -SamAccountName IT_Staff -GroupCategory Security -GroupScope Global -Path $groupPath
Write-Host "Created Group: IT_Staff"

New-ADGroup -Name "Sales_Team" -SamAccountName Sales_Team -GroupCategory Security -GroupScope Global -Path $groupPath
Write-Host "Created Group: Sales_Team"

New-ADGroup -Name "HR_Staff" -SamAccountName HR_Staff -GroupCategory Security -GroupScope Global -Path $groupPath
Write-Host "Created Group: HR_Staff"

New-ADGroup -Name "Workstation_Admins" -SamAccountName Workstation_Admins -GroupCategory Security -GroupScope Global -Path $groupPath
Write-Host "Created Group: Workstation_Admins"

Write-Host ""
Write-Host "All groups created successfully!" -ForegroundColor Green

# Verify
Write-Host ""
Write-Host "Verification - Custom security groups:"
Get-ADGroup -Filter * -SearchBase "OU=Groups,DC=aum,DC=local" | Select-Object Name, GroupScope, GroupCategory | Format-Table -AutoSize

# =============================================
# OPTION B: Remote execution via Azure CLI
# =============================================
# Run this from your LOCAL machine if Option A is not available
# Note: Output may be blank even on success - always verify afterwards

<#
$ResourceGroupName = "rg-aumlab"
$DC01Name = "DC01"

$groupScript = @'
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$groupPath = "OU=Groups,DC=aum,DC=local"

New-ADGroup -Name "IT_Staff" -SamAccountName IT_Staff -GroupCategory Security -GroupScope Global -Path $groupPath
Write-Host "Created Group: IT_Staff"

New-ADGroup -Name "Sales_Team" -SamAccountName Sales_Team -GroupCategory Security -GroupScope Global -Path $groupPath
Write-Host "Created Group: Sales_Team"

New-ADGroup -Name "HR_Staff" -SamAccountName HR_Staff -GroupCategory Security -GroupScope Global -Path $groupPath
Write-Host "Created Group: HR_Staff"

New-ADGroup -Name "Workstation_Admins" -SamAccountName Workstation_Admins -GroupCategory Security -GroupScope Global -Path $groupPath
Write-Host "Created Group: Workstation_Admins"

Write-Host "All groups created!" -ForegroundColor Green
Get-ADGroup -Filter * -SearchBase "OU=Groups,DC=aum,DC=local" | Select-Object Name, GroupScope | Format-Table -AutoSize
'@

$result = az vm run-command invoke `
    --resource-group $ResourceGroupName `
    --name $DC01Name `
    --command-id RunPowerShellScript `
    --scripts $groupScript `
    --output json | ConvertFrom-Json

Write-Host $result.value[0].message
if ($result.value[1].message) {
    Write-Host "Errors:" -ForegroundColor Red
    Write-Host $result.value[1].message
}

# Always verify after remote execution
Write-Host "Verifying groups were created..."
$verifyScript = @'
Get-ADGroup -Filter * -SearchBase "OU=Groups,DC=aum,DC=local" | Select-Object Name, GroupScope | Format-Table -AutoSize
'@

az vm run-command invoke `
    --resource-group $ResourceGroupName `
    --name $DC01Name `
    --command-id RunPowerShellScript `
    --scripts $verifyScript `
    --query 'value[0].message' -o tsv
#>