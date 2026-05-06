output "azurerm_postgresql_flexible_server" {
  value = "${azurerm_postgresql_flexible_server.pucar_postgres.name}"
}

output "postgresql_flexible_server_database_name" {
  value = "${azurerm_postgresql_flexible_server_database.pucar_postgres_db.name}"
}

output "postgresql_flexible_server_admin_password" {
  value     = "${azurerm_postgresql_flexible_server.pucar_postgres.administrator_password}"
}
