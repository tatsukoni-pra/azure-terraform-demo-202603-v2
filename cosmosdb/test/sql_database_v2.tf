resource "azurerm_cosmosdb_sql_database" "testdatabase_v2" {
  name                = "TestDatabase"
  resource_group_name = var.resource_group.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_account_test_v2.name

  autoscale_settings {
    max_throughput = 1000
  }
}
