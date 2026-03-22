resource "azurerm_cosmosdb_sql_container" "testcontainerapp_v2" {
  name                = "TestContainerApp"
  resource_group_name = var.resource_group.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_account_test_v2.name
  database_name       = azurerm_cosmosdb_sql_database.testdatabase_v2.name
  partition_key_paths = ["/id"]
}

resource "azurerm_cosmosdb_sql_container" "testcontainerfront_v2" {
  name                = "TestContainerFront"
  resource_group_name = var.resource_group.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_account_test_v2.name
  database_name       = azurerm_cosmosdb_sql_database.testdatabase_v2.name
  partition_key_paths = ["/userId"]
}
