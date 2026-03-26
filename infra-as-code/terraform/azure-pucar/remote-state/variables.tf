variable "storage_container_name" {
  type = string
  default = "pucar-dev-tfstate"
}

variable "environment" {
  type = string
  default = "dev"
}

variable "location" {
  type = string
  default = "SouthIndia"
}

variable "resource_group" {
  type = string
  default = "pucar-dev"
}

variable "subscription_id" {
  type = string
}
