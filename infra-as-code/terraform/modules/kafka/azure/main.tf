resource "azurerm_storage_account" "hd_kafka_storage_account" {
  name                     = var.kafka_storage_account.name
  resource_group_name      = var.resource_group
  location                 = var.location
  account_tier             = var.kafka_storage_account.account_tier
  account_replication_type = var.kafka_storage_account.account_replication_type

  tags = {
    environment = var.environment
  }
}

resource "azurerm_storage_container" "hd_kafka_storage_container" {
  name                  = "${var.environment}-kafka-sc"
  storage_account_name  = azurerm_storage_account.hd_kafka_storage_account.name
  container_access_type = var.kafka_storage_container.container_access_type
}

resource "azurerm_hdinsight_kafka_cluster" "HDin_Kafka_Cluster" {
  name                          = "${var.environment}-kafka"
  resource_group_name           = var.resource_group
  location                      = var.location
  cluster_version               = var.kafka_cluster.cluster_version
  tier                          = var.kafka_cluster.tier
  tls_min_version               = var.kafka_cluster.tls_min_version
  encryption_in_transit_enabled = true

  tags = {
    environment = "${var.environment}"
  }

  component_version {
    kafka = var.kafka_component_version
  }

  gateway {
    username = var.gateway_username
    password = var.gateway_password
  }

  storage_account {
    storage_container_id = azurerm_storage_container.hd_kafka_storage_container.id
    storage_account_key  = azurerm_storage_account.hd_kafka_storage_account.primary_access_key
    is_default           = true
  }

  roles {
    head_node {
      vm_size            = var.head_node_vm_size
      username           = var.head_node_username
      password           = var.head_node_password
      subnet_id          = var.head_node_subnet_id
      virtual_network_id = var.virtual_network_id
    }

    worker_node {
      vm_size                  = var.worker_node_vm_size
      username                 = var.worker_node_username
      password                 = var.worker_node_password
      number_of_disks_per_node = var.worker_node_number_of_disks_per_node
      target_instance_count    = var.worker_node_target_instance_count
      subnet_id                = var.worker_node_subnet_id
      virtual_network_id       = var.virtual_network_id
    }

    zookeeper_node {
      vm_size  = var.zookeeper_node_vm_size
      username = var.zookeeper_node_username
      password = var.zookeeper_node_password
    }
  }
}