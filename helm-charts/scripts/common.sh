#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Utility functions
validate_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd is not installed"
        return 1
    fi
}

wait_for_resource() {
    local resource="$1"
    local namespace="$2"
    local timeout="$3"

    log_info "Waiting for $resource in namespace $namespace..."
    if ! kubectl wait --for=condition=Available "$resource" \
        --namespace "$namespace" \
        --timeout="${timeout}s"; then
        log_error "Timeout waiting for $resource"
        return 1
    fi
}

check_namespace() {
    local namespace="$1"
    if ! kubectl get namespace "$namespace" > /dev/null 2>&1; then
        log_info "Creating namespace: $namespace"
        kubectl create namespace "$namespace"
    else
        log_info "Using existing namespace: $namespace"
    fi
}

# Error handling
handle_error() {
    log_error "An error occurred on line $1"
    exit 1
}

# Set error handling
trap 'handle_error $LINENO' ERR 