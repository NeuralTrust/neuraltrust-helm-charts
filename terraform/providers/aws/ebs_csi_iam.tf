# IAM Role for EBS CSI Driver (IRSA)
# This file contains IAM role and policy for the EBS CSI driver addon

# IAM Role for EBS CSI Driver
resource "aws_iam_role" "ebs_csi" {
  count = var.enable_ebs_csi_addon ? 1 : 0
  name  = "${var.cluster_name}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-ebs-csi-role"
  }

  # Ensure OIDC provider is created first
  depends_on = [aws_iam_openid_connect_provider.eks]
}

# Attach EBS CSI Driver policy
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count      = var.enable_ebs_csi_addon ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi[0].name
}

