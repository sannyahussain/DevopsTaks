
output "source_storage_account" {
  value = azurerm_storage_account.source.name
}

output "destination_storage_account" {
  value = azurerm_storage_account.destination.name
}

output "function_app_name" {
  value = azurerm_linux_function_app.function.name
}

output "function_identity" {
  value = azurerm_linux_function_app.function.identity[0].principal_id
}
