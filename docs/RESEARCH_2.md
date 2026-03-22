# 手動削除されたリソースに対する Terraform Refresh の挙動

## 概要

- 実リソースは手動で削除済
- terraformコードも削除済
- tfstateには状態が記録されている

場合の、terraform plan / terraform apply 実行時の挙動を記す。

## 挙動

plan結果が「No changes」となり、apply実行によってtfstateのみ削除される。<br>
これは、Terraformの正式な仕様・挙動である。<br>
ポイントは refresh（リフレッシュ） のメカニズムにある。

### refresh（リフレッシュ） のメカニズム

plan や apply の実行時、Terraformはまず refreshフェーズ を走らせる。<br>
このフェーズでは、tfstateに記録されている各リソースについて、実際のクラウドAPIに問い合わせて現在の状態を確認する。

### terraform plan 実行時

1. refreshフェーズで実リソースの存在を確認 → 存在しない
2. メモリ上のstateからそのリソースを除外
3. コード上にも記述がない
4. メモリ上のstateとコードが一致 → 「No changes」

※ ただし plan はstateファイルをディスクに書き戻さないので、tfstate上には古いエントリが残ったまま

```bash
$ terraform plan -var env=dev
Acquiring state lock. This may take a few moments...
module.cosmosdb.data.azurerm_resource_group.rg_tatsukoni: Reading...
data.azurerm_resource_group.rg_tatsukoni: Reading...
module.vnet.data.azurerm_resource_group.rg_tatsukoni: Reading...
module.cosmosdb.module.test.azurerm_cosmosdb_sql_database.testdatabase: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev/sqlDatabases/TestDatabase]
module.cosmosdb.module.test.azurerm_cosmosdb_sql_container.testcontainerfront: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev/sqlDatabases/TestDatabase/containers/TestContainerFront]
module.cosmosdb.module.test.azurerm_cosmosdb_sql_container.testcontainerapp: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev/sqlDatabases/TestDatabase/containers/TestContainerApp]
module.cosmosdb.module.test.azurerm_cosmosdb_account.cosmosdb_account_test: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev]
module.vnet.data.azurerm_resource_group.rg_tatsukoni: Read complete after 1s [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev]
module.vnet.azurerm_virtual_network.vnet: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.Network/virtualNetworks/vnet-tatsukoni-dev]
module.cosmosdb.data.azurerm_resource_group.rg_tatsukoni: Read complete after 1s [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev]
module.cosmosdb.module.feat.azurerm_cosmosdb_account.cosmosdb_account_feat: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-feat-dev]
data.azurerm_resource_group.rg_tatsukoni: Read complete after 1s [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev]
azurerm_storage_account.tfstate: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.Storage/storageAccounts/sttatsukonidevtfstate]
module.cosmosdb.module.feat.azurerm_cosmosdb_sql_database.featdatabase: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-feat-dev/sqlDatabases/FeatDatabase]
module.cosmosdb.module.feat.azurerm_cosmosdb_sql_container.featcontainerfront: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-feat-dev/sqlDatabases/FeatDatabase/containers/FeatContainerFront]
module.cosmosdb.module.feat.azurerm_cosmosdb_sql_container.featcontainerapp: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-feat-dev/sqlDatabases/FeatDatabase/containers/FeatContainerApp]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no changes are needed.
```

### terraform plan 実行時 (-refresh-only 指定時)

`-refresh-only` オプションを指定すると、通常のplanとは異なる動作になる。

#### 通常の terraform plan との違い

| 項目 | 通常の plan | plan -refresh-only |
|-----|-----------|-------------------|
| Refreshの実行 | ✅ メモリ内で実行 | ✅ メモリ内で実行 |
| 表示する差分 | **設定ファイル vs tfstate**<br>（インフラへの変更） | **実リソース vs tfstate**<br>（tfstateへの変更） |
| tfstateの更新 | ❌ 更新しない | ❌ 更新しない（planのため） |
| インフラへの変更 | 変更計画を表示 | 表示しない |

#### なぜtfstateの変更が差分として表示されるのか

通常の `terraform plan` は、以下の流れで動作する：
1. Refresh → 実リソースの状態を取得してメモリ内tfstateを更新
2. **メモリ内tfstate vs 設定ファイル** を比較
3. インフラへの変更（create/update/destroy）を表示

一方、`terraform plan -refresh-only` は：
1. Refresh → 実リソースの状態を取得してメモリ内tfstateを更新
2. **実リソースの状態 vs tfstateファイルの記録** を比較
3. **tfstateへの変更内容**を表示（インフラは変更しない）

つまり、`-refresh-only` では：
- **設定ファイルとの比較をスキップ**する
- 代わりに、**Refreshで取得した実リソースの状態**と**tfstateファイルに記録されている状態**の差分を表示する
- これにより「外部で変更されたこと」「削除されたこと」が明確になる

#### 出力される差分の種類

- `has been deleted` - tfstateに記録されているが、実リソースは存在しない
- `has changed` - 実リソースの状態がtfstateの記録と異なる（外部で変更された）

```bash
$ terraform plan -refresh-only -var env=dev
Acquiring state lock. This may take a few moments...
module.cosmosdb.data.azurerm_resource_group.rg_tatsukoni: Reading...
module.vnet.data.azurerm_resource_group.rg_tatsukoni: Reading...
data.azurerm_resource_group.rg_tatsukoni: Reading...
module.cosmosdb.module.test.azurerm_cosmosdb_sql_database.testdatabase: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev/sqlDatabases/TestDatabase]
module.cosmosdb.module.test.azurerm_cosmosdb_sql_container.testcontainerapp: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev/sqlDatabases/TestDatabase/containers/TestContainerApp]
module.cosmosdb.module.test.azurerm_cosmosdb_sql_container.testcontainerfront: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev/sqlDatabases/TestDatabase/containers/TestContainerFront]
module.cosmosdb.module.test.azurerm_cosmosdb_account.cosmosdb_account_test: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev]
module.cosmosdb.data.azurerm_resource_group.rg_tatsukoni: Read complete after 1s [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev]
module.cosmosdb.module.feat.azurerm_cosmosdb_account.cosmosdb_account_feat: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-feat-dev]
module.vnet.data.azurerm_resource_group.rg_tatsukoni: Read complete after 1s [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev]
module.vnet.azurerm_virtual_network.vnet: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.Network/virtualNetworks/vnet-tatsukoni-dev]
data.azurerm_resource_group.rg_tatsukoni: Read complete after 1s [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev]
azurerm_storage_account.tfstate: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.Storage/storageAccounts/sttatsukonidevtfstate]
module.cosmosdb.module.feat.azurerm_cosmosdb_sql_database.featdatabase: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-feat-dev/sqlDatabases/FeatDatabase]
module.cosmosdb.module.feat.azurerm_cosmosdb_sql_container.featcontainerfront: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-feat-dev/sqlDatabases/FeatDatabase/containers/FeatContainerFront]
module.cosmosdb.module.feat.azurerm_cosmosdb_sql_container.featcontainerapp: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-feat-dev/sqlDatabases/FeatDatabase/containers/FeatContainerApp]

Note: Objects have changed outside of Terraform

Terraform detected the following changes made outside of Terraform since the last "terraform apply" which may have affected this plan:

  # module.cosmosdb.module.feat.azurerm_cosmosdb_account.cosmosdb_account_feat has changed
  ~ resource "azurerm_cosmosdb_account" "cosmosdb_account_feat" {
        id                                       = "/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-feat-dev"
      + ip_range_filter                          = []
        name                                     = "tatsukoni-feat-dev"
        tags                                     = {
            "defaultExperience"       = "Core (SQL)"
            "env"                     = "dev"
            "hidden-cosmos-mmspecial" = null
            "service"                 = "tatsukoni"
        }
        # (30 unchanged attributes hidden)

        # (4 unchanged blocks hidden)
    }

  # module.cosmosdb.module.test.azurerm_cosmosdb_account.cosmosdb_account_test has been deleted
  - resource "azurerm_cosmosdb_account" "cosmosdb_account_test" {
      - access_key_metadata_writes_enabled       = true -> null
      - analytical_storage_enabled               = false -> null
      - automatic_failover_enabled               = false -> null
      - burst_capacity_enabled                   = false -> null
      - default_identity_type                    = "FirstPartyIdentity" -> null
      - endpoint                                 = "https://tatsukoni-test-dev.documents.azure.com:443/" -> null
      - free_tier_enabled                        = false -> null
      - id                                       = "/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev" -> null
      - is_virtual_network_filter_enabled        = false -> null
      - kind                                     = "GlobalDocumentDB" -> null
      - local_authentication_disabled            = false -> null
      - location                                 = "japaneast" -> null
      - minimal_tls_version                      = "Tls12" -> null
      - multiple_write_locations_enabled         = false -> null
      - name                                     = "tatsukoni-test-dev" -> null
      - network_acl_bypass_for_azure_services    = false -> null
      - network_acl_bypass_ids                   = [] -> null
      - offer_type                               = "Standard" -> null
      - partition_merge_enabled                  = false -> null
      - primary_key                              = (sensitive value) -> null
      - primary_readonly_key                     = (sensitive value) -> null
      - primary_readonly_sql_connection_string   = (sensitive value) -> null
      - primary_sql_connection_string            = (sensitive value) -> null
      - public_network_access_enabled            = true -> null
      - read_endpoints                           = [
          - "https://tatsukoni-test-dev-japaneast.documents.azure.com:443/",
        ] -> null
      - resource_group_name                      = "rg-tatsukoni-dev" -> null
      - secondary_key                            = (sensitive value) -> null
      - secondary_readonly_key                   = (sensitive value) -> null
      - secondary_readonly_sql_connection_string = (sensitive value) -> null
      - secondary_sql_connection_string          = (sensitive value) -> null
      - tags                                     = {
          - "defaultExperience"       = "Core (SQL)"
          - "env"                     = "dev"
          - "hidden-cosmos-mmspecial" = null
          - "service"                 = "tatsukoni"
        } -> null
      - write_endpoints                          = [
          - "https://tatsukoni-test-dev-japaneast.documents.azure.com:443/",
        ] -> null
        # (1 unchanged attribute hidden)

      - analytical_storage {
          - schema_type = "WellDefined" -> null
        }

      - backup {
          - interval_in_minutes = 240 -> null
          - retention_in_hours  = 8 -> null
          - storage_redundancy  = "Geo" -> null
          - type                = "Periodic" -> null
            # (1 unchanged attribute hidden)
        }

      - consistency_policy {
          - consistency_level       = "Session" -> null
          - max_interval_in_seconds = 5 -> null
          - max_staleness_prefix    = 100 -> null
        }

      - geo_location {
          - failover_priority = 0 -> null
          - id                = "tatsukoni-test-dev-japaneast" -> null
          - location          = "japaneast" -> null
          - zone_redundant    = false -> null
        }
    }

  # module.cosmosdb.module.test.azurerm_cosmosdb_sql_container.testcontainerapp has been deleted
  - resource "azurerm_cosmosdb_sql_container" "testcontainerapp" {
      - account_name        = "tatsukoni-test-dev" -> null
      - database_name       = "TestDatabase" -> null
      - id                  = "/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev/sqlDatabases/TestDatabase/containers/TestContainerApp" -> null
      - name                = "TestContainerApp" -> null
      - partition_key_kind  = "Hash" -> null
      - partition_key_paths = [
          - "/id",
        ] -> null
      - resource_group_name = "rg-tatsukoni-dev" -> null
      - throughput          = 0 -> null

      - conflict_resolution_policy {
          - conflict_resolution_path      = "/_ts" -> null
          - mode                          = "LastWriterWins" -> null
            # (1 unchanged attribute hidden)
        }

      - indexing_policy {
          - indexing_mode = "consistent" -> null

          - included_path {
              - path = "/*" -> null
            }
        }
    }

  # module.cosmosdb.module.test.azurerm_cosmosdb_sql_container.testcontainerfront has been deleted
  - resource "azurerm_cosmosdb_sql_container" "testcontainerfront" {
      - account_name        = "tatsukoni-test-dev" -> null
      - database_name       = "TestDatabase" -> null
      - id                  = "/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev/sqlDatabases/TestDatabase/containers/TestContainerFront" -> null
      - name                = "TestContainerFront" -> null
      - partition_key_kind  = "Hash" -> null
      - partition_key_paths = [
          - "/userId",
        ] -> null
      - resource_group_name = "rg-tatsukoni-dev" -> null
      - throughput          = 0 -> null

      - conflict_resolution_policy {
          - conflict_resolution_path      = "/_ts" -> null
          - mode                          = "LastWriterWins" -> null
            # (1 unchanged attribute hidden)
        }

      - indexing_policy {
          - indexing_mode = "consistent" -> null

          - included_path {
              - path = "/*" -> null
            }
        }
    }

  # module.cosmosdb.module.test.azurerm_cosmosdb_sql_database.testdatabase has been deleted
  - resource "azurerm_cosmosdb_sql_database" "testdatabase" {
      - account_name        = "tatsukoni-test-dev" -> null
      - id                  = "/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev/sqlDatabases/TestDatabase" -> null
      - name                = "TestDatabase" -> null
      - resource_group_name = "rg-tatsukoni-dev" -> null
      - throughput          = 100 -> null

      - autoscale_settings {
          - max_throughput = 1000 -> null
        }
    }


This is a refresh-only plan, so Terraform will not take any actions to undo these. If you were expecting these changes then you can apply this plan to record the updated values in the Terraform state without
changing any remote objects.

───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to take exactly these actions if you run "terraform apply" now.
Releasing state lock. This may take a few moments...
```

#### この出力の見方

上記の出力で表示されているのは、**tfstateへの変更**（インフラへの変更ではない）：

1. **`has changed`** - 実リソースとtfstateの記録に差異がある
   - 例: `ip_range_filter` が実リソースには存在するが、tfstateには記録されていない
   - これは外部で変更されたか、provider側の仕様変更による可能性がある

2. **`has been deleted`** - tfstateには記録があるが、実リソースは存在しない
   - CosmosDB test関連のリソースがすべて `has been deleted` として表示されている
   - これらはAzure Portal/CLIで手動削除されたため

3. **メッセージの意味**
   ```
   This is a refresh-only plan, so Terraform will not take any actions to undo these.
   ```
   - refresh-onlyモードでは、インフラへの変更は行わない
   - tfstateへの記録のみを更新する
   - 削除されたリソースを再作成したりはしない

4. **次のステップ**
   - `terraform apply -refresh-only` を実行すると、これらの変更がtfstateに反映される
   - 実リソースには一切変更が加えられない

### terraform apply 実行時

1. 同じrefreshフェーズを実行 → リソースが存在しないと判定
2. コードとの差分なし → インフラ変更は行わない
3. refreshした結果をtfstateファイルに書き戻す → 古いエントリが消える

```bash
$ terraform apply -var env=dev
data.azurerm_resource_group.rg_tatsukoni: Reading...
module.vnet.data.azurerm_resource_group.rg_tatsukoni: Reading...
module.cosmosdb.data.azurerm_resource_group.rg_tatsukoni: Reading...
module.cosmosdb.module.test.azurerm_cosmosdb_sql_container.testcontainerapp: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev/sqlDatabases/TestDatabase/containers/TestContainerApp]
module.cosmosdb.module.test.azurerm_cosmosdb_sql_database.testdatabase: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev/sqlDatabases/TestDatabase]
module.cosmosdb.module.test.azurerm_cosmosdb_sql_container.testcontainerfront: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev/sqlDatabases/TestDatabase/containers/TestContainerFront]
module.cosmosdb.module.test.azurerm_cosmosdb_account.cosmosdb_account_test: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev]
data.azurerm_resource_group.rg_tatsukoni: Read complete after 0s [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev]
azurerm_storage_account.tfstate: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.Storage/storageAccounts/sttatsukonidevtfstate]
module.vnet.data.azurerm_resource_group.rg_tatsukoni: Read complete after 0s [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev]
module.vnet.azurerm_virtual_network.vnet: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.Network/virtualNetworks/vnet-tatsukoni-dev]
module.cosmosdb.data.azurerm_resource_group.rg_tatsukoni: Read complete after 0s [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev]
module.cosmosdb.module.feat.azurerm_cosmosdb_account.cosmosdb_account_feat: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-feat-dev]
module.cosmosdb.module.feat.azurerm_cosmosdb_sql_database.featdatabase: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-feat-dev/sqlDatabases/FeatDatabase]
module.cosmosdb.module.feat.azurerm_cosmosdb_sql_container.featcontainerfront: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-feat-dev/sqlDatabases/FeatDatabase/containers/FeatContainerFront]
module.cosmosdb.module.feat.azurerm_cosmosdb_sql_container.featcontainerapp: Refreshing state... [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.DocumentDB/databaseAccounts/tatsukoni-feat-dev/sqlDatabases/FeatDatabase/containers/FeatContainerApp]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no changes are needed.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

### terraform plan 実行時 (-refresh=false 指定時)

refreshをスキップすると、tfstateの記録だけで判断するため、削除されたリソースが「削除対象」として表示される。

```bash
$ terraform plan -var env=dev -refresh=false
data.azurerm_resource_group.rg_tatsukoni: Reading...
data.azurerm_resource_group.rg_tatsukoni: Read complete after 0s [id=/subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  # module.cosmosdb.module.test.azurerm_cosmosdb_account.cosmosdb_account_test will be destroyed
  # (because azurerm_cosmosdb_account.cosmosdb_account_test is not in configuration)
  - resource "azurerm_cosmosdb_account" "cosmosdb_account_test" {
      - name                = "tatsukoni-test-dev" -> null
      # ... (詳細省略)
    }

  # module.cosmosdb.module.test.azurerm_cosmosdb_sql_database.testdatabase will be destroyed
  # (because azurerm_cosmosdb_sql_database.testdatabase is not in configuration)
  - resource "azurerm_cosmosdb_sql_database" "testdatabase" {
      - name = "TestDatabase" -> null
      # ... (詳細省略)
    }

  # ... (他のリソースも同様)

Plan: 0 to add, 0 to change, 4 to destroy.
```

### terraform apply -refresh-only 実行時

`-refresh-only`オプションを使うと、refreshの結果をtfstateに反映できる（インフラ変更は行わない）。

```bash
$ terraform apply -refresh-only -var env=dev
# ... (refresh処理)

Note: Objects have changed outside of Terraform

Terraform detected the following changes made outside of Terraform since the last "terraform apply":

  # module.cosmosdb.module.test.azurerm_cosmosdb_account.cosmosdb_account_test has been deleted
  # ... (削除されたリソースの一覧)

This is a refresh-only plan, so Terraform will not take any actions to undo
these. If you were expecting these changes then you can apply this plan to
record the updated values in the Terraform state without changing any remote
objects.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

実行後、tfstateから削除されたリソースのエントリが削除される。

### tfstateの確認方法

```bash
# apply実行前（削除されたリソースがまだ記録されている）
$ terraform state list
data.azurerm_resource_group.rg_tatsukoni
azurerm_storage_account.tfstate
module.cosmosdb.data.azurerm_resource_group.rg_tatsukoni
module.cosmosdb.module.test.azurerm_cosmosdb_account.cosmosdb_account_test
module.cosmosdb.module.test.azurerm_cosmosdb_sql_container.testcontainerapp
module.cosmosdb.module.test.azurerm_cosmosdb_sql_container.testcontainerfront
module.cosmosdb.module.test.azurerm_cosmosdb_sql_database.testdatabase
module.cosmosdb.module.feat.azurerm_cosmosdb_account.cosmosdb_account_feat
# ... (他のリソース)

# apply実行後（削除されたリソースのエントリが消える）
$ terraform state list
data.azurerm_resource_group.rg_tatsukoni
azurerm_storage_account.tfstate
module.cosmosdb.data.azurerm_resource_group.rg_tatsukoni
module.cosmosdb.module.feat.azurerm_cosmosdb_account.cosmosdb_account_feat
module.cosmosdb.module.feat.azurerm_cosmosdb_sql_database.featdatabase
# ... (残存するリソースのみ)
```

## まとめ

### 重要なポイント

1. **terraform planはtfstateファイルを更新しない**
   - Refreshはin-memory（メモリ内）で実行される
   - Remote/Local tfstateは読み取り専用

2. **terraform applyのみがtfstateファイルを更新する**
   - Refresh結果をファイルに書き戻す
   - 削除されたリソースのエントリが削除される

3. **-refresh=falseオプション**
   - Refreshをスキップ
   - tfstateの記録だけで判断
   - 削除されたリソースが「削除対象」として表示される

4. **-refresh-onlyオプション**
   - インフラ変更なしでrefresh結果をtfstateに反映
   - 安全にtfstateをクリーンアップできる

### State Locking（Remote Backend使用時）

Remote backend（Azure Blob Storage）を使用している場合：

- `terraform plan`実行時もState Lockが取得される
- Refreshフェーズ中もLockが保持される
- 複数人が同時に実行すると、後から実行した人はLock解放待ちになる

```bash
Acquiring state lock. This may take a few moments...
# ... (処理)
Releasing state lock. This may take a few moments...
```

### ベストプラクティス

1. **リソースを外部で削除した場合**
   - `terraform apply`または`terraform apply -refresh-only`を実行してtfstateを同期
   - `-refresh-only`の方が安全（インフラ変更が発生しない）

2. **意図的にコードを削除してリソースも削除する場合**
   - コードを削除後、`terraform plan`で削除対象を確認
   - `terraform apply`でリソースとtfstateエントリを両方削除

3. **-refresh=falseは慎重に使用**
   - 外部変更を検知できない
   - デバッグ用途や高速化が必要な場合のみ使用

## Terraform Refresh のバージョン履歴

### デフォルト動作の歴史

**結論: `refresh=true` は Terraform の最初期バージョンからデフォルト動作でした。**

特定のバージョンで「デフォルトになった」のではなく、**Terraform の設計思想として最初から plan/apply 時に自動的に refresh を実行する仕様**でした。

### 重要なマイルストーン

| バージョン | 変更内容 |
|-----------|---------|
| **初期バージョン〜** | `terraform plan` / `terraform apply` はデフォルトで refresh を実行（暗黙的動作） |
| **Terraform 0.15.4**<br>(2021年6月) | **主要な変更:**<br>- `-refresh-only` オプションの追加<br>- `terraform refresh` コマンドの非推奨化<br>- 外部変更の明示的な表示機能の追加<br>- `-refresh=false` オプションで refresh をスキップ可能に |

### Terraform 0.15.4 での詳細な変更内容

#### 1. `-refresh-only` オプションの追加

従来の `terraform refresh` コマンドは、ユーザーの確認なしで state ファイルを更新していました。これは以下の問題がありました：

- **危険性**: 認証情報の設定ミスがあると、全リソースが削除されたと誤判断される可能性
- **トレーサビリティ**: 何が変更されたのか事前確認できない
- **リスク**: 意図しない state 更新が発生する可能性

**解決策として追加された機能:**

```bash
# 安全に state を同期（事前確認あり）
terraform plan -refresh-only
terraform apply -refresh-only
```

これにより：
- refresh の結果をユーザーが**事前に確認**できる
- インフラ変更なしで state を同期できる
- 外部変更を明示的に表示

#### 2. `terraform refresh` コマンドの非推奨化

公式ドキュメントより：
> "The terraform refresh command is deprecated. We don't have any plans to remove it, but we do recommend using terraform apply -refresh-only instead in most cases."

**非推奨の理由:**
- 確認プロンプトなしで state ファイルを更新する
- 認証情報の誤設定時に危険
- 変更内容を事前レビューできない

**推奨される代替方法:**
```bash
# 従来（非推奨）
terraform refresh

# 推奨
terraform apply -refresh-only
```

#### 3. 外部変更の明示的な表示

**0.15.4 以前:**
- refresh で検出した変更を**静かに** state に反映
- ユーザーは外部変更に気づきにくい

**0.15.4 以降:**
```
Note: Objects have changed outside of Terraform

Terraform detected the following changes made outside of Terraform
since the last "terraform apply":

  # resource has changed
  # resource has been deleted
```

このメッセージにより、外部で行われた変更が明確になりました。

### なぜバージョン特定が難しいのか

`refresh=true` がデフォルトになったバージョンの特定が困難な理由：

1. **最初からの設計思想**
   - これは「変更」ではなく「初期からの仕様」
   - CHANGELOG に「refresh をデフォルトにした」という記述がない

2. **追加されたのは「スキップする」オプション**
   - 0.15.4 で追加されたのは `-refresh=false` と `-refresh-only`
   - デフォルト動作自体は変更されていない

3. **公式ドキュメントの表現**
   - "Reads the current state..." とデフォルト動作として説明
   - 特定バージョンからの変更とは記載されていない

### 参考: Terraform 0.11 → 0.12 での refresh 関連の注意事項

Terraform 0.11 から 0.12 へのアップグレード時：

**重要な警告:**
> "Running `terraform refresh` with Terraform 0.12 creates a new state snapshot in the 0.12 format, which is not compatible with the 0.11 format - this has a similar effect to running `terraform apply`, taking you past the point of no return on the upgrade."

**推奨アップグレード手順:**
1. `terraform plan` を実行（何度でも安全に実行可能）
2. plan が空または許容可能になるまで設定を調整
3. `terraform apply` でアップグレードをコミット

この例からも、refresh が plan/apply の一部として実行される動作が 0.11 時代から存在していたことがわかります。

---

## 公式ドキュメント

### Terraform Core Documentation

- [terraform plan command](https://developer.hashicorp.com/terraform/cli/commands/plan)
  - デフォルトで "Reads the current state of any already-existing remote objects to make sure that the Terraform state is up-to-date"
  - `-refresh=false`: "Disables the default behavior of synchronizing the Terraform state with remote objects"
  - `-refresh-only`: "Creates a plan whose goal is only to update the Terraform state and any root module output values"

- [terraform apply command](https://developer.hashicorp.com/terraform/cli/commands/apply)
  - `-refresh-only`: "Update the state file without modifying real remote objects"

- [Use refresh-only mode to sync Terraform state](https://developer.hashicorp.com/terraform/tutorials/state/refresh)
  - 公式チュートリアル
  - `-refresh-only`モードの使用方法

### 関連記事

- [GitHub Issue #28342: Documentation Update - Slightly clearer description of 'Refresh' and 'Plan' execution](https://github.com/hashicorp/terraform/issues/28342)
  - "Plan は local/remote state files に対して実際のrefreshを行わない。in-memoryで行う"

---

## 調査日

2026-03-20
```
