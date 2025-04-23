variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "use_existing_resource_group" {
  description = "Whether to use an existing resource group"
  type        = bool
  default     = false
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "eastus"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.24.0"
}

variable "system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 1
}

variable "system_node_size" {
  description = "Size of the nodes in the system node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "system_node_disk_size" {
  description = "OS disk size for system nodes in GB"
  type        = number
  default     = 50
}

variable "use_existing_vnet" {
  description = "Whether to use an existing virtual network"
  type        = bool
  default     = false
}

variable "existing_vnet_name" {
  description = "Name of the existing virtual network"
  type        = string
  default     = ""
}

variable "existing_vnet_resource_group" {
  description = "Resource group name of the existing virtual network"
  type        = string
  default     = ""
}

variable "existing_subnet_name" {
  description = "Name of the existing subnet"
  type        = string
  default     = ""
}

variable "user_node_size" {
  description = "Size of the nodes in the user node pool"
  type        = string
  default     = "Standard_D4s_v3"  # 4 vCPU, 16GB RAM
}

variable "user_node_count" {
  description = "Initial number of nodes in the user node pool"
  type        = number
  default     = 3
}

variable "user_node_disk_size" {
  description = "OS disk size for user nodes in GB"
  type        = number
  default     = 100
}

variable "user_node_min_count" {
  description = "Minimum number of nodes in the user node pool"
  type        = number
  default     = 3
}

variable "user_node_max_count" {
  description = "Maximum number of nodes in the user node pool"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
} 