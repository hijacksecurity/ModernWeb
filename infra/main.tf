terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.3.0"
}

provider "azurerm" {
  subscription_id = var.subscription_id

  features {}
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.project_name}-pg"
  location               = var.location
  resource_group_name    = azurerm_resource_group.main.name
  administrator_login    = var.db_admin_username
  administrator_password = var.db_admin_password

  version                = "13"
  sku_name               = "B_Standard_B1ms" # Corrected SKU name
  storage_mb             = 32768
  zone                   = "1"

  authentication {
    active_directory_auth_enabled = false
    password_auth_enabled         = true
  }
}

resource "azurerm_postgresql_flexible_server_database" "default" {
  name      = "appdb"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_container_registry" "acr" {
  name                = "${var.project_name}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_container_app_environment" "env" {
  name                = "${var.project_name}-env"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

}

resource "azurerm_container_app" "app" {
  name                         = "${var.project_name}-app"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  template {
    container {
      name   = "fastapi"
      image  = "${azurerm_container_registry.acr.login_server}/modernweb-api:latest"

      env {
        name  = "ENV"
        value = "test"
      }

      env {
        name  = "DB_HOST"
        value = azurerm_postgresql_flexible_server.main.fqdn
      }

      env {
        name  = "DB_NAME"
        value = azurerm_postgresql_flexible_server_database.default.name
      }

      env {
        name  = "DB_USER"
        value = var.db_admin_username
      }

      env {
        name  = "DB_PASS"
        value = var.db_admin_password
      }

      cpu    = 0.5
      memory = "1.0Gi"
    }
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "auto"

    traffic_weight {
      percentage      = 100     # ✅ Send all traffic to latest revision
      latest_revision = true
    }
  }
}

# PROD PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "prod" {
  name                   = "modernweb-pg-prod"
  location               = azurerm_resource_group.main.location
  resource_group_name    = azurerm_resource_group.main.name
  administrator_login    = "pgadmin"
  administrator_password = var.prod_pg_admin_password
  sku_name               = "B_Standard_B1ms"
  version                = "13"
  storage_mb             = 32768
  zone                   = "1"
  public_network_access_enabled = true

  authentication {
    password_auth_enabled = true
    active_directory_auth_enabled = false
  }
}

resource "azurerm_postgresql_flexible_server_database" "prod" {
  name      = "appdb"
  server_id = azurerm_postgresql_flexible_server.prod.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "prod" {
  name         = "allow-all-azure"
  server_id    = azurerm_postgresql_flexible_server.prod.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# PROD Container App
resource "azurerm_container_app" "prod" {
  name                         = "modernweb-prod"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.env.id
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  template {
    container {
      name   = "fastapi"
      image  = "${azurerm_container_registry.acr.login_server}/modernweb-api:v1.0.4"
      cpu    = 0.5
      memory = "1.0Gi"

      env {
        name  = "DB_HOST"
        value = azurerm_postgresql_flexible_server.prod.fqdn
      }
      env {
        name  = "DB_NAME"
        value = azurerm_postgresql_flexible_server_database.prod.name
      }
      env {
        name  = "DB_USER"
        value = "pgadmin"
      }
      env {
        name  = "DB_PASS"
        value = var.prod_pg_admin_password
      }
      env {
        name  = "ENV"
        value = "prod"
      }
    }
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }

  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }

  ingress {
    external_enabled = true
    target_port      = 8000

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

resource "azurerm_role_assignment" "container_app_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.prod.identity[0].principal_id
}

