# Project Structure

## Root Directory Organization

```
terraform-basemachina-modules/
├── .claude/              # Claude Code設定
│   └── commands/         # カスタムスラッシュコマンド
├── .kiro/                # Kiro spec-driven development
│   ├── specs/            # 機能仕様書
│   └── steering/         # プロジェクトステアリング（このファイル）
├── modules/              # 再利用可能なTerraformモジュール
│   └── aws/              # AWSリソース用モジュール
│       └── ecs-fargate/  # ECS Fargateデプロイメントモジュール
├── examples/             # 使用例とデモ
│   └── aws-ecs-fargate/  # ECS Fargateデプロイ例
├── test/                 # 統合テスト
│   └── aws/              # AWSリソーステスト
└── docs/                 # ドキュメント（将来追加予定）
```

## Subdirectory Structures

### modules/aws/ecs-fargate/
メインのTerraformモジュール - BaseMachina BridgeをECS Fargateにデプロイ

```
modules/aws/ecs-fargate/
├── alb.tf                # Application Load Balancer設定
├── ecr.tf                # ECRプルスルーキャッシュ設定
├── ecs.tf                # ECSクラスター、タスク定義、サービス
├── iam.tf                # IAMロールとポリシー
├── nat_gateway.tf        # NAT Gateway設定（Bridge初期化用）
├── outputs.tf            # モジュール出力値
├── security_groups.tf    # セキュリティグループ（ALB、Bridge、VPCエンドポイント）
├── variables.tf          # モジュール入力変数
├── vpc_endpoints.tf      # VPCエンドポイント（ECR、S3、Logs）
└── README.md             # モジュールドキュメント
```

**設計原則**:
- **1ファイル = 1AWSサービスカテゴリ**: 保守性向上
- **明確な責務分離**: 各ファイルが独立した機能を持つ
- **依存関係の明示**: モジュール間の依存をoutputsで管理

### examples/aws-ecs-fargate/
実際の使用例 - 完全な動作環境

```
examples/aws-ecs-fargate/
├── acm.tf                      # ACM証明書インポート（テスト用）
├── main.tf                     # モジュール呼び出し
├── outputs.tf                  # 出力値（モジュール + RDS）
├── rds.tf                      # RDS PostgreSQLインスタンス
├── variables.tf                # 入力変数定義
├── terraform.tfvars            # 実際の値（Gitignore対象）
├── terraform.tfvars.example    # 設定例
├── scripts/
│   ├── generate-cert.sh        # 自己署名証明書生成
│   └── init.sql                # RDSシードデータ
├── certs/                      # 生成された証明書（Gitignore対象）
│   ├── private-key.pem
│   ├── certificate.pem
│   └── certificate-chain.pem
└── README.md                   # デプロイ手順とドキュメント
```

**設計原則**:
- **実践的な例**: 本番環境に近い構成
- **テスト対応**: 自己署名証明書とRDSでテスト可能
- **セキュリティ**: 機密情報は.gitignoreで除外

### test/aws/
Terratestを使用した統合テスト

```
test/aws/
├── ecs_fargate_test.go         # メインテストファイル
├── go.mod                       # Go依存関係
├── go.sum                       # Go依存関係チェックサム
└── tmp/                         # テストログ（Gitignore対象）
    └── test_*.log
```

**テスト構造**:
- **実際のAWS環境でテスト**: 本物のリソースを作成・削除
- **包括的な検証**: ネットワーク、セキュリティ、ヘルスチェック
- **詳細な診断**: 失敗時のトラブルシューティング情報

## Code Organization Patterns

### Terraform Module Pattern
```hcl
# 1. データソース
data "aws_region" "current" {}

# 2. ローカル変数
locals {
  full_name = "${var.name_prefix}-bridge"
}

# 3. リソース（論理的にグループ化）
resource "aws_ecs_cluster" "main" {
  # ...
}

# 4. 出力値
output "cluster_arn" {
  description = "ECSクラスターARN"
  value       = aws_ecs_cluster.main.arn
}
```

### Security Group Organization Pattern
```hcl
# セキュリティグループ定義
resource "aws_security_group" "bridge" {
  name_prefix = "${var.name_prefix}-bridge-"
  # ...
}

# インバウンドルール（個別リソース）
resource "aws_security_group_rule" "bridge_ingress_http" {
  type = "ingress"
  # ...
}

# アウトバウンドルール（個別リソース）
resource "aws_security_group_rule" "bridge_egress_all" {
  type = "egress"
  # ...
}
```

**理由**: ルールを個別リソースにすることで、条件付き作成や依存関係管理が容易

### RDS Pattern with Secrets Manager
```hcl
# 1. パスワード生成
resource "random_password" "rds_master_password" {
  # ...
}

# 2. RDSインスタンス
resource "aws_db_instance" "postgres" {
  password = random_password.rds_master_password.result
  # ...
}

# 3. Secrets Managerに保存
resource "aws_secretsmanager_secret" "rds_credentials" {
  # ...
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_string = jsonencode({
    username = aws_db_instance.postgres.username
    password = random_password.rds_master_password.result
    # ...
  })
}
```

**理由**: パスワードを安全に生成・管理し、アプリケーションから参照可能に

## File Naming Conventions

### Terraform Files
- **リソース定義**: `<service>.tf`
  - 例: `alb.tf`, `ecs.tf`, `rds.tf`
- **変数定義**: `variables.tf`
- **出力値**: `outputs.tf`
- **メイン設定**: `main.tf`（モジュール呼び出し用）
- **プロバイダー設定**: `versions.tf`または`main.tf`内

### Test Files
- **テストファイル**: `*_test.go`
  - 例: `ecs_fargate_test.go`
- **ヘルパー**: `<helper_name>.go`（現在未使用）

### Scripts
- **Bashスクリプト**: `<action>-<target>.sh`
  - 例: `generate-cert.sh`
- **SQLスクリプト**: `init.sql`, `seed.sql`など

### Documentation
- **README**: `README.md`（各ディレクトリ）
- **ステアリング**: `<domain>.md`（.kiro/steering/）
- **仕様書**: `<feature-name>.md`（.kiro/specs/）

## Import Organization

### Terraform Import Pattern
```hcl
# モジュール呼び出し
module "basemachina_bridge" {
  source = "../../modules/aws/ecs-fargate"

  # ネットワーク設定
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids

  # 他の設定...
}
```

### Go Import Pattern
```go
import (
    // 標準ライブラリ
    "fmt"
    "testing"
    "time"

    // サードパーティライブラリ
    "github.com/aws/aws-sdk-go/aws"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)
```

**順序**:
1. 標準ライブラリ
2. サードパーティライブラリ
3. プロジェクト内パッケージ

## Key Architectural Principles

### 1. モジュール化と再利用性
- **modules/**: 再利用可能なコンポーネント
- **examples/**: 具体的な使用パターン
- 明確なインターフェース（variables.tf, outputs.tf）

### 2. Infrastructure as Code
- 宣言的な構成管理
- バージョン管理による変更追跡
- コードレビューとCI/CD

### 3. セキュリティバイデザイン
- プライベートサブネット優先
- 最小権限の原則
- 暗号化（転送時・保管時）
- 機密情報の分離（terraform.tfvars, Secrets Manager）

### 4. テスタビリティ
- 実際のAWS環境でのテスト
- 自動クリーンアップ
- 詳細な診断とログ

### 5. ドキュメントファースト
- 各モジュールにREADME
- インラインコメント
- 使用例の提供

### 6. コスト最適化
- VPCエンドポイント活用
- ECRプルスルーキャッシュ
- 適切なリソースサイズ

### 7. 運用性
- CloudWatch統合
- 自動バックアップ
- スケーラビリティ

## Resource Naming Conventions

### 命名パターン
```
${var.name_prefix}-<resource-type>-<optional-suffix>
```

**例**:
- ECSクラスター: `prod-basemachina-bridge`
- ALB: `prod-basemachina-bridge`
- セキュリティグループ: `prod-bridge-<random>`
- RDS: `prod-bridge-example-<random>`
- Secrets: `prod-rds-credentials-<random>`

### タグ戦略
```hcl
tags = merge(
  var.tags,
  {
    Name = "${var.name_prefix}-<resource-name>"
  }
)
```

**デフォルトタグ**:
- `Environment`: 環境識別（production, staging, development）
- `Project`: プロジェクト名（basemachina-bridge）
- `ManagedBy`: 管理方法（terraform）
- `Name`: リソース名
