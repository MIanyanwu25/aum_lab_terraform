# Lab 3: Azure Update Manager with Terraform

## Overview

**Lab 3** demonstrates how to deploy and configure **Azure Update Manager (AUM)** using Terraform and PowerShell. The lab deploys a realistic on-premises-like environment in Azure with a domain controller, workstations, and automated patch management.

## Lab Architecture

```
Azure Subscription (eastus)
├── Resource Group: rg-aumlab
│   ├── VNet: 10.0.0.0/16
│   │   └── Subnet: 10.0.0.0/24
│   │
│   ├── VMs:
│   │   ├── DC01 (10.0.1.4) - Domain Controller
│   │   ├── WS01 (10.0.1.6) - Workstation
│   │   └── WS02 (10.0.1.5) - Workstation
│   │
│   ├── Networking:
│   │   ├── Network Security Group (NSG) - Port 3389 RDP allowed
│   │   ├── Public IPs for each VM
│   │   └── Network Interfaces
│   │
│   ├── Security:
│   │   └── Key Vault: kv-aumlab-7c3e9a18 (stores VM admin password)
│   │
│   └── Update Manager:
│       ├── Maintenance Window: aum-ws-maintenance-window (Tuesday 02:00 UTC)
│       └── Maintenance Window: aum-dc-maintenance-window (Wednesday 03:00 UTC)
│
└── Resource Group: rg-tfstate
    └── Storage Account: tfstateaumlab0783 (Terraform state storage)
```

## Key Components

### Infrastructure (Terraform)
- **VMs**: 3x Windows Server 2022 with patch mode set to `AutomaticByPlatform`
- **Networking**: VNet, subnet, NSG with RDP access from your IP
- **Active Directory**: Domain forest (aum.local) with OUs, security groups, and test users
- **Azure Update Manager**: Maintenance windows for scheduled patching

### Domain Structure
- **Domain**: aum.local
- **OUs**:
  - Computers/Workstations
  - Computers/Servers
  - Users/IT
  - Users/Sales
  - Users/HR
  - Groups
- **Security Groups**: IT_Staff, Sales_Team, HR_Staff, Workstation_Admins
- **Test Users**: john.smith, jane.doe, bob.johnson, alice.williams

### Patch Management
- **Patch Mode**: AutomaticByPlatform (Azure handles updates)
- **Workstation Window**: Every Tuesday 02:00 UTC (4 hours)
- **DC Window**: Every Wednesday 03:00 UTC (4 hours)
- **Patch Types**: Critical and Security updates
- **Reboot**: If Required

## Prerequisites

1. **Azure Subscription** with Owner or Contributor role
2. **Terraform** (>= 1.5.0)
3. **Azure CLI** (az command)
4. **PowerShell 7+** (for orchestration scripts)
5. **Git** (for GitHub push)

## Deployment Steps

### Step 1: Initialize Terraform

```powershell
cd $HOME\Projects\aum-lab-terraform
terraform init
```

### Step 2: Plan Infrastructure

```powershell
terraform plan
```

Verify the plan shows ~18 resources to create (VMs, networking, Key Vault, maintenance windows).

### Step 3: Apply Infrastructure

```powershell
terraform apply
```

This creates all VMs, networking, and Azure Update Manager maintenance windows. Takes ~10-15 minutes.

### Step 4: Configure Domain (Remote via Azure Run Command)

```powershell
.\orchestrate-lab3-setup.ps1
```

This script:
- Promotes DC01 to domain controller
- Creates OUs, security groups, and test users
- Joins WS01 and WS02 to the domain
- Configures RDP permissions

You'll be prompted for:
- Safe Mode Administrator Password
- Domain Admin Password

The script handles restarts automatically and takes ~5-10 minutes total.

### Step 5: Configure Azure Update Manager

```powershell
.\configure-update-manager.ps1
```

This script:
- Sets patch mode on all VMs
- Creates update deployment schedules
- Verifies patch configuration

Takes ~2 minutes.

### Step 6: Verify Configuration

```powershell
.\verify-patch-status.ps1
```

Confirms:
- VMs are running
- Patch settings are applied
- Maintenance windows exist
- Update schedules are active

## Usage After Deployment

### RDP to VMs

```powershell
# DC01
mstsc /v:20.228.165.35

# WS01
mstsc /v:172.191.89.208

# WS02
mstsc /v:20.85.223.83
```

**Credentials**: `labadmin` / (your chosen password)

### View Patch Status in Azure Portal

1. Go to Azure Portal
2. Select a VM
3. Go to **Updates** (Preview)
4. Check "Available critical and security updates"
5. View "Last patch assessment"

### Monitor Maintenance Windows

1. Azure Portal → Search "Maintenance Configurations"
2. Select `aum-ws-maintenance-window` or `aum-dc-maintenance-window`
3. View schedule and assignments

## File Structure

```
aum-lab-terraform/
├── Terraform Files:
│   ├── versions.tf              # Provider versions
│   ├── backend.tf               # Remote state config
│   ├── variables.tf             # Input variables
│   ├── main.tf                  # VMs, networking
│   ├── keyvault.tf              # Key Vault for secrets
│   ├── outputs.tf               # Output values
│   ├── update-manager.tf        # Maintenance windows
│   ├── terraform.tfvars         # Actual values (gitignored)
│   ├── terraform.lock.hcl       # Dependency lock
│   └── .gitignore               # Git ignore rules
│
├── PowerShell Scripts:
│   ├── 00-promote-dc.ps1                  # DC promotion
│   ├── 01-join-domain.ps1                 # Domain join
│   ├── 02-create-ous.ps1                  # Create OUs
│   ├── 03-create-groups.ps1               # Create groups
│   ├── 04-create-users.ps1                # Create users
│   ├── 05-add-rdp-users.ps1               # RDP config
│   ├── orchestrate-lab3-setup.ps1         # Master domain setup
│   ├── configure-update-manager.ps1       # AUM setup
│   └── verify-patch-status.ps1            # Verification
│
└── Documentation:
    ├── README.md                # This file
    └── TROUBLESHOOTING.md       # Known issues and fixes
```

## Cleaning Up

To delete all resources and save costs:

```powershell
terraform destroy
```

This removes:
- All VMs and disks
- VNet and NSG
- Key Vault
- Maintenance windows
- **Note**: rg-tfstate resource group remains (contains Terraform state)

To fully clean up, also delete rg-tfstate:

```powershell
az group delete --name rg-tfstate
```

## Learning Outcomes

After completing Lab 3, you should understand:

1. **Terraform**: Infrastructure as code for Azure
2. **Active Directory**: Domain setup, OUs, groups, users
3. **Azure Update Manager**: Maintenance windows, patch schedules
4. **Azure Networking**: VNets, NSGs, public IPs
5. **Azure Security**: Key Vault, RBAC, secrets management
6. **PowerShell**: Azure automation and remote scripting
7. **DevOps**: Infrastructure orchestration and documentation

## Next Steps

1. **Monitor patches**: Watch patch assessments and deployments in Azure Portal
2. **Extend the lab**: Add more VMs, create additional security groups
3. **Automate further**: Create Azure Automation runbooks for more complex tasks
4. **Compare with Lab 1**: See similarities/differences in NTFS/file server setup
5. **Compare with Lab 2**: See how RBAC differs from domain permissions

## References

- [Azure Update Manager Documentation](https://learn.microsoft.com/en-us/azure/update-manager/overview)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Active Directory on Windows Server](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/active-directory-domain-services)
- [Azure Maintenance Configurations](https://learn.microsoft.com/en-us/azure/virtual-machines/maintenance-configurations)

## Troubleshooting

See **TROUBLESHOOTING.md** for:
- Terraform errors
- Domain setup issues
- RDP connection problems
- Patch assessment issues
- Azure Update Manager configuration errors

## Support

If you encounter issues not covered in TROUBLESHOOTING.md:

1. Check the Azure Portal for error messages
2. Review Terraform plan output
3. Run `verify-patch-status.ps1` to check current state
4. Check PowerShell script output for specific errors
5. Review this README and TROUBLESHOOTING.md again
