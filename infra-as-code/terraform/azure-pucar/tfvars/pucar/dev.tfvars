# credentials for creating resources
resource_group = "pucar-dev"
environment    = "dev"
# networking
address_space = ["10.7.0.0/16"]

# postgres
db_version                = "11"
address_prefixes_postgres = ["10.7.2.0/24"]
zone                      = "2"

# kubernetes variables
private_cluster_enabled  = false
vm_size                  = "Standard_D4_v4"
node_count               = "2"
min_count                = "2"
max_count                = "4"
address_prefixes_aks     = ["10.7.1.0/24"]
aks_dns_service_ip       = "10.7.4.10"
aks_service_cidr         = "10.7.4.0/24"

# storage account kafka
kafka_storage_account = {
  name                     = "pucarhdinsightkafka"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
# storage container kafka
kafka_storage_container = {
  container_access_type = "private"
}
# kafka cluster
kafka_cluster = {
  cluster_version = 5.1
  tier            = "Standard"
  tls_min_version = 1.2
}
kafka_component_version = 3.2
# kafka variables
address_prefixes_kafka = ["10.7.7.0/24"]
# head node
head_node_vm_size = "Standard_E2_V3"
# worker node
worker_node_number_of_disks_per_node = 1
worker_node_target_instance_count    = 1
worker_node_vm_size                  = "Standard_E2_V3"
# zookeeper node
zookeeper_node_vm_size = "Standard_A1_V2"

# agw
#agw_public_ip = {
#  allocation_method    = "Static"
#  sku                  = "Standard"
#  ddos_protection_mode = "Enabled"
#}
#agw_sku = {
#  name     = "WAF_v2"
#  tier     = "WAF_v2"
#  capacity = "2"
#}
#agw_subnet_add_prefixes = ["10.7.5.0/24"]
#backend = {
#  protocol              = "Https"
#  port                  = 443
#  request_timeout       = 20
#  host_name             = "www.biharkrishi.in"
#  cookie_based_affinity = "Disabled"
#}
#backend_address_pool_ip_address = ["10.7.1.134"]
#frontend = {
#  port       = 443
#  protocol   = "Https"
#  host_names = ["biharkrishi.in", "www.biharkrishi.in"]
#}
#probe = {
#  host                = "www.biharkrishi.in"
#  path                = "/"
#  protocol            = "Https"
#  unhealthy_threshold = 3
#  timeout             = 30
#  interval            = 30
#}
#request_routing_rule = {
#  priority  = 100
#  rule_type = "Basic"
#}

# firewall
#firewall = {
#  sku_name = "AZFW_VNet"
#  sku_tier = "Standard"
#}
#firewall_public_ip = {
#  allocation_method = "Static"
#  sku               = "Standard"
#}
#firewall_subnet_address_prefixes = ["10.7.4.0/24"]
#
## waf
#policy_settings_waf = {
#  file_upload_limit_in_mb     = 100
#  max_request_body_size_in_kb = 128
#  mode                        = "Detection"
#}
#managed_rule_set = {
#  OWASP = {
#    type    = "OWASP"
#    version = "3.2"
#  }
#  Microsoft_BotManagerRuleSet = {
#    type    = "Microsoft_BotManagerRuleSet"
#    version = "0.1"
#  }
#}
#custom_rules = {
#  "customrule1" = {
#    name               = "AccessibleFromIndia"
#    priority           = 1
#    rule_type          = "MatchRule"
#    action             = "Block"
#    variable_name      = "RemoteAddr"
#    operator           = "GeoMatch"
#    negation_condition = true
#    match_values       = ["IN"]
#  }
#}

#container_registry_name = "stagingcrtest"
#cr_default_environment  = "staging"
#cr_resource_group       = "pucar-staging"
#container_registry = {
#  sku                       = "Premium"
#  quarantine_policy_enabled = false
#  trust_policy_enabled      = false
#  retention_policy = {
#    days    = 7
#    enabled = false
#  }
#  network_rule_set = {
#    default_action = "Deny"
#    ip_rules = [
#      {
#        action   = "Allow"
#        ip_range = "123.123.123.123/32"
#      },
#      {
#        action   = "Allow"
#        ip_range = "123.123.123.124/32"
#      }
#    ]
#
#  }
#}
#envs = [ "dev"]
#apps_role = {
#  "dev"     = "AcrPush"
#}
#manual_connection_pvt_endpoint = {
#  "dev"     = false
#}
#subresource_names = {
#  "dev"     = ["registry"]
#}
