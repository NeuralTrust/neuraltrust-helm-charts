#!/bin/bash

set -e

shopt -s expand_aliases

# Source common functions
source scripts/common.sh

# Initialize variables
NAMESPACE=""
DEFAULT_NAMESPACE="neuraltrust"
VALUES_FILE="./neuraltrust/values-neuraltrust.yaml"

# Parse command line arguments
RELEASE_NAME="data-plane"
AVOID_NEURALTRUST_PRIVATE_REGISTRY=false # if false, uses NeuralTrust private registry (GCP)
SKIP_INGRESS=false # if true, skips ingress-nginx installation

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --namespace)
      NAMESPACE="$2"
      shift
      shift
      ;;
    --release-name)
      RELEASE_NAME="$2"
      shift
      shift
      ;;
    --avoid-neuraltrust-private-registry)
      AVOID_NEURALTRUST_PRIVATE_REGISTRY=true
      shift
      ;;
    --skip-ingress)
      SKIP_INGRESS=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --namespace <namespace>                      Set the namespace (default: neuraltrust)"
      echo "  --release-name <name>                        Set the release name (default: data-plane)"
      echo "  --avoid-neuraltrust-private-registry         Use public images instead of NeuralTrust private registry"
      echo "  --skip-ingress                               Skip ingress-nginx controller installation"
      exit 1
      ;;
  esac
done

verify_environment() {
    local env="${1:-$ENVIRONMENT}"
    if [ -z "$env" ]; then
        log_error "No environment specified. Please set ENVIRONMENT variable (dev/prod)"
        exit 1
    fi

    case "$env" in
        dev|prod)
            ;;
        *)
            log_error "Invalid environment: $env. Must be 'dev' or 'prod'"
            exit 1
            ;;
    esac

    # Ask for confirmation
    log_warn "You are about to install NeuralTrust Data Plane in ${env} environment"
    
    read -p "Are you sure you want to continue? (yes/no) " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_error "Installation aborted"
        exit 1
    fi

    # Second confirmation for production
    if [ "$env" = "prod" ]; then
        log_warn "⚠️  WARNING: You are about to modify PRODUCTION environment!"
        read -p "Please type 'PRODUCTION' to confirm: " -r
        echo
        if [ "$REPLY" != "PRODUCTION" ]; then
            log_error "Installation aborted"
            exit 1
        fi
    fi
}

ENV_FILE=".env.data-plane.${ENVIRONMENT:-prod}"

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    log_error "Environment file $ENV_FILE not found"
    exit 1
fi

# Function to prompt for namespace
prompt_for_namespace() {
    if [ -z "$NAMESPACE" ]; then
        read -p "Enter namespace (default: $DEFAULT_NAMESPACE): " NAMESPACE
        NAMESPACE=${NAMESPACE:-$DEFAULT_NAMESPACE}
    fi
    log_info "Using namespace: $NAMESPACE"
}

# Function to create namespace if it doesn't exist
create_namespace_if_not_exists() {
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_info "Namespace $NAMESPACE does not exist. Creating..."
        kubectl create namespace "$NAMESPACE"
        log_info "Namespace $NAMESPACE created successfully"
    else
        log_info "Namespace $NAMESPACE runningrun."
        kubectl config set-context --current --namespace="$NAMESPACE"
    fi
}

# Function to prompt for OpenAI API key
prompt_for_openai_api_key() {
    # Check if already set via environment
    if [ -n "$OPENAI_API_KEY" ]; then
        log_info "Using OpenAI API key from environment variables."
        return 0
    fi

    # Only prompt if interactive
    if [ -t 0 ]; then
        log_info "OpenAI API key not found in environment variables."
        read -p "Enter your OpenAI API key (leave blank if using Google API Key): " OPENAI_API_KEY_INPUT
        # Export only if a value was entered
        if [ -n "$OPENAI_API_KEY_INPUT" ]; then
            export OPENAI_API_KEY="$OPENAI_API_KEY_INPUT"
            log_info "Using provided OpenAI API key."
        fi
    fi
}

# Function to prompt for Google API key
prompt_for_google_api_key() {
    # Check if already set via environment
    if [ -n "$GOOGLE_API_KEY" ]; then
        log_info "Using Google API key from environment variables."
        return 0
    fi

    # Only prompt if interactive
    if [ -t 0 ]; then
        log_info "Google API key not found in environment variables."
        read -p "Enter your Google API key (leave blank if using OpenAI API Key): " GOOGLE_API_KEY_INPUT
        # Export only if a value was entered
        if [ -n "$GOOGLE_API_KEY_INPUT" ]; then
            export GOOGLE_API_KEY="$GOOGLE_API_KEY_INPUT"
            log_info "Using provided Google API key."
        fi
    fi
}

# Function to validate that at least one API key is provided
validate_api_keys() {
    if [ -z "$OPENAI_API_KEY" ] && [ -z "$GOOGLE_API_KEY" ]; then
        log_error "At least one API key (OpenAI or Google) must be provided."
        log_error "Set OPENAI_API_KEY or GOOGLE_API_KEY environment variables, or enter them when prompted."
        exit 1
    fi
}

# Function to prompt for HuggingFace token
prompt_for_huggingface_token() {
    if [ -z "$HUGGINGFACE_TOKEN" ]; then
        log_info "HuggingFace token not found in environment variables."
        log_info "This token should have been provided by NeuralTrust."
        read -p "Enter your HuggingFace token from NeuralTrust: " HUGGINGFACE_TOKEN
        
        if [ -z "$HUGGINGFACE_TOKEN" ]; then
            log_warn "No HuggingFace token provided. Some features may not work properly."
            log_warn "Please contact NeuralTrust support to obtain a valid token."
            HUGGINGFACE_TOKEN="none"
        fi
    else
        log_info "Using HuggingFace token from environment variables."
    fi
}

create_data_plane_secrets() {
    log_info "Creating data plane secrets..."

    # Generate DATA_PLANE_JWT_SECRET if not provided
    if [ -z "$DATA_PLANE_JWT_SECRET" ]; then
        log_info "DATA_PLANE_JWT_SECRET not provided, generating a new one..."
        DATA_PLANE_JWT_SECRET=$(openssl rand -base64 32)
        log_info "Generated DATA_PLANE_JWT_SECRET. Please store this securely if needed for direct API access or debugging."
    fi

    if [ "$AVOID_NEURALTRUST_PRIVATE_REGISTRY" = false ]; then
        # Create registry credentials secret
        log_info "Please provide your GCR service account key (JSON format)"
        log_info "This key is required to pull images from Google Container Registry"
        log_info "You should have received this key from NeuralTrust"
        
        # Check if GCR_KEY_FILE environment variable is set
        if [ -n "$GCR_KEY_FILE" ] && [ -f "$GCR_KEY_FILE" ]; then
            log_info "Using GCR key file from environment variable: $GCR_KEY_FILE"
            GCR_KEY=$(cat "$GCR_KEY_FILE")
        else
            # If running in interactive mode, prompt for the key
            if [ -t 0 ]; then
                log_info "Enter the path to your GCR key file:"
                read -p "> " GCR_KEY_FILE
                
                if [ ! -f "$GCR_KEY_FILE" ]; then
                    log_error "File not found: $GCR_KEY_FILE"
                    exit 1
                fi
                
                GCR_KEY=$(cat "$GCR_KEY_FILE")
            else
                # If not interactive, check if the key is provided via stdin
                if [ -p /dev/stdin ]; then
                    GCR_KEY=$(cat)
                else
                    log_error "GCR key not provided. Please set GCR_KEY_FILE environment variable or provide the key via stdin."
                    exit 1
                fi
            fi
        fi
        
        # Validate JSON format
        if ! echo "$GCR_KEY" | jq . > /dev/null 2>&1; then
            log_error "Invalid JSON format for GCR key"
            exit 1
        fi
        
        # Create the secret
        kubectl create -n "$NAMESPACE" secret docker-registry gcr-secret \
            --docker-server=europe-west1-docker.pkg.dev \
            --docker-username=_json_key \
            --docker-password="$GCR_KEY" \
            --docker-email=admin@neuraltrust.ai \
            --dry-run=client -o yaml | kubectl apply -f -
        
        log_info "GCR secret created successfully"
    else
        log_info "Skipping GCR secret creation as public images will be used."
    fi
}

install_databases() {
    log_info "Installing databases..."
    CLICKHOUSE_PASSWORD=$(openssl rand -base64 32)

    # Install ClickHouse with configuration from values file and only password via --set
    helm upgrade --install clickhouse "./clickhouse" \
        --namespace "$NAMESPACE" \
        --version "8.0.10" \
        -f ./neuraltrust/values-clickhouse.yaml \
        --set auth.password="$CLICKHOUSE_PASSWORD" \
        --wait

    log_info "ClickHouse password generated and stored in secret 'clickhouse-secrets'"
    log_info "Password: $CLICKHOUSE_PASSWORD"
    log_info "Please save this password in a secure location"
    
}

install_messaging() {
    log_info "Installing messaging system..."

    # Install Kafka
    helm upgrade --install kafka "./kafka" \
        --version "31.0.0" \
        --namespace "$NAMESPACE" \
        -f ./neuraltrust/values-kafka.yaml \
        --wait
}

# Function to install data plane components
install_data_plane() {
    log_info "Installing NeuralTrust Data Plane infrastructure..."

    # Prompt for namespace and create it if it doesn't exist
    prompt_for_namespace
    create_namespace_if_not_exists

    # Install ingress-nginx controller first
    if [ "$SKIP_INGRESS" = true ]; then
        log_info "Skipping ingress-nginx installation as requested"
        log_warn "Note: When skipping ingress, services will only be accessible via ClusterIP or manual port-forwarding"
        log_warn "To access services externally, you'll need to set up your own ingress controller or use port-forwarding:"
        log_warn "  kubectl port-forward -n $NAMESPACE svc/data-plane-api-service 8000:80"
    fi
    
    # Prompt for API keys and validate
    prompt_for_openai_api_key
    prompt_for_google_api_key
    validate_api_keys # Ensure at least one key is set
    prompt_for_huggingface_token

    # Create required secrets
    create_data_plane_secrets

    # Install databases
    install_databases

    # Install messaging system
    install_messaging

    # Install data plane components for Kubernetes
    log_info "Installing data plane components..."

    PULL_SECRET=""
    if [ "$AVOID_NEURALTRUST_PRIVATE_REGISTRY" = false ]; then
        PULL_SECRET="gcr-secret"
    fi

    helm upgrade --install data-plane "./neuraltrust/data-plane" \
        --namespace "$NAMESPACE" \
        -f "$VALUES_FILE" \
        --timeout 15m \
        --set dataPlane.imagePullSecrets="$PULL_SECRET" \
        --set dataPlane.secrets.huggingFaceToken="$HUGGINGFACE_TOKEN" \
        --set dataPlane.secrets.dataPlaneJWTSecret="$DATA_PLANE_JWT_SECRET" \
        --set dataPlane.secrets.openaiApiKey="${OPENAI_API_KEY:-}" \
        --set dataPlane.secrets.googleApiKey="${GOOGLE_API_KEY:-}" \
        --set dataPlane.secrets.resendApiKey="${RESEND_API_KEY:-}" \
        --set dataPlane.components.clickhouse.backup.s3.accessKey="${S3_ACCESS_KEY:-}" \
        --set dataPlane.components.clickhouse.backup.s3.secretKey="${S3_SECRET_KEY:-}" \
        --set dataPlane.components.clickhouse.backup.gcs.accessKey="${GCS_ACCESS_KEY:-}" \
        --set dataPlane.components.clickhouse.backup.gcs.secretKey="${GCS_SECRET_KEY:-}" \
        --set dataPlane.components.api.ingress.enabled="$([ "$SKIP_INGRESS" = true ] && echo false || echo true)" \
        --wait

    log_info "NeuralTrust Data Plane infrastructure installed successfully!"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    validate_command "kubectl"
    validate_command "helm"
    validate_command "openssl"
    # validate_command "yq" # yq is no longer a prerequisite

    # Check if jq is installed, as it's used for GCR key validation and potentially other tasks
    validate_command "jq"

    # Check if cluster is accessible
    if ! kubectl get pods &> /dev/null; then
        log_error "Cannot access Kubernetes cluster"
        exit 1
    fi
}

main() {
    verify_environment "$ENVIRONMENT"
    prompt_for_namespace
    check_prerequisites
    install_data_plane
}

main "$@" 