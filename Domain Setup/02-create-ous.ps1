# Lab 3: Create Organizational Units Remotely
# Purpose: Create OUs on DC01 via Azure CLI remote execution
# Run this from your LOCAL machine (not DC01)
# Updated: Uses Lab_Computers and Lab_Users to avoid conflicts
#          with default AD containers (CN=Computers, CN=Users)

$ResourceGroupName = "rg-aumlab"
$DC01Name = "DC01"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Lab 3: Creating Organizational Units"
Write-Host "Target: DC01 (remote execution)"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Single-quote here-string: no escaping needed
# Variables expand when script runs ON DC01
# NOTE: Using Lab_Computers and Lab_Users instead of Computers/Users
#       because AD already has default containers with those names (CN=Computers, CN=Users)
#       which prevents creating OUs with the same name at the root level
$ouScript = @'
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$domainDN = "DC=aum,DC=local"
Write-Host "Creating OUs in domain: $domainDN"
Write-Host ""

# Top-level OUs
New-ADOrganizationalUnit -Name "Lab_Computers" -Path $domainDN
Write-Host "Created OU: Lab_Computers"

New-ADOrganizationalUnit -Name "Lab_Users" -Path $domainDN
Write-Host "Created OU: Lab_Users"

# Groups OU already created separately
# New-ADOrganizationalUnit -Name "Groups" -Path $domainDN

# Sub-OUs under Lab_Computers
New-ADOrganizationalUnit -Name "Workstations" -Path "OU=Lab_Computers,$domainDN"
Write-Host "Created OU: Workstations (under Lab_Computers)"

New-ADOrganizationalUnit -Name "Servers" -Path "OU=Lab_Computers,$domainDN"
Write-Host "Created OU: Servers (under Lab_Computers)"

# Sub-OUs under Lab_Users
New-ADOrganizationalUnit -Name "IT" -Path "OU=Lab_Users,$domainDN"
Write-Host "Created OU: IT (under Lab_Users)"

New-ADOrganizationalUnit -Name "Sales" -Path "OU=Lab_Users,$domainDN"
Write-Host "Created OU: Sales (under Lab_Users)"

New-ADOrganizationalUnit -Name "HR" -Path "OU=Lab_Users,$domainDN"
Write-Host "Created OU: HR (under Lab_Users)"

Write-Host ""
Write-Host "All OUs created successfully!" -ForegroundColor Green

# Verify - list all OUs
Write-Host ""
Write-Host "Verification - All OUs in domain:"
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName | Format-Table -AutoSize
'@

Write-Host "Sending OU creation script to DC01..." -ForegroundColor Yellow
Write-Host ""

$result = az vm run-command invoke `
    --resource-group $ResourceGroupName `
    --name $DC01Name `
    --command-id RunPowerShellScript `
    --scripts $ouScript `
    --output json | ConvertFrom-Json

# Show stdout
Write-Host "=== Output ===" -ForegroundColor Cyan
Write-Host $result.value[0].message

# Show stderr if any
if ($result.value[1].message) {
    Write-Host ""
    Write-Host "=== Errors ===" -ForegroundColor Red
    Write-Host $result.value[1].message
}