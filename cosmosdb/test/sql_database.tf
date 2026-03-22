resource "azurerm_cosmosdb_sql_database" "testdatabase" {
  name                = "TestDatabase"
  resource_group_name = var.resource_group.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_account_test.name

  autoscale_settings {
    max_throughput = local.sql_database_max_throughput
  }
}
