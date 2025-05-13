# Resource Group
resource "azurerm_resource_group" "main" {
  count    = var.use_existing_resource_group ? 0 : 1
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Data source for existing resource group
data "azurerm_resource_group" "existing" {
  count = var.use_existing_resource_group ? 1 : 0
  name  = var.resource_group_name
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  count               = var.use_existing_vnet ? 0 : 1
  name                = "${var.cluster_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.use_existing_resource_group ? data.azurerm_resource_group.existing[0].location : azurerm_resource_group.main[0].location
  resource_group_name = var.use_existing_resource_group ? data.azurerm_resource_group.existing[0].name : azurerm_resource_group.main[0].name
  tags                = var.tags
}

# Data source for existing virtual network
data "azurerm_virtual_network" "existing" {
  count               = var.use_existing_vnet ? 1 : 0
  name                = var.existing_vnet_name
  resource_group_name = var.existing_vnet_resource_group
}

# Subnet
resource "azurerm_subnet" "main" {
  count                = var.use_existing_vnet ? 0 : 1
  name                 = "${var.cluster_name}-subnet"
  resource_group_name  = var.use_existing_resource_group ? data.azurerm_resource_group.existing[0].name : azurerm_resource_group.main[0].name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = ["10.0.1.0/24"]
}

# Data source for existing subnet
data "azurerm_subnet" "existing" {
  count                = var.use_existing_vnet ? 1 : 0
  name                 = var.existing_subnet_name
  virtual_network_name = var.existing_vnet_name
  resource_group_name  = var.existing_vnet_resource_group
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.use_existing_resource_group ? data.azurerm_resource_group.existing[0].location : azurerm_resource_group.main[0].location
  resource_group_name = var.use_existing_resource_group ? data.azurerm_resource_group.existing[0].name : azurerm_resource_group.main[0].name
  dns_prefix         = var.cluster_name
  kubernetes_version = var.kubernetes_version

  default_node_pool {
    name            = "system"
    node_count      = var.system_node_count
    vm_size         = var.system_node_size
    os_disk_size_gb = var.system_node_disk_size
    vnet_subnet_id  = var.use_existing_vnet ? data.azurerm_subnet.existing[0].id : azurerm_subnet.main[0].id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = "10.0.2.0/24"
    dns_service_ip    = "10.0.2.10"
  }

  tags = var.tags
}

# User Node Pool for NeuralTrust Application
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size              = var.user_node_size
  node_count           = var.user_node_count
  os_disk_size_gb      = var.user_node_disk_size
  vnet_subnet_id       = var.use_existing_vnet ? data.azurerm_subnet.existing[0].id : azurerm_subnet.main[0].id

  # Node labels for workload scheduling
  node_labels = {
    "node.kubernetes.io/role" = "user"
    "workload"               = "neuraltrust"
  }

  # Enable auto-scaling
  enable_auto_scaling = true
  min_count          = var.user_node_min_count
  max_count          = var.user_node_max_count

  # Upgrade settings
  upgrade_settings {
    max_surge = "1"
  }
}

# Outputs
output "kube_config" {
  value     = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive = true
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "resource_group_name" {
  value = var.use_existing_resource_group ? data.azurerm_resource_group.existing[0].name : azurerm_resource_group.main[0].name
}

output "vnet_name" {
  value = var.use_existing_vnet ? data.azurerm_virtual_network.existing[0].name : azurerm_virtual_network.main[0].name
}

output "subnet_name" {
  value = var.use_existing_vnet ? data.azurerm_subnet.existing[0].name : azurerm_subnet.main[0].name
} 