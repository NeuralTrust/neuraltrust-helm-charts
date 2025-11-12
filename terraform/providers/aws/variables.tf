# AWS EKS Variables
# This file contains all variable definitions for AWS EKS infrastructure

# Region Configuration
variable "region" {
  description = "The AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Cluster Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
}

# Network Configuration
variable "existing_vpc_id" {
  description = "ID of existing VPC to use (optional). If not provided, a new VPC will be created."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for VPC (only used when creating new VPC)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

# Cluster Endpoint Configuration
variable "enable_private_endpoint" {
  description = "Enable private endpoint for EKS API server"
  type        = bool
  default     = true
}

variable "enable_public_endpoint" {
  description = "Enable public endpoint for EKS API server"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Encryption Configuration
variable "kms_key_id" {
  description = "KMS key ID for EKS encryption (optional). If not provided, a new key will be created."
  type        = string
  default     = null
}

# Logging Configuration
variable "enable_logging" {
  description = "Enable EKS cluster logging"
  type        = bool
  default     = true
}

variable "cluster_log_types" {
  description = "List of log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7
}

# Node Group Configuration
variable "node_count" {
  description = "Desired number of nodes in the primary node group"
  type        = number
  default     = 3
}

variable "min_node_count" {
  description = "Minimum number of nodes in the primary node group"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes in the primary node group"
  type        = number
  default     = 10
}

variable "instance_type" {
  description = "EC2 instance type for nodes"
  type        = string
  default     = "t3.medium"
}

variable "disk_size_gb" {
  description = "Disk size in GB for nodes"
  type        = number
  default     = 20
}

variable "use_spot_instances" {
  description = "Use Spot instances for cost savings"
  type        = bool
  default     = false
}

variable "node_labels" {
  description = "Labels to apply to nodes"
  type        = map(string)
  default     = {}
}

variable "node_taints" {
  description = "Taints to apply to nodes"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "max_unavailable" {
  description = "Maximum number of unavailable nodes during updates (must be 1-100 for AWS EKS). Note: 0 will be converted to 1."
  type        = number
  default     = 1
  validation {
    condition     = var.max_unavailable >= 0 && var.max_unavailable <= 100
    error_message = "max_unavailable must be between 0 and 100 (0 will be converted to 1 for AWS EKS)."
  }
}

# SSH Access Configuration
variable "enable_ssh_access" {
  description = "Enable SSH access to nodes"
  type        = bool
  default     = false
}

variable "ssh_key_name" {
  description = "Name of the EC2 Key Pair for SSH access"
  type        = string
  default     = null
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH to nodes"
  type        = list(string)
  default     = []
}

# GPU Node Pool Configuration
variable "enable_gpu_node_pool" {
  description = "Enable separate GPU node pool"
  type        = bool
  default     = false
}

variable "gpu_node_pool_name" {
  description = "Name of the GPU node pool"
  type        = string
  default     = "gpu-pool"
}

variable "gpu_instance_types" {
  description = "EC2 instance types for GPU nodes"
  type        = list(string)
  default     = ["g4dn.xlarge"]
}

variable "gpu_node_pool_count" {
  description = "Desired number of nodes in GPU node pool"
  type        = number
  default     = 1
}

variable "gpu_node_pool_min_count" {
  description = "Minimum number of nodes in GPU node pool"
  type        = number
  default     = 0
}

variable "gpu_node_pool_max_count" {
  description = "Maximum number of nodes in GPU node pool"
  type        = number
  default     = 5
}

variable "gpu_node_pool_disk_size_gb" {
  description = "Disk size in GB for GPU nodes"
  type        = number
  default     = 100
}

variable "gpu_node_pool_taints" {
  description = "Taints for GPU node pool"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = [
    {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NO_SCHEDULE"
    }
  ]
}

# EKS Add-ons Configuration
variable "enable_vpc_cni" {
  description = "Enable VPC CNI for pod networking"
  type        = bool
  default     = true
}

variable "enable_vpc_cni_addon" {
  description = "Enable VPC CNI addon"
  type        = bool
  default     = true
}

variable "vpc_cni_addon_version" {
  description = "Version of VPC CNI addon"
  type        = string
  default     = null
}

variable "enable_coredns_addon" {
  description = "Enable CoreDNS addon"
  type        = bool
  default     = true
}

variable "coredns_addon_version" {
  description = "Version of CoreDNS addon"
  type        = string
  default     = null
}

variable "enable_kube_proxy_addon" {
  description = "Enable kube-proxy addon"
  type        = bool
  default     = true
}

variable "kube_proxy_addon_version" {
  description = "Version of kube-proxy addon"
  type        = string
  default     = null
}

variable "enable_ebs_csi_addon" {
  description = "Enable EBS CSI driver addon"
  type        = bool
  default     = false
}

variable "ebs_csi_addon_version" {
  description = "Version of EBS CSI addon"
  type        = string
  default     = null
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs for nodes"
  type        = bool
  default     = true
}

