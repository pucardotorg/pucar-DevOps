variable "resource_group" {
  type = string
}

variable "location" {
  type = string
}

variable "environment" {
  type = string
}

# azurerm_storage_account variables
variable "kafka_storage_account" {
  type = object({
    name                     = string
    account_tier             = string
    account_replication_type = string
  })
}

# azurerm_storage_container variables
variable "kafka_storage_container" {
  type = object({
    container_access_type = string
  })
}

# azurem_hdinsight_kafka_cluster variables
variable "kafka_cluster" {
  type = object({
    cluster_version = number
    tier            = string
    tls_min_version = number
  })
}

variable "kafka_component_version" {
  type = number
}

# gateway variables
variable "gateway_username" {
  type = string
}

variable "gateway_password" {
  type = string
}

# head_node variables
variable "head_node_username" {
  type = string
}

variable "head_node_password" {
  type = string
}

variable "head_node_subnet_id" {
  type = string
}

variable "virtual_network_id" {
  type = string
}

variable "head_node_vm_size" {
  type = string
}

#  worker_node variables
variable "worker_node_username" {
  type = string
}

variable "worker_node_password" {
  type = string
}

variable "worker_node_subnet_id" {
  type = string
}

variable "worker_node_vm_size" {
  type = string
}

variable "worker_node_number_of_disks_per_node" {
  type = number
}

variable "worker_node_target_instance_count" {
  type = number
}

# zookeeper_node variables
variable "zookeeper_node_username" {
  type = string
}

variable "zookeeper_node_password" {
  type = string
}

variable "zookeeper_node_vm_size" {
  type = string
}