resource "azurerm_container_registry" "container_registry" {
  name                      = var.container_registry_name
  resource_group_name       = var.cr_resource_group
  location                  = var.location
  sku                       = var.container_registry.sku
  quarantine_policy_enabled = var.container_registry.quarantine_policy_enabled
  trust_policy {
    enabled = var.container_registry.trust_policy_enabled
  }
  retention_policy {
    days    = var.container_registry.retention_policy.days
    enabled = var.container_registry.retention_policy.enabled
  }
  network_rule_set {
    default_action = var.container_registry.network_rule_set.default_action
    ip_rule        = var.container_registry.network_rule_set.ip_rules
  }

  tags = {
    environment = "${var.cr_default_environment}"
  }
}

# end points
resource "azurerm_private_endpoint" "private_endpoint" {
  for_each            = var.envs
  resource_group_name = "pucar-${each.value}"
  location            = var.location
  subnet_id           = data.azurerm_subnet.subnet_aks[each.value].id
  name                = "${each.value}-pvt-endpoint"
  private_service_connection {
    is_manual_connection           = var.manual_connection_pvt_endpoint[each.value]
    name                           = "${each.value}-service-connection"
    private_connection_resource_id = azurerm_container_registry.container_registry.id
    subresource_names              = var.subresource_names[each.value]
  }
  depends_on = [data.azurerm_subnet.subnet_aks, azurerm_container_registry.container_registry]
}

resource "azurerm_role_assignment" "app_cr_role" {
  for_each                         = var.envs
  principal_id                     = data.azuread_service_principal.app_service_principal[each.value].id
  role_definition_name             = var.apps_role[each.value]
  scope                            = azurerm_container_registry.container_registry.id
  skip_service_principal_aad_check = true
  depends_on                       = [data.azuread_application.app_registry, data.azurerm_subnet.subnet_aks]
}

# data blocks
data "azurerm_subnet" "subnet_aks" {
  for_each             = var.envs
  name                 = "pucar-${each.value}-aks-subnet"
  virtual_network_name = "pucar-${each.value}-virtual-network"
  resource_group_name  = "pucar-${each.value}"
  depends_on           = [data.azuread_application.app_registry]
}

data "azuread_application" "app_registry" {
  for_each     = var.envs
  display_name = "${each.value}-app"
  depends_on   = [azurerm_container_registry.container_registry]
}

data "azuread_service_principal" "app_service_principal" {
  for_each   = var.envs
  client_id  = data.azuread_application.app_registry[each.value].client_id
  depends_on = [data.azuread_application.app_registry]
}