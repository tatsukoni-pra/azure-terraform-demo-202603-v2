data "azurerm_resource_group" "rg_tatsukoni" {
  name = "rg-${local.service_name}-${var.env}"
}
