# Lab 3: Azure Update Manager Configuration
# Purpose: Define maintenance windows and update schedules for AUM lab

# Maintenance Window for Workstations - Weekly Tuesday 2 AM
resource "azurerm_maintenance_configuration" "ws_maintenance" {
  name                = "aum-ws-maintenance-window"
  location            = var.location
  resource_group_name = var.resource_group_name
  scope               = "InGuestPatch"
  in_guest_user_patch_mode = "User"

  window {
    start_date_time      = "2024-01-02 02:00"  # First Tuesday of the month
    recur_every          = "1Week"
    time_zone            = "UTC"
    duration             = "04:00"  # 4 hours in HH:mm format
  }

  install_patches {
    windows {
      classifications_to_include = ["Critical", "Security"]
    }
    reboot = "IfRequired"
  }

  tags = {
    Environment = "Lab3"
    Lab         = "Azure Update Manager"
    Purpose     = "Workstation patching"
  }
}

# Maintenance Window for DC - Weekly Wednesday 3 AM
resource "azurerm_maintenance_configuration" "dc_maintenance" {
  name                = "aum-dc-maintenance-window"
  location            = var.location
  resource_group_name = var.resource_group_name
  scope               = "InGuestPatch"
  in_guest_user_patch_mode = "User"

  window {
    start_date_time      = "2024-01-03 03:00"  # First Wednesday of the month
    recur_every          = "1Week"
    time_zone            = "UTC"
    duration             = "04:00"  # 4 hours in HH:mm format
  }

  install_patches {
    windows {
      classifications_to_include = ["Critical", "Security"]
    }
    reboot = "IfRequired"
  }

  tags = {
    Environment = "Lab3"
    Lab         = "Azure Update Manager"
    Purpose     = "DC patching"
  }
}

# Note: VM assignment to maintenance windows is done via tags on the VMs themselves.
# Add these tags to your VM resources in main.tf:
# - DC01: tags = { Environment = "Lab3", Role = "DC" }
# - WS01/WS02: tags = { Environment = "Lab3", Role = "Workstation" }

# Output maintenance configuration IDs
output "dc_maintenance_window_id" {
  value       = azurerm_maintenance_configuration.dc_maintenance.id
  description = "DC maintenance window resource ID"
}

output "ws_maintenance_window_id" {
  value       = azurerm_maintenance_configuration.ws_maintenance.id
  description = "Workstation maintenance window resource ID"
}
