#!/bin/bash

set -e

shopt -s expand_aliases

# Source common functions
source ../scripts/common.sh

NAMESPACE=""
DEFAULT_NAMESPACE="neuraltrust"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--namespace NAMESPACE]"
            echo "  --namespace NAMESPACE  Set the namespace (default: $DEFAULT_NAMESPACE)"
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

log_info "Installing ingress-nginx controller..."

# Check if ingress-nginx is already installed
if helm list -n $NAMESPACE | grep -q ingress-nginx; then
    log_info "ingress-nginx is already installed, skipping..."
    return 0
fi

# Create ingress-nginx namespace if it doesn't exist
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    log_info "Creating ingress-nginx namespace..."
    kubectl create namespace $NAMESPACE
fi

# Install ingress-nginx using the local chart
helm upgrade --install ingress-nginx ./ingress-nginx \
    --namespace $NAMESPACE \
    --set controller.service.type=LoadBalancer \
    --wait --timeout=10m

log_info "ingress-nginx controller installed successfully!"

# Wait for the ingress controller to be ready
log_info "Waiting for ingress controller to be ready..."
kubectl wait --namespace $NAMESPACE \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=300s

log_info "ingress-nginx controller is ready!"