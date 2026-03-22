module "cosmosdb" {
  source = "./cosmosdb"
  env    = var.env
}

module "vnet" {
  source = "./vnet"
  env    = var.env
}

## データ参照 リソースグループ
data "azurerm_resource_group" "rg_tatsukoni" {
  name = "rg-${local.service_name}-${var.env}"
}

## tfstate用ストレージアカウント
resource "azurerm_storage_account" "tfstate" {
  name                             = "st${local.service_name}${var.env}tfstate"
  resource_group_name              = data.azurerm_resource_group.rg_tatsukoni.name
  location                         = data.azurerm_resource_group.rg_tatsukoni.location
  account_tier                     = "Standard"
  account_replication_type         = "GRS"
  allow_nested_items_to_be_public  = false
  min_tls_version                  = "TLS1_2"
  cross_tenant_replication_enabled = true

  blob_properties {
    versioning_enabled = true
  }

  tags = {
    env     = var.env
    service = local.service_name
  }
}
