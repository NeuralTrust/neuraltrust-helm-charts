#!/bin/bash
# Helper script to apply taints to EKS node groups
# Note: AWS EKS managed node groups don't support taints at creation time
# This script applies taints after nodes are created

set -e

CLUSTER_NAME="${CLUSTER_NAME:-neuraltrust-dev}"
REGION="${REGION:-eu-west-1}"

echo "Applying taints to EKS cluster: ${CLUSTER_NAME}"

# Ensure kubectl is configured
echo "Configuring kubectl..."
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}"

# Apply taints to GPU node pool (if exists)
if kubectl get nodes -l pool=gpu --no-headers 2>/dev/null | grep -q .; then
  echo "Applying taints to GPU nodes..."
  kubectl taint nodes -l pool=gpu nvidia.com/gpu=present:NoSchedule --overwrite
  echo "✓ GPU node taints applied"
else
  echo "No GPU nodes found, skipping GPU taints"
fi

# Apply any other taints defined in dev.tfvars
# Example: If you have node_taints defined, you can add them here
# kubectl taint nodes -l pool=primary key=value:effect --overwrite

echo "Done! Verify taints with: kubectl get nodes --show-labels"

