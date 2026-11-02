# Lab 3: Configure Azure Update Manager
# Purpose: Set patch mode on all VMs and verify Update Manager configuration
# Run from your LOCAL machine
# NOTE: Maintenance windows and VM assignments are managed by Terraform (update-manager.tf)
#       This script handles patch mode settings only

param(
    [string]$ResourceGroup   = "rg-aumlab",
    [string]$SubscriptionId  = "195955b1-cb7f-4b52-84ca-0a71f7743e9c",
    [string]$Location        = "eastus"
)

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message, [string]$Color = "White")
    Write-Host "* $Message" -ForegroundColor $Color
}

Write-Header "Lab 3: Azure Update Manager Configuration"
Write-Step "Resource Group : $ResourceGroup"
Write-Step "Location       : $Location"
Write-Step "Subscription   : $SubscriptionId"

# Set subscription context
Write-Step "Setting subscription context..." "Yellow"
az account set --subscription $SubscriptionId

# =============================================
# Step 1: Set Patch Mode on All VMs
# NOTE: --set uses osProfile (no properties. prefix)
# =============================================

Write-Header "Step 1: Set Patch Mode on VMs"

$vms = @("DC01", "WS01", "WS02")

foreach ($vmName in $vms) {
    Write-Step "Setting patch mode for $vmName..." "Yellow"

    try {
        az vm update `
            --resource-group $ResourceGroup `
            --name $vmName `
            --set osProfile.windowsConfiguration.patchSettings.patchMode="AutomaticByPlatform" `
            --query "id" `
            -o tsv | Out-Null

        Write-Step "Patch mode set to AutomaticByPlatform for $vmName" "Green"
    } catch {
        Write-Step "Error setting patch mode for $vmName : $_" "Red"
    }
}

# =============================================
# Step 2: Verify Maintenance Windows (Terraform)
# =============================================

Write-Header "Step 2: Verify Maintenance Windows"
Write-Step "Maintenance windows are managed by Terraform (update-manager.tf)" "Yellow"
Write-Step "Checking maintenance configurations..."

$configs = az resource list `
    --resource-group $ResourceGroup `
    --resource-type "Microsoft.Maintenance/maintenanceConfigurations" `
    --output json | ConvertFrom-Json

if ($configs.Count -gt 0) {
    Write-Step "Found $($configs.Count) maintenance window(s):" "Green"
    foreach ($config in $configs) {
        Write-Step "  - $($config.name)" "Green"
    }
} else {
    Write-Step "No maintenance windows found - run terraform apply first" "Red"
}

# =============================================
# Step 3: Verify Patch Mode Was Set
# =============================================

Write-Header "Step 3: Verify Patch Mode Settings"

foreach ($vmName in $vms) {
    Write-Step "Checking patch mode for $vmName..."

    try {
        $patchMode = az vm show `
            --resource-group $ResourceGroup `
            --name $vmName `
            --query "osProfile.windowsConfiguration.patchSettings.patchMode" `
            -o tsv

        if ($patchMode) {
            Write-Step "$vmName patch mode: $patchMode" "Green"
        } else {
            Write-Step "$vmName patch mode not set - VM may need restart" "Yellow"
        }
    } catch {
        Write-Step "Error checking $vmName : $_" "Red"
    }
}

# =============================================
# Summary
# =============================================

Write-Header "Configuration Complete"
Write-Step "Patch mode set to AutomaticByPlatform on all VMs" "Green"
Write-Step "Maintenance windows managed by Terraform" "Green"
Write-Step "VM assignments managed by Terraform" "Green"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Run .\verify-patch-status.ps1 to confirm status"
Write-Host "  2. Go to Azure Portal > Update Manager to monitor patches"
Write-Host "  3. Patches will be assessed within 24 hours"
Write-Host ""