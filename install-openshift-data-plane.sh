#!/bin/bash

set -e

shopt -s expand_aliases

# Source common functions
source scripts/common.sh

# Initialize variables
NAMESPACE=""
DEFAULT_NAMESPACE="neuraltrust"
VALUES_FILE="openshift-helm/values.yaml"

# Parse command line arguments
INSTALL_CERT_MANAGER=false # Default for OpenShift, assuming Routes handle certs or manual setup
RELEASE_NAME="data-plane"
USE_OPENSHIFT_IMAGESTREAM=true # if false uses GCP image registry

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --install-cert-manager) # New flag to explicitly install cert-manager
      INSTALL_CERT_MANAGER=true
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
    --use-openshift-imagestream)
      USE_OPENSHIFT_IMAGESTREAM=true
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
# Default for OpenShift: disable chart's Ingress, assume Routes will be used or chart handles it
ADDITIONAL_VALUES="$ADDITIONAL_VALUES --set global.ingress.enabled=false"

if [ "$INSTALL_CERT_MANAGER" = true ]; then
  ADDITIONAL_VALUES="$ADDITIONAL_VALUES --set global.certManager.enabled=true"
else
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
    if ! oc get project "$NAMESPACE" &> /dev/null; then
        log_info "Project $NAMESPACE does not exist. Creating..."
        oc new-project "$NAMESPACE"
        log_info "Project $NAMESPACE created successfully"
    else
        log_info "Project $NAMESPACE already exists. Switching to it."
        oc project "$NAMESPACE"
    fi
}

yaml_to_json() {
    local yaml_file="$1"
    python3.12 -c "import yaml, json, sys; print(json.dumps(yaml.safe_load(open('$yaml_file'))))"
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
    
    # Create JWT secret
    oc create secret generic data-plane-jwt-secret \
        --namespace "$NAMESPACE" \
        --from-literal=DATA_PLANE_JWT_SECRET="$DATA_PLANE_JWT_SECRET" \
        --dry-run=client -o yaml | oc apply -f -

    # Create OpenAI API key secret if provided
    if [ -n "$OPENAI_API_KEY" ]; then
        # Use the secret name from values.yaml via Helm --set, requires passing it down
        # For simplicity here, we'll hardcode the default or assume it's passed via env
        # A better approach might involve 'helm template' + 'oc apply' or querying values
        OPENAI_SECRET_NAME=$(yaml_to_json "$VALUES_FILE" | jq -r '.dataPlane.secrets.openaiApiKeySecretName')
        log_info "Creating OpenAI secret ($OPENAI_SECRET_NAME)..."
        oc create secret generic "$OPENAI_SECRET_NAME" \
            --namespace "$NAMESPACE" \
            --from-literal=OPENAI_API_KEY="$OPENAI_API_KEY" \
            --dry-run=client -o yaml | oc apply -f -
    fi

    # Create Google API key secret if provided
    if [ -n "$GOOGLE_API_KEY" ]; then
        GOOGLE_SECRET_NAME=$(yaml_to_json "$VALUES_FILE" | jq -r '.dataPlane.secrets.googleApiKeySecretName')
        log_info "Creating Google secret ($GOOGLE_SECRET_NAME)..."
        oc create secret generic "$GOOGLE_SECRET_NAME" \
            --namespace "$NAMESPACE" \
            --from-literal=GOOGLE_API_KEY="$GOOGLE_API_KEY" \
            --dry-run=client -o yaml | oc apply -f -
    fi

    # Create Resend API key secret
    oc create secret generic resend-secrets \
        --namespace "$NAMESPACE" \
        --from-literal=RESEND_API_KEY="$RESEND_API_KEY" \
        --dry-run=client -o yaml | oc apply -f -

    if [ "$USE_OPENSHIFT_IMAGESTREAM" = false ]; then
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
        oc create -n "$NAMESPACE" secret docker-registry gcr-secret \
            --docker-server=europe-west1-docker.pkg.dev \
            --docker-username=_json_key \
            --docker-password="$GCR_KEY" \
            --docker-email=admin@neuraltrust.ai \
            --dry-run=client -o yaml | oc apply -f -
        
        log_info "GCR secret created successfully"
    else
        log_info "Skipping GCR secret creation as OpenShift ImageStream will be used."
    fi
}

install_databases() {
    log_info "Installing databases..."
    CLICKHOUSE_PASSWORD=$(openssl rand -base64 32)

    # Determine ClickHouse image repository
    CLICKHOUSE_IMAGE_REPO_FINAL="${CLICKHOUSE_IMAGE_REPOSITORY:-oci://registry-1.docker.io/bitnamicharts/clickhouse}"
    log_info "Using ClickHouse image repository: $CLICKHOUSE_IMAGE_REPO_FINAL"

    # Determine ClickHouse chart version
    CLICKHOUSE_CHART_VERSION_FINAL="${CLICKHOUSE_VERSION:-8.0.10}"
    log_info "Using ClickHouse chart version: $CLICKHOUSE_CHART_VERSION_FINAL"

    # Install ClickHouse with backup configuration
    helm upgrade --install clickhouse "$CLICKHOUSE_IMAGE_REPO_FINAL" \
        --namespace "$NAMESPACE" \
        --version "$CLICKHOUSE_CHART_VERSION_FINAL" \
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
    
    oc create secret generic clickhouse-secrets \
        --namespace "$NAMESPACE" \
        --from-literal=CLICKHOUSE_USER="neuraltrust" \
        --from-literal=CLICKHOUSE_DATABASE="neuraltrust" \
        --from-literal=CLICKHOUSE_HOST="clickhouse.${NAMESPACE}.svc.cluster.local" \
        --from-literal=CLICKHOUSE_PORT="8123" \
        --dry-run=client -o yaml | oc apply -f -
    
    oc create configmap clickhouse-init-job \
        --namespace "$NAMESPACE" \
        --from-file=openshift-helm/data-plane/templates/clickhouse/sql-configmap.yaml \
        --dry-run=client -o yaml | oc apply -f -
}

install_messaging() {
    log_info "Installing messaging system..."

    # Determine Kafka image repository
    KAFKA_IMAGE_REPO_FINAL="${KAFKA_IMAGE_REPOSITORY:-oci://registry-1.docker.io/bitnamicharts/kafka}"
    log_info "Using Kafka image repository: $KAFKA_IMAGE_REPO_FINAL"

    # Determine Kafka chart version
    KAFKA_CHART_VERSION_FINAL="${KAFKA_VERSION:-31.0.0}"
    log_info "Using Kafka chart version: $KAFKA_CHART_VERSION_FINAL"

    # Install Kafka
    helm upgrade --install kafka "$KAFKA_IMAGE_REPO_FINAL" \
        --version "$KAFKA_CHART_VERSION_FINAL" \
        --namespace "$NAMESPACE" \
        -f openshift-helm/values-kafka.yaml \
        --wait
}

# Function to check if cert-manager is installed in any namespace
check_cert_manager_installed() {
    # Check in common namespaces where cert-manager might be installed
    if oc get deployment -n cert-manager cert-manager-webhook &> /dev/null; then
        log_info "cert-manager found in cert-manager namespace"
        return 0
    elif oc get deployment -n kube-system cert-manager-webhook &> /dev/null; then
        log_info "cert-manager found in kube-system namespace"
        return 0
    elif oc get deployment -n "$NAMESPACE" cert-manager-webhook &> /dev/null; then
        log_info "cert-manager found in $NAMESPACE namespace"
        return 0
    fi
    # Removed cluster-wide check to avoid permission issues
    log_info "cert-manager not found in common namespaces (cert-manager, kube-system, $NAMESPACE)."
    return 1
}

install_cert_manager() {
    if [ "$INSTALL_CERT_MANAGER" = false ]; then
        log_info "Skipping cert-manager installation (default for OpenShift)."
        log_info "If using OpenShift Routes, manage certificates via Route definition or OpenShift's integrated CA."
        return 0
    fi
    
    if ! check_cert_manager_installed; then
        log_info "Installing cert-manager (explicitly requested via --install-cert-manager flag)..."
        helm upgrade --install cert-manager jetstack/cert-manager \
            --namespace "$NAMESPACE" \
            --set installCRDs=true \
            --wait

        # Wait for cert-manager webhook to be ready
        log_info "Waiting for cert-manager webhook..."
        oc wait --for=condition=Available deployment/cert-manager-webhook \
            --namespace "$NAMESPACE" \
            --timeout=120s

        # Create ClusterIssuer only if NGINX controller is also being installed,
        # as the default ClusterIssuer is for NGINX.
        # if [ "$INSTALL_NGINX_CONTROLLER" = true ]; then
        #     log_info "Creating ClusterIssuer for NGINX Ingress..."
        #     oc apply -f - <<EOF
        #     apiVersion: cert-manager.io/v1
        #     kind: ClusterIssuer
        #     metadata:
        #       name: letsencrypt-prod
        #     spec:
        #       acme:
        #         server: https://acme-v02.api.letsencrypt.org/directory
        #         email: ${EMAIL} # Make sure EMAIL env var is set
        #         privateKeySecretRef:
        #           name: letsencrypt-prod
        #         solvers:
        #         - http01:
        #             ingress:
        #               class: nginx
# EOF
        # else
        log_info "Skipping NGINX-specific ClusterIssuer creation."
        log_info "If using cert-manager with OpenShift Routes, configure a suitable ClusterIssuer manually."
        # fi
    else
        log_info "cert-manager already installed, skipping its installation script."
        # Even if already installed, check if we need to create our specific ClusterIssuer
        # if [ "$INSTALL_NGINX_CONTROLLER" = true ]; then
        #     log_info "Checking/Creating ClusterIssuer for NGINX Ingress (since cert-manager is present and NGINX controller is requested)..."
        #     # A more robust check would be to see if 'letsencrypt-prod' ClusterIssuer already exists
        #     # For now, we'll re-apply; kubectl apply is idempotent.
        #     oc apply -f - <<EOF
        #     apiVersion: cert-manager.io/v1
        #     kind: ClusterIssuer
        #     metadata:
        #       name: letsencrypt-prod
        #     spec:
        #       acme:
        #         server: https://acme-v02.api.letsencrypt.org/directory
        #         email: ${EMAIL} # Make sure EMAIL env var is set
        #         privateKeySecretRef:
        #           name: letsencrypt-prod
        #         solvers:
        #         - http01:
        #             ingress:
        #               class: nginx
# EOF
        # fi
    fi
}

# Function to install data plane components
install_data_plane() {
    log_info "Installing NeuralTrust Data Plane infrastructure..."

    # Prompt for namespace and create it if it doesn't exist
    prompt_for_namespace
    create_namespace_if_not_exists

    # Grant image pull permissions to the default service account in the namespace
    log_info "Granting image pull permissions to default service account in namespace '$NAMESPACE'..."
    oc policy add-role-to-user system:image-puller "system:serviceaccount:${NAMESPACE}:default" -n "$NAMESPACE"
    
    # Prompt for API keys and validate
    prompt_for_openai_api_key
    prompt_for_google_api_key
    validate_api_keys # Ensure at least one key is set
    prompt_for_huggingface_token

    # Add required Helm repositories
    log_info "Adding Helm repositories..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add jetstack https://charts.jetstack.io
    # helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update

    # Install cert-manager first
    install_cert_manager

    # Wait a moment for the ClusterIssuer to be ready
    sleep 10

    # Install ingress controller
    # install_nginx_ingress

    # Create required secrets
    create_data_plane_secrets

    # Install databases
    install_databases

    # Install messaging system
    install_messaging

    # Install data plane components for SaaS
    log_info "Installing data plane components..."

    FINAL_DATA_PLANE_API_URL=""
    if [ -n "$DATA_PLANE_API_URL" ]; then
        FINAL_DATA_PLANE_API_URL=$DATA_PLANE_API_URL
    fi

    helm upgrade --install data-plane ./openshift-helm/data-plane \
        --namespace "$NAMESPACE" \
        -f "$VALUES_FILE" \
        --timeout 15m \
        --set dataPlane.components.api.host=$FINAL_DATA_PLANE_API_URL\
        --set dataPlane.components.api.image.repository="$DATA_PLANE_API_IMAGE_REPOSITORY" \
        --set dataPlane.components.api.image.tag="$DATA_PLANE_API_IMAGE_TAG" \
        --set dataPlane.components.api.image.pullPolicy="$DATA_PLANE_API_IMAGE_PULL_POLICY" \
        --set dataPlane.components.api.huggingfaceToken="$HUGGINGFACE_TOKEN" \
        --set dataPlane.components.api.secrets.dataPlaneJWTSecret="$DATA_PLANE_JWT_SECRET" \
        --set dataPlane.components.worker.image.repository="$WORKER_IMAGE_REPOSITORY" \
        --set dataPlane.components.worker.image.tag="$WORKER_IMAGE_TAG" \
        --set dataPlane.components.worker.image.pullPolicy="$WORKER_IMAGE_PULL_POLICY" \
        --set clickhouse.backup.type="${CLICKHOUSE_BACKUP_TYPE:-s3}" \
        --set clickhouse.backup.s3.bucket="$S3_BUCKET" \
        --set clickhouse.backup.s3.region="$S3_REGION" \
        --set clickhouse.backup.s3.accessKey="$S3_ACCESS_KEY" \
        --set clickhouse.backup.s3.secretKey="$S3_SECRET_KEY" \
        --set clickhouse.backup.s3.endpoint="$S3_ENDPOINT" \
        --set clickhouse.backup.gcs.bucket="$GCS_BUCKET" \
        --set clickhouse.backup.gcs.accessKey="$GCS_ACCESS_KEY" \
        --set clickhouse.backup.gcs.secretKey="$GCS_SECRET_KEY" \
        $ADDITIONAL_VALUES \
        --wait

    log_info "NeuralTrust Data Plane infrastructure installed successfully!"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    validate_command "oc"
    validate_command "helm"
    validate_command "openssl"
    #validate_command "yq" # Added yq dependency for reading values.yaml

    # Check if cluster is accessible
    if ! oc get pods &> /dev/null; then
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