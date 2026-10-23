# Lab 3: Create Security Groups
# Purpose: Create department and role-based security groups
# Run this on DC01

param(
    [string]$DomainName = "aum.local"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Lab 3: Creating Security Groups"
Write-Host "Domain: $DomainName"
Write-Host "========================================" -ForegroundColor Cyan

# Get domain DN
$domainDN = "DC=" + ($DomainName -split '\.' | ForEach-Object { "DC=$_" } | Join-String -Separator ",")
$groupsOU = "OU=Groups,$domainDN"

# Define groups: @(Name, Description, Path)
$groups = @(
    @("IT_Staff", "IT Department Staff", $groupsOU),
    @("Sales_Team", "Sales Department Team", $groupsOU),
    @("HR_Staff", "Human Resources Staff", $groupsOU),
    @("Workstation_Admins", "Local Admins on Workstations", $groupsOU)
)

foreach ($group in $groups) {
    $groupName = $group[0]
    $description = $group[1]
    $path = $group[2]
    
    if (-not (Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue)) {
        Write-Host "Creating group: $groupName" -ForegroundColor Yellow
        New-ADGroup `
            -Name $groupName `
            -SamAccountName $groupName `
            -GroupCategory Security `
            -GroupScope Global `
            -Description $description `
            -Path $path `
            -Confirm:$false
    } else {
        Write-Host "Group already exists: $groupName" -ForegroundColor Green
    }
}

Write-Host "Security groups created successfully!" -ForegroundColor Green