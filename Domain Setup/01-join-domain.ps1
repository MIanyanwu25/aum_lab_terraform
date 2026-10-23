# Lab 3: Join Workstations to Domain
# Purpose: Join WS01 and WS02 to aum.local domain
# Run this on each workstation

param(
    [string]$DomainName = "aum.local",
    [string]$DomainAdminUser = "labadmin",
    [string]$DomainPassword
)

# If password not provided, prompt for it
if (-not $DomainPassword) {
    $DomainPassword = Read-Host "Enter domain admin password" -AsSecureString
} else {
    $DomainPassword = ConvertTo-SecureString $DomainPassword -AsPlainText -Force
}

$DomainAdmin = "$DomainName\$DomainAdminUser"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Lab 3: Joining Computer to Domain"
Write-Host "Domain: $DomainName"
Write-Host "Admin User: $DomainAdmin"
Write-Host "========================================" -ForegroundColor Cyan

# Create credentials
$cred = New-Object System.Management.Automation.PSCredential($DomainAdmin, $DomainPassword)

# Join domain
Add-Computer -DomainName $DomainName -Credential $cred -Restart -Force -Confirm:$false

Write-Host "Domain join initiated. Computer will restart." -ForegroundColor Green