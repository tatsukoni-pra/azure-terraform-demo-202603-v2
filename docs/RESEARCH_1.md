# Terraform Remote Backend 内部動作の調査結果

## 概要

tfstateファイルが外部（Azure Blob Storage）にある際の、Terraformコマンド実行時の内部的な挙動を調査した結果をまとめる。

## 調査環境

- Terraform: v1.14.0
- Backend: azurerm (Azure Blob Storage)
- Storage Account: `sttatsukonidevtfstate`
- Container: `tfstate`
- State file: `terraform.tfstate`

---

## 1. `terraform init -reconfigure -backend-config=tfbackend/dev.tfbackend`

### 内部動作フロー

```
1. 作業ディレクトリの準備
   - .terraform/ ディレクトリの確認・作成

2. Backend設定の読み込み
   - backend.tf から backend "azurerm" {} を読み込み
   - tfbackend/dev.tfbackend から具体的な設定を読み込み
     * resource_group_name = "rg-tatsukoni-dev"
     * storage_account_name = "sttatsukonidevtfstate"
     * container_name = "tfstate"
     * key = "terraform.tfstate"

3. -reconfigure フラグの効果
   - 既存の.terraform/terraform.tfstate を無視
   - 新しいbackend設定で上書き
   - 既存のtfstate移行は行わない

4. Backend初期化
   - Azure認証（Azure CLIの認証情報を使用）
   - Azure Blob Storageへの接続テスト
   - 指定されたcontainer/blobの存在確認

5. Backend設定の保存
   - .terraform/terraform.tfstate に設定を保存

6. Provider/Module のダウンロード
   - .terraform/providers/ にprovider pluginをダウンロード
   - .terraform/modules/ にmodule設定を保存

7. 完了メッセージ
   "Terraform has been successfully initialized!"
```

### `.terraform/terraform.tfstate` の役割

このファイルは**backend設定**を保存するためのファイルであり、実際のインフラの状態を保存する `terraform.tfstate` とは別物。

**ファイル内容例:**
```json
{
  "version": 3,
  "terraform_version": "1.14.0",
  "backend": {
    "type": "azurerm",
    "config": {
      "container_name": "tfstate",
      "key": "terraform.tfstate",
      "resource_group_name": "rg-tatsukoni-dev",
      "storage_account_name": "sttatsukonidevtfstate"
    },
    "hash": 750355294
  }
}
```

### 重要なポイント

- **State Lockは取得しない**（接続確認のみ）
- Remote tfstateファイルの読み書きは行わない
- Backend接続情報をローカルに保存するのみ

---

## 2. `terraform plan -var env=dev`

### 内部動作フロー

```
1. Backend設定の読み込み
   - .terraform/terraform.tfstate を読み込み
   - 接続先: sttatsukonidevtfstate/tfstate/terraform.tfstate

2. State Lock取得開始
   - "Acquiring state lock. This may take a few moments..."
   - Azure Blob Storageのlease機能を使用
   - Blobが "leased" 状態になる

3. Remote tfstate のダウンロード
   GET https://sttatsukonidevtfstate.blob.core.windows.net/tfstate/terraform.tfstate
   ↓
   メモリ内にtfstateをロード

4. Provider初期化
   - .terraform/providers/ からprovider pluginをロード
   - Azure APIとの接続確立

5. 設定ファイルの読み込み
   - main.tf, variables.tf, locals.tf などを解析
   - module構造を展開

6. Refresh実行（デフォルト: -refresh=true）
   For each resource in memory tfstate:
     ├─ Azure API呼び出し（GET request）
     ├─ 実リソースの現在状態を取得
     ├─ メモリ内tfstateを更新
     └─ 実リソース不在 → メモリ内tfstateから削除

   例（CosmosDBの場合）:
   GET /subscriptions/.../Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev
   → Response: 404 Not Found
   → メモリ内tfstateから削除

7. Dependency Graph構築
   - リソース間の依存関係を解析
   - 作成/更新/削除の順序を決定

8. Plan生成
   - 更新後のメモリ内tfstate vs 設定ファイル を比較
   - 差分を計算
   - Plan: X to add, Y to change, Z to destroy

9. Plan表示
   - ユーザーに変更内容を表示

10. State Lock解放
    - Blob leaseを解放
    - Blobが "available" 状態に戻る

11. 重要：Remote tfstate は変更されない
    - メモリ内の変更は破棄される
    - Azure Blob Storage上のファイルは未変更
```

### Refresh動作の詳細

**デフォルト（-refresh=true）の場合:**

公式ドキュメント：
> "Reads the current state of any already-existing remote objects to make sure that the Terraform state is up-to-date."

- Remote tfstateに記録された各リソースの実態をAzure APIで確認
- **In-memory（メモリ内）で** tfstateを更新
- 実リソースが存在しない場合、メモリ内tfstateから削除
- **ファイルには書き込まない**（読み取り専用操作）

**-refresh=false の場合:**

公式ドキュメント：
> "Disables the default behavior of synchronizing the Terraform state with remote objects before checking for configuration changes."

- Azure APIへの問い合わせをスキップ
- Remote tfstateをダウンロードしたままの状態で比較
- 高速化されるが、外部変更を検知できない

### State Lock中のBlob状態

```bash
# 確認コマンド
az storage blob show \
  --account-name sttatsukonidevtfstate \
  --container-name tfstate \
  --name terraform.tfstate \
  --query '{LeaseState:properties.lease.state, LeaseStatus:properties.lease.status}'
```

**plan実行中:**
```json
{
  "LeaseState": "leased",
  "LeaseStatus": "locked"
}
```

**待機中:**
```json
{
  "LeaseState": "available",
  "LeaseStatus": "unlocked"
}
```

---

## 3. `terraform apply -var env=dev`

### 内部動作フロー

```
1. Backend設定の読み込み
   - .terraform/terraform.tfstate を読み込み

2. State Lock取得
   - "Acquiring state lock. This may take a few moments..."
   - Azure Blob lease取得

3. Remote tfstate のダウンロード
   GET https://sttatsukonidevtfstate.blob.core.windows.net/tfstate/terraform.tfstate
   ↓
   メモリ内にロード

4. Refresh + Plan生成（planと同じ処理）
   - メモリ内でRefresh実行
   - 変更計画を生成

5. ユーザー承認待ち（auto-approveでない場合）
   "Do you want to perform these actions?"
   Enter a value: yes

   ※この間もState Lockは保持され続ける

6. リソース変更の実行
   For each resource change:
     ├─ Azure API呼び出し（PUT/POST/DELETE request）
     ├─ リソース作成/更新/削除
     ├─ 結果をメモリ内tfstateに反映
     └─ Progress表示

   例（CosmosDB作成の場合）:
   PUT /subscriptions/.../Microsoft.DocumentDB/databaseAccounts/tatsukoni-test-dev
   → Creating...
   → Creation complete after 5m23s

7. メモリ内tfstateの最終更新
   - すべての変更結果を統合
   - Serial番号をインクリメント
   - Lineageを維持

8. Remote tfstate への書き込み
   PUT https://sttatsukonidevtfstate.blob.core.windows.net/tfstate/terraform.tfstate
   ↓
   更新されたtfstateをアップロード

   ※この時点で初めてRemote tfstateが更新される

9. State Lock解放
   - Blob leaseを解放

10. 完了メッセージ
    "Apply complete! Resources: X added, Y changed, Z destroyed."
```

### 重要なポイント

- **terraform apply 実行後のみ、Remote tfstateが更新される**
- リソース変更とtfstate更新は1つのトランザクションではない
- State Lockは承認待ちの間も保持される

---

## 4. State更新のタイミング比較

| コマンド | Remote tfstate読み込み | Remote tfstate書き込み | State Lock |
|---------|---------------------|---------------------|-----------|
| `terraform init` | ❌ 接続確認のみ | ❌ | ❌ |
| `terraform plan` | ✅ ダウンロード | ❌ 読み取り専用 | ✅ 取得・解放 |
| `terraform apply` | ✅ ダウンロード | ✅ アップロード | ✅ 取得・解放 |
| `terraform refresh` | ✅ ダウンロード | ✅ アップロード | ✅ 取得・解放 |

---

## 5. State Locking の仕組み

### Azure Blob Storage Backend

公式ドキュメント：
> "This backend supports state locking and consistency checking with Azure Blob Storage native capabilities."

**実装:**
- Azure Blob StorageのLease機能を使用
- Lock取得 = Blobに対してLease取得（60秒間のリース）
- Lock中は他のterraform実行がブロックされる
- Lock解放 = Lease解放

**公式の説明:**

terraform.io/docs:
> "State locking happens automatically on all operations that could write state."
> "If supported by your backend, Terraform will lock your state for all operations that could write state."

### Lockが取得される操作

- `terraform plan` - 読み取り専用だがLock取得
- `terraform apply` - 書き込みを伴うためLock取得
- `terraform destroy` - 書き込みを伴うためLock取得
- `terraform refresh` - 書き込みを伴うためLock取得

### Force Unlock

Lockが解放されない場合の手動解除：

```bash
# Terraform CLIから
terraform force-unlock <LOCK_ID>

# Azure CLIから
az storage blob lease break \
  --account-name sttatsukonidevtfstate \
  --container-name tfstate \
  --blob-name terraform.tfstate
```

---

## 6. 実例：CosmosDBリソース削除時の挙動

### シナリオ

1. terraform apply でCosmosDBリソースを作成
2. Azure Portal/CLIからCosmosDBアカウントを手動削除
3. main.tf で `module "cosmosdb"` をコメントアウト
4. terraform plan 実行

### 挙動の詳細

#### `terraform plan -var env=dev` 実行時

```
1. Remote tfstate ダウンロード
   内容: CosmosDBリソース4個が記録されている
   - azurerm_cosmosdb_account.cosmosdb_account_test
   - azurerm_cosmosdb_sql_database.testdatabase
   - azurerm_cosmosdb_sql_container.testcontainerapp
   - azurerm_cosmosdb_sql_container.testcontainerfront

2. メモリ内でRefresh
   - azurerm_cosmosdb_account.cosmosdb_account_test
     GET /.../databaseAccounts/tatsukoni-test-dev
     → 404 Not Found
     → メモリ内から削除

   - azurerm_cosmosdb_sql_database.testdatabase
     → 親リソースがないため削除

   - azurerm_cosmosdb_sql_container × 2
     → 親リソースがないため削除

3. 比較
   - 更新後のメモリ内tfstate: CosmosDBリソースなし
   - 設定（main.tf）: module "cosmosdb" コメントアウト → リソースなし
   → 一致！

4. 結果: "No changes. Your infrastructure matches the configuration."

5. Remote tfstate は変更されず
   → まだCosmosDBリソースが記録されたまま
```

#### `terraform plan -var env=dev -refresh=false` 実行時

```
1. Remote tfstate ダウンロード（同じ）

2. Refreshをスキップ
   → メモリ内tfstateはダウンロードしたまま
   → CosmosDBリソース4個が残っている

3. 比較
   - メモリ内tfstate: CosmosDBリソース4個
   - 設定: リソースなし
   → 不一致！

4. 結果: "Plan: 0 to add, 0 to change, 4 to destroy."
   - module.cosmosdb.module.test.azurerm_cosmosdb_account.cosmosdb_account_test will be destroyed
   - module.cosmosdb.module.test.azurerm_cosmosdb_sql_database.testdatabase will be destroyed
   - module.cosmosdb.module.test.azurerm_cosmosdb_sql_container.testcontainerapp will be destroyed
   - module.cosmosdb.module.test.azurerm_cosmosdb_sql_container.testcontainerfront will be destroyed
```

### Remote tfstateの更新方法

Remote tfstateからCosmosDBリソースを削除するには：

```bash
# 方法1: terraform apply実行
terraform apply -var env=dev
# → メモリ内の状態（リソースなし）がRemoteに反映される

# 方法2: terraform state rm で手動削除
terraform state rm 'module.cosmosdb.module.test.azurerm_cosmosdb_account.cosmosdb_account_test'
terraform state rm 'module.cosmosdb.module.test.azurerm_cosmosdb_sql_database.testdatabase'
terraform state rm 'module.cosmosdb.module.test.azurerm_cosmosdb_sql_container.testcontainerapp'
terraform state rm 'module.cosmosdb.module.test.azurerm_cosmosdb_sql_container.testcontainerfront'
```

---

## 7. ファイルシステム構造

```
Azure Blob Storage
└── tfstate (container)
    └── terraform.tfstate ←─────┐
         ↑                      │
         │                      │
    plan時: ダウンロードのみ      │
    apply時: ダウンロード＋アップロード
         │                      │
         ↓                      │
    ローカルメモリ内               │
    ├── in-memory tfstate       │
    ├── refresh実行             │
    ├── plan生成                │
    └── apply時のみ更新 ─────────┘

ローカルファイルシステム
└── .terraform/
    ├── terraform.tfstate（backend設定のみ、インフラ状態ではない）
    ├── providers/
    │   └── registry.terraform.io/
    │       └── hashicorp/
    │           └── azurerm/
    └── modules/
        └── modules.json
```

---

## 8. 公式ドキュメント

### Terraform Core Documentation

- [terraform init command](https://developer.hashicorp.com/terraform/cli/commands/init)
  - `-reconfigure`: "disregards any existing configuration, preventing migration of any existing state"
  - `-backend-config`: 動的なbackend設定に使用

- [terraform plan command](https://developer.hashicorp.com/terraform/cli/commands/plan)
  - デフォルトで "Reads the current state of any already-existing remote objects to make sure that the Terraform state is up-to-date"
  - `-refresh=false`: "Disables the default behavior of synchronizing the Terraform state with remote objects"

- [State: Locking](https://developer.hashicorp.com/terraform/language/state/locking)
  - "State locking happens automatically on all operations that could write state"
  - "you won't see any message that it happens"

- [Backends: State Storage and Locking](https://developer.hashicorp.com/terraform/language/state/backends)
  - Backend の役割と種類

### Azure Backend Specific

- [Backend Type: azurerm](https://developer.hashicorp.com/terraform/language/backend/azurerm)
  - "This backend supports state locking and consistency checking with Azure Blob Storage native capabilities"

- [Store Terraform state in Azure Storage | Microsoft Learn](https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage)
  - Azure Blob Storageをbackendとして使用する方法

### Blog Posts & Technical Articles

- [New Terraform Planning Options: -refresh=false, -refresh-only, -replace](https://www.hashicorp.com/en/blog/new-terraform-planning-options-refresh-false-refresh-only-replace)
  - HashiCorp公式ブログ

- [Use refresh-only mode to sync Terraform state](https://developer.hashicorp.com/terraform/tutorials/state/refresh)
  - 公式チュートリアル

- [GitHub Issue #28342: Documentation Update - Slightly clearer description of 'Refresh' and 'Plan' execution](https://github.com/hashicorp/terraform/issues/28342)
  - "Plan は local/remote state files に対して実際のrefreshを行わない。in-memoryで行う"

---

## 9. まとめ

### 重要な発見

1. **`terraform plan` はtfstateファイルを更新しない**
   - Refreshはin-memoryで実行される
   - Remote tfstateは読み取り専用

2. **`terraform apply` のみがRemote tfstateを更新する**
   - リソース変更実行後にアップロード
   - Serial番号がインクリメントされる

3. **State Lockingは自動的に行われる**
   - Azure Blob StorageのLease機能を使用
   - plan/apply両方でLock取得

4. **実リソースが存在しない場合の挙動**
   - Refreshで404エラー検知
   - メモリ内tfstateから削除
   - Remote tfstateは変更されない（planの場合）

5. **`.terraform/terraform.tfstate` はbackend設定ファイル**
   - インフラの状態は保存されない
   - 接続先のremote backend情報のみ

### ベストプラクティス

- リソースを外部で削除した場合、`terraform apply` を実行してtfstateを同期
- `-refresh=false` は慎重に使用（外部変更を検知できない）
- State Lockがスタックした場合、`terraform force-unlock` または Azure CLI で解除
- Remote backendを使用する場合、必ず State Locking対応のbackendを選択

---

## 調査日

2026-03-20
