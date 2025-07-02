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
INSTALL_POSTGRESQL=false
RELEASE_NAME="control-plane"
AVOID_NEURALTRUST_PRIVATE_REGISTRY=false # if false, uses NeuralTrust private registry (GCP)
SKIP_INGRESS=false # if true, skips ingress-nginx installation
USE_OPENSHIFT=false # if true, uses oc instead of kubectl

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --install-postgresql)
      INSTALL_POSTGRESQL=true
      shift
      ;;
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
    --openshift)
      USE_OPENSHIFT=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --install-postgresql                         Install PostgreSQL in the cluster"
      echo "  --namespace <namespace>                      Set the namespace (default: neuraltrust)"
      echo "  --release-name <name>                        Set the release name (default: control-plane)"
      echo "  --avoid-neuraltrust-private-registry         Use public images instead of NeuralTrust private registry"
      echo "  --skip-ingress                               Skip ingress-nginx controller installation"
      echo "  --openshift                                  Use oc commands instead of kubectl for OpenShift"
      exit 1
      ;;
  esac
done

# Set up additional Helm values based on parameters

if [ -z "$ENVIRONMENT" ]; then
    log_info "No environment specified. Please choose an environment."
    read -p "Enter environment (dev/prod): " ENVIRONMENT
    
    if [ -z "$ENVIRONMENT" ]; then
        log_error "Environment cannot be empty"
        exit 1
    fi
fi

case "$ENVIRONMENT" in
    dev|prod)
        ;;
    *)
        log_error "Invalid environment: $ENVIRONMENT. Must be 'dev' or 'prod'"
        exit 1
        ;;
esac

# Ask for confirmation
log_warn "You are about to install NeuralTrust Data Plane in ${ENVIRONMENT} environment"

read -p "Are you sure you want to continue? (yes/no) " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    log_error "Installation aborted"
    exit 1
fi

# Second confirmation for production
if [ "$ENVIRONMENT" = "prod" ]; then
    log_warn "⚠️  WARNING: You are about to modify PRODUCTION environment!"
    read -p "Please type 'PRODUCTION' to confirm: " -r
    echo
    if [ "$REPLY" != "PRODUCTION" ]; then
        log_error "Installation aborted"
        exit 1
    fi
fi

ENV_FILE=".env.control-plane.${ENVIRONMENT}"

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    log_error "Environment file $ENV_FILE not found"
    exit 1
fi

# Set kubectl command based on platform
if [ "$USE_OPENSHIFT" = true ]; then
    KUBECTL_CMD="oc"
else
    KUBECTL_CMD="kubectl"
fi

# Function to prompt for namespace
prompt_for_namespace() {
    if [ -z "$NAMESPACE" ]; then
        read -p "Enter namespace (default: $DEFAULT_NAMESPACE): " NAMESPACE
        NAMESPACE=${NAMESPACE:-$DEFAULT_NAMESPACE}
    fi
    log_info "Using namespace: $NAMESPACE"
}

# Function to prompt for mandatory DATA_PLANE_API_URL
prompt_for_data_plane_api_url() {
    if [ -z "$DATA_PLANE_API_URL" ]; then
        log_info "DATA_PLANE_API_URL is required for the control plane to communicate with the data plane."
        while [ -z "$DATA_PLANE_API_URL" ]; do
            read -p "Enter the Data Plane API URL (e.g., data-api.example.com): " DATA_PLANE_API_URL
            if [ -z "$DATA_PLANE_API_URL" ]; then
                log_error "DATA_PLANE_API_URL cannot be empty. Please provide a valid URL."
            fi
        done
    fi
    log_info "Using Data Plane API URL: $DATA_PLANE_API_URL"
}

# Function to prompt for mandatory CONTROL_PLANE_JWT_SECRET
prompt_for_control_plane_jwt_secret() {
    if [ -z "$CONTROL_PLANE_JWT_SECRET" ]; then
        log_info "CONTROL_PLANE_JWT_SECRET is required for secure communication between control plane and data plane."
        log_info "This MUST be the same JWT secret used by your data plane installation."
        
        while [ -z "$CONTROL_PLANE_JWT_SECRET" ]; do
            read -p "Enter the Control Plane JWT Secret (same as data plane): " CONTROL_PLANE_JWT_SECRET
            if [ -z "$CONTROL_PLANE_JWT_SECRET" ]; then
                log_error "JWT Secret cannot be empty. Please provide the same JWT secret used by your data plane."
            fi
        done
        log_info "Using provided JWT secret for control plane authentication."
    else
        log_info "Using Control Plane JWT Secret from environment variables."
    fi
}

# Function to create namespace if it doesn't exist
create_namespace_if_not_exists() {
    if ! $KUBECTL_CMD get namespace "$NAMESPACE" &> /dev/null; then
        log_info "Namespace $NAMESPACE does not exist. Creating..."
        $KUBECTL_CMD create namespace "$NAMESPACE"
        log_info "Namespace $NAMESPACE created successfully"
    else
        log_info "Namespace $NAMESPACE already exists"
    fi
}

create_gcr_secret() {
    
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
        $KUBECTL_CMD create -n "$NAMESPACE" secret docker-registry gcr-secret \
            --docker-server=europe-west1-docker.pkg.dev \
            --docker-username=_json_key \
            --docker-password="$GCR_KEY" \
            --docker-email=admin@neuraltrust.ai \
            --dry-run=client -o yaml | $KUBECTL_CMD apply -f -
        
        log_info "GCR secret created successfully"
    else
        log_info "Skipping GCR secret creation as requested."
    fi
}

install_control_plane() {
    log_info "Installing NeuralTrust Control Plane infrastructure..."

    # Prompt for namespace and create it if it doesn't exist
    prompt_for_namespace
    create_namespace_if_not_exists

    # Install ingress-nginx controller first
    if [ "$SKIP_INGRESS" = true ]; then
        log_info "Skipping ingress-nginx installation as requested"
        log_warn "Note: When skipping ingress, services will only be accessible via ClusterIP or manual port-forwarding"
        log_warn "To access services externally, you'll need to set up your own ingress controller or use port-forwarding:"
        log_warn "  $KUBECTL_CMD port-forward -n $NAMESPACE svc/control-plane-api-service 8080:80"
        log_warn "  $KUBECTL_CMD port-forward -n $NAMESPACE service/control-plane-app-service 8000:80"
        log_warn "  $KUBECTL_CMD port-forward -n $NAMESPACE svc/control-plane-scheduler-service 8081:80"
    fi

    # Create required secrets
    create_gcr_secret

    PULL_SECRET=""
    if [ "$AVOID_NEURALTRUST_PRIVATE_REGISTRY" = false ]; then
        PULL_SECRET="gcr-secret"
    fi

    # Install control plane components
    log_info "Installing control plane..."
    
    if [ "$INSTALL_POSTGRESQL" = true ]; then
        POSTGRES_HOST_FINAL="${RELEASE_NAME}-postgresql.$NAMESPACE.svc.cluster.local"
    elif [ -n "$POSTGRES_HOST" ]; then
        POSTGRES_HOST_FINAL="$POSTGRES_HOST"
    fi
    
    # Build optional configuration overrides for non-sensitive data
    OPTIONAL_OVERRIDES=()
    
    # Add image pull secrets if specified
    if [ -n "$PULL_SECRET" ]; then
        OPTIONAL_OVERRIDES+=(--set "controlPlane.imagePullSecrets=$PULL_SECRET")
    fi

    # Add PostgreSQL host if it has a value
    if [ -n "$POSTGRES_HOST_FINAL" ]; then
        log_info "Using PostgreSQL host: $POSTGRES_HOST_FINAL"
        OPTIONAL_OVERRIDES+=(--set "controlPlane.components.postgresql.secrets.host=$POSTGRES_HOST_FINAL")
    fi

    if [ -z "$POSTGRES_PASSWORD" ]; then
        log_error "POSTGRES_PASSWORD is not set. Please set it in the environment variables."
        exit 1
    fi

    log_info "Using data plane API URL: $DATA_PLANE_API_URL"
    
    helm upgrade --install $RELEASE_NAME "./neuraltrust/control-plane" \
        --namespace "$NAMESPACE" \
        -f "$VALUES_FILE" \
        --timeout 15m \
        --set global.openshift="$USE_OPENSHIFT" \
        --set controlPlane.secrets.controlPlaneJWTSecret="$CONTROL_PLANE_JWT_SECRET" \
        --set controlPlane.secrets.openaiApiKey="$OPENAI_API_KEY" \
        --set controlPlane.components.postgresql.installInCluster="$INSTALL_POSTGRESQL" \
        --set controlPlane.components.postgresql.secrets.password="$POSTGRES_PASSWORD" \
        --set controlPlane.components.app.config.dataPlaneApiUrl="$DATA_PLANE_API_URL" \
        --set controlPlane.components.scheduler.config.dataPlaneApiUrl="$DATA_PLANE_API_URL" \
        --set controlPlane.components.api.config.dataPlaneApiUrl="$DATA_PLANE_API_URL" \
        --set controlPlane.secrets.resendApiKey="${RESEND_API_KEY:-}" \
        --set controlPlane.components.scheduler.ingress.enabled="$([ "$SKIP_INGRESS" = true ] && echo false || echo true)" \
        --set controlPlane.components.api.ingress.enabled="$([ "$SKIP_INGRESS" = true ] && echo false || echo true)" \
        --set controlPlane.components.app.ingress.enabled="$([ "$SKIP_INGRESS" = true ] && echo false || echo true)" \
        "${OPTIONAL_OVERRIDES[@]}" \
        --wait


    log_info "NeuralTrust Control Plane infrastructure installed successfully!"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    validate_command "$KUBECTL_CMD"
    validate_command "helm"
    validate_command "openssl"

    # Check if cluster is accessible
    if ! $KUBECTL_CMD get pods &> /dev/null; then
        log_error "Cannot access Kubernetes cluster"
        exit 1
    fi
}

main() {
    prompt_for_namespace
    prompt_for_data_plane_api_url
    prompt_for_control_plane_jwt_secret
    check_prerequisites
    install_control_plane
}

main "$@" 