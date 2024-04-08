provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  features {}
  skip_provider_registration = true
}

terraform {
  backend "azurerm" {
    resource_group_name  = "pucar-dev"
    storage_account_name = "tfstate1dkna"
    container_name       = "pucar-dev-tfstate"
    key                  = "infra.tfstate"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.resource_group}-virtual-network"
  address_space       = var.address_space
  location            = var.location
  resource_group_name = var.resource_group
}

resource "azurerm_subnet" "aks" {
  name                 = "${var.resource_group}-aks-subnet"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.address_prefixes_aks
}

resource "azurerm_subnet" "postgres" {
  name                 = "${var.resource_group}-postgres-subnet"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.address_prefixes_postgres
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "fs"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

#resource "azurerm_subnet" "kafka" {
#  name                 = "${var.resource_group}-kafka-subnet"
#  resource_group_name  = var.resource_group
#  virtual_network_name = azurerm_virtual_network.vnet.name
#  address_prefixes     = var.address_prefixes_kafka
#}

resource "azurerm_network_security_group" "aks_nsg" {
  name                = "${var.environment}-aks-nsg"
  location            = var.location
  resource_group_name = var.resource_group
}

resource "azurerm_network_security_group" "db_nsg" {
  name                = "${var.environment}-db-nsg"
  location            = var.location
  resource_group_name = var.resource_group
}

resource "azurerm_network_security_rule" "pucar_dev_http" {
  name                        = "aks_rule1"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.aks_nsg.name
}

resource "azurerm_network_security_rule" "pucar_dev_https" {
  name                        = "aks_rule2"
  priority                    = 500
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.aks_nsg.name
}

module "kubernetes" {
  source                    = "../modules/kubernetes/azure"
  environment               = var.environment
  name                      = var.environment
  location                  = var.location
  resource_group            = var.resource_group
  client_id                 = var.client_id
  client_secret             = var.client_secret
  private_cluster_enabled   = var.private_cluster_enabled
  vm_size                   = var.vm_size
  ssh_public_key            = var.environment
  node_count                = var.node_count
  min_count                 = var.min_count
  max_count                 = var.max_count
  aks_service_cidr          = var.aks_service_cidr
  aks_dns_service_ip        = var.aks_dns_service_ip
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
  subnet_id                 = azurerm_subnet.aks.id
}

module "postgres-db" {
  source                    = "../modules/db/azure"
  resource_group            = var.resource_group
  location                  = var.location
  sku_tier                  = "GP_Standard_D2ds_v4"
  storage_mb                = "65536"
  backup_retention_days     = "7"
  administrator_login       = var.db_username
  administrator_password    = var.db_password
  db_version                = var.db_version
  subnet_id                 = azurerm_subnet.postgres.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
  virtual_network_id        = azurerm_virtual_network.vnet.id
}

module "zookeeper" {
  source = "../modules/storage/azure"
  environment = "${var.environment}"
  itemCount = "3"
  disk_prefix = "zookeeper"
  location = var.location
  resource_group = "${module.kubernetes.node_resource_group}"
  storage_sku = "Premium_LRS"
  disk_size_gb = "5"
}

module "kafka" {
  source = "../modules/storage/azure"
  environment = "${var.environment}"
  itemCount = "3"
  disk_prefix = "kafka"
  location = var.location
  resource_group = "${module.kubernetes.node_resource_group}"
  storage_sku = "Standard_LRS"
  disk_size_gb = "50"
}

module "es-master" {
  source = "../modules/storage/azure"
  environment = "${var.environment}"
  itemCount = "3"
  disk_prefix = "es-master"
  location = var.location
  resource_group = "${module.kubernetes.node_resource_group}"
  storage_sku = "Premium_LRS"
  disk_size_gb = "2"
}

module "es-data-v1" {
  source = "../modules/storage/azure"
  environment = "${var.environment}"
  itemCount = "2"
  disk_prefix = "es-data-v1"
  location = var.location
  resource_group = "${module.kubernetes.node_resource_group}"
  storage_sku = "Premium_LRS"
  disk_size_gb = "50"
}


#module "kafka" {
#  source                  = "../modules/kafka/azure"
#  environment             = var.environment
#  resource_group          = var.resource_group
#  location                = var.location
#  virtual_network_id      = azurerm_virtual_network.vnet.id
#  kafka_storage_account   = var.kafka_storage_account
#  kafka_storage_container = var.kafka_storage_container
#  kafka_cluster           = var.kafka_cluster
#  kafka_component_version = var.kafka_component_version
#
#  # gateway
#  gateway_username = var.gateway_username
#  gateway_password = var.gateway_password
#
#  # head node
#  head_node_vm_size   = var.head_node_vm_size
#  head_node_username  = var.head_node_username
#  head_node_password  = var.head_node_password
#  head_node_subnet_id = azurerm_subnet.kafka.id
#
#  # worker node
#  worker_node_vm_size                  = var.worker_node_vm_size
#  worker_node_username                 = var.worker_node_username
#  worker_node_password                 = var.worker_node_password
#  worker_node_number_of_disks_per_node = var.worker_node_number_of_disks_per_node
#  worker_node_target_instance_count    = var.worker_node_target_instance_count
#  worker_node_subnet_id                = azurerm_subnet.kafka.id
#
#  # zookeeper node
#  zookeeper_node_vm_size  = var.zookeeper_node_vm_size
#  zookeeper_node_username = var.zookeeper_node_username
#  zookeeper_node_password = var.zookeeper_node_password
#}


#module "agw" {
#  source                          = "../modules/Network/applicationGateway"
#  resource_group                  = var.resource_group
#  location                        = var.location
#  environment                     = var.environment
#  virtual_network_name            = azurerm_virtual_network.vnet.name
#  agw_subnet_add_prefixes         = var.agw_subnet_add_prefixes
#  agw_public_ip                   = var.agw_public_ip
#  sku                             = var.agw_sku
#  frontend                        = var.frontend
#  backend_address_pool_ip_address = var.backend_address_pool_ip_address
#  backend                         = var.backend
#  request_routing_rule            = var.request_routing_rule
#  probe                           = var.probe
#  waf_policy_id                   = module.waf.waf_policy_id
#  ssl_certificate_name            = var.ssl_certificate_name
#  ssl_certificate_data            = var.ssl_certificate_data
#  ssl_certificate_password        = var.ssl_certificate_password
#}


#module "firewall" {
#  source                           = "../modules/Network/Firewall"
#  environment                      = var.environment
#  resource_group                   = var.resource_group
#  location                         = var.location
#  virtual_network_name             = azurerm_virtual_network.vnet.name
#  firewall_public_ip               = var.firewall_public_ip
#  firewall                         = var.firewall
#  firewall_subnet_address_prefixes = var.firewall_subnet_address_prefixes
#}


#module "waf" {
#  source              = "../modules/Network/WAF/azure"
#  resource_group      = var.resource_group
#  location            = var.location
#  environment         = var.environment
#  policy_settings_waf = var.policy_settings_waf
#  managed_rule_sets   = var.managed_rule_set
#  custom_rules        = var.custom_rules
#}


#module "container_registry" {
#  source                         = "../modules/containers/azure"
#  cr_default_environment         = var.cr_default_environment
#  cr_resource_group              = var.cr_resource_group
#  location                       = var.location
#  container_registry_name        = var.container_registry_name
#  container_registry             = var.container_registry
#  envs                           = var.envs
#  apps_role                      = var.apps_role
#  manual_connection_pvt_endpoint = var.manual_connection_pvt_endpoint
#  subresource_names              = var.subresource_names
#}
