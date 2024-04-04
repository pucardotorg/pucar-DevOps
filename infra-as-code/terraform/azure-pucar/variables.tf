variable "subscription_id" {
    type = string
}

variable "tenant_id" {
    type = string
}

variable "client_id" {
    type = string
}

variable "client_secret" {
    type = string
}

variable "kafka_storage_account" {
    type = object({
        name                     = string
        account_tier             = string
        account_replication_type = string
    })
}

variable "kafka_storage_container" {
    type = object({
        container_access_type = string
    })
}

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

variable "address_space" {
    type = list(string)
}

variable "address_prefixes_aks" {
    type = list(string)
}

variable "environment" {
    type = string
}

variable "resource_group" {
    type = string
}

variable "location" {
    default = "Central India"
}

variable "db_version" {
    default = "11"
}

variable "db_username" {
    type = string
}

variable "db_password" {
    type = string
}

variable "address_prefixes_postgres" {
    type = list(string)
}

variable "private_cluster_enabled" {
    type = bool
}

variable "node_count" {
    type = number
}

variable "min_count" {
    type = number
}

variable "max_count" {
    type = number
}

variable "aks_service_cidr" {
    type = string
}

variable "aks_dns_service_ip" {
    type = string
}

variable "vm_size" {
    type = string
}

#variable "gateway_username" {
#    type = string
#}
#
#variable "gateway_password" {
#    type = string
#}
#
#variable "head_node_vm_size" {
#    type = string
#}
#
#variable "head_node_username" {
#    type = string
#}
#
#variable "head_node_password" {
#    type = string
#}
#
#variable "worker_node_vm_size" {
#    type = string
#}
#
#variable "worker_node_username" {
#    type = string
#}
#
#variable "worker_node_password" {
#    type = string
#}
#
#variable "worker_node_number_of_disks_per_node" {
#    type = number
#}
#
#variable "worker_node_target_instance_count" {
#    type = number
#}
#
#variable "zookeeper_node_vm_size" {
#    type = string
#}
#
#variable "zookeeper_node_username" {
#    type = string
#}
#
#variable "zookeeper_node_password" {
#    type = string
#}
#
#variable "address_prefixes_kafka" {
#    type = list(string)
#}

#variable "agw_subnet_add_prefixes" {
#    type = list(string)
#}
#
#variable "agw_public_ip" {
#    type = object({
#        allocation_method    = string
#        sku                  = string
#        ddos_protection_mode = string
#    })
#}
#
#variable "agw_sku" {
#    type = object({
#        name     = string
#        tier     = string
#        capacity = number
#    })
#}

#variable "ssl_certificate_name" {
#    type = string
#}
#
#variable "ssl_certificate_data" {
#    type = string
#}
#
#variable "ssl_certificate_password" {
#    type = string
#}
#
#variable "frontend" {
#    type = object({
#        port       = number
#        protocol   = string
#        host_names = list(string)
#    })
#}
#
#variable "backend_address_pool_ip_address" {
#    type = list(string)
#}

#variable "backend" {
#    type = object({
#        protocol              = string
#        port                  = number
#        request_timeout       = number
#        host_name             = string
#        cookie_based_affinity = string
#    })
#}
#
#variable "request_routing_rule" {
#    type = object({
#        priority  = number
#        rule_type = string
#    })
#}
#
#variable "probe" {
#    type = object({
#        host                = string
#        path                = string
#        protocol            = string
#        unhealthy_threshold = number
#        timeout             = number
#        interval            = number
#    })
#}
#
#variable "firewall_public_ip" {
#    type = object({
#        allocation_method = string
#        sku               = string
#    })
#}
#
#variable "firewall" {
#    type = object({
#        sku_name = string
#        sku_tier = string
#    })
#}
#
#variable "firewall_subnet_address_prefixes" {
#    type = list(string)
#}
#
## waf
#variable "policy_settings_waf" {
#    type = object({
#        file_upload_limit_in_mb     = number
#        max_request_body_size_in_kb = number
#        mode                        = string
#    })
#}
#
#variable "managed_rule_set" {
#    type = map(object({
#        type    = string
#        version = string
#    }))
#}
#
#variable "custom_rules" {
#    type = map(object({
#        name               = string
#        priority           = number
#        rule_type          = string
#        action             = string
#        variable_name      = string
#        operator           = string
#        negation_condition = bool
#        match_values       = list(string)
#    }))
#}
#
#variable "cr_default_environment" {
#    type = string
#}
#
#variable "cr_resource_group" {
#    type = string
#}
#
#variable "container_registry_name" {
#    type = string
#}
#
#variable "container_registry" {
#    type = object({
#        sku                       = string
#        quarantine_policy_enabled = bool
#        trust_policy_enabled      = bool
#        retention_policy = object({
#            days    = number
#            enabled = bool
#        })
#        network_rule_set = object({
#            default_action = string
#            ip_rules = list(object({
#                action   = string
#                ip_range = string
#            }))
#        })
#    })
#}
#
#variable "envs" {
#    type = set(string)
#}
#
#variable "apps_role" {
#    type = map(string)
#}
#
#variable "manual_connection_pvt_endpoint" {
#    type = map(bool)
#}
#
#variable "subresource_names" {
#    type = map(list(string))
#}
