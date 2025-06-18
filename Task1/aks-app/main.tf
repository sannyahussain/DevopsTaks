terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "azurerm" {
  features {}
  subscription_id = "466b6209-d050-463b-9aa5-f66f1d047d5e"

}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "main-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "jumpbox_subnet" {
  name                 = "jumpbox-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}


resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet" # this name is required
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.4.0/24"]
}
module "bastion" {
  source              = "./modules/bastion"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  subnet_id           = azurerm_subnet.bastion_subnet.id
}
module "jumpbox" {
  source              = "./modules/jumpbox"
  vm_name             = var.vm_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.jumpbox_subnet.id
  admin_username      = var.admin_username
}

module "storage" {
  source                    = "./modules/storage"
  storage_account_name      = var.storage_account_name
  container_name            = var.container_name
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = var.location
  user_assigned_identity_id = module.managed-identity.identity_id

}
module "app-gateway" {
  source              = "./modules/app-gateway"
  appgateway_name     = var.appgateway_name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.appgw_subnet.id
}
resource "azurerm_role_assignment" "blob_data_contributor" {
  scope                = module.storage.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.managed-identity.principal_id
}

module "managed-identity" {
  source              = "./modules/managed-identity"
  identity_name       = var.identity_name
  location            = var.location
  resource_group_name = var.resource_group_name
}
module "aks_cluster" {
  source              = "./modules/aks_cluster"
  aks_name            = var.aks_name
  dns_prefix          = var.dns_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.aks_subnet.id
  vm_size             = var.vm_size
}

