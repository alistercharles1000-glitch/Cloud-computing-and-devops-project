output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "app_service_name" {
  description = "Name of the App Service (used by the deploy script and pipeline)"
  value       = azurerm_linux_web_app.app.name
}

output "app_service_url" {
  description = "Public URL of the deployed web application"
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.storage.name
}

output "storage_container_name" {
  description = "Name of the blob container"
  value       = azurerm_storage_container.images.name
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.kv.name
}

output "key_vault_url" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.kv.vault_uri
}
