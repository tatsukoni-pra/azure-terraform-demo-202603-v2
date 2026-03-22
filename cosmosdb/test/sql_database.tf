resource "azurerm_cosmosdb_sql_database" "testdatabase" {
  # count               = var.env == "prd" ? 1 : 0  # prd環境のみ作成
  name                = "TestDatabase"
  resource_group_name = var.resource_group.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_account_test.name

  autoscale_settings {
    max_throughput = local.sql_database_max_throughput
  }
}
