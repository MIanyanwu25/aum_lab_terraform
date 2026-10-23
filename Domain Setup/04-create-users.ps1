# Lab 3: Create Test Users
# Purpose: Create test user accounts across departments
# Run this on DC01

param(
    [string]$DomainName = "aum.local",
    [string]$DefaultPassword = "P@ssw0rd123!"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Lab 3: Creating Test Users"
Write-Host "Domain: $DomainName"
Write-Host "========================================" -ForegroundColor Cyan

# Get domain DN
$domainDN = "DC=" + ($DomainName -split '\.' | ForEach-Object { "DC=$_" } | Join-String -Separator ",")

# Define users: @(Username, DisplayName, Department, OU)
$users = @(
    @("john.smith", "John Smith", "IT", "OU=IT,OU=Users,$domainDN"),
    @("jane.doe", "Jane Doe", "Sales", "OU=Sales,OU=Users,$domainDN"),
    @("bob.johnson", "Bob Johnson", "HR", "OU=HR,OU=Users,$domainDN"),
    @("alice.williams", "Alice Williams", "IT", "OU=IT,OU=Users,$domainDN")
)

$securePassword = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force

foreach ($user in $users) {
    $samAccountName = $user[0]
    $displayName = $user[1]
    $department = $user[2]
    $path = $user[3]
    
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue)) {
        Write-Host "Creating user: $displayName ($samAccountName)" -ForegroundColor Yellow
        New-ADUser `
            -SamAccountName $samAccountName `
            -UserPrincipalName "$samAccountName@$DomainName" `
            -Name $displayName `
            -DisplayName $displayName `
            -GivenName ($displayName.Split()[0]) `
            -Surname ($displayName.Split()[-1]) `
            -Department $department `
            -Path $path `
            -AccountPassword $securePassword `
            -Enabled $true `
            -PasswordNotRequired $false `
            -ChangePasswordAtLogon $false `
            -Confirm:$false
    } else {
        Write-Host "User already exists: $samAccountName" -ForegroundColor Green
    }
}

# Add users to appropriate groups
Write-Host ""
Write-Host "Adding users to groups..." -ForegroundColor Yellow

$groupMemberships = @(
    @("john.smith", "IT_Staff"),
    @("alice.williams", "IT_Staff"),
    @("jane.doe", "Sales_Team"),
    @("bob.johnson", "HR_Staff")
)

foreach ($membership in $groupMemberships) {
    $userName = $membership[0]
    $groupName = $membership[1]
    
    $user = Get-ADUser -Filter "SamAccountName -eq '$userName'" -ErrorAction SilentlyContinue
    $group = Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue
    
    if ($user -and $group) {
        $isMember = Get-ADGroupMember -Identity $group | Where-Object { $_.SamAccountName -eq $userName }
        if (-not $isMember) {
            Write-Host "Adding $userName to $groupName" -ForegroundColor Yellow
            Add-ADGroupMember -Identity $group -Members $user -Confirm:$false
        } else {
            Write-Host "$userName already in $groupName" -ForegroundColor Green
        }
    }
}

Write-Host "Test users created and grouped successfully!" -ForegroundColor Green