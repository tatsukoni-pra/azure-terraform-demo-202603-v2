# Module で count を使用した場合のリソースアドレス変更

## 概要

moduleブロックで `count` を使用すると、リソースアドレスが以下のように変化します：

- **変更前**: `module.test`
- **変更後**: `module.test[0]`

この変更の理由と、それに伴う影響について説明します。

---

## なぜリソースアドレスが変わるのか

### 理由: count を使うとモジュールが「配列（リスト）」として扱われる

Terraformの設計思想として、`count` を使用したリソースやモジュールは**常に配列として扱われます**。

---

## count なしの場合

### コード例

```hcl
module "test" {
  source         = "./test"
  env            = var.env
  resource_group = data.azurerm_resource_group.rg_tatsukoni
}
```

### 動作

- モジュールは**単一のインスタンス**
- アドレス: `module.test`

### tfstate内のリソース例

```
module.test.azurerm_cosmosdb_account.cosmosdb_account_test
module.test.azurerm_cosmosdb_sql_database.testdatabase
module.test.azurerm_cosmosdb_sql_container.testcontainerapp
module.test.azurerm_cosmosdb_sql_container.testcontainerfront
```

### terraform state list の出力

```bash
$ terraform state list
module.test.azurerm_cosmosdb_account.cosmosdb_account_test
module.test.azurerm_cosmosdb_sql_database.testdatabase
module.test.azurerm_cosmosdb_sql_container.testcontainerapp
module.test.azurerm_cosmosdb_sql_container.testcontainerfront
```

---

## count ありの場合

### コード例

```hcl
module "test" {
  count          = var.env == "prd" ? 1 : 0  # prd環境のみ有効
  source         = "./test"
  env            = var.env
  resource_group = data.azurerm_resource_group.rg_tatsukoni
}
```

### 動作

- モジュールは**配列（リスト）**として扱われる
- `count = 1` → 1つの要素を持つ配列
- `count = 0` → 空の配列（要素なし）
- アドレス: `module.test[0]`（配列の最初の要素）

### tfstate内のリソース例

```
module.test[0].azurerm_cosmosdb_account.cosmosdb_account_test
module.test[0].azurerm_cosmosdb_sql_database.testdatabase
module.test[0].azurerm_cosmosdb_sql_container.testcontainerapp
module.test[0].azurerm_cosmosdb_sql_container.testcontainerfront
```

### terraform state list の出力

```bash
$ terraform state list
module.test[0].azurerm_cosmosdb_account.cosmosdb_account_test
module.test[0].azurerm_cosmosdb_sql_database.testdatabase
module.test[0].azurerm_cosmosdb_sql_container.testcontainerapp
module.test[0].azurerm_cosmosdb_sql_container.testcontainerfront
```

---

## Terraformの設計思想

### なぜ常に配列として扱うのか

#### 1. 一貫性のため

- `count = 0` でも `count = 5` でも同じルールで扱える
- 配列インデックスによって、どのインスタンスか明確に識別できる

```hcl
# count = 0 の場合
# インスタンス: なし（空の配列）

# count = 1 の場合
# インスタンス: module.test[0]

# count = 3 の場合
# インスタンス: module.test[0], module.test[1], module.test[2]
```

#### 2. 拡張性のため

将来的に複数インスタンスが必要になった場合に対応可能：

```hcl
# 初期: 1つのインスタンス
count = 1
# → module.test[0]

# 後で拡張: 3つのインスタンス
count = 3
# → module.test[0]（既存）
# → module.test[1]（新規）
# → module.test[2]（新規）
```

既存の `[0]` は維持されるため、リソースの削除・再作成が発生しない。

#### 3. 明示性のため

`module.test[0]` を見れば、これが配列の一部（count または for_each を使用）だとわかる。

---

## 具体例: count = 3 の場合

```hcl
module "test" {
  count          = 3
  source         = "./test"
  env            = var.env
  resource_group = data.azurerm_resource_group.rg_tatsukoni
}
```

### 作成されるインスタンス

```
module.test[0] → 1つ目のインスタンス
module.test[1] → 2つ目のインスタンス
module.test[2] → 3つ目のインスタンス
```

### terraform state list の出力

```bash
module.test[0].azurerm_cosmosdb_account.cosmosdb_account_test
module.test[0].azurerm_cosmosdb_sql_database.testdatabase
module.test[1].azurerm_cosmosdb_account.cosmosdb_account_test
module.test[1].azurerm_cosmosdb_sql_database.testdatabase
module.test[2].azurerm_cosmosdb_account.cosmosdb_account_test
module.test[2].azurerm_cosmosdb_sql_database.testdatabase
```

---

## 環境ごとに異なる動作

### prd環境（count = 1）

```hcl
count = var.env == "prd" ? 1 : 0  # prd環境では 1
```

**動作:**
- モジュールインスタンス: `module.test[0]` が1つ作成される
- 既存のtfstateには `module.test` として記録されている
- **アドレスの不一致が発生** → `moved` ブロックが必要

**terraform plan の結果（moved ブロックなしの場合）:**

```
Plan: 4 to add, 0 to change, 4 to destroy.

# 削除される（旧アドレス）
- module.test.azurerm_cosmosdb_account.cosmosdb_account_test

# 作成される（新アドレス）
+ module.test[0].azurerm_cosmosdb_account.cosmosdb_account_test
```

### dev環境（count = 0）

```hcl
count = var.env == "prd" ? 1 : 0  # dev環境では 0
```

**動作:**
- モジュールインスタンス: なし（空の配列）
- 既存のtfstateには `module.test` として記録されている
- **リソースは削除対象**となる

**terraform plan の結果:**

```
Plan: 0 to add, 0 to change, 4 to destroy.

# 削除される
- module.test.azurerm_cosmosdb_account.cosmosdb_account_test
- module.test.azurerm_cosmosdb_sql_database.testdatabase
- module.test.azurerm_cosmosdb_sql_container.testcontainerapp
- module.test.azurerm_cosmosdb_sql_container.testcontainerfront
```

---

## moved ブロックの役割

### 目的

既存のリソースアドレスを新しいアドレスに変更し、**実リソースの削除・再作成を防ぐ**。

### コード例

```hcl
# cosmosdb/moved.tf
moved {
  from = module.test      # 旧アドレス
  to   = module.test[0]   # 新アドレス
}
```

### このブロックにより実現すること

1. **Terraformに「リソースが移動した」ことを伝える**
   - 削除・再作成ではなく、アドレス変更として認識される

2. **実リソースは変更されない**
   - Azure上のCosmos DBアカウントは削除・再作成されない
   - データは保持される

3. **tfstate内のアドレスのみが変更される**
   - `module.test` → `module.test[0]`

### terraform plan の結果（moved ブロックありの場合）

```
Terraform will perform the following actions:

  # module.test.azurerm_cosmosdb_account.cosmosdb_account_test has moved to module.test[0].azurerm_cosmosdb_account.cosmosdb_account_test
    resource "azurerm_cosmosdb_account" "cosmosdb_account_test" {
        name = "tatsukoni-test-prd"
        # (30 unchanged attributes hidden)
    }

Plan: 0 to add, 0 to change, 0 to destroy.
```

**重要:** `Plan: 0 to add, 0 to change, 0 to destroy.` → リソースは変更されない

---

## moved ブロックの代替: terraform state mv コマンド

`moved` ブロックの代わりに、手動でアドレスを変更することもできます。

### コマンド例

```bash
# prd環境で実行
terraform state mv 'module.test' 'module.test[0]'
```

### moved ブロック vs terraform state mv

| 項目 | moved ブロック | terraform state mv |
|------|---------------|-------------------|
| 記録 | コードとして記録される | 手動操作（記録なし） |
| 共有 | チーム全員に自動適用 | 各自が手動実行する必要 |
| 安全性 | plan で事前確認可能 | 即座に実行される |
| 推奨 | ✅ 推奨 | 一時的な用途のみ |

**推奨:** `moved` ブロックを使用することで、変更履歴がコードとして残り、チーム全員に自動適用されます。

---

## 実装手順（環境ごとに異なる構成にする場合）

### Phase 1: count と moved ブロックの追加

#### 1. count を追加

```hcl
# cosmosdb/main.tf
module "test" {
  count          = var.env == "prd" ? 1 : 0  # prd環境のみ有効
  source         = "./test"
  env            = var.env
  resource_group = data.azurerm_resource_group.rg_tatsukoni
}
```

#### 2. moved ブロックを作成

```hcl
# cosmosdb/moved.tf
# prd環境のリソースアドレス変更用
# module.test → module.test[0]
moved {
  from = module.test
  to   = module.test[0]
}
```

### Phase 2: prd環境で適用（リソースアドレス変更）

```bash
# prd環境に切り替え
terraform init -reconfigure -backend-config=tfbackend/prd.tfbackend

# plan確認（リソースアドレス変更のみ、リソースは変更されない）
terraform plan -var env=prd
# 出力: Plan: 0 to add, 0 to change, 0 to destroy.

# apply実行
terraform apply -var env=prd
```

**確認:**

```bash
# アドレスが変更されていることを確認
terraform state list
# 出力:
# module.test[0].azurerm_cosmosdb_account.cosmosdb_account_test
# module.test[0].azurerm_cosmosdb_sql_database.testdatabase
# ...
```

### Phase 3: dev環境で適用（リソース削除）

```bash
# dev環境に切り替え
terraform init -reconfigure -backend-config=tfbackend/dev.tfbackend

# plan確認（リソース削除）
terraform plan -var env=dev
# 出力: Plan: 0 to add, 0 to change, 4 to destroy.
# - module.test.azurerm_cosmosdb_account.cosmosdb_account_test (削除)
# - module.test.azurerm_cosmosdb_sql_database.testdatabase (削除)
# - module.test.azurerm_cosmosdb_sql_container.testcontainerapp (削除)
# - module.test.azurerm_cosmosdb_sql_container.testcontainerfront (削除)

# apply実行（実リソースは既に手動削除済みなので、tfstateから削除されるのみ）
terraform apply -var env=dev
```

**注意:** dev環境では実リソースは既に手動削除されているため、refresh時に検出されず、tfstateから削除されるのみです。

### Phase 4: moved.tf 削除

リソースアドレスの変更が完了したら、moved.tf は削除できます。

```bash
rm cosmosdb/moved.tf

# prd環境で確認
terraform init -reconfigure -backend-config=tfbackend/prd.tfbackend
terraform plan -var env=prd
# 出力: No changes. Your infrastructure matches the configuration.
```

---

## resourceブロック vs moduleブロック: count追加時の自動検出の違い

### 重要な発見

Terraformでは、**resourceブロック**と**moduleブロック**で`count`を追加した際の自動移動検出の動作が**異なります**。

### resourceブロックの場合（自動検出あり）

#### 公式ドキュメントの記載

> "When you add `count` to an existing resource that didn't previously have the argument, Terraform **automatically proposes** moving the original object to instance `0` unless you write a `moved` block that explicitly mentions that resource."
>
> — [Refactoring: moved blocks](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)

#### 動作

```hcl
# 既存のコード
resource "azurerm_cosmosdb_account" "example" {
  name = "example"
  # ...
}

# count を追加
resource "azurerm_cosmosdb_account" "example" {
  count = var.env == "prd" ? 1 : 0  # ← 追加
  name  = "example"
  # ...
}
```

**結果:**
- Terraformが**自動的に**移動を検出
- `moved`ブロックなしでも以下のように表示される:

```
Terraform will perform the following actions:

  # azurerm_cosmosdb_account.example has moved to azurerm_cosmosdb_account.example[0]
    resource "azurerm_cosmosdb_account" "example" {
        name = "example"
        # (attributes unchanged)
    }

Plan: 0 to add, 0 to change, 0 to destroy.
```

**重要:** リソースの削除・再作成は発生しない（自動検出されるため）

### moduleブロックの場合（自動検出なし）

#### 公式ドキュメントの記載

> "To preserve an object that was previously associated with `module.a` alone, **you can add a `moved` block** to specify which instance key that object will take in the new configuration."
>
> — [Refactoring: moved blocks](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)

#### 動作

```hcl
# 既存のコード
module "test" {
  source         = "./test"
  env            = var.env
  resource_group = data.azurerm_resource_group.rg_tatsukoni
}

# count を追加
module "test" {
  count          = var.env == "prd" ? 1 : 0  # ← 追加
  source         = "./test"
  env            = var.env
  resource_group = data.azurerm_resource_group.rg_tatsukoni
}
```

**結果（`moved`ブロックなしの場合）:**
- Terraformは自動検出**しない**
- 削除と作成として扱われる:

```
Plan: 4 to add, 0 to change, 4 to destroy.

# 削除される
- module.test.azurerm_cosmosdb_account.cosmosdb_account_test
- module.test.azurerm_cosmosdb_sql_database.testdatabase
- module.test.azurerm_cosmosdb_sql_container.testcontainerapp
- module.test.azurerm_cosmosdb_sql_container.testcontainerfront

# 作成される
+ module.test[0].azurerm_cosmosdb_account.cosmosdb_account_test
+ module.test[0].azurerm_cosmosdb_sql_database.testdatabase
+ module.test[0].azurerm_cosmosdb_sql_container.testcontainerapp
+ module.test[0].azurerm_cosmosdb_sql_container.testcontainerfront
```

**重要:** リソースの削除・再作成が計画される（自動検出されないため）

#### 対処法: `moved`ブロックが必須

```hcl
# cosmosdb/moved.tf
moved {
  from = module.test
  to   = module.test[0]
}
```

このブロックを追加することで、resourceブロックと同様に移動として扱われます。

### 比較表

| 項目 | resourceブロック | moduleブロック |
|------|-----------------|---------------|
| **自動検出** | ✅ あり | ❌ なし |
| **`moved`ブロック** | 推奨（なくても動作） | **必須** |
| **`moved`なしの動作** | 移動として扱われる | 削除・作成として扱われる |
| **リソース影響（`moved`なし）** | なし | **削除・再作成が発生** |
| **公式ドキュメント記載** | "automatically proposes" | "you can add a moved block" |

### なぜ違いがあるのか

公式ドキュメントに明確な理由は記載されていませんが、以下のような理由が考えられます：

1. **複雑性の違い**
   - resourceは単一のリソース定義
   - moduleは複数のリソースを含む複雑な構造
   - moduleの自動検出は予期しない影響が大きい可能性

2. **明示性の重視**
   - moduleの変更は影響範囲が広い
   - 自動検出よりも明示的な宣言を求めることで、意図しない変更を防ぐ

3. **段階的な機能追加**
   - resourceの自動検出は比較的新しい機能
   - moduleへの拡張は将来的な改善の可能性

### ベストプラクティス

#### resourceブロックの場合

自動検出されますが、公式ドキュメントでは明示的な`moved`ブロックの記述を推奨しています：

> "However, we recommend writing out the corresponding `moved` block explicitly to make the change clearer to future readers of the module."

**理由:**
- コードの変更履歴が明確になる
- 将来のメンテナンス担当者が理解しやすい
- チーム開発での可読性向上

#### moduleブロックの場合

**必ず**`moved`ブロックを記述してください。これは推奨ではなく必須です。

### 実際の挙動確認

#### resourceブロックでの確認（自動検出あり）

```bash
# countを追加後、movedブロックなしでplan実行
terraform plan -var env=prd

# 結果: 自動的に移動として検出される
# has moved to resource[0]
# Plan: 0 to add, 0 to change, 0 to destroy.
```

#### moduleブロックでの確認（自動検出なし）

```bash
# countを追加後、movedブロックなしでplan実行
terraform plan -var env=prd

# 結果: 削除・作成として扱われる
# Plan: N to add, 0 to change, N to destroy.

# movedブロック追加後
terraform plan -var env=prd

# 結果: 移動として扱われる
# has moved to module[0]
# Plan: 0 to add, 0 to change, 0 to destroy.
```

---

## まとめ

### 重要なポイント

1. **`count` を使うと配列として扱われる**
   - `count = 1` でも `module.test[0]` となる
   - これはTerraformの一貫した設計

2. **既存のリソースとアドレスが異なる**
   - 既存: `module.test`
   - 新規: `module.test[0]`
   - アドレスが異なるため、削除・再作成が計画される

3. **`moved` ブロックでアドレス変更を管理**
   - 実リソースは削除・再作成されない
   - tfstate内のアドレスのみが変更される
   - 安全にリソースアドレスを移行できる

4. **環境ごとに異なる構成が可能**
   - `count = var.env == "prd" ? 1 : 0`
   - prd環境: リソースを保持
   - dev環境: リソースを削除

### Terraformの設計思想

- **一貫性**: すべての count 使用リソースを配列として扱う
- **拡張性**: 将来的な複数インスタンス化に対応
- **明示性**: `[0]` によって配列の一部だと明確にわかる

---

## 公式ドキュメント

- [The count Meta-Argument](https://developer.hashicorp.com/terraform/language/meta-arguments/count)
- [Refactoring: moved blocks](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)
- [Command: state mv](https://developer.hashicorp.com/terraform/cli/commands/state/mv)

---

## 調査日

2026-03-21
