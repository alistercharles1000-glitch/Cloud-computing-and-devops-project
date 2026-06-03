# Retrieve the current Azure client 
# Used to grant Key Vault access during setup.
data "azurerm_client_config" "current" {}


# Resource Group
# All resources live inside a single resource group.
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
}


# Storage Account + Blob Container
resource "azurerm_storage_account" "storage" {
  name                     = "st${var.project_name}${var.environment}"
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
# The App Service retrieves it at runtime using its managed identity 
# No credentials are ever stored in code or environment variables.
resource "azurerm_key_vault" "kv" {
  name                = "kv-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  tags = {
    environment = var.environment
    project     = var.project_name
  }
}

# Grant account full access to the vault
resource "azurerm_key_vault_access_policy" "deployer" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "List", "Set", "Delete", "Purge"]
}

# Store the storage connection string as a Key Vault secret.
resource "azurerm_key_vault_secret" "storage_connection" {
  name         = "StorageConnectionString"
  value        = azurerm_storage_account.storage.primary_connection_string
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_key_vault_access_policy.deployer]
}


# App Service Plan + App Service
# Mentions the subscription plan type (Free F1 tier)
# The App Service will host the Python web application.
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
  # We use its object_id below to grant Key Vault access.
  # We assign false to always on because the free tier means that the app will sleep when idle.
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }
    always_on = false # must be false on Free tier
  }


  # Pass the Key Vault URL into the app as an environment variable.
  # The app uses this to look up the storage connection string at runtime.
  app_settings = {
    "KEY_VAULT_URL"             = azurerm_key_vault.kv.vault_uri
    "STORAGE_CONTAINER_NAME"    = azurerm_storage_container.images.name
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
  }

  tags = {
    environment = var.environment
    project     = var.project_name
  }
}


# Key Vault Access Policy — App Service Managed Identity
# Grants the App Service permission to GET secrets from Key Vault.
# It can only read, not write — principle of least privilege.
resource "azurerm_key_vault_access_policy" "app_service" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.app.identity[0].principal_id

  secret_permissions = ["Get", "List"]

  depends_on = [azurerm_linux_web_app.app]
}
