# Lab 3: Add RDP Permissions to Workstations
# Purpose: Grant domain users RDP access to workstations
# Run this on WS01 and WS02 after domain join

param(
    [string]$DomainName = "aum.local"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Lab 3: Configuring RDP Permissions"
Write-Host "Computer: $env:COMPUTERNAME"
Write-Host "Domain: $DomainName"
Write-Host "========================================" -ForegroundColor Cyan

# Add IT_Staff group to Remote Desktop Users
$rdpGroupName = "Remote Desktop Users"
$groupToAdd = "$DomainName\IT_Staff"

Write-Host "Adding $groupToAdd to $rdpGroupName" -ForegroundColor Yellow

try {
    Add-LocalGroupMember -Group $rdpGroupName -Member $groupToAdd -ErrorAction SilentlyContinue
    Write-Host "Successfully added $groupToAdd to local $rdpGroupName" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -like "*already a member*") {
        Write-Host "$groupToAdd is already a member of $rdpGroupName" -ForegroundColor Green
    } else {
        Write-Host "Error adding user: $_" -ForegroundColor Red
    }
}

# Enable RDP (ensure it's enabled)
Write-Host "Ensuring RDP is enabled..." -ForegroundColor Yellow
$rdpReg = "HKLM:\System\CurrentControlSet\Control\Terminal Server"
Set-ItemProperty -Path $rdpReg -Name fDenyTSConnections -Value 0 -Confirm:$false

# Enable firewall rule for RDP
Write-Host "Enabling RDP Firewall Rules..." -ForegroundColor Yellow
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue

Write-Host "RDP permissions configured successfully!" -ForegroundColor Green
Write-Host "Users in IT_Staff can now RDP to this workstation" -ForegroundColor Cyan