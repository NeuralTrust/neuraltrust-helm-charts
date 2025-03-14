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
INSTALL_POSTGRESQL=false
RELEASE_NAME="control-plane"

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
if [ "$INSTALL_POSTGRESQL" = true ]; then
  ADDITIONAL_VALUES="$ADDITIONAL_VALUES --set global.postgresql.enabled=true"
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
    log_warn "You are about to install NeuralTrust Control Plane in ${env} environment"
    log_warn "This will affect the following domains:"
    log_warn "- Control Plane: $(grep CONTROL_PLANE_DOMAIN .env.$env | cut -d= -f2)"
    log_warn "- WebApp: $(grep WEBAPP_DOMAIN .env.$env | cut -d= -f2)"
    
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

create_control_plane_secrets() {
    log_info "Creating control plane secrets..."
    
    kubectl create secret generic control-plane-jwt-secret \
        --namespace "$NAMESPACE" \
        --from-literal=CONTROL_PLANE_JWT_SECRET="$CONTROL_PLANE_JWT_SECRET" \
        --dry-run=client -o yaml | kubectl apply -f -

    kubectl create secret generic trigger-secrets \
        --namespace "$NAMESPACE" \
        --from-literal=MAGIC_LINK_SECRET="$TRIGGER_MAGIC_LINK_SECRET" \
        --from-literal=SESSION_SECRET="$TRIGGER_SESSION_SECRET" \
        --from-literal=ENCRYPTION_KEY="$TRIGGER_ENCRYPTION_KEY" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create PostgreSQL secrets if needed
    if [ "$INSTALL_POSTGRESQL" = true ]; then
        # Generate a random password if not provided
        if [ -z "$POSTGRES_PASSWORD" ]; then
            POSTGRES_PASSWORD=$(openssl rand -base64 12)
            log_info "Generated random PostgreSQL password"
        fi
        
        kubectl create secret generic postgresql-secrets \
            --namespace "$NAMESPACE" \
            --from-literal=POSTGRES_USER="${POSTGRES_USER:-postgres}" \
            --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
            --from-literal=POSTGRES_DB="${POSTGRES_DB:-neuraltrust}" \
            --from-literal=POSTGRES_HOST="${POSTGRES_HOST:-$RELEASE_NAME-postgresql.$NAMESPACE.svc.cluster.local}" \
            --from-literal=POSTGRES_PORT="${POSTGRES_PORT:-5432}" \
            --dry-run=client -o yaml | kubectl apply -f -
            
        log_info "PostgreSQL credentials:"
        log_info "  Host: ${POSTGRES_HOST:-$RELEASE_NAME-postgresql.$NAMESPACE.svc.cluster.local}"
        log_info "  Port: ${POSTGRES_PORT:-5432}"
        log_info "  Database: ${POSTGRES_DB:-neuraltrust}"
        log_info "  User: ${POSTGRES_USER:-postgres}"
        log_info "  Password: $POSTGRES_PASSWORD"
    else
        # Create the PostgreSQL secrets from provided environment variables
        kubectl create secret generic postgresql-secrets \
            --namespace "$NAMESPACE" \
            --from-literal=POSTGRES_HOST="$POSTGRES_HOST" \
            --from-literal=POSTGRES_PORT="${POSTGRES_PORT:-5432}" \
            --from-literal=POSTGRES_DB="${POSTGRES_DB:-triggerprod}" \
            --from-literal=POSTGRES_USER="$POSTGRES_USER" \
            --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi
    
    # Create OpenAI API key secret
    kubectl create secret generic openai-secrets \
        --namespace "$NAMESPACE" \
        --from-literal=OPENAI_API_KEY="$OPENAI_API_KEY" \
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

# Function to check if cert-manager is installed in any namespace
check_cert_manager_installed() {
    # Check in common namespaces where cert-manager might be installed
    if kubectl get deployment -n cert-manager cert-manager-webhook &> /dev/null; then
        log_info "cert-manager found in cert-manager namespace"
        return 0
    elif kubectl get deployment -n kube-system cert-manager-webhook &> /dev/null; then
        log_info "cert-manager found in kube-system namespace"
        return 0
    elif kubectl get deployment -n "$NAMESPACE" cert-manager-webhook &> /dev/null; then
        log_info "cert-manager found in $NAMESPACE namespace"
        return 0
    else
        # Check across all namespaces as a last resort
        if kubectl get deployment --all-namespaces | grep cert-manager-webhook &> /dev/null; then
            log_info "cert-manager found in another namespace"
            return 0
        fi
    fi
    return 1
}

# Function to check if NGINX Ingress Controller is installed in any namespace
check_nginx_ingress_installed() {
    # Check in common namespaces where NGINX Ingress might be installed
    if kubectl get deployment -n ingress-nginx ingress-nginx-controller &> /dev/null; then
        log_info "NGINX Ingress Controller found in ingress-nginx namespace"
        return 0
    elif kubectl get deployment -n kube-system ingress-nginx-controller &> /dev/null; then
        log_info "NGINX Ingress Controller found in kube-system namespace"
        return 0
    elif kubectl get deployment -n "$NAMESPACE" ingress-nginx-controller &> /dev/null; then
        log_info "NGINX Ingress Controller found in $NAMESPACE namespace"
        return 0
    else
        # Check across all namespaces as a last resort
        if kubectl get deployment --all-namespaces | grep ingress-nginx-controller &> /dev/null; then
            log_info "NGINX Ingress Controller found in another namespace"
            return 0
        fi
    fi
    return 1
}

# Function to install cert-manager if needed
install_cert_manager() {
    if [ "$SKIP_CERT_MANAGER" = true ]; then
        log_info "Skipping cert-manager installation as requested"
        return 0
    fi
    
    if ! check_cert_manager_installed; then
        log_info "Installing cert-manager..."
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
    else
        log_info "cert-manager already installed, skipping..."
    fi
}

# Function to install NGINX Ingress Controller if needed
install_nginx_ingress() {
    if [ "$SKIP_INGRESS" = true ]; then
        log_info "Skipping NGINX Ingress Controller installation as requested"
        return 0
    fi
    
    if ! check_nginx_ingress_installed; then
        log_info "Installing NGINX Ingress Controller..."
        helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
            --namespace "$NAMESPACE" \
            --set controller.replicaCount=2 \
            --set controller.service.type=LoadBalancer \
            --set controller.config.proxy-body-size="50m" \
            --set controller.config.proxy-connect-timeout="600" \
            --set controller.config.proxy-read-timeout="600" \
            --set controller.config.proxy-send-timeout="600" \
            --set controller.config.ssl-protocols="TLSv1.2 TLSv1.3" \
            --set controller.metrics.enabled=true \
            --wait

        # Wait for ingress controller to be ready
        log_info "Waiting for ingress controller to be ready..."
        kubectl wait --for=condition=Available deployment/ingress-nginx-controller \
            --namespace "$NAMESPACE" \
            --timeout=120s
    else
        log_info "NGINX Ingress Controller already installed, skipping..."
    fi
}

install_control_plane() {
    log_info "Installing NeuralTrust Control Plane infrastructure..."

    # Prompt for namespace and create it if it doesn't exist
    prompt_for_namespace
    create_namespace_if_not_exists

    # Add required Helm repositories
    log_info "Adding Helm repositories..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add jetstack https://charts.jetstack.io
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update

    # Install cert-manager if needed
    install_cert_manager

    # Install NGINX Ingress Controller if needed
    install_nginx_ingress

    # Create required secrets
    create_control_plane_secrets

    # Install control plane components
    log_info "Installing control plane..."
    helm upgrade --install $RELEASE_NAME ./helm/control-plane \
        --namespace "$NAMESPACE" \
        -f "$VALUES_FILE" \
        --timeout 15m \
        --set controlPlane.components.api.host="$CONTROL_PLANE_API_URL" \
        --set controlPlane.components.api.image.repository="$CONTROL_PLANE_API_IMAGE_REPOSITORY" \
        --set controlPlane.components.api.image.tag="$CONTROL_PLANE_API_IMAGE_TAG" \
        --set controlPlane.components.api.image.pullPolicy="$CONTROL_PLANE_API_IMAGE_PULL_POLICY" \
        --set controlPlane.components.app.host="$CONTROL_PLANE_APP_URL" \
        --set controlPlane.components.app.image.repository="$CONTROL_PLANE_APP_IMAGE_REPOSITORY" \
        --set controlPlane.components.app.image.tag="$CONTROL_PLANE_APP_IMAGE_TAG" \
        --set controlPlane.components.app.image.pullPolicy="$CONTROL_PLANE_APP_IMAGE_PULL_POLICY" \
        --set controlPlane.components.app.config.controlPlaneApiUrl="$CONTROL_PLANE_API_URL" \
        --set controlPlane.components.app.config.controlPlaneAppUrl="$CONTROL_PLANE_APP_URL" \
        --set controlPlane.components.app.config.dataPlaneApiUrl="$DATA_PLANE_API_URL" \
        --set controlPlane.components.app.config.openaiModel="$OPENAI_MODEL" \
        --set controlPlane.components.app.secrets.auth.secret="$CONTROL_PLANE_AUTH_SECRET" \
        --set controlPlane.components.app.secrets.app.secretKey="$APP_SECRET_KEY" \
        --set controlPlane.components.app.secrets.oauth.clientKey="$OAUTH_CLIENT_KEY" \
        --set controlPlane.components.app.secrets.oauth.clientSecret="$OAUTH_CLIENT_SECRET" \
        --set controlPlane.components.app.secrets.sendgrid.apiKey="$SENDGRID_API_KEY" \
        --set controlPlane.components.app.secrets.sendgrid.sender="$SENDER" \
        --set controlPlane.components.app.secrets.trigger.apiKey="$TRIGGER_API_KEY" \
        --set controlPlane.components.app.secrets.trigger.publicApiKey="$TRIGGER_PUBLIC_API_KEY" \
        --set dataPlane.components.trigger.magicLinkSecret="$TRIGGER_MAGIC_LINK_SECRET" \
        --set dataPlane.components.trigger.sessionSecret="$TRIGGER_SESSION_SECRET" \
        --set dataPlane.components.trigger.encryptionKey="$TRIGGER_ENCRYPTION_KEY" \
        --set dataPlane.components.trigger.postgres.url="$POSTGRES_URL" \
        --set dataPlane.components.trigger.postgres.user="$POSTGRES_USER" \
        --set dataPlane.components.trigger.postgres.password="$POSTGRES_PASSWORD" \
        --set dataPlane.components.trigger.postgres.host="$POSTGRES_HOST" \
        --set dataPlane.components.trigger.postgres.database="triggerprod" \
        $ADDITIONAL_VALUES \
        --wait

    log_info "NeuralTrust Control Plane infrastructure installed successfully!"
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

    # Check if data plane is installed
    if ! kubectl get deployment -n "$NAMESPACE" data-plane-api &> /dev/null; then
        log_warn "Data Plane components not found. It's recommended to install Data Plane first."
        read -p "Continue anyway? (yes/no) " -r
        echo
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log_error "Installation aborted"
            exit 1
        fi
    fi
}

main() {
    verify_environment "$ENVIRONMENT"
    prompt_for_namespace
    check_prerequisites
    install_control_plane
}

main "$@" 