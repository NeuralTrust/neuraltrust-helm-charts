#!/bin/bash

set -e

shopt -s expand_aliases

# Source common functions
source scripts/common.sh

# Initialize variables
NAMESPACE=""
DEFAULT_NAMESPACE="neuraltrust"
VALUES_FILE="helm/values.yaml"

# Parse command line arguments
SKIP_INGRESS=false
SKIP_CERT_MANAGER=false
RELEASE_NAME="data-plane"

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --skip-ingress)
      SKIP_INGRESS=true
      shift
      ;;
    --skip-cert-manager)
      SKIP_CERT_MANAGER=true
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
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set up additional Helm values based on parameters
ADDITIONAL_VALUES=""
if [ "$SKIP_INGRESS" = true ]; then
  ADDITIONAL_VALUES="$ADDITIONAL_VALUES --set global.ingress.enabled=false"
fi
if [ "$SKIP_CERT_MANAGER" = true ]; then
  ADDITIONAL_VALUES="$ADDITIONAL_VALUES --set global.certManager.enabled=false"
fi

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
    log_warn "This will affect the following domains:"
    log_warn "- API: $(grep API_DOMAIN .env.$env | cut -d= -f2)"
    
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

ENV_FILE=".env.${ENVIRONMENT:-prod}"

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
        log_info "Namespace $NAMESPACE already exists"
    fi
}

# Function to prompt for OpenAI API key
prompt_for_openai_api_key() {
    if [ -z "$OPENAI_API_KEY" ]; then
        log_info "OpenAI API key not found in environment variables."
        read -p "Enter your OpenAI API key: " OPENAI_API_KEY
        
        if [ -z "$OPENAI_API_KEY" ]; then
            log_error "OpenAI API key is required."
            exit 1
        fi
    else
        log_info "Using OpenAI API key from environment variables."
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
    
    # Create JWT secret
    kubectl create secret generic data-plane-jwt-secret \
        --namespace "$NAMESPACE" \
        --from-literal=DATA_PLANE_JWT_SECRET="$DATA_PLANE_JWT_SECRET" \
        --dry-run=client -o yaml | kubectl apply -f -

    # Create OpenAI API key secret
    kubectl create secret generic openai-secrets \
        --namespace "$NAMESPACE" \
        --from-literal=OPENAI_API_KEY="$OPENAI_API_KEY" \
        --dry-run=client -o yaml | kubectl apply -f -
    

    # Create Resend API key secret
    kubectl create secret generic resend-secrets \
        --namespace "$NAMESPACE" \
        --from-literal=RESEND_API_KEY="$RESEND_API_KEY" \
        --dry-run=client -o yaml | kubectl apply -f -

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
}

install_databases() {
    log_info "Installing databases..."
    CLICKHOUSE_PASSWORD=$(openssl rand -base64 32)

    # Install ClickHouse with backup configuration
    helm upgrade --install clickhouse oci://registry-1.docker.io/bitnamicharts/clickhouse \
        --namespace "$NAMESPACE" \
        --version 8.0.10 \
        --set auth.username=neuraltrust \
        --set auth.password="$CLICKHOUSE_PASSWORD" \
        --set shards=1 \
        --set replicaCount=1 \
        --set zookeeper.enabled=false \
        --set persistence.size=100Gi \
        --set resources.limits.memory=8Gi \
        --set resources.requests.memory=4Gi \
        --set resources.limits.cpu=4 \
        --set resources.requests.cpu=2 \
        --set logLevel=fatal \
        --wait

    log_info "ClickHouse password generated and stored in secret 'clickhouse-secrets'"
    log_info "Password: $CLICKHOUSE_PASSWORD"
    log_info "Please save this password in a secure location"
    
    kubectl create secret generic clickhouse-secrets \
        --namespace "$NAMESPACE" \
        --from-literal=CLICKHOUSE_USER="neuraltrust" \
        --from-literal=CLICKHOUSE_DATABASE="neuraltrust" \
        --from-literal=CLICKHOUSE_HOST="clickhouse.${NAMESPACE}.svc.cluster.local" \
        --from-literal=CLICKHOUSE_PORT="8123" \
        --dry-run=client -o yaml | kubectl apply -f -
}

install_messaging() {
    log_info "Installing messaging system..."

    # Install Kafka
    helm upgrade --install kafka oci://registry-1.docker.io/bitnamicharts/kafka \
        --version 31.0.0 \
        --namespace "$NAMESPACE" \
        -f helm/values-kafka.yaml \
        --wait
}

install_cert_manager() {
    if [ "$SKIP_CERT_MANAGER" = true ]; then
        echo "Skipping cert-manager installation as requested"
        return 0
    fi
    
    echo "Installing cert-manager..."
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace "$NAMESPACE" \
        --set installCRDs=true \
        --wait
    

    # Wait for cert-manager webhook to be ready
    log_info "Waiting for cert-manager webhook..."
    kubectl wait --for=condition=Available deployment/cert-manager-webhook \
        --namespace "$NAMESPACE" \
        --timeout=120s

    # Create ClusterIssuer
    log_info "Creating ClusterIssuer..."
    kubectl apply -f - <<EOF
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${EMAIL}
        privateKeySecretRef:
          name: letsencrypt-prod
        solvers:
        - http01:
            ingress:
              class: nginx
EOF
}

install_ingress_controller() {
    if [ "$SKIP_INGRESS" = true ]; then
        echo "Skipping ingress controller installation as requested"
        return 0
    fi
    
    echo "Installing ingress controller..."
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace "$NAMESPACE" \
        --set controller.replicaCount=2 \
        --set controller.service.type=LoadBalancer \
        --wait
    
    # Wait for ingress controller to be ready
    log_info "Waiting for ingress controller to be ready..."
    kubectl wait --for=condition=Available deployment/ingress-nginx-controller \
        --namespace "$NAMESPACE" \
        --timeout=120s
}

install_data_plane() {
    log_info "Installing NeuralTrust Data Plane infrastructure..."

    # Prompt for namespace and create it if it doesn't exist
    prompt_for_namespace
    create_namespace_if_not_exists
    
    # Prompt for API keys
    prompt_for_openai_api_key
    prompt_for_huggingface_token

    # Add required Helm repositories
    log_info "Adding Helm repositories..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add jetstack https://charts.jetstack.io
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update

    # Install cert-manager first
    install_cert_manager

    # Wait a moment for the ClusterIssuer to be ready
    sleep 10

    # Install ingress controller
    install_ingress_controller

    # Create required secrets
    create_data_plane_secrets

    # Install databases
    install_databases

    # Install messaging system
    install_messaging

    # Install data plane components for SaaS
    log_info "Installing data plane components..."
    helm upgrade --install data-plane ./helm/data-plane \
        --namespace "$NAMESPACE" \
        -f "$VALUES_FILE" \
        --timeout 15m \
        --set dataPlane.components.api.host="$DATA_PLANE_API_URL" \
        --set dataPlane.components.api.image.repository="$DATA_PLANE_API_IMAGE_REPOSITORY" \
        --set dataPlane.components.api.image.tag="$DATA_PLANE_API_IMAGE_TAG" \
        --set dataPlane.components.api.image.pullPolicy="$DATA_PLANE_API_IMAGE_PULL_POLICY" \
        --set dataPlane.components.api.huggingfaceToken="$HUGGINGFACE_TOKEN" \
        --set dataPlane.components.api.secrets.dataPlaneJWTSecret="$DATA_PLANE_JWT_SECRET" \
        --set dataPlane.components.worker.image.repository="$WORKER_IMAGE_REPOSITORY" \
        --set dataPlane.components.worker.image.tag="$WORKER_IMAGE_TAG" \
        --set dataPlane.components.worker.image.pullPolicy="$WORKER_IMAGE_PULL_POLICY" \
        --set clickhouse.backup.gcsBucket="$GCS_BUCKET" \
        --set clickhouse.backup.gcsAccessKey="$GCS_ACCESS_KEY" \
        --set clickhouse.backup.gcsSecretKey="$GCS_SECRET_KEY" \
        $ADDITIONAL_VALUES \
        --wait

    log_info "NeuralTrust Data Plane infrastructure installed successfully!"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    validate_command "kubectl"
    validate_command "helm"
    validate_command "openssl"

    # Check if cluster is accessible
    if ! kubectl get nodes &> /dev/null; then
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