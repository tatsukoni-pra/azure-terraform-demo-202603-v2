resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${local.service_name}-${var.env}"
  resource_group_name = data.azurerm_resource_group.rg_tatsukoni.name
  location            = data.azurerm_resource_group.rg_tatsukoni.location
  address_space       = local.address_space

  tags = {
    env     = var.env
    service = local.service_name
  }
}
