# Lab 3: Verify Domain Joins
# Purpose: Verify WS01 and WS02 are properly joined to aum.local domain
# Run this from your local PC

$ResourceGroupName = "rg-aumlab"
$WS01Name = "WS01"
$WS02Name = "WS02"
$DomainName = "aum.local"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Lab 3: Verify Domain Joins"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

function Check-DomainJoin {
    param(
        [string]$VMName,
        [string]$ExpectedDomain
    )
    
    Write-Host "Checking $VMName domain status..." -ForegroundColor Cyan
    
    $joinCheck = @"
Get-WmiObject Win32_ComputerSystem | Select-Object Name, Domain
"@
    
    $result = az vm run-command invoke `
        --resource-group $ResourceGroupName `
        --name $VMName `
        --command-id RunPowerShellScript `
        --scripts $joinCheck `
        --query 'value[0].message' -o tsv
    
    if ($result -match $ExpectedDomain) {
        Write-Host "✓ $VMName is properly joined to $ExpectedDomain" -ForegroundColor Green
        Write-Host "  Output: $result"
        return $true
    } elseif ($result -match "WORKGROUP") {
        Write-Host "✗ $VMName is still in WORKGROUP (not joined)" -ForegroundColor Red
        Write-Host "  Output: $result"
        return $false
    } else {
        Write-Host "⚠ Could not determine domain join status for $VMName" -ForegroundColor Yellow
        Write-Host "  Output: $result"
        return $false
    }
}

# Check WS01
Write-Host "CHECK 1: WS01 Domain Join Status" -ForegroundColor Yellow
$ws01Status = Check-DomainJoin -VMName $WS01Name -ExpectedDomain $DomainName

Write-Host ""

# Check WS02
Write-Host "CHECK 2: WS02 Domain Join Status" -ForegroundColor Yellow
$ws02Status = Check-DomainJoin -VMName $WS02Name -ExpectedDomain $DomainName

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Domain Join Verification Summary"
Write-Host "========================================" -ForegroundColor Cyan

if ($ws01Status -and $ws02Status) {
    Write-Host "✓ All workstations are properly domain-joined!" -ForegroundColor Green
} else {
    Write-Host "⚠ Some workstations are not properly joined" -ForegroundColor Yellow
    if (-not $ws01Status) {
        Write-Host "  - WS01 needs manual domain join via RDP" -ForegroundColor Yellow
    }
    if (-not $ws02Status) {
        Write-Host "  - WS02 needs manual domain join via RDP" -ForegroundColor Yellow
    }
}

Write-Host ""
