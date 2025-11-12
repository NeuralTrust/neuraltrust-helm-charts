# EKS Cluster Configuration
# This file contains the EKS cluster and addon configurations

# Create EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(local.private_subnet_ids, local.public_subnet_ids)
    endpoint_private_access = var.enable_private_endpoint
    endpoint_public_access  = var.enable_public_endpoint
    public_access_cidrs     = var.enable_public_endpoint ? var.public_access_cidrs : []
  }

  # Enable encryption
  encryption_config {
    provider {
      key_arn = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.eks[0].arn
    }
    resources = ["secrets"]
  }

  # Enable logging
  enabled_cluster_log_types = var.enable_logging ? var.cluster_log_types : []

  # OIDC Identity Provider for IRSA (IAM Roles for Service Accounts)
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_cloudwatch_log_group.cluster,
  ]

  tags = {
    Name = var.cluster_name
  }
}

# Create KMS key for EKS encryption (if not provided)
resource "aws_kms_key" "eks" {
  count       = var.kms_key_id == null ? 1 : 0
  description = "EKS cluster encryption key for ${var.cluster_name}"

  tags = {
    Name = "${var.cluster_name}-eks-key"
  }
}

resource "aws_kms_alias" "eks" {
  count         = var.kms_key_id == null ? 1 : 0
  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks[0].key_id
}

# CloudWatch Log Group for EKS
resource "aws_cloudwatch_log_group" "cluster" {
  count             = var.enable_logging ? 1 : 0
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.cluster_name}-logs"
  }
}

# OIDC Identity Provider for IRSA
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.cluster_name}-oidc"
  }
}

# EKS Add-ons
resource "aws_eks_addon" "vpc_cni" {
  count                      = var.enable_vpc_cni_addon ? 1 : 0
  cluster_name               = aws_eks_cluster.main.name
  addon_name                 = "vpc-cni"
  addon_version              = var.vpc_cni_addon_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  count                      = var.enable_coredns_addon ? 1 : 0
  cluster_name               = aws_eks_cluster.main.name
  addon_name                 = "coredns"
  addon_version              = var.coredns_addon_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                 = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "kube_proxy" {
  count                      = var.enable_kube_proxy_addon ? 1 : 0
  cluster_name               = aws_eks_cluster.main.name
  addon_name                 = "kube-proxy"
  addon_version              = var.kube_proxy_addon_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "ebs_csi" {
  count                      = var.enable_ebs_csi_addon ? 1 : 0
  cluster_name               = aws_eks_cluster.main.name
  addon_name                 = "aws-ebs-csi-driver"
  addon_version              = var.ebs_csi_addon_version
  service_account_role_arn   = var.enable_ebs_csi_addon ? aws_iam_role.ebs_csi[0].arn : null
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi,
    aws_eks_node_group.main,
  ]
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      aws_eks_cluster.main.name,
      "--region",
      var.region
    ]
  }
}

