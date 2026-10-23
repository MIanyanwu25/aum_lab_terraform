provider "azurerm" {
  features {}
}

# ---------- Resource group ----------

resource "azurerm_resource_group" "aum" {
  name     = var.resource_group_name
  location = var.location
}

# ---------- Network ----------

resource "azurerm_virtual_network" "aum" {
  name                = "vnet-aumlab"
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.aum.location
  resource_group_name = azurerm_resource_group.aum.name

  # Every VM uses DC01 for DNS, so domain join can find aum.local
  dns_servers = [var.dc01_private_ip]
}

resource "azurerm_subnet" "aum" {
  name                 = "snet-aumlab"
  resource_group_name  = azurerm_resource_group.aum.name
  virtual_network_name = azurerm_virtual_network.aum.name
  address_prefixes     = var.subnet_address_prefix
}

resource "azurerm_network_security_group" "aum" {
  name                = "nsg-aumlab"
  location            = azurerm_resource_group.aum.location
  resource_group_name = azurerm_resource_group.aum.name

  security_rule {
    name                       = "Allow-RDP-From-Me"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.allowed_rdp_source_ip
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "aum" {
  subnet_id                 = azurerm_subnet.aum.id
  network_security_group_id = azurerm_network_security_group.aum.id
}

# ---------- DC01 ----------

resource "azurerm_public_ip" "dc01" {
  name                = "pip-dc01"
  location            = azurerm_resource_group.aum.location
  resource_group_name = azurerm_resource_group.aum.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "dc01" {
  name                = "dc01-nic"
  location            = azurerm_resource_group.aum.location
  resource_group_name = azurerm_resource_group.aum.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.aum.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.dc01_private_ip
    public_ip_address_id          = azurerm_public_ip.dc01.id
  }
}

resource "azurerm_windows_virtual_machine" "dc01" {
  name                              = "DC01"
  resource_group_name               = azurerm_resource_group.aum.name
  location                          = azurerm_resource_group.aum.location
  size                              = "Standard_F1ams_v7"
  admin_username                    = var.admin_username
  admin_password                    = var.admin_password
  network_interface_ids             = [azurerm_network_interface.dc01.id]
  vm_agent_platform_updates_enabled = true

  # Update Manager settings
  patch_mode                                             = "AutomaticByPlatform"
  patch_assessment_mode                                  = "AutomaticByPlatform"
  bypass_platform_safety_checks_on_user_schedule_enabled = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  
  tags = {
    Environment = "Lab3"
    Role        = "DC"
  }
}

# ---------- WS01 ----------

resource "azurerm_public_ip" "ws01" {
  name                = "pip-ws01"
  location            = azurerm_resource_group.aum.location
  resource_group_name = azurerm_resource_group.aum.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "ws01" {
  name                = "ws01-nic"
  location            = azurerm_resource_group.aum.location
  resource_group_name = azurerm_resource_group.aum.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.aum.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ws01.id
  }

  # Wait for DC01's static IP to be reserved so this NIC can't take 10.0.1.4
  depends_on = [azurerm_network_interface.dc01]
}

resource "azurerm_windows_virtual_machine" "ws01" {
  name                              = "WS01"
  resource_group_name               = azurerm_resource_group.aum.name
  location                          = azurerm_resource_group.aum.location
  size                              = "Standard_F1ams_v7"
  admin_username                    = var.admin_username
  admin_password                    = var.admin_password
  network_interface_ids             = [azurerm_network_interface.ws01.id]
  vm_agent_platform_updates_enabled = true

  patch_mode                                             = "AutomaticByPlatform"
  patch_assessment_mode                                  = "AutomaticByPlatform"
  bypass_platform_safety_checks_on_user_schedule_enabled = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  tags = {
    Environment = "Lab3"
    Role        = "Workstation"
  }
}

# ---------- WS02 ----------

resource "azurerm_public_ip" "ws02" {
  name                = "pip-ws02"
  location            = azurerm_resource_group.aum.location
  resource_group_name = azurerm_resource_group.aum.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "ws02" {
  name                = "ws02-nic"
  location            = azurerm_resource_group.aum.location
  resource_group_name = azurerm_resource_group.aum.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.aum.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ws02.id
  }

  depends_on = [azurerm_network_interface.dc01]
}

resource "azurerm_windows_virtual_machine" "ws02" {
  name                              = "WS02"
  resource_group_name               = azurerm_resource_group.aum.name
  location                          = azurerm_resource_group.aum.location
  size                              = "Standard_F1ams_v7"
  admin_username                    = var.admin_username
  admin_password                    = var.admin_password
  network_interface_ids             = [azurerm_network_interface.ws02.id]
  vm_agent_platform_updates_enabled = true

  patch_mode                                             = "AutomaticByPlatform"
  patch_assessment_mode                                  = "AutomaticByPlatform"
  bypass_platform_safety_checks_on_user_schedule_enabled = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  tags = {
    Environment = "Lab3"
    Role        = "Workstation"
  }
}