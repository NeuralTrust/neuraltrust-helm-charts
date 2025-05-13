#!/bin/bash

# Read values from auth.tfvars
CLIENT_ID=$(grep client_id auth.tfvars | cut -d'=' -f2 | tr -d ' "')
CLIENT_SECRET=$(grep client_secret auth.tfvars | cut -d'=' -f2 | tr -d ' "')
SUBSCRIPTION_ID=$(grep subscription_id auth.tfvars | cut -d'=' -f2 | tr -d ' "')
TENANT_ID=$(grep tenant_id auth.tfvars | cut -d'=' -f2 | tr -d ' "')

# Get the access token using service principal credentials
TOKEN=$(curl -s -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&resource=https://management.azure.com/" \
  "https://login.microsoftonline.com/${TENANT_ID}/oauth2/token" | jq -r '.access_token')

# Function to register a provider
register_provider() {
    local provider=$1
    echo "Registering provider: $provider"
    curl -s -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -H "Content-Length: 2" \
        -d "{}" \
        "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/providers/$provider/register?api-version=2019-05-01"
    echo
}

# Register required providers
register_provider "Microsoft.Network"
register_provider "Microsoft.ContainerService"
register_provider "Microsoft.Compute"

echo "Provider registration initiated. It may take a few minutes to complete." 