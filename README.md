## 構成

### リソース構成

**dev環境:**

- リソースグループ: `rg-tatsukoni-dev` (既存、terraform管理外)
- tfstate用ストレージ: `sttatsukonidevtfstate`
- VNet: `vnet-tatsukoni-dev` (アドレス空間: `10.0.0.0/16`)
- Cosmos DBアカウント: `tatsukoni-test-dev`
  - データベース: `TestDatabase` (AutoScaling: 100-1000 RU/s)
    - コンテナ: `TestContainerApp` (パーティションキー: `/id`)
    - コンテナ: `TestContainerFront` (パーティションキー: `/userId`)
- Cosmos DBアカウント: `tatsukoni-test-dev-v2`
  - データベース: `TestDatabase` (AutoScaling: 100-1000 RU/s)
    - コンテナ: `TestContainerApp` (パーティションキー: `/id`)
    - コンテナ: `TestContainerFront` (パーティションキー: `/userId`)

**prd環境:**

- リソースグループ: `rg-tatsukoni-prd` (既存、terraform管理外)
- tfstate用ストレージ: `sttatsukoniprdtfstate`
- VNet: `vnet-tatsukoni-prd` (アドレス空間: `10.1.0.0/16`)
- Cosmos DBアカウント: `tatsukoni-test-prd`
  - データベース: `TestDatabase` (AutoScaling: 100-1000 RU/s)
    - コンテナ: `TestContainerApp` (パーティションキー: `/id`)
    - コンテナ: `TestContainerFront` (パーティションキー: `/userId`)
- Cosmos DBアカウント: `tatsukoni-test-prd-v2`
  - データベース: `TestDatabase` (AutoScaling: 100-1000 RU/s)
    - コンテナ: `TestContainerApp` (パーティションキー: `/id`)
    - コンテナ: `TestContainerFront` (パーティションキー: `/userId`)

### ディレクトリ構造

```
azure-terraform-demo-202603-v2/
├── main.tf                    # ルートモジュール
├── variables.tf               # 環境変数定義
├── locals.tf                  # ローカル変数
├── backend.tf                 # バックエンド設定
├── providers.tf               # プロバイダー設定
├── versions.tf                # バージョン制約
├── tfbackend/
│   ├── dev.tfbackend         # dev環境バックエンド設定
│   └── prd.tfbackend         # prd環境バックエンド設定
├── cosmosdb/
│   ├── main.tf               # cosmosdb moduleの呼び出し
│   ├── variables.tf          # cosmosdb module変数
│   ├── data_sources.tf       # リソースグループ参照
│   └── test/
│       ├── cosmosdb_account.tf       # CosmosDBアカウント定義
│       ├── cosmosdb_account_v2.tf    # CosmosDBアカウント定義 (v2)
│       ├── sql_database.tf           # データベース定義
│       ├── sql_database_v2.tf        # データベース定義 (v2)
│       ├── sql_container.tf          # コンテナ定義
│       ├── sql_container_v2.tf       # コンテナ定義 (v2)
│       ├── locals.tf                 # ローカル変数
│       └── variables.tf              # test module変数
└── vnet/
    ├── main.tf               # VNet定義
    ├── variables.tf          # vnet module変数
    ├── data_sources.tf       # リソースグループ参照
    └── locals.tf             # ローカル変数
```

## 使い方

### 初期構築（dev環境）

```bash
cd /Users/konishitatsuhiro/Desktop/git/azure-terraform-demo-202603-v2

# Resource Groupの作成
az group create --name rg-tatsukoni-dev --location japaneast

# Storage Accountの作成
az storage account create \
  --name sttatsukonidevtfstate \
  --resource-group rg-tatsukoni-dev \
  --location japaneast \
  --sku Standard_GRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-cross-tenant-replication true \
  --tags env=dev service=tatsukoni

# Blob versioningの有効化
az storage account blob-service-properties update \
  --account-name sttatsukonidevtfstate \
  --resource-group rg-tatsukoni-dev \
  --enable-versioning true

# Blob Containerの作成
az storage container create \
  --name tfstate \
  --account-name sttatsukonidevtfstate

# dev環境で初期化
# StorageAccount：sttatsukonidevtfstate 内に、tfstateファイルが生成される
terraform init -reconfigure -backend-config=tfbackend/dev.tfbackend

# Terraformへインポート（Storage AccountはTerraformで管理するため）
# StorageAccount：sttatsukonidevtfstate 内に、main.tf の StorageAccount 定義がimportされる
terraform import \
  -var env=dev \
  azurerm_storage_account.tfstate \
  /subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-dev/providers/Microsoft.Storage/storageAccounts/sttatsukonidevtfstate
```

### リソース操作(dev環境)

```bash
# tfstateの向き先をdev環境に変更
terraform init -reconfigure -backend-config=tfbackend/dev.tfbackend

# planで確認
terraform plan -var env=dev

# apply実行
terraform apply -var env=dev
```

### 初期構築（prd環境）

```bash
cd /Users/konishitatsuhiro/Desktop/git/azure-terraform-demo-202603-v2

# Resource Groupの作成
az group create --name rg-tatsukoni-prd --location japaneast

# Storage Accountの作成
az storage account create \
  --name sttatsukoniprdtfstate \
  --resource-group rg-tatsukoni-prd \
  --location japaneast \
  --sku Standard_GRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-cross-tenant-replication true \
  --tags env=prd service=tatsukoni

# Blob versioningの有効化
az storage account blob-service-properties update \
  --account-name sttatsukoniprdtfstate \
  --resource-group rg-tatsukoni-prd \
  --enable-versioning true

# Blob Containerの作成
az storage container create \
  --name tfstate \
  --account-name sttatsukoniprdtfstate

# prd環境で初期化
# StorageAccount：sttatsukoniprdtfstate 内に、tfstateファイルが生成される
terraform init -reconfigure -backend-config=tfbackend/prd.tfbackend

# Terraformへインポート（Storage AccountはTerraformで管理するため）
# StorageAccount：sttatsukoniprdtfstate 内に、main.tf の StorageAccount 定義がimportされる
terraform import \
  -var env=prd \
  azurerm_storage_account.tfstate \
  /subscriptions/ba29533e-1e4c-43a8-898a-a5815e9b577b/resourceGroups/rg-tatsukoni-prd/providers/Microsoft.Storage/storageAccounts/sttatsukoniprdtfstate
```

### リソース操作(prd環境)

```bash
# tfstateの向き先をprd環境に変更
terraform init -reconfigure -backend-config=tfbackend/prd.tfbackend

# planで確認
terraform plan -var env=prd

# apply実行
terraform apply -var env=prd
```
