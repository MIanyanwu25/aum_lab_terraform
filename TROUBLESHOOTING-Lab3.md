cd# Lab 3: Azure Update Manager - Troubleshooting Guide

## Terraform Errors

### Error: "Resource Group Name not found" or "Storage Account not found"

**Symptom**: `terraform init` fails with 404 error on `rg-tfstate` or storage account.

**Cause**: The `rg-tfstate` resource group or storage account doesn't exist in your subscription.

**Solution**:
```powershell
# Create the tfstate resource group
az group create --name rg-tfstate --location eastus

# Create the storage account (use your unique name)
az storage account create --name tfstateaumlab0783 --resource-group rg-tfstate --sku Standard_LRS

# Create the container
az storage container create --name tfstate --account-name tfstateaumlab0783 --auth-mode login
```

Then run `terraform init` again.

---

### Error: "Reference to undeclared resource" on update-manager.tf

**Symptom**: `terraform plan` fails with "azurerm_resource_group.rg has not been declared"

**Cause**: The filename has a space (`Update Manager.tf` instead of `update-manager.tf`).

**Solution**:
1. Check your file name: `ls *.tf | grep -i update`
2. If you see `Update Manager.tf`, delete it
3. Rename to `update-manager.tf` (lowercase, with hyphen)
4. Run `terraform plan` again

---

### Error: "duration must match the format HH:mm"

**Symptom**: Terraform apply fails on `update-manager.tf` with duration format error.

**Cause**: Duration is specified as number (4) instead of string in HH:mm format.

**Solution**: In `update-manager.tf`, change:
```hcl
duration = 4  # Wrong
```
To:
```hcl
duration = "04:00"  # Correct (4 hours in HH:mm format)
```

---

### Error: "install_patches must be specified" OR "Patch configuration not supported for InGuestPatchMode = Platform"

**Symptom**: Conflicting errors about patch configuration when using `scope = "InGuestPatch"`.

**Cause**: Azure Update Manager requires specific combinations of `scope`, `in_guest_user_patch_mode`, and `install_patches` parameters.

**Solution**: Use the correct combination:
```hcl
scope                        = "InGuestPatch"
in_guest_user_patch_mode     = "User"  # Must be "User" to support custom patch config

install_patches {
  windows {
    classifications_to_include = ["Critical", "Security"]
  }
  reboot = "IfRequired"
}
```

**Don't use `Platform` mode** — it doesn't allow custom patch configuration.

---

### Error: "The value Standard_F1ams_v provided for the VM size is not valid"

**Symptom**: Terraform apply fails because VM size doesn't exist in the region.

**Cause**: Typo in VM size — missing version suffix (v7, v6, etc.) or completely wrong size name.

**Solution**: In `main.tf`, verify VM size is `Standard_F1ams_v7` (not `Standard_F1ams_v`):
```hcl
vm_size = "Standard_F1ams_v7"  # Correct
```

---

## RDP Connection Issues

### Error: "Remote Desktop can't connect" or "Remote access to the server is not enabled"

**Symptom**: Can't RDP to any VM using public IP.

**Cause**: NSG rule is blocking your IP, or your public IP changed since Terraform was applied.

**Solution**:

1. **Check your current public IP**:
   ```powershell
   (Invoke-WebRequest -Uri "https://api.ipify.org?format=json").Content | ConvertFrom-Json | Select-Object ip
   ```

2. **Compare with `terraform.tfvars`**:
   ```powershell
   cat terraform.tfvars | grep allowed_rdp_source_ip
   ```

3. **If different, update `terraform.tfvars`**:
   ```powershell
   # Edit terraform.tfvars and change allowed_rdp_source_ip to your new IP
   ```

4. **Apply the change**:
   ```powershell
   terraform apply
   ```

5. **Wait ~30 seconds for NSG rule to update, then retry RDP**

---

### Error: "Authentication failed" when RDP

**Symptom**: RDP connects but authentication fails.

**Cause**: Wrong credentials or domain not yet configured.

**Solution**:
- Use username: `labadmin`
- Use password: the one you set in `terraform.tfvars` and during orchestration script
- If domain is not configured yet, wait for `orchestrate-lab3-setup.ps1` to complete

---

## Domain Setup Issues

### Script Error: "Script not found" in orchestration script

**Symptom**: `orchestrate-lab3-setup.ps1` runs but can't find individual scripts.

**Cause**: Individual scripts (00-promote-dc.ps1, 01-join-domain.ps1, etc.) are not in the same folder.

**Solution**:
1. Ensure all 6 PowerShell scripts are in `$HOME\Projects\aum-lab-terraform`:
   - `00-promote-dc.ps1`
   - `01-join-domain.ps1`
   - `02-create-ous.ps1`
   - `03-create-groups.ps1`
   - `04-create-users.ps1`
   - `05-add-rdp-users.ps1`

2. Run `orchestrate-lab3-setup.ps1` from the same directory

---

### Error: "Already domain-joined" message appears

**Symptom**: Orchestration script says "This computer is already domain-joined" and skips DC promotion.

**Cause**: DC01 was already promoted (already ran the script before).

**Solution**: This is normal if you're re-running the script. It will skip promotion and go to Phase 2 (create OUs, groups, users). If you need a fresh start, delete and recreate the VMs:
```powershell
terraform destroy
terraform apply
terraform apply  # Run orchestration script
```

---

### Error: "The RPC server is unavailable" during domain join

**Symptom**: `01-join-domain.ps1` fails with RPC server error on WS01/WS02.

**Cause**: DC01 is still starting up or is not responding to domain queries.

**Solution**:
1. Wait 2-3 minutes after DC01 restarts
2. RDP into DC01 and verify `Active Directory Domain Services` service is running:
   ```powershell
   Get-Service adws | Select-Object Status
   ```
3. Try domain join script again

---

## Azure Update Manager Issues

### Error: "Patch configuration not supported"

**Symptom**: Terraform apply fails with "Patch configuration not supported for InGuestPatchMode = Platform"

**Cause**: Using `Platform` mode with custom patch configuration (they're incompatible).

**Solution**: Change `in_guest_user_patch_mode` to `"User"`:
```hcl
in_guest_user_patch_mode = "User"  # Not "Platform"
```

---

### Maintenance windows don't appear in Azure Portal

**Symptom**: Maintenance windows created by Terraform but don't show in portal.

**Cause**: Portal may not immediately reflect newly created resources.

**Solution**:
1. Verify they exist via CLI:
   ```powershell
   az resource list -g rg-aumlab --resource-type "Microsoft.Maintenance/maintenanceConfigurations" -o table
   ```

2. Refresh Azure Portal (F5)

3. If still not showing, check Terraform state:
   ```powershell
   terraform state show azurerm_maintenance_configuration.ws_maintenance
   ```

---

### Verification script hangs at "Step 3: Maintenance Windows"

**Symptom**: `verify-patch-status.ps1` hangs when checking maintenance windows.

**Cause**: Azure REST API call times out.

**Solution**:
1. Press **Ctrl+C** to interrupt
2. Run quick verification instead:
   ```powershell
   az resource list -g rg-aumlab --resource-type "Microsoft.Maintenance/maintenanceConfigurations" -o table
   ```

3. If using updated `verify-patch-status.ps1`, it uses the faster `az resource list` method and won't hang

---

## Patch Assessment Issues

### VMs show "No assessments yet"

**Symptom**: `verify-patch-status.ps1` or Azure Portal shows no patch assessments.

**Cause**: This is normal — patch assessments can take up to 24 hours for the first run.

**Solution**:
1. Wait 24 hours
2. VMs will automatically assess available patches
3. Azure Portal will update: VM → Updates (Preview) → "Available critical and security updates"

---

### Patch assessment fails with "Operation not permitted"

**Symptom**: Update Manager shows assessment failures on VMs.

**Cause**: VM Guest Agent is not running or patch settings are not fully applied.

**Solution**:
1. RDP into the affected VM
2. Check Guest Agent status:
   ```powershell
   Get-Service WindowsAzureGuestAgent | Select-Object Status
   ```

3. If not running, start it:
   ```powershell
   Start-Service WindowsAzureGuestAgent
   ```

4. Wait 5 minutes and check Azure Portal again

---

## General Troubleshooting Tips

### Check VM Status

```powershell
# Check all VMs are running
az vm get-instance-view -g rg-aumlab -n DC01 --query "instanceView.statuses" -o table
az vm get-instance-view -g rg-aumlab -n WS01 --query "instanceView.statuses" -o table
az vm get-instance-view -g rg-aumlab -n WS02 --query "instanceView.statuses" -o table
```

### Check Terraform State

```powershell
# View current state
terraform show

# View specific resource
terraform state show azurerm_windows_virtual_machine.dc01

# List all resources
terraform state list
```

### Review Terraform Logs

```powershell
# Enable debug logging
$env:TF_LOG = "DEBUG"
terraform plan > debug.log 2>&1
```

### Check Azure Portal Insights

1. VM → Insights → check CPU, memory, disk usage
2. VM → Extensions → verify Guest Agent is installed
3. VM → Update Management → check patch status (if using legacy Update Management)

### Common File Issues

| Issue | Solution |
|-------|----------|
| File not found errors | Check file exists: `ls -Path "filename"` |
| Execution policy errors | Run: `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process` |
| Script syntax errors | Validate: `Test-Path -Path "script.ps1"` |
| Encoding issues | Save files as UTF-8 (not UTF-16 with BOM) |

---

## Contact & Resources

- **Lab 3 README**: See architecture and deployment steps
- **Terraform Errors**: Check `terraform.log` for details
- **PowerShell Errors**: Check the full error message in PowerShell output
- **Azure Errors**: Check Azure Portal Activity Log for VM operations

---

## Changelog

- **Initial Release**: Lab 3 Azure Update Manager with maintenance windows
- **Fix**: Updated `verify-patch-status.ps1` to use faster `az resource list` for maintenance windows check
