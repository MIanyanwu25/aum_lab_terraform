# Lab 3: Promote DC01 to Domain Controller for aum.local
# Purpose: Create Active Directory forest and domain

param(
    [string]$DomainName = "aum.local",
    [string]$NetBIOSName = "AUM",
    [securestring]$SafeModeAdminPassword
)

# If password not provided, prompt for it
if (-not $SafeModeAdminPassword) {
    $SafeModeAdminPassword = Read-Host "Enter Safe Mode Administrator Password" -AsSecureString
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Lab 3: Promoting DC01 to Domain Controller"
Write-Host "Domain: $DomainName"
Write-Host "NetBIOS: $NetBIOSName"
Write-Host "========================================" -ForegroundColor Cyan

# Install AD DS and DNS roles
Write-Host "Installing Active Directory Domain Services..." -ForegroundColor Yellow
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools -Restart:$false

# Install ADDSForest
Write-Host "Installing Forest: $DomainName" -ForegroundColor Yellow
Install-ADDSForest `
    -DomainName $DomainName `
    -DomainNetBIOSName $NetBIOSName `
    -SafeModeAdministratorPassword $SafeModeAdminPassword `
    -Force `
    -Confirm:$false `
    -NoRebootOnCompletion

Write-Host "Domain promotion complete! Reboot required." -ForegroundColor Green
Write-Host "Run: Restart-Computer -Force" -ForegroundColor Yellow