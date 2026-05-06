output "azure_storage_account" {
  value = azurerm_storage_account.pucar_tfstate.name
}

output "resource_group" {
  value = azurerm_resource_group.pucar_resource_group.name
}

output "storage_container_name" {
  value = azurerm_storage_container.pucar_tfstate.name
}