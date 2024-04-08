resource "azurerm_kubernetes_cluster" "aks" {
  name                    = var.name
  location                = var.location
  resource_group_name     = var.resource_group
  dns_prefix              = var.name
  private_cluster_enabled = var.private_cluster_enabled

  default_node_pool {
    name                = "default"
    vm_size             = var.vm_size
    enable_auto_scaling = "true"
    node_count          = var.node_count
    vnet_subnet_id      = var.subnet_id
    min_count           = var.min_count
    max_count           = var.max_count
  }

  service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = var.aks_service_cidr
    dns_service_ip = var.aks_dns_service_ip
    network_policy = "calico"
    outbound_type  = "loadBalancer"
  }

  lifecycle {
    ignore_changes = [
      default_node_pool["node_count"],
    ]
  }
  tags = {
    Environment = "${var.environment}"
  }

}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = var.subnet_id
  network_security_group_id = var.network_security_group_id
}
