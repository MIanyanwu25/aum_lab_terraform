# Lab 3: Create Test Users
# Purpose: Create test user accounts across departments to mimic real AD environment
# RECOMMENDED: Run directly on DC01 via RDP as Administrator
# NOTE: Run AFTER 02-create-ous.ps1 and 03-create-groups.ps1
# UPDATED: Uses OU=Lab_Users instead of OU=Users to match actual OU structure

param(
    [string]$DomainName = "aum.local",
    [string]$DefaultPassword = "P@ssw0rd123!"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Lab 3: Creating Test Users"
Write-Host "Domain: $DomainName"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Domain DN - hardcoded to avoid Join-String compatibility issues
$domainDN = "DC=aum,DC=local"

# Define users: Username, DisplayName, Department, OU Path
# NOTE: Using Lab_Users (not Users) to match our OU structure
$users = @(
    @("john.smith",      "John Smith",      "IT",    "OU=IT,OU=Lab_Users,$domainDN"),
    @("alice.williams",  "Alice Williams",  "IT",    "OU=IT,OU=Lab_Users,$domainDN"),
    @("jane.doe",        "Jane Doe",        "Sales", "OU=Sales,OU=Lab_Users,$domainDN"),
    @("bob.johnson",     "Bob Johnson",     "HR",    "OU=HR,OU=Lab_Users,$domainDN")
)

$securePassword = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force

Write-Host "Creating test users..." -ForegroundColor Yellow
Write-Host ""

foreach ($user in $users) {
    $samAccountName = $user[0]
    $displayName    = $user[1]
    $department     = $user[2]
    $path           = $user[3]

    # Check if user already exists
    $existingUser = Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue

    if (-not $existingUser) {
        Write-Host "Creating: $displayName ($samAccountName)" -ForegroundColor Cyan
        Write-Host "  Path: $path"
        try {
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
                -PasswordNeverExpires $true `
                -ChangePasswordAtLogon $false `
                -Confirm:$false
            Write-Host "  ✓ Created successfully" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ Error: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Skipping: $samAccountName (already exists)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Adding users to security groups..." -ForegroundColor Yellow
Write-Host ""

# Define group memberships
$groupMemberships = @(
    @("john.smith",     "IT_Staff"),
    @("alice.williams", "IT_Staff"),
    @("jane.doe",       "Sales_Team"),
    @("bob.johnson",    "HR_Staff")
)

foreach ($membership in $groupMemberships) {
    $userName  = $membership[0]
    $groupName = $membership[1]

    $user  = Get-ADUser  -Filter "SamAccountName -eq '$userName'"  -ErrorAction SilentlyContinue
    $group = Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue

    if ($user -and $group) {
        $isMember = Get-ADGroupMember -Identity $group | Where-Object { $_.SamAccountName -eq $userName }
        if (-not $isMember) {
            Write-Host "Adding $userName to $groupName" -ForegroundColor Cyan
            try {
                Add-ADGroupMember -Identity $group -Members $user -Confirm:$false
                Write-Host "  ✓ Added successfully" -ForegroundColor Green
            } catch {
                Write-Host "  ✗ Error: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "Skipping: $userName already in $groupName" -ForegroundColor Yellow
        }
    } else {
        if (-not $user)  { Write-Host "✗ User not found: $userName"   -ForegroundColor Red }
        if (-not $group) { Write-Host "✗ Group not found: $groupName" -ForegroundColor Red }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✓ Test users created and grouped!"
Write-Host "========================================"  -ForegroundColor Green
Write-Host ""
Write-Host "Users Summary:" -ForegroundColor Cyan
Write-Host "  john.smith      (IT)    → IT_Staff"
Write-Host "  alice.williams  (IT)    → IT_Staff"
Write-Host "  jane.doe        (Sales) → Sales_Team"
Write-Host "  bob.johnson     (HR)    → HR_Staff"
Write-Host ""
Write-Host "Default Password: $DefaultPassword" -ForegroundColor Yellow
Write-Host ""

# Verify users were created
Write-Host "Verification - Users in Lab_Users OU:" -ForegroundColor Cyan
Get-ADUser -Filter * -SearchBase "OU=Lab_Users,DC=aum,DC=local" `
    -Properties Department | `
    Select-Object Name, SamAccountName, Department | `
    Format-Table -AutoSize

Write-Host "Verification - IT_Staff group members:" -ForegroundColor Cyan
Get-ADGroupMember -Identity "IT_Staff" | Select-Object Name, SamAccountName | Format-Table -AutoSize

Write-Host "Verification - Sales_Team group members:" -ForegroundColor Cyan
Get-ADGroupMember -Identity "Sales_Team" | Select-Object Name, SamAccountName | Format-Table -AutoSize

Write-Host "Verification - HR_Staff group members:" -ForegroundColor Cyan
Get-ADGroupMember -Identity "HR_Staff" | Select-Object Name, SamAccountName | Format-Table -AutoSize