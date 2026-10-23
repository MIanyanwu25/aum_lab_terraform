output "resource_group_name" {
  value = azurerm_resource_group.aum.name
}

output "key_vault_name" {
  value = azurerm_key_vault.aum.name
}

output "dc01_public_ip" {
  value = azurerm_public_ip.dc01.ip_address
}

output "dc01_private_ip" {
  value = azurerm_network_interface.dc01.private_ip_address
}

output "ws01_public_ip" {
  value = azurerm_public_ip.ws01.ip_address
}

output "ws02_public_ip" {
  value = azurerm_public_ip.ws02.ip_address
}