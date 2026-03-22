module "test" {
  # count          = var.env == "prd" ? 1 : 0  # prd環境のみ有効
  source         = "./test"
  env            = var.env
  resource_group = data.azurerm_resource_group.rg_tatsukoni
}

module "feat" {
  # count          = var.env == "prd" ? 1 : 0  # prd環境のみ有効
  source         = "./feat"
  env            = var.env
  resource_group = data.azurerm_resource_group.rg_tatsukoni
}
