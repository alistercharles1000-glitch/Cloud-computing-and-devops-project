#!/usr/bin/env bash
#
# Deploys the Flask application in ./app to the Azure App Service
# provisioned by the Terraform in ./infra.
#
# Prerequisites:
#   - Azure CLI installed and logged in (az login)
#   - The infrastructure already created (terraform apply, run from ./infra)
#
# Usage:
#   ./deploy.sh

set -euo pipefail

RESOURCE_GROUP="rg-imageapp-dev"
APP_NAME="app-imageapp-dev"
APP_DIR="app"
ZIP_FILE="release.zip"

echo "==> Packaging application from ./$APP_DIR"
rm -f "$ZIP_FILE"
(cd "$APP_DIR" && zip -r "../$ZIP_FILE" . -x "*.pyc" "__pycache__/*" > /dev/null)

echo "==> Deploying to Azure App Service: $APP_NAME (resource group: $RESOURCE_GROUP)"
az webapp deploy \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --src-path "$ZIP_FILE" \
  --type zip

echo "==> Cleaning up local artifact"
rm -f "$ZIP_FILE"

echo "==> Done. App should be live at:"
echo "    https://$APP_NAME.azurewebsites.net"
