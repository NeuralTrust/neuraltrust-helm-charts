#!/bin/bash

set -e

shopt -s expand_aliases

# Source common functions
source scripts/common.sh

# Initialize variables
NAMESPACE=""
DEFAULT_NAMESPACE="neuraltrust"
VALUES_FILE="helm-charts/openshift/values.yaml"

# Parse command line arguments
INSTALL_POSTGRESQL=false
RELEASE_NAME="control-plane"
AVOID_NEURALTRUST_PRIVATE_REGISTRY=false # if false, uses NeuralTrust private registry (GCP)

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
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set up additional Helm values based on parameters

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

ENV_FILE=".env.control-plane.${ENVIRONMENT:-prod}"

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
    if ! oc get namespace "$NAMESPACE" &> /dev/null; then
        log_info "Namespace $NAMESPACE does not exist. Creating..."
        oc create namespace "$NAMESPACE"
        log_info "Namespace $NAMESPACE created successfully"
    else
        log_info "Namespace $NAMESPACE already exists"
    fi
}

create_control_plane_secrets() {
    log_info "Creating control plane secrets..."
    
    # Create PostgreSQL secrets if needed
    if [ "$INSTALL_POSTGRESQL" = true ]; then
        log_info "Installing PostgreSQL in $NAMESPACE namespace..."
        
        log_info "PostgreSQL credentials will be configured via Helm chart:"
        log_info "  Host: ${RELEASE_NAME}-postgresql.$NAMESPACE.svc.cluster.local"
        log_info "  Port: ${POSTGRES_PORT:-5432}"
        log_info "  Database: ${POSTGRES_DB:-neuraltrust}"
        log_info "  User: ${POSTGRES_USER:-postgres}"
    else
        log_info "Using external PostgreSQL database"
        log_info "PostgreSQL credentials will be configured via Helm chart"
    fi
    
    # Create OpenAI API key secret
    oc create secret generic openai-secrets \
        --namespace "$NAMESPACE" \
        --from-literal=OPENAI_API_KEY="$OPENAI_API_KEY" \
        --dry-run=client -o yaml | oc apply -f -

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
        oc create -n "$NAMESPACE" secret docker-registry gcr-secret \
            --docker-server=europe-west1-docker.pkg.dev \
            --docker-username=_json_key \
            --docker-password="$GCR_KEY" \
            --docker-email=admin@neuraltrust.ai \
            --dry-run=client -o yaml | oc apply -f -
        
        log_info "GCR secret created successfully"
    else
        log_info "Defaulting to OpenShift ImageStream. Skipping GCR secret creation."
    fi
}

install_control_plane() {
    log_info "Installing NeuralTrust Control Plane infrastructure..."

    # Prompt for namespace and create it if it doesn't exist
    prompt_for_namespace
    create_namespace_if_not_exists

    # Create required secrets
    create_control_plane_secrets

    PULL_SECRET=""
    if [ "$AVOID_NEURALTRUST_PRIVATE_REGISTRY" = false ]; then
        PULL_SECRET="gcr-secret"
    fi

    # Install control plane components
    log_info "Installing control plane..."
    
    # Set PostgreSQL configuration based on installation type
    if [ "$INSTALL_POSTGRESQL" = true ]; then
        # Generate a random password if not provided
        if [ -z "$POSTGRES_PASSWORD" ]; then
            POSTGRES_PASSWORD=$(openssl rand -base64 12)
            log_info "Generated random PostgreSQL password: $POSTGRES_PASSWORD"
        fi
        POSTGRES_HOST_FINAL="${RELEASE_NAME}-postgresql.$NAMESPACE.svc.cluster.local"
        POSTGRES_USER_FINAL="${POSTGRES_USER:-postgres}"
        POSTGRES_DB_FINAL="${POSTGRES_DB:-neuraltrust}"
        POSTGRES_PORT_FINAL="${POSTGRES_PORT:-5432}"
    else
        POSTGRES_HOST_FINAL="$POSTGRES_HOST"
        POSTGRES_USER_FINAL="$POSTGRES_USER"
        POSTGRES_DB_FINAL="${POSTGRES_DB:-neuraltrust}"
        POSTGRES_PORT_FINAL="${POSTGRES_PORT:-5432}"
    fi
    
    helm upgrade --install $RELEASE_NAME ./helm-charts/openshift/control-plane \
        --namespace "$NAMESPACE" \
        -f "$VALUES_FILE" \
        --set controlPlane.imagePullSecrets="$PULL_SECRET" \
        --set controlPlane.secrets.controlPlaneJWTSecret="$CONTROL_PLANE_JWT_SECRET" \
        --set postgresql.secrets.user="$POSTGRES_USER_FINAL" \
        --set postgresql.secrets.password="$POSTGRES_PASSWORD" \
        --set postgresql.secrets.database="$POSTGRES_DB_FINAL" \
        --set postgresql.secrets.host="$POSTGRES_HOST_FINAL" \
        --set postgresql.secrets.port="$POSTGRES_PORT_FINAL" \
        --set global.postgresql.enabled="$INSTALL_POSTGRESQL" \
        --set controlPlane.components.api.host="$CONTROL_PLANE_API_URL" \
        --set controlPlane.components.api.image.repository="$CONTROL_PLANE_API_IMAGE_REPOSITORY" \
        --set controlPlane.components.api.image.tag="$CONTROL_PLANE_API_IMAGE_TAG" \
        --set controlPlane.components.api.image.pullPolicy="$CONTROL_PLANE_API_IMAGE_PULL_POLICY" \
        --set controlPlane.components.app.host="$CONTROL_PLANE_APP_URL" \
        --set controlPlane.components.app.secondaryHost="$CONTROL_PLANE_APP_SECONDARY_URL" \
        --set controlPlane.components.app.image.repository="$CONTROL_PLANE_APP_IMAGE_REPOSITORY" \
        --set controlPlane.components.app.image.tag="$CONTROL_PLANE_APP_IMAGE_TAG" \
        --set controlPlane.components.app.image.pullPolicy="$CONTROL_PLANE_APP_IMAGE_PULL_POLICY" \
        --set controlPlane.components.app.config.controlPlaneApiUrl="$CONTROL_PLANE_API_URL" \
        --set controlPlane.components.app.config.dataPlaneApiUrl="$DATA_PLANE_API_URL" \
        --set controlPlane.components.app.config.openaiModel="$OPENAI_MODEL" \
        --set controlPlane.components.scheduler.env.dataPlaneApiUrl="$DATA_PLANE_API_URL" \
        --set controlPlane.components.scheduler.env.controlPlaneApiUrl="$CONTROL_PLANE_API_URL" \
        --set controlPlane.components.scheduler.image.repository="$CONTROL_PLANE_SCHEDULER_IMAGE_REPOSITORY" \
        --set controlPlane.components.scheduler.image.tag="$CONTROL_PLANE_SCHEDULER_IMAGE_TAG" \
        --set controlPlane.components.scheduler.image.pullPolicy="$CONTROL_PLANE_SCHEDULER_IMAGE_PULL_POLICY" \
        --set controlPlane.components.scheduler.host="$CONTROL_PLANE_SCHEDULER_URL" \
        --set controlPlane.components.global.resend.apiKey="$RESEND_API_KEY" \
        --set controlPlane.components.global.resend.alertSender="$RESEND_ALERT_SENDER" \
        --set controlPlane.components.global.resend.inviteSender="$RESEND_INVITE_SENDER" \
        --set controlPlane.components.global.clerk.publishableKey="$NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY" \
        --set controlPlane.components.global.clerk.secretKey="$CLERK_SECRET_KEY" \
        --set controlPlane.components.global.clerk.webhookSecretSessions="$CLERK_WEBHOOK_SECRET_SESSIONS" \
        --set controlPlane.components.global.clerk.webhookSecretUsers="$CLERK_WEBHOOK_SECRET_USERS" \
        --set controlPlane.components.global.clerk.authorizationCallbackUrl="$GITHUB_AUTHORIZATION_CALLBACK_URL" \
        --set controlPlane.components.global.clerk.signInUrl="$NEXT_PUBLIC_CLERK_SIGN_IN_URL" \
        --set controlPlane.components.global.clerk.signUpUrl="$NEXT_PUBLIC_CLERK_SIGN_UP_URL" \
        $ADDITIONAL_VALUES \
        --timeout 15m \
        --wait

    # If CONTROL_PLANE_API_URL was initially empty (meaning OpenShift generates the API host),
    # we need to fetch this generated host and update the app's configuration.
    # The $CONTROL_PLANE_API_URL variable holds its value from the sourced .env file.
    if [ -z "$CONTROL_PLANE_API_URL" ]; then
        log_info "CONTROL_PLANE_API_URL was empty. Attempting to fetch the generated API route host..."
        # Assuming the API route is named based on the release name and a suffix '-api'
        API_ROUTE_NAME="$RELEASE_NAME-api-route"
        
        ACTUAL_API_HOST=""
        RETRY_COUNT=0
        MAX_RETRIES=12  # Total wait time: MAX_RETRIES * RETRY_DELAY (e.g., 12 * 10s = 120s)
        RETRY_DELAY=10 # Seconds

        log_info "Waiting for API route '$API_ROUTE_NAME' in namespace '$NAMESPACE' to be assigned a host..."
        while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            # Fetch the host. Use 2>/dev/null to suppress errors if route not found yet.
            RAW_OC_GET_ROUTE=$(oc get route "$API_ROUTE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null)
            
            # Check if oc command was successful and output is not empty
            if [ $? -eq 0 ] && [ -n "$RAW_OC_GET_ROUTE" ]; then
                ACTUAL_API_HOST=$RAW_OC_GET_ROUTE
                log_info "Fetched API host: $ACTUAL_API_HOST"
                break
            else
                log_info "API route host not yet available or route not found. Retrying in $RETRY_DELAY seconds... (Attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
                sleep $RETRY_DELAY
                RETRY_COUNT=$((RETRY_COUNT+1))
            fi
        done

        if [ -n "$ACTUAL_API_HOST" ]; then
            log_info "Updating app deployment with the fetched API host: $ACTUAL_API_HOST"
            # --reuse-values ensures all other configurations from the initial install are preserved.
            # We only override the specific value for the app's API URL.
            helm upgrade $RELEASE_NAME ./helm-charts/openshift/control-plane \
                --namespace "$NAMESPACE" \
                --reuse-values \
                --set controlPlane.components.app.config.controlPlaneApiUrl="$ACTUAL_API_HOST" \
                --set controlPlane.components.scheduler.env.controlPlaneApiUrl="$ACTUAL_API_HOST" \
                --timeout 5m \
                --wait
            
            if [ $? -eq 0 ]; then
                log_info "App deployment successfully updated to use API host: $ACTUAL_API_HOST"
            else
                log_error "Failed to update app deployment with the new API host '$ACTUAL_API_HOST'. Check Helm status for release '$RELEASE_NAME'."
            fi
        else
            log_error "Failed to fetch API route host after $MAX_RETRIES attempts for route '$API_ROUTE_NAME'."
            log_warn "The app's CONTROL_PLANE_API_URL (controlPlane.components.app.config.controlPlaneApiUrl) might be incorrect."
            log_warn "It was initially configured with an empty value, resulting in 'https://' and was not updated."
            log_warn "Manual intervention might be required to set it to the correct API host."
        fi
    else
        log_info "CONTROL_PLANE_API_URL was set to '$CONTROL_PLANE_API_URL'. The app deployment will use this value directly."
        log_info "No dynamic update needed for controlPlane.components.app.config.controlPlaneApiUrl based on a generated route host."
    fi

    log_info "NeuralTrust Control Plane infrastructure installed successfully!"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    validate_command "oc"
    validate_command "helm"
    validate_command "openssl"

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
    install_control_plane
}

main "$@" 