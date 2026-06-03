# Part 1

This repository defines the cloud infrastructure for a web application that stores and displays images. Users can upload image files through a web form, which are saved to an Azure blob storage container.

All infrastructure is defined as code using Terraform, targeting Microsoft Azure.

# Cloud Provider: Microsoft Azure (Azure for Students subscription)

Tool: Terraform v1.3+ with the `azurerm` provider (~> 3.0)

Design principles:

- Avoid hardcoded secrets — the storage connection string lives in Key Vault, not in code or environment variables
- Use a managed identity

Resource naming convention: All resources use the pattern `<type>-<project>-<environment>`,e.g. `rg-imageapp-dev`. The storage account omits hyphens because Azure does not allow them in storage account names.

# Connections Between Resources

1. The browser makes HTTP requests to the App Service public URL.
2. The App Service reads KEY_VAULT_URL from its application settings (set by Terraform).
3. At startup, the app fetches the Connection String secret from Key Vault using the Azure SDK.
4. The app uses that connection string to list and upload blobs in the images container.

# Managed Identity

is the key security pattern here. Azure automatically creates an identity for the App Service and sends a credential into the runtime environment. The app calls DefaultAzureCredential() from the Azure SDK — no usernames, passwords, or API keys appear anywhere in the code or Terraform files.
The access policy for the App Service grants only Get and List on secrets (principle of least privilege). It cannot create or delete secrets.

# Repository Structure

provider.tf
variables.tf  
main.tf
outputs.tf
README.md
