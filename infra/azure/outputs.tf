output "database_url" {
  description = "Postgres connection URL (postgres://user:pass@host:port/dbname)"
  value       = "postgres://${var.db_admin_username}:${random_password.db_password.result}@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/${var.db_name}"
  sensitive   = true
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.postgres.fqdn
}
