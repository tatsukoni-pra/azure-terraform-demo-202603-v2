resource "azurerm_cosmosdb_sql_container" "testcontainerapp" {
  name                = "TestContainerApp"
  resource_group_name = var.resource_group.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_account_test.name
  database_name       = azurerm_cosmosdb_sql_database.testdatabase.name
  partition_key_paths = ["/id"]
}

resource "azurerm_cosmosdb_sql_container" "testcontainerfront" {
  name                = "TestContainerFront"
  resource_group_name = var.resource_group.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_account_test.name
  database_name       = azurerm_cosmosdb_sql_database.testdatabase.name
  partition_key_paths = ["/userId"]
}
