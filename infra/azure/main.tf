resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "random_id" "suffix" {
  byte_length = 2
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
}

resource "azurerm_postgresql_flexible_server" "postgres" {
  name                = "${var.prefix}-${random_id.suffix.hex}"
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = "13"

  sku_name                  = "B_Standard_B1ms"
  storage_mb                = 32768
  backup_retention_days     = 7

  administrator_login      = var.db_admin_username
  administrator_password   = random_password.db_password.result

  public_network_access_enabled = true
  delegated_subnet_id          = null
}

resource "azurerm_postgresql_flexible_server_database" "db" {
  name      = var.db_name
  server_id = azurerm_postgresql_flexible_server.postgres.id
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_my_ip" {
  name             = "allow_client"
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = var.allowed_ip
  end_ip_address   = var.allowed_ip
}
