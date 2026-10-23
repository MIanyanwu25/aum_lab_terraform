variable "resource_group_name" {
  description = "Resource group for Lab 3"
  type        = string
  default     = "rg-aumlab"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "admin_username" {
  description = "Local admin username for every VM"
  type        = string
  default     = "labadmin"
}

variable "admin_password" {
  description = "Local admin password. Set via $env:TF_VAR_admin_password — never in a file."
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Active Directory domain for this lab"
  type        = string
  default     = "aum.local"
}

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

variable "subnet_address_prefix" {
  type    = list(string)
  default = ["10.0.1.0/24"]
}

variable "dc01_private_ip" {
  description = "Static private IP for DC01 (DNS server)"
  type        = string
  default     = "10.0.1.4"
}

variable "allowed_rdp_source_ip" {
  description = "Your public IP — the only one allowed through the NSG on port 3389"
  type        = string
}

variable "key_vault_name" {
  description = "Must be globally unique. Create a new one for Lab 3."
  type        = string
}