# Lab 3: Verify Users Created
# Purpose: Verify test users are created and added to correct groups
# Run this from your local PC

$ResourceGroupName = "rg-aumlab"
$DC01Name = "DC01"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Lab 3: Verify Users Created"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check 1: List all users
Write-Host "CHECK 1: Verifying Test Users Exist..." -ForegroundColor Yellow

$userCheck = @"
Get-ADUser -Filter * -SearchBase "OU=IT,OU=Users,DC=aum,DC=local" | Select-Object Name, SamAccountName
Get-ADUser -Filter * -SearchBase "OU=Sales,OU=Users,DC=aum,DC=local" | Select-Object Name, SamAccountName
Get-ADUser -Filter * -SearchBase "OU=HR,OU=Users,DC=aum,DC=local" | Select-Object Name, SamAccountName
"@

Write-Host "Retrieving users..." -ForegroundColor Cyan
$userResult = az vm run-command invoke `
    --resource-group $ResourceGroupName `
    --name $DC01Name `
    --command-id RunPowerShellScript `
    --scripts $userCheck `
    --query 'value[0].message' -o tsv

$expectedUsers = @("john.smith", "alice.williams", "jane.doe", "bob.johnson")
$allFound = $true

foreach ($user in $expectedUsers) {
    if ($userResult -match $user) {
        Write-Host "✓ Found: $user" -ForegroundColor Green
    } else {
        Write-Host "✗ Missing: $user" -ForegroundColor Red
        $allFound = $false
    }
}

Write-Host ""
Write-Host "CHECK 2: Verifying Group Memberships..." -ForegroundColor Yellow

$groupCheck = @"
Write-Host "IT_Staff members:"
Get-ADGroupMember -Identity "IT_Staff" | Select-Object Name

Write-Host ""
Write-Host "Sales_Team members:"
Get-ADGroupMember -Identity "Sales_Team" | Select-Object Name

Write-Host ""
Write-Host "HR_Staff members:"
Get-ADGroupMember -Identity "HR_Staff" | Select-Object Name
"@

Write-Host "Retrieving group memberships..." -ForegroundColor Cyan
$groupResult = az vm run-command invoke `
    --resource-group $ResourceGroupName `
    --name $DC01Name `
    --command-id RunPowerShellScript `
    --scripts $groupCheck `
    --query 'value[0].message' -o tsv

Write-Host $groupResult

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($allFound) {
    Write-Host "✓ All test users created successfully!" -ForegroundColor Green
} else {
    Write-Host "⚠ Some test users are missing" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
