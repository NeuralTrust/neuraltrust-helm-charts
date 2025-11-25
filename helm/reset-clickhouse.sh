#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
NAMESPACE="neuraltrust"
KEEP_DATA=false
USE_OC=false

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --namespace)
      NAMESPACE="$2"
      shift
      shift
      ;;
    --keep-data)
      KEEP_DATA=true
      shift
      ;;
    --openshift)
      USE_OC=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --namespace <namespace>    Set the namespace (default: neuraltrust)"
      echo "  --keep-data                Keep PVC data (only restart pods)"
      echo "  --openshift                Use oc instead of kubectl"
      exit 1
      ;;
  esac
done

# Set kubectl or oc command
if [ "$USE_OC" = true ]; then
    K8S_CMD="oc"
else
    K8S_CMD="kubectl"
fi

log_info "Resetting ClickHouse in namespace: $NAMESPACE"

# Check if ClickHouse StatefulSet exists
if ! $K8S_CMD get statefulset clickhouse-shard0 -n $NAMESPACE &> /dev/null; then
    log_error "ClickHouse StatefulSet not found in namespace $NAMESPACE"
    exit 1
fi

# Delete the StatefulSet (keeping pods)
log_info "Scaling down ClickHouse StatefulSet..."
$K8S_CMD scale statefulset clickhouse-shard0 -n $NAMESPACE --replicas=0

# Wait for pods to terminate
log_info "Waiting for pods to terminate..."
sleep 10

if [ "$KEEP_DATA" = false ]; then
    log_warn "⚠️  WARNING: You are about to DELETE all ClickHouse data!"
    log_warn "This will remove all PVCs and data will be lost."
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Operation cancelled"
        exit 0
    fi
    
    log_info "Deleting ClickHouse PVCs..."
    $K8S_CMD delete pvc -l app.kubernetes.io/instance=clickhouse -n $NAMESPACE --ignore-not-found=true
    
    log_info "Waiting for PVCs to be deleted..."
    sleep 5
fi

# Uninstall ClickHouse completely
log_info "Uninstalling ClickHouse helm release..."
helm uninstall clickhouse -n $NAMESPACE --wait || true

log_info "Waiting for cleanup..."
sleep 5

# Reinstall ClickHouse with updated configuration
log_info "Reinstalling ClickHouse with CephFS-compatible configuration..."

# Generate new password
CLICKHOUSE_PASSWORD=$(openssl rand -base64 32)

# Install ClickHouse
helm upgrade --install clickhouse "./clickhouse" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    -f ./neuraltrust/values-clickhouse.yaml \
    --set auth.password="$CLICKHOUSE_PASSWORD" \
    --wait --timeout 10m

# Store password in secret
log_info "Storing ClickHouse credentials in secret..."
$K8S_CMD create secret generic clickhouse-secrets \
    --from-literal=CLICKHOUSE_HOST="clickhouse.$NAMESPACE.svc.cluster.local" \
    --from-literal=CLICKHOUSE_USER="neuraltrust" \
    --from-literal=CLICKHOUSE_PASSWORD="$CLICKHOUSE_PASSWORD" \
    --from-literal=CLICKHOUSE_DATABASE="neuraltrust" \
    --namespace "$NAMESPACE" \
    --dry-run=client -o yaml | $K8S_CMD apply -f -

log_info "✅ ClickHouse reset complete!"
log_info "Password: $CLICKHOUSE_PASSWORD"
log_info ""
log_info "Next steps:"
log_info "1. Wait for ClickHouse pods to be ready: $K8S_CMD get pods -n $NAMESPACE -l app.kubernetes.io/instance=clickhouse"
log_info "2. Run the init job to create database schema"

