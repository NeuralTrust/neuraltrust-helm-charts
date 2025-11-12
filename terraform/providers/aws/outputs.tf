# AWS EKS Outputs
# This file contains output values for the EKS cluster

# Cluster Information
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_id" {
  description = "ID of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
  sensitive   = true
}

output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

# OIDC Provider Information
output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Network Information
output "vpc_id" {
  description = "ID of the VPC"
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = local.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = local.public_subnet_ids
}

# Node Group Information
output "node_group_id" {
  description = "ID of the primary node group"
  value       = aws_eks_node_group.main.id
}

output "node_group_arn" {
  description = "ARN of the primary node group"
  value       = aws_eks_node_group.main.arn
}

output "node_group_status" {
  description = "Status of the primary node group"
  value       = aws_eks_node_group.main.status
}

output "gpu_node_group_id" {
  description = "ID of the GPU node group (if enabled)"
  value       = var.enable_gpu_node_pool ? aws_eks_node_group.gpu[0].id : null
}

# IAM Role Information
output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "node_iam_role_arn" {
  description = "IAM role ARN of the node groups"
  value       = aws_iam_role.node.arn
}

# KMS Key Information
output "kms_key_id" {
  description = "KMS key ID used for cluster encryption"
  value       = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.eks[0].id
}

output "kms_key_arn" {
  description = "KMS key ARN used for cluster encryption"
  value       = var.kms_key_id != null ? null : aws_kms_key.eks[0].arn
}

# Connection Information
output "kubectl_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${var.region}"
}

output "cluster_info" {
  description = "Cluster information for kubectl configuration"
  value = {
    name     = aws_eks_cluster.main.name
    endpoint = aws_eks_cluster.main.endpoint
    ca_data  = aws_eks_cluster.main.certificate_authority[0].data
    region   = var.region
  }
  sensitive = true
}

