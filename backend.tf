terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "tfstateaumlab0783"
    container_name       = "tfstate"
    key                  = "aum-lab.tfstate"
  }
}