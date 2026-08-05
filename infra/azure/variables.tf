variable "location" {
  description = "Azure location/region"
  type        = string
  default     = "centralus"
}

variable "resource_group_name" {
  description = "Name of the resource group to create"
  type        = string
  default     = "mario-rg"
}

variable "db_admin_username" {
  description = "Postgres administrator username"
  type        = string
  default     = "pgadmin"
}

variable "db_name" {
  description = "Database name to create (used in URL)"
  type        = string
  default     = "mario"
}

variable "allowed_ip" {
  description = "CIDR or single IP allowed to access the DB (default 0.0.0.0 allows any). Override for safety."
  type        = string
  default     = "0.0.0.0"
}

variable "prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "mario"
}
