#!/bin/bash

set -e

shopt -s expand_aliases

# Source common functions
source ../scripts/common.sh

# Initialize variables
NAMESPACE=""
DEFAULT_NAMESPACE="neuraltrust"
EMAIL=""
PRIVATE_KEY_PATH=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --private-key)
            PRIVATE_KEY_PATH="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--namespace NAMESPACE] [--email EMAIL] [--private-key PATH]"
            echo "  --namespace NAMESPACE     Set the namespace (default: $DEFAULT_NAMESPACE)"
            echo "  --email EMAIL            Set the email for Let's Encrypt"
            echo "  --private-key PATH       Path to the private key file"
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

if [ -z "$NAMESPACE" ]; then
    read -p "Enter namespace (default: $DEFAULT_NAMESPACE): " NAMESPACE
    NAMESPACE=${NAMESPACE:-$DEFAULT_NAMESPACE}
fi
log_info "Using namespace: $NAMESPACE"

if [ -z "$EMAIL" ]; then
    read -p "Enter email for Let's Encrypt: " EMAIL
fi
log_info "Using email: $EMAIL"

if [ -z "$PRIVATE_KEY_PATH" ]; then
    read -p "Enter path to private key file: " PRIVATE_KEY_PATH
fi

# Validate private key file exists
if [ ! -f "$PRIVATE_KEY_PATH" ]; then
    log_error "Private key file not found: $PRIVATE_KEY_PATH"
    exit 1
fi
log_info "Using private key: $PRIVATE_KEY_PATH"

# Create namespace if it doesn't exist
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    log_info "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
else
    log_info "Namespace $NAMESPACE already exists"
fi


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
else
    log_info "cert-manager already installed, skipping..."
fi

# Create letsencrypt-secret
log_info "Creating letsencrypt-secret..."
kubectl create secret generic letsencrypt-secret \
    --from-file=tls.key="$PRIVATE_KEY_PATH" \
    --namespace "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# Create ClusterIssuer
log_info "Creating ClusterIssuer..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
    name: letsencrypt-issuer
spec:
    acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${EMAIL}
        privateKeySecretRef:
            name: letsencrypt-secret
        solvers:
        - http01:
            ingress:
                class: nginx
EOF