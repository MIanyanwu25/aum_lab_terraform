# Lab 3: Complete Verification Suite
# Purpose: Run all verification checks in sequence
# Run this from your local PC after domain setup completes

Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║ Lab 3: Complete Verification Suite     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = $PSScriptRoot

# Define verification scripts
$verificationScripts = @(
    @{
        Name = "Domain Setup"
        Script = "verify-domain-setup.ps1"
        Description = "Verify DC01, OUs, and Security Groups"
    },
    @{
        Name = "Domain Joins"
        Script = "verify-domain-joins.ps1"
        Description = "Verify WS01 and WS02 are domain-joined"
    },
    @{
        Name = "Users Created"
        Script = "verify-users-created.ps1"
        Description = "Verify test users and group memberships"
    }
)

$allPassed = $true

foreach ($verification in $verificationScripts) {
    Write-Host ""
    Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host $verification.Name -ForegroundColor Cyan
    Write-Host $verification.Description -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    $scriptPath = Join-Path $ScriptDir $verification.Script
    
    if (Test-Path $scriptPath) {
        try {
            & $scriptPath
        } catch {
            Write-Host "✗ Error running $($verification.Script): $_" -ForegroundColor Red
            $allPassed = $false
        }
    } else {
        Write-Host "✗ Script not found: $scriptPath" -ForegroundColor Red
        $allPassed = $false
    }
    
    Write-Host ""
}

Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║ Verification Summary                   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($allPassed) {
    Write-Host "✓ All verifications completed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. .\04-create-users.ps1         (create test users)"
    Write-Host "2. .\05-add-rdp-users.ps1 on WS01 (enable RDP)"
    Write-Host "3. .\05-add-rdp-users.ps1 on WS02 (enable RDP)"
    Write-Host "4. .\configure-update-manager.ps1   (setup patching)"
} else {
    Write-Host "⚠ Some verifications had issues" -ForegroundColor Yellow
    Write-Host "Review the output above for details" -ForegroundColor Yellow
}

Write-Host ""
