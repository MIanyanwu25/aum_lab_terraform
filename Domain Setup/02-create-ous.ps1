# Lab 3: Create Organizational Units
# Purpose: Build OU structure for aum.local domain
# Run this on DC01 after domain promotion

param(
    [string]$DomainName = "aum.local"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Lab 3: Creating Organizational Units"
Write-Host "Domain: $DomainName"
Write-Host "========================================" -ForegroundColor Cyan

# Get domain DN
$domainDN = "DC=" + ($DomainName -split '\.' | ForEach-Object { "DC=$_" } | Join-String -Separator ",")
Write-Host "Domain DN: $domainDN" -ForegroundColor Gray

# Create root OUs
$ouPaths = @(
    "OU=Computers,$domainDN",
    "OU=Users,$domainDN",
    "OU=Groups,$domainDN"
)

foreach ($ouPath in $ouPaths) {
    $ouName = $ouPath.Split(',')[0].Replace('OU=', '')
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -ErrorAction SilentlyContinue)) {
        Write-Host "Creating OU: $ouName" -ForegroundColor Yellow
        New-ADOrganizationalUnit -Name $ouName -Path $domainDN -Confirm:$false
    } else {
        Write-Host "OU already exists: $ouName" -ForegroundColor Green
    }
}

# Create sub-OUs under Computers
$computerOUs = @(
    "OU=Workstations,OU=Computers,$domainDN",
    "OU=Servers,OU=Computers,$domainDN"
)

foreach ($ouPath in $computerOUs) {
    $ouName = $ouPath.Split(',')[0].Replace('OU=', '')
    $parentPath = ($ouPath -split ',', 2)[1]
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -SearchBase $parentPath -ErrorAction SilentlyContinue)) {
        Write-Host "Creating OU: $ouName (under Computers)" -ForegroundColor Yellow
        New-ADOrganizationalUnit -Name $ouName -Path $parentPath -Confirm:$false
    } else {
        Write-Host "OU already exists: $ouName" -ForegroundColor Green
    }
}

# Create sub-OUs under Users (departments)
$userOUs = @(
    "OU=IT,OU=Users,$domainDN",
    "OU=Sales,OU=Users,$domainDN",
    "OU=HR,OU=Users,$domainDN"
)

foreach ($ouPath in $userOUs) {
    $ouName = $ouPath.Split(',')[0].Replace('OU=', '')
    $parentPath = ($ouPath -split ',', 2)[1]
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -SearchBase $parentPath -ErrorAction SilentlyContinue)) {
        Write-Host "Creating OU: $ouName (under Users)" -ForegroundColor Yellow
        New-ADOrganizationalUnit -Name $ouName -Path $parentPath -Confirm:$false
    } else {
        Write-Host "OU already exists: $ouName" -ForegroundColor Green
    }
}

Write-Host "OU structure created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  OU=Computers" -ForegroundColor White
Write-Host "    ├─ OU=Workstations" -ForegroundColor White
Write-Host "    └─ OU=Servers" -ForegroundColor White
Write-Host "  OU=Users" -ForegroundColor White
Write-Host "    ├─ OU=IT" -ForegroundColor White
Write-Host "    ├─ OU=Sales" -ForegroundColor White
Write-Host "    └─ OU=HR" -ForegroundColor White
Write-Host "  OU=Groups" -ForegroundColor White