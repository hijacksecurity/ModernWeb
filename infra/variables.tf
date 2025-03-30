variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "resource_group_name" {
  type        = string
  default     = "modern-web-rg"
}

variable "location" {
  type        = string
  default     = "eastus"
}

variable "project_name" {
  type        = string
  default     = "modernweb"
}

variable "db_admin_username" {
  type        = string
  default     = "pgadmin"
}

variable "db_admin_password" {
  type        = string
  description = "Database admin password"
  sensitive   = true
}

variable "prod_pg_admin_password" {
  description = "The admin password for the PROD PostgreSQL server"
  type        = string
  sensitive   = true
}