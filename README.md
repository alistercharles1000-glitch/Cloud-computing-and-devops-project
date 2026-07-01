# Image Vault — Scripted Infrastructure as Code

A small web application that lets users upload images to Azure Blob Storage and view/download everything that's been uploaded. All infrastructure is defined with Terraform; the app is deployed automatically via a GitHub Actions pipeline.

## Description

The application has two pages:

- **Files** (`/`) — lists every blob in the storage container with a download link for each.
- **Upload** (`/upload`) — a form to upload a new image, which is saved to the storage container.

The storage connection string is never hardcoded. It is stored in Azure Key Vault, and the App Service reads it at runtime using its system-assigned managed identity.

## Approach

**Cloud provider:** Microsoft Azure (Azure for Students subscription)
**IaC tool:** Terraform (`azurerm` provider, ~> 3.0)
**App framework:** Flask (Python)
**CI/CD:** GitHub Actions

Design priorities :

1. No secrets in code or in Git and everything sensitive lives in Key Vault.
2. Clean separation between infrastructure (`infra/`) and application code (`app/`), so each can be worked on independently.

## Connections Between Resources

```
Browser
  └──► App Service (app-imageapp-dev)
          ├── reads KEY_VAULT_URL from its app settings
          ├──► Key Vault (kv-imageapp-dev)
          │       └── returns StorageConnectionString secret
          └──► Storage Account (stimageappdev) → "images" container
                  ├── list_blobs()   → powers the Files page
                  └── upload_blob()  → powers the Upload page
```

1. A user's browser talks only to the App Service's public URL.
2. On each request that needs storage data, the Flask app calls Key Vault to retrieve the storage connection string.
3. The Flask app uses that connection string to either list blobs (`/`) or upload a new one (`/upload`).

## Authentication / Identity Context

The App Service never has direct credentials to the storage account. It authenticates to Key Vault using its managed identity (`DefaultAzureCredential()` in `app.py`), retrieves the storage connection string from there, and uses that to talk to Blob Storage. This means no password, key, or token exists in the source code, the Terraform files, or the pipeline, only in Key Vault, gated behind identity based access.

The GitHub Actions pipeline is intentionally scoped to deployment only: its publish-profile credential can push code to the App Service, but has no access to Key Vault or Storage.

## Repository Content (Git)

```
imageapp/
├── infra/                          # Part I — Terraform infrastructure
│   ├── provider.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── outputs.tf
├── app/                             # Part II — Test application
│   ├── app.py
│   ├── requirements.txt
│   └── templates/
│       ├── base.html
│       ├── index.html               # Web Page 1 — file list + download links
│       └── upload.html              # Web Page 2 — upload form
├── .github/workflows/
│   └── deploy.yml                   # Build/Deployment Pipeline YAML
├── deploy.sh                        # Manual deployment script
└── README.md
```

## Terraform Definition

See `infra/main.tf`.

Resource summary:

`azurerm_resource_group.rg` | Container for all resources  
 `azurerm_storage_account.storage` + `azurerm_storage_container.images` | Stores uploaded images  
 `azurerm_key_vault.kv` + `azurerm_key_vault_secret.storage_connection` | Securely stores the storage connection string  
 `azurerm_role_assignment.developer_secrets_admin` / `.app_service_secrets_user` | Grants Key Vault access — full for the developer, read-only for the app
`azurerm_service_plan.plan` + `azurerm_linux_web_app.app` | Hosts the Flask app (Free F1 tier, Linux, system-assigned identity)

### Deploying the infrastructure

```bash
cd infra
az login
terraform init
terraform plan
terraform apply
```

## Pipeline YAML

`.github/workflows/deploy.yml` runs on every push to `main` that touches the `app/` folder. It:

1. Installs Python dependencies into a build folder.
2. Zips the app into a deployable package.
3. Deploys that package to the App Service using its publish profile.

### One-time setup to make the pipeline work

```bash
# Get the publish profile for your App Service
az webapp deployment list-publishing-profiles \
  --name app-imageapp-dev \
  --resource-group rg-imageapp-dev \
  --xml
```

## Running the app locally

```bash
cd app
pip install -r requirements.txt
az login   # so DefaultAzureCredential can authenticate locally too
export KEY_VAULT_URL="https://kv-imageapp-dev.vault.azure.net/"
export STORAGE_CONTAINER_NAME="images"
python app.py
```

Then open (http://127.0.0.1:8000/) in your browser.

## Deployment Script

```bash
./deploy.sh
```

It zips the `app/` folder and pushes it to the App Service using the Azure CLI (`az webapp deploy`).

## Web Pages

- **Web Page 1 — Files (`/`):** shows every blob currently in the storage container, with its size and a download link.
- **Web Page 2 — Upload (`/upload`):** a form to choose and upload a new file, which then appears on the Files page.
