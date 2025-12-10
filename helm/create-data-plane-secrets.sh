#!/bin/bash
# Script to create all necessary Kubernetes secrets for data-plane deployment
# This should be run before deploying with Helm/ArgoCD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default namespace
NAMESPACE="${NAMESPACE:-neuraltrust}"

# Option to replace existing secrets (default: ask)
REPLACE_EXISTING="${REPLACE_EXISTING:-}"

# Function to check if secret should be replaced
should_replace_secret() {
    local secret_name=$1
    
    # If REPLACE_EXISTING is set, use it
    if [ -n "$REPLACE_EXISTING" ]; then
        if [ "$REPLACE_EXISTING" = "true" ] || [ "$REPLACE_EXISTING" = "yes" ] || [ "$REPLACE_EXISTING" = "y" ]; then
            return 0  # true
        else
            return 1  # false
        fi
    else
        # Ask user if not set
        echo -e "${YELLOW}Secret ${secret_name} already exists.${NC}"
        read -p "Do you want to replace it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            return 0  # true
        else
            return 1  # false
        fi
    fi
}

# Function to trim whitespace from a value
trim_value() {
    local value="$1"
    # Remove leading/trailing whitespace and control characters
    echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\n\r'
}

# Function to create secret
create_secret() {
    local secret_name=$1
    local key=$2
    local value=$3
    local description=$4
    
    # Trim whitespace from value
    value=$(trim_value "$value")
    
    # Check if secret already exists BEFORE asking for value
    if kubectl get secret "$secret_name" -n "$NAMESPACE" &>/dev/null; then
        if ! should_replace_secret "$secret_name"; then
            echo -e "${GREEN}Skipping secret ${secret_name} (already exists)${NC}"
            return 0
        fi
        echo -e "${YELLOW}Replacing secret ${secret_name}...${NC}"
        kubectl delete secret "$secret_name" -n "$NAMESPACE" --ignore-not-found=true
    fi
    
    if [ -z "$value" ]; then
        echo -e "${YELLOW}Warning: ${description} is empty, skipping secret ${secret_name}${NC}"
        return 0
    fi
    
    echo -e "${GREEN}Creating secret: ${secret_name} (key: ${key})${NC}"
    
    # Create secret (no Helm labels needed - Helm won't manage these secrets)
    kubectl create secret generic "$secret_name" \
        --from-literal="$key=$value" \
        -n "$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    echo -e "${GREEN}✓ Secret ${secret_name} created/updated${NC}"
}

# Function to prompt for secret value
prompt_secret() {
    local var_name=$1
    local description=$2
    local current_value="${!var_name}"
    
    if [ -n "$current_value" ]; then
        echo -e "${GREEN}Using ${var_name} from environment${NC}"
        # Trim whitespace from environment variable value
        trim_value "$current_value"
    else
        read -sp "${description}: " value
        echo
        # Trim whitespace from user input
        trim_value "$value"
    fi
}

echo "=========================================="
echo "Data Plane Secrets Creation Script"
echo "=========================================="
echo ""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --replace-existing)
            REPLACE_EXISTING="true"
            shift
            ;;
        --no-replace-existing)
            REPLACE_EXISTING="false"
            shift
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --replace-existing      Replace existing secrets without asking"
            echo "  --no-replace-existing   Skip existing secrets without asking"
            echo "  --namespace NAMESPACE   Use specified namespace (default: neuraltrust)"
            echo "  --help, -h              Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  REPLACE_EXISTING        Set to 'true' or 'false' to control replacement behavior"
            echo "  NAMESPACE               Set the namespace to use"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if namespace exists, create if not
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}Namespace ${NAMESPACE} does not exist. Creating...${NC}"
    kubectl create namespace "$NAMESPACE"
fi

echo -e "${GREEN}Using namespace: ${NAMESPACE}${NC}"
echo ""

# Data Plane JWT Secret
echo "=== Data Plane JWT Secret ==="
# Check if secret exists and ask before prompting for value
if kubectl get secret "data-plane-jwt-secret" -n "$NAMESPACE" &>/dev/null; then
    if should_replace_secret "data-plane-jwt-secret"; then
        DATA_PLANE_JWT_SECRET=$(prompt_secret "DATA_PLANE_JWT_SECRET" "Enter Data Plane JWT Secret (or set DATA_PLANE_JWT_SECRET env var)")
        if [ -n "$DATA_PLANE_JWT_SECRET" ]; then
            create_secret "data-plane-jwt-secret" "DATA_PLANE_JWT_SECRET" "$DATA_PLANE_JWT_SECRET" "Data Plane JWT Secret"
        fi
    fi
else
    DATA_PLANE_JWT_SECRET=$(prompt_secret "DATA_PLANE_JWT_SECRET" "Enter Data Plane JWT Secret (or set DATA_PLANE_JWT_SECRET env var)")
    if [ -n "$DATA_PLANE_JWT_SECRET" ]; then
        create_secret "data-plane-jwt-secret" "DATA_PLANE_JWT_SECRET" "$DATA_PLANE_JWT_SECRET" "Data Plane JWT Secret"
    fi
fi
echo ""

# OpenAI API Key
echo "=== OpenAI API Key ==="
if kubectl get secret "openai-secrets" -n "$NAMESPACE" &>/dev/null; then
    if should_replace_secret "openai-secrets"; then
        OPENAI_API_KEY=$(prompt_secret "OPENAI_API_KEY" "Enter OpenAI API Key (or set OPENAI_API_KEY env var, optional)")
        if [ -n "$OPENAI_API_KEY" ]; then
            create_secret "openai-secrets" "OPENAI_API_KEY" "$OPENAI_API_KEY" "OpenAI API Key"
        fi
    fi
else
    OPENAI_API_KEY=$(prompt_secret "OPENAI_API_KEY" "Enter OpenAI API Key (or set OPENAI_API_KEY env var, optional)")
    if [ -n "$OPENAI_API_KEY" ]; then
        create_secret "openai-secrets" "OPENAI_API_KEY" "$OPENAI_API_KEY" "OpenAI API Key"
    fi
fi
echo ""

# Google API Key
echo "=== Google API Key ==="
if kubectl get secret "google-secrets" -n "$NAMESPACE" &>/dev/null; then
    if should_replace_secret "google-secrets"; then
        GOOGLE_API_KEY=$(prompt_secret "GOOGLE_API_KEY" "Enter Google API Key (or set GOOGLE_API_KEY env var, optional)")
        if [ -n "$GOOGLE_API_KEY" ]; then
            create_secret "google-secrets" "GOOGLE_API_KEY" "$GOOGLE_API_KEY" "Google API Key"
        fi
    fi
else
    GOOGLE_API_KEY=$(prompt_secret "GOOGLE_API_KEY" "Enter Google API Key (or set GOOGLE_API_KEY env var, optional)")
    if [ -n "$GOOGLE_API_KEY" ]; then
        create_secret "google-secrets" "GOOGLE_API_KEY" "$GOOGLE_API_KEY" "Google API Key"
    fi
fi
echo ""

# Resend API Key
echo "=== Resend API Key ==="
if kubectl get secret "resend-secrets" -n "$NAMESPACE" &>/dev/null; then
    if should_replace_secret "resend-secrets"; then
        RESEND_API_KEY=$(prompt_secret "RESEND_API_KEY" "Enter Resend API Key (or set RESEND_API_KEY env var, optional)")
        if [ -n "$RESEND_API_KEY" ]; then
            create_secret "resend-secrets" "RESEND_API_KEY" "$RESEND_API_KEY" "Resend API Key"
        fi
    fi
else
    RESEND_API_KEY=$(prompt_secret "RESEND_API_KEY" "Enter Resend API Key (or set RESEND_API_KEY env var, optional)")
    if [ -n "$RESEND_API_KEY" ]; then
        create_secret "resend-secrets" "RESEND_API_KEY" "$RESEND_API_KEY" "Resend API Key"
    fi
fi
echo ""

# Hugging Face Token
echo "=== Hugging Face Token ==="
if kubectl get secret "huggingface-secrets" -n "$NAMESPACE" &>/dev/null; then
    if should_replace_secret "huggingface-secrets"; then
        HUGGINGFACE_TOKEN=$(prompt_secret "HUGGINGFACE_TOKEN" "Enter Hugging Face Token (or set HUGGINGFACE_TOKEN env var, optional)")
        if [ -n "$HUGGINGFACE_TOKEN" ]; then
            create_secret "huggingface-secrets" "HUGGINGFACE_TOKEN" "$HUGGINGFACE_TOKEN" "Hugging Face Token"
        fi
    fi
else
    HUGGINGFACE_TOKEN=$(prompt_secret "HUGGINGFACE_TOKEN" "Enter Hugging Face Token (or set HUGGINGFACE_TOKEN env var, optional)")
    if [ -n "$HUGGINGFACE_TOKEN" ]; then
        create_secret "huggingface-secrets" "HUGGINGFACE_TOKEN" "$HUGGINGFACE_TOKEN" "Hugging Face Token"
    fi
fi
echo ""

# ClickHouse Password
echo "=== ClickHouse Password ==="
if kubectl get secret "clickhouse" -n "$NAMESPACE" &>/dev/null; then
    if should_replace_secret "clickhouse"; then
        CLICKHOUSE_PASSWORD=$(prompt_secret "CLICKHOUSE_PASSWORD" "Enter ClickHouse Password (or set CLICKHOUSE_PASSWORD env var)")
        if [ -z "$CLICKHOUSE_PASSWORD" ]; then
            # Generate a random password if not provided
            CLICKHOUSE_PASSWORD=$(openssl rand -base64 32)
            echo -e "${YELLOW}No password provided, generated random password${NC}"
        fi
        create_secret "clickhouse" "admin-password" "$CLICKHOUSE_PASSWORD" "ClickHouse Admin Password"
    fi
else
    CLICKHOUSE_PASSWORD=$(prompt_secret "CLICKHOUSE_PASSWORD" "Enter ClickHouse Password (or set CLICKHOUSE_PASSWORD env var)")
    if [ -z "$CLICKHOUSE_PASSWORD" ]; then
        # Generate a random password if not provided
        CLICKHOUSE_PASSWORD=$(openssl rand -base64 32)
        echo -e "${YELLOW}No password provided, generated random password${NC}"
    fi
    create_secret "clickhouse" "admin-password" "$CLICKHOUSE_PASSWORD" "ClickHouse Admin Password"
fi
echo ""

# Check if gcr-secret exists
echo "=== GCR Secret (for private Docker registry) ==="
if kubectl get secret gcr-secret -n "$NAMESPACE" &>/dev/null; then
    echo -e "${GREEN}GCR secret already exists${NC}"
else
    echo -e "${YELLOW}GCR secret not found.${NC}"
    echo "To create it, run:"
    echo "  kubectl create secret docker-registry gcr-secret \\"
    echo "    --docker-server=europe-west1-docker.pkg.dev \\"
    echo "    --docker-username=_json_key \\"
    echo "    --docker-password=\"\$(cat path/to/gcr-keys.json)\" \\"
    echo "    --docker-email=admin@neuraltrust.ai \\"
    echo "    -n ${NAMESPACE}"
    echo ""
    read -p "Do you want to create it now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter path to GCR keys JSON file: " gcr_key_path
        # Trim whitespace from path
        gcr_key_path=$(trim_value "$gcr_key_path")
        if [ -f "$gcr_key_path" ]; then
            # Read and trim the JSON content
            gcr_key_content=$(cat "$gcr_key_path" | tr -d '\n\r')
            kubectl create secret docker-registry gcr-secret \
                --docker-server=europe-west1-docker.pkg.dev \
                --docker-username=_json_key \
                --docker-password="$gcr_key_content" \
                --docker-email=admin@neuraltrust.ai \
                -n "$NAMESPACE" \
                --dry-run=client -o yaml | kubectl apply -f -
            echo -e "${GREEN}✓ GCR secret created${NC}"
        else
            echo -e "${RED}Error: File not found: $gcr_key_path${NC}"
        fi
    fi
fi
echo ""

echo "=========================================="
echo -e "${GREEN}All secrets created successfully!${NC}"
echo "=========================================="
echo ""
echo "You can now deploy using Helm with secret references:"
echo "  helm upgrade --install data-plane ./neuraltrust/data-plane \\"
echo "    --namespace ${NAMESPACE} \\"
echo "    -f ./neuraltrust/values-neuraltrust.yaml \\"
echo "    -f ./neuraltrust/values-data-plane-secrets.yaml \\"
echo "    --set dataPlane.imagePullSecrets=\"gcr-secret\""
echo ""

