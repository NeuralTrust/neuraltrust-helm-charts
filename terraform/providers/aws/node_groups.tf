# EKS Node Groups Configuration
# This file contains managed node groups for EKS

# Primary Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "primary-pool"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = local.private_subnet_ids
  version         = var.kubernetes_version

  scaling_config {
    desired_size = var.node_count
    min_size     = var.min_node_count
    max_size     = var.max_node_count
  }

  instance_types = [var.instance_type]

  capacity_type = var.use_spot_instances ? "SPOT" : "ON_DEMAND"

  disk_size = var.disk_size_gb

  labels = merge(var.node_labels, {
    pool = "primary"
  })

  # Note: Taints cannot be set directly on AWS EKS managed node groups.
  # Apply taints via Kubernetes after nodes are created, or use node labels
  # to identify nodes and apply taints using kubectl or Kubernetes resources.

  # Only include remote_access block when SSH is enabled to avoid forced replacement
  dynamic "remote_access" {
    for_each = var.enable_ssh_access && var.ssh_key_name != null ? [1] : []
    content {
      ec2_ssh_key               = var.ssh_key_name
      source_security_group_ids = [aws_security_group.ssh_access[0].id]
    }
  }

  update_config {
    # AWS EKS requires max_unavailable to be between 1-100
    # If 0 is provided, use 1 (minimum allowed value)
    max_unavailable = var.max_unavailable == 0 ? 1 : var.max_unavailable
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  depends_on = [
    aws_iam_role_policy_attachment.node_worker_node_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_container_registry_policy,
  ]

  tags = {
    Name = "${var.cluster_name}-primary-pool"
  }
}

# GPU Node Group (optional)
resource "aws_eks_node_group" "gpu" {
  count           = var.enable_gpu_node_pool ? 1 : 0
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = var.gpu_node_pool_name
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = local.private_subnet_ids
  version         = var.kubernetes_version

  scaling_config {
    desired_size = var.gpu_node_pool_count
    min_size     = var.gpu_node_pool_min_count
    max_size     = var.gpu_node_pool_max_count
  }

  instance_types = var.gpu_instance_types

  capacity_type = "ON_DEMAND" # GPUs typically not available as spot

  disk_size = var.gpu_node_pool_disk_size_gb

  labels = {
    pool = "gpu"
  }

  # Note: Taints cannot be set directly on AWS EKS managed node groups.
  # Apply taints via Kubernetes after nodes are created.
  # For GPU nodes, apply: kubectl taint nodes -l pool=gpu nvidia.com/gpu=present:NoSchedule

  # Only include remote_access block when SSH is enabled to avoid forced replacement
  dynamic "remote_access" {
    for_each = var.enable_ssh_access && var.ssh_key_name != null ? [1] : []
    content {
      ec2_ssh_key               = var.ssh_key_name
      source_security_group_ids = [aws_security_group.ssh_access[0].id]
    }
  }

  update_config {
    # AWS EKS requires max_unavailable to be between 1-100
    # If 0 is provided, use 1 (minimum allowed value)
    max_unavailable = var.max_unavailable == 0 ? 1 : var.max_unavailable
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_node_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_container_registry_policy,
  ]

  tags = {
    Name = "${var.cluster_name}-${var.gpu_node_pool_name}"
  }
}

# Security Group for SSH access to nodes
resource "aws_security_group" "ssh_access" {
  count       = var.enable_ssh_access ? 1 : 0
  name        = "${var.cluster_name}-ssh-access"
  description = "Security group for SSH access to EKS nodes"
  vpc_id      = local.vpc_id

  ingress {
    description = "SSH from allowed CIDRs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-ssh-access"
  }
}

