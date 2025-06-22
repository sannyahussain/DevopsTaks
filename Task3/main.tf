terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "azurerm" {
  subscription_id = "466b6209-d050-463b-9aa5-f66f1d047d5e"
  features {
    
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
      
    }
  }
}

#-------------------- VNET AND SUBNETS --------------------#
resource "azurerm_virtual_network" "main" {
  name                = "devops-vnet"
  address_space       = ["10.20.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group
}

resource "azurerm_subnet" "function_subnet" {
  name                 = "function-subnet"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.1.0/24"]

  delegation {
    name = "function-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "private_endpoint_subnet" {
  name                 = "private-endpoint-subnet"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.2.0/24"]
}

#-------------------- PRIVATE DNS ZONES --------------------#
resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault_link" {
  name                  = "keyvault-vnet-link"
  resource_group_name   = var.resource_group
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

#-------------------- STORAGE ACCOUNTS --------------------#
resource "azurerm_storage_account" "source" {
  name                     = var.source_storage_name
  resource_group_name      = var.resource_group
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  is_hns_enabled = false
}

resource "azurerm_storage_container" "source_container" {
  name                  = "source-container"
  storage_account_id    = azurerm_storage_account.source.id
  container_access_type = "private"
}

resource "azurerm_storage_account" "destination" {
  name                     = var.destination_storage_name
  resource_group_name      = var.resource_group
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true # Required for Data Lake Gen2
}

resource "azurerm_storage_container" "destination_container" {
  name                  = "destination-container"
  storage_account_id    = azurerm_storage_account.destination.id
  container_access_type = "private"
}

#-------------------- KEY VAULT --------------------#
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "private_kv" {
  name                          = "kv-func-private"
  location                      = var.location
  resource_group_name           = var.resource_group
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  purge_protection_enabled      = true
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

resource "azurerm_private_endpoint" "keyvault_pe" {
  name                = "kv-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id

  private_service_connection {
    name                           = "kv-privatesc"
    private_connection_resource_id = azurerm_key_vault.private_kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "keyvault-dnszone"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }
}

#-------------------- FUNCTION APP --------------------#
resource "azurerm_storage_account" "function_storage" {
  name                     = "funcstor${random_id.unique_id.hex}"
  resource_group_name      = var.resource_group
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "random_id" "unique_id" {
  byte_length = 4
}

resource "azurerm_service_plan" "function_plan" {
  name                = "function-plan"
  location            = var.location
  resource_group_name = var.resource_group
  os_type = "Linux"
  sku_name = "P1v2"
}
resource "azurerm_linux_function_app" "function" {
  name                       = "blob-trigger-func"
  location                   = var.location
  resource_group_name        = var.resource_group
  service_plan_id            = azurerm_service_plan.function_plan.id
  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key

  site_config {
    application_stack {
      python_version = "3.10"
    }
    vnet_route_all_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }
}


resource "azurerm_key_vault_access_policy" "function_kv" {
  key_vault_id = azurerm_key_vault.private_kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_function_app.function.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}
