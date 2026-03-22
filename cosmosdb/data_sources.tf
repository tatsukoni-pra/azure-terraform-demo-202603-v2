## リソースグループ参照
data "azurerm_resource_group" "rg_tatsukoni" {
  name = "rg-tatsukoni-${var.env}"
}
