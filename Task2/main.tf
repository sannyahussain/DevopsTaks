# main.tf

provider "azurerm" {
  features {}

  subscription_id = "466b6209-d050-463b-9aa5-f66f1d047d5e"

}

# RESOURCE GROUP was already created in task1


# VNET & SUBNETS
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = ["10.10.0.0/16"]
  location            = var.location
  resource_group_name = "DevOpsResourceGroup"
}

resource "azurerm_subnet" "subnet_vm1" {
  name                 = var.snet1_name
  resource_group_name  = "DevOpsResourceGroup"
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "subnet_vm2" {
  name                 = var.snet2_name
  resource_group_name  = "DevOpsResourceGroup"
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.2.0/24"]
}

resource "azurerm_subnet" "subnet_db" {
  name                 = var.snet_db_name
  resource_group_name  = "DevOpsResourceGroup"
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.3.0/24"]
  delegation {
    name = "dbdelegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# NSGs
resource "azurerm_network_security_group" "nsg_vm1" {
  name                = "nsg-vm1"
  location            = var.location
  resource_group_name = "DevOpsResourceGroup"
}

resource "azurerm_network_security_group" "nsg_vm2" {
  name                = "nsg-vm2"
  location            = var.location
  resource_group_name = "DevOpsResourceGroup"
}

resource "azurerm_subnet_network_security_group_association" "assoc_vm1" {
  subnet_id                 = azurerm_subnet.subnet_vm1.id
  network_security_group_id = azurerm_network_security_group.nsg_vm1.id
}

resource "azurerm_subnet_network_security_group_association" "assoc_vm2" {
  subnet_id                 = azurerm_subnet.subnet_vm2.id
  network_security_group_id = azurerm_network_security_group.nsg_vm2.id
}

resource "azurerm_network_security_rule" "allow_db_from_vm1" {
  name                        = "allow-db-from-vm1"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = "*"
  destination_address_prefix  = "10.10.3.0/24"
  source_port_range           = "*"                # Allow from any source port (required!)
  destination_port_range      = "5432"
  resource_group_name         = "DevOpsResourceGroup"
  network_security_group_name = azurerm_network_security_group.nsg_vm1.name
}

resource "azurerm_network_security_rule" "deny_db_from_vm2" {
  name                        = "deny-db-from-vm2"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_address_prefix       = "*"
  destination_address_prefix  = "10.10.3.0/24"
  source_port_range           = "*"                # Allow from any source port (required!)
  destination_port_range      = "5432"
  resource_group_name         = "DevOpsResourceGroup"
  network_security_group_name = azurerm_network_security_group.nsg_vm2.name
}

# VIRTUAL MACHINES
resource "azurerm_network_interface" "nic_vm1" {
  name                = "nic-vm1"
  location            = var.location
  resource_group_name = "DevOpsResourceGroup"
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet_vm1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "nic_vm2" {
  name                = "nic-vm2"
  location            = var.location
  resource_group_name = "DevOpsResourceGroup"
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet_vm2.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm1" {
  name                = "vm1"
  resource_group_name = "DevOpsResourceGroup"
  location            = var.location
  size                = "Standard_B1ms"
  admin_username      = "vmadmin"
  network_interface_ids = [
    azurerm_network_interface.nic_vm1.id
  ]

  admin_ssh_key {
    username   = "vmadmin"
    public_key = file("C:/Users/sannya/.ssh/id_rsa.pub")
  }

  os_disk {
    name                 = "vm1-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18_04-lts-gen2"
    version   = "latest"
  }

  disable_password_authentication = true
}

resource "azurerm_linux_virtual_machine" "vm2" {
  name                = "vm2"
  resource_group_name = "DevOpsResourceGroup"
  location            = var.location
  size                = "Standard_B1ms"
  admin_username      = "Adminuser"
  network_interface_ids = [
    azurerm_network_interface.nic_vm2.id
  ]

  admin_ssh_key {
    username   = "Adminuser"
    public_key = file("C:/Users/sannya/.ssh/id_rsa.pub")
  }

  os_disk {
    name                 = "vm2-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18_04-lts-gen2"
    version   = "latest"
  }

  disable_password_authentication = true
}

# POSTGRESQL DATABASE
resource "azurerm_postgresql_flexible_server" "db" {
  name                   = "pgsqlserver-devopstest"
  location               = var.location
  resource_group_name    = "DevOpsResourceGroup"
  administrator_login    = data.azurerm_key_vault_secret.db-user.value
  administrator_password = data.azurerm_key_vault_secret.db-password.value
  sku_name               = "B_Standard_B1ms"
  version                = "14"
  storage_mb             = 32768
  delegated_subnet_id    = azurerm_subnet.subnet_db.id
  zone                   = "1"

  authentication {
    password_auth_enabled = true
  }
      public_network_access_enabled = false

  #REQUIRED FOR PRIVATE ACCESS
  private_dns_zone_id = azurerm_private_dns_zone.postgresql_dns.id

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgresql_dns_link
  ]
}


# KEY VAULT SECRET FETCH

data "azurerm_key_vault" "kv" {
  name                = "devopsRg-test-keyvault"
  resource_group_name = "DevOpsResourceGroup"
}

data "azurerm_key_vault_secret" "db-password" {
  name         = "db-password"
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "db-user" {
  name         = "db-user"
  key_vault_id = data.azurerm_key_vault.kv.id
}



# Create Private DNS Zone for PostgreSQL Flexible Server
resource "azurerm_private_dns_zone" "postgresql_dns" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = "DevOpsResourceGroup"
}

# Link DNS zone with VNet
resource "azurerm_private_dns_zone_virtual_network_link" "postgresql_dns_link" {
  name                  = "postgresql-dns-link"
  resource_group_name   = "DevOpsResourceGroup"
  private_dns_zone_name = azurerm_private_dns_zone.postgresql_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

# Private Endpoint for PostgreSQL Flexible Server
resource "azurerm_private_endpoint" "db_pe" {
  name                = "pe-pg-db-task2"
  location            = var.location
  resource_group_name = "DevOpsResourceGroup"
  subnet_id           = azurerm_subnet.subnet_vm1.id # You can change to a dedicated subnet if needed

  private_service_connection {
    name                           = "postgresql-pe-connection"
    private_connection_resource_id = azurerm_postgresql_flexible_server.db.id
    is_manual_connection           = false
    subresource_names              = ["postgresqlServer"]
  }

  private_dns_zone_group {
    name                 = "postgresql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.postgresql_dns.id]
  }
}