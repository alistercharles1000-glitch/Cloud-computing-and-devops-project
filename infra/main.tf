# Retrieve the current Azure client (your logged-in account / service principal).
# Used to grant your own account Key Vault access during setup.
data "azurerm_client_config" "current" {}


# Resource Group
# All resources for this project live inside a single resource group.

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
}


# Storage Account + Blob Container
# Stores the uploaded images.
# The container uses "blob" access so that
# individual files can be read publicly via their URL (needed for the
# "show all blobs" page).

resource "azurerm_storage_account" "storage" {
  name                     = "st${var.project_name}${var.environment}2"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = var.environment
    project     = var.project_name
  }
}

resource "azurerm_storage_container" "images" {
  name                  = "images"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "blob"
}


# Key Vault
# Stores the storage account connection string as a secret.
# The App Service retrieves it at runtime using its managed identity,
# no credentials are ever stored in code or environment variables.

resource "azurerm_key_vault" "kv" {
  name                      = "kv-${var.project_name}-${var.environment}"
  location                  = azurerm_resource_group.rg.location
  resource_group_name       = azurerm_resource_group.rg.name
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = "standard"
  
  # Switched from Access Policies to RBAC authorization
  enable_rbac_authorization = true 

  tags = {
    environment = var.environment
    project     = var.project_name
  }
}

# Grant yout account Administrator access to the vault.
# This lets you read/write secrets during development.
resource "azurerm_role_assignment" "developer_secrets_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Store the storage connection string as a Key Vault secret.
resource "azurerm_key_vault_secret" "storage_connection" {
  name         = "StorageConnectionString"
  value        = azurerm_storage_account.storage.primary_connection_string
  key_vault_id = azurerm_key_vault.kv.id

  # Must wait for the developer to have permissions before creating the secret
  depends_on = [azurerm_role_assignment.developer_secrets_admin]
}


# App Service Plan + App Service
# The plan defines the compute tier 
# The App Service hosts the Flask web application.

resource "azurerm_service_plan" "plan" {
  name                = "plan-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "F1"
}

resource "azurerm_linux_web_app" "app" {
  name                = "app-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  # System-assigned managed identity.
  # Azure generates an identity for this app automatically.
  # We use its principal_id below to grant Key Vault access.
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }
    # Tells Azure how to start the Flask app after deployment.
    # "app" here refers to app.py, and the second "app" is the Flask
    # instance variable (app = Flask(__name__)) inside it.
    app_command_line = "gunicorn --bind=0.0.0.0 --timeout 600 app:app"
    always_on        = false # must be false on Free tier
  }

  # Pass configuration into the app as environment variables.
  # The app uses KEY_VAULT_URL to look up the storage connection string
  # at runtime, instead of having it hardcoded anywhere.
  app_settings = {
    "KEY_VAULT_URL"                   = azurerm_key_vault.kv.vault_uri
    "STORAGE_CONTAINER_NAME"          = azurerm_storage_container.images.name
    "SCM_DO_BUILD_DURING_DEPLOYMENT"  = "true"
  }

  tags = {
    environment = var.environment
    project     = var.project_name
  }
}


# Key Vault Role Assignment : App Service Managed Identity
# Grants the App Service permission to get secrets from Key Vault.
# It can only read, not write : principle of least privilege.

resource "azurerm_role_assignment" "app_service_secrets_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id

  depends_on = [azurerm_linux_web_app.app]
}