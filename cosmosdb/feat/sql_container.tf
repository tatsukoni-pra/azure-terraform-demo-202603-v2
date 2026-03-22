resource "azurerm_cosmosdb_sql_container" "featcontainerapp" {
  name                = "FeatContainerApp"
  resource_group_name = var.resource_group.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_account_feat.name
  database_name       = azurerm_cosmosdb_sql_database.featdatabase.name
  partition_key_paths = ["/id"]
}

resource "azurerm_cosmosdb_sql_container" "featcontainerfront" {
  name                = "FeatContainerFront"
  resource_group_name = var.resource_group.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_account_feat.name
  database_name       = azurerm_cosmosdb_sql_database.featdatabase.name
  partition_key_paths = ["/userId"]
}
