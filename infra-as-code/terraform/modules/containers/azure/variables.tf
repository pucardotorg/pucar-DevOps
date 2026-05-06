variable "cr_default_environment" {
  type = string
}

variable "cr_resource_group" {
  type = string
}

variable "location" {
  type = string
}

variable "container_registry_name" {
  type = string
}

variable "container_registry" {
  type = object({
    sku                       = string
    quarantine_policy_enabled = bool
    trust_policy_enabled      = bool
    retention_policy = object({
      days    = number
      enabled = bool
    })
    network_rule_set = object({
      default_action = string
      ip_rules = list(object({
        action   = string
        ip_range = string
      }))
    })
  })
}

variable "envs" {
  type = set(string)
}

variable "apps_role" {
  type = map(string)
}

variable "manual_connection_pvt_endpoint" {
  type = map(bool)
}

variable "subresource_names" {
  type = map(list(string))
}