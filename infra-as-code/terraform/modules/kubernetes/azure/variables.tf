variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group" {
  type = string
}

variable "vm_size" {
  type = string
}

variable "node_count" {
  type = number
}

variable "subnet_id" {
  type = string
}

variable "min_count" {
  type = number
}

variable "max_count" {
  type = number
}

variable "max_pod" {
  type = number
}

variable "client_id" {
  type = string
}

variable "client_secret" {
  type = string
}

variable "aks_service_cidr" {
  type = string
}

variable "aks_dns_service_ip" {
  type = string
}

variable "environment" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "network_security_group_id" {
  type = string
}

variable "private_cluster_enabled" {
  type = bool
}
