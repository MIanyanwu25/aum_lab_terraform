# Lab 3: Verify Domain Setup
# Purpose: Verify DC01, OUs, and Security Groups are properly configured
# Run this from your local PC

$ResourceGroupName = "rg-aumlab"
$DC01Name = "DC01"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Lab 3: Verify Domain Setup"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check 1: Verify DC01 Forest and Domain
Write-Host "CHECK 1: Verifying DC01 is a Domain Controller..." -ForegroundColor Yellow
$dcCheck = @"
Get-ADForest
Get-ADDomain
Write-Host 'DC01 verification complete'
"@

Write-Host "Checking DC01..." -ForegroundColor Cyan
$result = az vm run-command invoke `
    --resource-group $ResourceGroupName `
    --name $DC01Name `
    --command-id RunPowerShellScript `
    --scripts $dcCheck `
    --query 'value[0].message' -o tsv

if ($result -match "aum.local") {
    Write-Host "✓ DC01 is properly configured as domain controller for aum.local" -ForegroundColor Green
    Write-Host $result | Select-Object -First 10
} else {
    Write-Host "✗ DC01 not showing as domain controller" -ForegroundColor Red
    Write-Host $result
}

Write-Host ""
Write-Host "CHECK 2: Verifying Organizational Units..." -ForegroundColor Yellow

$ouCheck = @"
Get-ADOrganizationalUnit -Filter * | Select-Object Name | Sort-Object Name
"@

Write-Host "Retrieving OUs..." -ForegroundColor Cyan
$ouResult = az vm run-command invoke `
    --resource-group $ResourceGroupName `
    --name $DC01Name `
    --command-id RunPowerShellScript `
    --scripts $ouCheck `
    --query 'value[0].message' -o tsv

if ($ouResult -match "Computers|Workstations|Users") {
    Write-Host "✓ Organizational Units created successfully:" -ForegroundColor Green
    Write-Host $ouResult
} else {
    Write-Host "✗ OUs not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "CHECK 3: Verifying Security Groups..." -ForegroundColor Yellow

$groupCheck = @"
Get-ADGroup -Filter * | Select-Object Name | Sort-Object Name
"@

Write-Host "Retrieving Groups..." -ForegroundColor Cyan
$groupResult = az vm run-command invoke `
    --resource-group $ResourceGroupName `
    --name $DC01Name `
    --command-id RunPowerShellScript `
    --scripts $groupCheck `
    --query 'value[0].message' -o tsv

if ($groupResult -match "IT_Staff|Sales_Team|Domain Users") {
    Write-Host "✓ Security Groups created successfully:" -ForegroundColor Green
    Write-Host $groupResult
} else {
    Write-Host "✗ Groups not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Domain Setup Verification Complete"
Write-Host "========================================" -ForegroundColor Cyan
