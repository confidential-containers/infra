resource "azurerm_resource_group" "garm_rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_user_assigned_identity" "garm_id" {
  name                = "garm"
  location            = azurerm_resource_group.garm_rg.location
  resource_group_name = azurerm_resource_group.garm_rg.name
}

data "azurerm_subscription" "current" {
}

data "azurerm_client_config" "current" {
}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  special = false
}

resource "azurerm_role_assignment" "garm_role_as" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.garm_id.principal_id
}

resource "azurerm_storage_account" "garm_sa" {
  name                     = "garm${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.garm_rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "garm_share" {
  name                 = "garm-etc-folder"
  storage_account_name = azurerm_storage_account.garm_sa.name
  quota                = 10

  lifecycle {
    prevent_destroy = true
  }
}

resource "random_password" "garm_jwt_secret" {
  length = 32
}

// needs to be >= 32 characters
resource "random_password" "garm_db_passphrase" {
  length = 32
}

resource "random_password" "garm_admin_pw" {
  length = 32
}

locals {
  dns_name_label = "garm-${random_string.suffix.result}"
  fqdn           = "${local.dns_name_label}.${var.location}.azurecontainer.io"
}

resource "azurerm_container_group" "garm_aci" {
  name                = "garm-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.garm_rg.name
  ip_address_type     = "Public"
  os_type             = "Linux"
  dns_name_label      = local.dns_name_label

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.garm_id.id,
    ]
  }

  init_container {
    name  = "init"
    image = var.garm_image

    environment_variables = {
      GARM_HOSTNAME   = local.fqdn
      SUBSCRIPTION_ID = data.azurerm_subscription.current.subscription_id
      AZURE_CLIENT_ID = azurerm_user_assigned_identity.garm_id.client_id
      VM_LOCATION     = var.vm_location
    }

    secure_environment_variables = {
      GARM_JWT_SECRET    = random_password.garm_jwt_secret.result
      GARM_DB_PASSPHRASE = random_password.garm_db_passphrase.result
      GARM_ADMIN_PW      = random_password.garm_admin_pw.result
      GITHUB_CONFIG      = jsonencode(var.github_config)
    }

    volume {
      name                 = "init"
      mount_path           = "/etc/garm"
      read_only            = false
      share_name           = azurerm_storage_share.garm_share.name
      storage_account_name = azurerm_storage_account.garm_sa.name
      storage_account_key  = azurerm_storage_account.garm_sa.primary_access_key
    }

    commands = [
      "/init.sh",
    ]
  }

  container {
    name   = "garm"
    image  = var.garm_image
    cpu    = "1.0"
    memory = "0.5"

    volume {
      name                 = "garm"
      mount_path           = "/etc/garm"
      read_only            = false
      share_name           = azurerm_storage_share.garm_share.name
      storage_account_name = azurerm_storage_account.garm_sa.name
      storage_account_key  = azurerm_storage_account.garm_sa.primary_access_key
    }

    commands = [
      "garm",
      "-config",
      "/etc/garm/config.toml",
    ]
  }

  container {
    name   = "caddy"
    image  = var.caddy_image
    cpu    = "1.0"
    memory = "0.5"

    volume {
      name                 = "caddy"
      mount_path           = "/data"
      read_only            = false
      share_name           = azurerm_storage_share.garm_share.name
      storage_account_name = azurerm_storage_account.garm_sa.name
      storage_account_key  = azurerm_storage_account.garm_sa.primary_access_key
    }

    ports {
      port     = 80
      protocol = "TCP"
    }

    ports {
      port     = 443
      protocol = "TCP"
    }

    commands = [
      "caddy",
      "reverse-proxy",
      "--from",
      local.fqdn,
      "--to",
      "localhost:9997",
    ]
  }
}

output "webhook_url" {
  value = "https://${local.fqdn}/webhooks"
}

output "container_group_name" {
  value = azurerm_container_group.garm_aci.name
}
