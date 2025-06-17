output "vm1_private_ip" {
  value = azurerm_network_interface.nic_vm1.private_ip_address
}

output "vm2_private_ip" {
  value = azurerm_network_interface.nic_vm2.private_ip_address
}

output "postgres_server_name" {
  value = azurerm_postgresql_flexible_server.db.name
}