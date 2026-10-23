# Lab 3: Configure Azure Update Manager Patch Schedules
# Purpose: Set up patch deployment schedules for DC01, WS01, WS02
# Usage: .\configure-update-manager.ps1

param(
    [string]$ResourceGroup = "rg-aumlab",
    [string]$SubscriptionId = "195955b1-cb7f-4b52-84ca-0a71f7743e9c",
    [string]$Location = "eastus"
)

$colors = @{
    Title   = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "White"
}

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor $colors.Title
    Write-Host $Message -ForegroundColor $colors.Title
    Write-Host "========================================" -ForegroundColor $colors.Title
}

function Write-Step {
    param([string]$Message, [string]$Color = $colors.Info)
    Write-Host "* $Message" -ForegroundColor $Color
}

Write-Header "Lab 3: Azure Update Manager Configuration"
Write-Step "Resource Group: $ResourceGroup" $colors.Info
Write-Step "Location: $Location" $colors.Info
Write-Step "Subscription: $SubscriptionId" $colors.Info

# Set subscription
Write-Step "Setting subscription context..." $colors.Warning
az account set --subscription $SubscriptionId

# ==================== CONFIGURE PATCH SETTINGS ====================

Write-Header "Step 1: Configure Patch Settings on VMs"

$vms = @("DC01", "WS01", "WS02")

foreach ($vmName in $vms) {
    Write-Step "Configuring patch settings for $vmName..."
    
    try {
        # Update VM with required patch settings
        az vm update `
            --resource-group $ResourceGroup `
            --name $vmName `
            --set "properties.osProfile.windowsConfiguration.patchSettings.patchMode=AutomaticByPlatform" `
            --query "id" `
            -o tsv | Out-Null
        
        Write-Step "Patch mode set to AutomaticByPlatform for $vmName" $colors.Success
    }
    catch {
        Write-Step "Error configuring $vmName : $_" $colors.Error
    }
}

# ==================== CREATE UPDATE SCHEDULE ====================

Write-Header "Step 2: Create Update Schedules"

# Schedule 1: Workstations - Weekly Tuesday 02:00 UTC
Write-Step "Creating update schedule for workstations (WS01, WS02)..."

$wsScheduleBody = @{
    properties = @{
        updateClasses = @("Critical", "Security")
        duration = "PT4H"
        expiryTimeInUtc = "2025-12-31T23:59:59Z"
        interval = 1
        nextRunTimeUtc = "2024-01-02T02:00:00Z"
        rebootIfNeeded = $true
        maintenanceWindow = @{
            duration = "PT4H"
            expiryTimeInUtc = "2025-12-31T23:59:59Z"
            maintenanceDay = "Tuesday"
            maintenanceWindowDuration = "PT4H"
            startDateTime = "2024-01-02T02:00:00Z"
        }
    }
} | ConvertTo-Json -Depth 10

try {
    az rest `
        --method put `
        --uri "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Maintenance/maintenanceConfigurations/aum-ws-patch-schedule?api-version=2023-09-01-preview" `
        --body $wsScheduleBody | Out-Null
    
    Write-Step "Workstation update schedule created" $colors.Success
}
catch {
    Write-Step "Note: Schedule creation may require portal configuration" $colors.Warning
}

# Schedule 2: Domain Controller - Weekly Wednesday 03:00 UTC
Write-Step "Creating update schedule for DC01..."

$dcScheduleBody = @{
    properties = @{
        updateClasses = @("Critical", "Security")
        duration = "PT4H"
        expiryTimeInUtc = "2025-12-31T23:59:59Z"
        interval = 1
        nextRunTimeUtc = "2024-01-03T03:00:00Z"
        rebootIfNeeded = $true
        maintenanceWindow = @{
            duration = "PT4H"
            expiryTimeInUtc = "2025-12-31T23:59:59Z"
            maintenanceDay = "Wednesday"
            maintenanceWindowDuration = "PT4H"
            startDateTime = "2024-01-03T03:00:00Z"
        }
    }
} | ConvertTo-Json -Depth 10

try {
    az rest `
        --method put `
        --uri "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Maintenance/maintenanceConfigurations/aum-dc-patch-schedule?api-version=2023-09-01-preview" `
        --body $dcScheduleBody | Out-Null
    
    Write-Step "DC update schedule created" $colors.Success
}
catch {
    Write-Step "Note: Schedule creation may require portal configuration" $colors.Warning
}

# ==================== VERIFY CONFIGURATION ====================

Write-Header "Step 3: Verify Configuration"

foreach ($vmName in $vms) {
    Write-Step "Checking patch settings for $vmName..."
    
    try {
        $patchMode = az vm show `
            --resource-group $ResourceGroup `
            --name $vmName `
            --query "properties.osProfile.windowsConfiguration.patchSettings.patchMode" `
            -o tsv
        
        if ($patchMode) {
            Write-Step "Patch mode for $vmName : $patchMode" $colors.Success
        }
        else {
            Write-Step "$vmName patch mode not yet set (may need restart)" $colors.Warning
        }
    }
    catch {
        Write-Step "Error checking $vmName : $_" $colors.Error
    }
}

Write-Header "Azure Update Manager Configuration Complete"
Write-Step "Maintenance windows created and VMs configured" $colors.Success
Write-Step "Next: Monitor patch assessments and deployments in Azure Portal" $colors.Info
Write-Host ""
Write-Host "To view patch status:" -ForegroundColor $colors.Info
Write-Host "  1. Go to Azure Portal" -ForegroundColor $colors.Info
Write-Host "  2. VM -> Updates (Preview)" -ForegroundColor $colors.Info
Write-Host "  3. Check 'Available critical and security updates'" -ForegroundColor $colors.Info
Write-Host ""