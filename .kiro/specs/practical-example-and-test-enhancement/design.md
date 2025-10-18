# Technical Design Document

## Overview

このドキュメントは、ECS Fargateモジュールのexampleとテストを実践的に強化するための技術設計を定義します。既存の`examples/aws-ecs-fargate/`と`test/aws/ecs_fargate_test.go`を拡張し、HTTPS証明書検証とRDS接続検証を追加します。

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                     Example Deployment                          │
│                                                                 │
│  ┌──────────────┐  HTTPS   ┌─────────┐  HTTP   ┌───────────┐  │
│  │ ACM Certificate │ ──────> │   ALB   │ ──────> │  Bridge   │  │
│  │ (Self-signed) │         │(Port 443)│        │(ECS Fargate)│ │
│  └──────────────┘           └─────────┘         └───────────┘  │
│                                                        │         │
│                                                   PostgreSQL    │
│                                                        │         │
│                                                        v         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              RDS PostgreSQL                             │   │
│  │  - Instance: db.t3.micro                                │   │
│  │  - Database: bridgedb                                   │   │
│  │  - Seed data: users table (3+ records)                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      Terratest Validation                       │
│                                                                 │
│  ┌──────────────┐  HTTPS   ┌─────────┐                         │
│  │   Terratest  │ ──────> │ ALB DNS │ (GET /ok → 200 OK)       │
│  │  Test Code   │          └─────────┘                         │
│  └──────────────┘                                               │
│                                                                 │
│  Note: RDS connection testing is done manually, not in Terratest│
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **証明書生成フロー**
   - 開発者が`generate-cert.sh`スクリプトを実行
   - OpenSSLで自己署名証明書を生成（`certs/`ディレクトリ）
   - Terraformで証明書をACMにインポート
   - ACM証明書ARNをALBに設定

2. **RDSデプロイフロー**
   - Terraform applyでRDS PostgreSQLインスタンスを作成
   - null_resourceでpsqlクライアントを使い`init.sql`を実行
   - usersテーブルとシードデータを投入
   - Bridgeセキュリティグループからのアクセスを許可

3. **テスト実行フロー**
   - Terratest → Terraform apply（example環境デプロイ）
   - HTTPSリクエストテスト（ALB DNS → `/ok`エンドポイント）
   - Terraform destroy（リソースクリーンアップ）
   - **注**: RDS接続テストはTerratestでは実施せず、手動検証のみとする

## Component Design

### 1. 自己署名証明書生成スクリプト

**ファイル**: `examples/aws-ecs-fargate/scripts/generate-cert.sh`

**機能**:
- OpenSSLを使用した2048ビットRSA鍵ペアの生成
- 有効期限365日の自己署名証明書の生成
- Common Name: `bridge.example.local`
- 証明書ファイルの保存先: `examples/aws-ecs-fargate/certs/`

**生成ファイル**:
- `certs/private-key.pem` - 秘密鍵（2048ビットRSA）
- `certs/certificate.pem` - 自己署名証明書
- `certs/certificate-chain.pem` - 証明書チェーン（自己署名の場合、certificateと同じ内容）

**実装詳細**:
```bash
#!/bin/bash
# examples/aws-ecs-fargate/scripts/generate-cert.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="$SCRIPT_DIR/../certs"
DOMAIN="bridge.example.local"

mkdir -p "$CERTS_DIR"

# 既存ファイルチェック
if [ -f "$CERTS_DIR/private-key.pem" ]; then
  read -p "Certificate files already exist. Overwrite? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

# 秘密鍵生成
openssl genrsa -out "$CERTS_DIR/private-key.pem" 2048

# 自己署名証明書生成
openssl req -new -x509 -key "$CERTS_DIR/private-key.pem" \
  -out "$CERTS_DIR/certificate.pem" -days 365 \
  -subj "/C=JP/ST=Tokyo/L=Tokyo/O=BaseMachina/CN=$DOMAIN"

# 証明書チェーン（自己署名なので証明書と同じ）
cp "$CERTS_DIR/certificate.pem" "$CERTS_DIR/certificate-chain.pem"

echo "Self-signed certificate generated successfully!"
echo "Files created in: $CERTS_DIR"
```

### 2. ACM証明書インポートリソース

**ファイル**: `examples/aws-ecs-fargate/acm.tf`（新規作成）

**機能**:
- ローカルで生成した自己署名証明書をACMにインポート
- 条件付きリソース作成（`enable_acm_import`変数）

**実装詳細**:
```hcl
# ACM証明書インポート（オプション）
resource "aws_acm_certificate" "self_signed" {
  count = var.enable_acm_import ? 1 : 0

  private_key       = file("${path.module}/certs/private-key.pem")
  certificate_body  = file("${path.module}/certs/certificate.pem")
  certificate_chain = file("${path.module}/certs/certificate-chain.pem")

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-bridge-self-signed-cert"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# 証明書ARNをモジュールに渡す
locals {
  certificate_arn = var.enable_acm_import ? aws_acm_certificate.self_signed[0].arn : var.certificate_arn
}
```

**新規変数**:
```hcl
variable "enable_acm_import" {
  description = "ローカル証明書をACMにインポートする（テスト環境向け）"
  type        = bool
  default     = false
}
```

### 3. RDS PostgreSQLリソース

**ファイル**: `examples/aws-ecs-fargate/rds.tf`（新規作成）

**機能**:
- PostgreSQL RDSインスタンスの作成（db.t3.micro）
- プライベートサブネットへの配置
- セキュリティグループルールの設定
- Secrets Managerでの認証情報管理
- 条件付きリソース作成（`enable_rds`変数）

**実装詳細**:
```hcl
# RDS用セキュリティグループ
resource "aws_security_group" "rds" {
  count = var.enable_rds ? 1 : 0

  name_prefix = "${var.name_prefix}-rds-"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rds-sg"
    }
  )
}

# BridgeからRDSへのアクセス許可
resource "aws_security_group_rule" "rds_ingress_from_bridge" {
  count = var.enable_rds ? 1 : 0

  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = module.basemachina_bridge.bridge_security_group_id
  security_group_id        = aws_security_group.rds[0].id
  description              = "Allow PostgreSQL access from Bridge"
}

# RDSサブネットグループ
resource "aws_db_subnet_group" "rds" {
  count = var.enable_rds ? 1 : 0

  name_prefix = "${var.name_prefix}-rds-"
  subnet_ids  = var.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rds-subnet-group"
    }
  )
}

# Secrets Managerでの認証情報保存
resource "aws_secretsmanager_secret" "rds_credentials" {
  count = var.enable_rds ? 1 : 0

  name_prefix = "${var.name_prefix}-rds-credentials-"
  description = "RDS PostgreSQL master credentials"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  count = var.enable_rds ? 1 : 0

  secret_id = aws_secretsmanager_secret.rds_credentials[0].id
  secret_string = jsonencode({
    username = var.database_username
    password = var.database_password
    database = var.database_name
  })
}

# RDSインスタンス
resource "aws_db_instance" "postgres" {
  count = var.enable_rds ? 1 : 0

  identifier = "${var.name_prefix}-bridgedb"

  engine         = "postgres"
  engine_version = var.database_engine_version
  instance_class = var.database_instance_class

  allocated_storage = var.database_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.database_name
  username = var.database_username
  password = var.database_password

  db_subnet_group_name   = aws_db_subnet_group.rds[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]
  publicly_accessible    = false

  backup_retention_period = 7
  skip_final_snapshot     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-bridgedb"
    }
  )
}
```

**新規変数**:
```hcl
variable "enable_rds" {
  description = "RDSインスタンスをデプロイする"
  type        = bool
  default     = true
}

variable "database_name" {
  description = "データベース名"
  type        = string
  default     = "bridgedb"
}

variable "database_username" {
  description = "データベースマスターユーザー名"
  type        = string
  sensitive   = true
}

variable "database_password" {
  description = "データベースマスターパスワード"
  type        = string
  sensitive   = true
}

variable "database_instance_class" {
  description = "RDSインスタンスクラス"
  type        = string
  default     = "db.t3.micro"
}

variable "database_allocated_storage" {
  description = "RDSストレージサイズ（GB）"
  type        = number
  default     = 20
}

variable "database_engine_version" {
  description = "PostgreSQLエンジンバージョン"
  type        = string
  default     = "14.7"
}
```

**新規出力値**:
```hcl
output "rds_endpoint" {
  description = "RDSエンドポイント"
  value       = var.enable_rds ? aws_db_instance.postgres[0].endpoint : null
}

output "rds_port" {
  description = "RDSポート"
  value       = var.enable_rds ? aws_db_instance.postgres[0].port : null
}

output "rds_database_name" {
  description = "データベース名"
  value       = var.enable_rds ? aws_db_instance.postgres[0].db_name : null
}
```

### 4. データベースシードスクリプト

**ファイル**: `examples/aws-ecs-fargate/scripts/init.sql`

**機能**:
- usersテーブルの作成
- サンプルレコードの挿入（3件以上）

**実装詳細**:
```sql
-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert seed data
INSERT INTO users (name, email) VALUES
    ('Alice Johnson', 'alice@example.com'),
    ('Bob Smith', 'bob@example.com'),
    ('Charlie Brown', 'charlie@example.com'),
    ('Diana Prince', 'diana@example.com'),
    ('Ethan Hunt', 'ethan@example.com')
ON CONFLICT (email) DO NOTHING;

-- Verify data
SELECT COUNT(*) AS user_count FROM users;
```

**実行リソース**: `examples/aws-ecs-fargate/rds.tf`に追加

```hcl
# データベース初期化
resource "null_resource" "db_init" {
  count = var.enable_rds ? 1 : 0

  depends_on = [aws_db_instance.postgres]

  provisioner "local-exec" {
    command = <<-EOT
      PGPASSWORD='${var.database_password}' psql \
        -h ${aws_db_instance.postgres[0].address} \
        -U ${var.database_username} \
        -d ${var.database_name} \
        -f ${path.module}/scripts/init.sql
    EOT
  }

  triggers = {
    sql_file_hash = filemd5("${path.module}/scripts/init.sql")
  }
}
```

**注意**: `psql`クライアントが実行環境にインストールされている必要があります。

### 5. Terratest HTTPS検証

**ファイル**: `test/aws/ecs_fargate_test.go`（既存ファイルに追加）

**機能**:
- ALB DNSエンドポイントへのHTTPSリクエスト
- TLS証明書検証スキップ（自己署名証明書対応）
- リトライロジック（最大5分間、10秒間隔）

**実装詳細**:
```go
// testHTTPSHealthCheck tests HTTPS endpoint health check
func testHTTPSHealthCheck(t *testing.T, terraformOptions *terraform.Options) {
	albDNSName := terraform.Output(t, terraformOptions, "alb_dns_name")
	healthCheckURL := fmt.Sprintf("https://%s/ok", albDNSName)

	// Create HTTP client with TLS verification skip (for self-signed certs)
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	client := &http.Client{
		Transport: tr,
		Timeout:   30 * time.Second,
	}

	maxRetries := 30 // 5 minutes with 10s interval
	timeBetweenRetries := 10 * time.Second

	for i := 0; i < maxRetries; i++ {
		startTime := time.Now()
		resp, err := client.Get(healthCheckURL)
		elapsed := time.Since(startTime)

		if err != nil {
			t.Logf("Attempt %d/%d: HTTPS request failed: %v (elapsed: %v)", i+1, maxRetries, err, elapsed)
			time.Sleep(timeBetweenRetries)
			continue
		}
		defer resp.Body.Close()

		body, _ := ioutil.ReadAll(resp.Body)
		t.Logf("Attempt %d/%d: Status=%d, Body=%s (elapsed: %v)", i+1, maxRetries, resp.StatusCode, string(body), elapsed)

		if resp.StatusCode == http.StatusOK {
			assert.Equal(t, http.StatusOK, resp.StatusCode, "Health check should return 200 OK")
			return
		}

		if i == maxRetries-1 {
			require.Equal(t, http.StatusOK, resp.StatusCode, "Health check should return 200 OK after retries")
		}

		time.Sleep(timeBetweenRetries)
	}
}
```

### 6. .gitignore更新

**ファイル**: `.gitignore`（ルート）

**追加内容**:
```
# Self-signed certificates (should not be committed)
examples/aws-ecs-fargate/certs/
*.pem
*.key
*.crt
```

### 7. ドキュメント強化

**ファイル**: `examples/aws-ecs-fargate/README.md`（既存ファイルを大幅に拡張）

**セクション追加**:
1. **自己署名証明書の生成**
   - スクリプト実行手順
   - ACMインポート手順
   - 注意事項（ブラウザ警告、`curl -k`オプション）

2. **RDSデプロイ手順**
   - 必須変数の説明
   - terraform.tfvars.exampleの使用方法
   - Secrets Managerでの認証情報管理

3. **シードデータ**
   - usersテーブル構造
   - サンプルレコードの内容
   - カスタマイズ方法

4. **テスト実行手順**
   - 必要な環境変数のリスト
   - `go test`コマンド例
   - `.env.example`の使用方法

**ファイル**: `test/README.md`（既存ファイルを拡張）

**セクション追加**:
1. **環境変数設定**
   - HTTPS テスト用: `TEST_VPC_ID`, `TEST_PUBLIC_SUBNET_IDS`, `TEST_TENANT_ID`, `TEST_CERTIFICATE_ARN`
   - **注**: TerratestではRDSインスタンスを作成せず、Bridge単体のHTTPS疎通確認のみ実施

2. **.env.example ファイル**
   ```bash
   # AWS Configuration
   export AWS_DEFAULT_REGION=ap-northeast-1
   export AWS_ACCESS_KEY_ID=your-access-key
   export AWS_SECRET_ACCESS_KEY=your-secret-key

   # Network Configuration
   export TEST_VPC_ID=vpc-xxxxx
   export TEST_PUBLIC_SUBNET_IDS=subnet-xxxxx,subnet-yyyyy

   # Bridge Configuration
   export TEST_TENANT_ID=your-tenant-id

   # Certificate Configuration (optional)
   export TEST_CERTIFICATE_ARN=arn:aws:acm:region:account:certificate/xxxxx
   ```

**ファイル**: `examples/aws-ecs-fargate/terraform.tfvars.example`（既存ファイルを拡張）

**追加内容**:
```hcl
# ========================================
# RDS Configuration (Optional)
# ========================================

enable_rds = true

database_name     = "bridgedb"
database_username = "dbadmin"
database_password = "ChangeMe123!"  # WARNING: Use AWS Secrets Manager in production!

database_instance_class     = "db.t3.micro"
database_allocated_storage  = 20
database_engine_version     = "14.7"

# ========================================
# ACM Certificate Import (Optional)
# ========================================

enable_acm_import = false  # Set to true to import local self-signed certificate
# certificate_arn = "arn:aws:acm:ap-northeast-1:123456789012:certificate/xxxxx"
```

## File Structure Changes

### 新規作成ファイル

```
examples/aws-ecs-fargate/
├── scripts/
│   ├── generate-cert.sh        # 証明書生成スクリプト
│   └── init.sql                # RDSシードデータ
├── acm.tf                      # ACM証明書インポート
├── rds.tf                      # RDS PostgreSQLリソース
└── certs/                      # 証明書ディレクトリ（gitignore）
    ├── private-key.pem
    ├── certificate.pem
    └── certificate-chain.pem
```

### 既存ファイルの変更

```
examples/aws-ecs-fargate/
├── variables.tf                # RDS/ACM関連変数を追加
├── outputs.tf                  # RDS関連出力値を追加
├── main.tf                     # certificate_arnの参照をlocalsに変更
├── README.md                   # 証明書/RDS/テスト手順を追加
└── terraform.tfvars.example    # RDS/ACM変数例を追加

test/
├── aws/
│   └── ecs_fargate_test.go     # HTTPS検証関数を追加（RDSテストなし）
├── README.md                   # 環境変数設定を追加
└── .env.example                # 環境変数サンプル（新規）

.gitignore                      # certs/ディレクトリを追加
```

## Implementation Constraints

### 技術的制約

1. **psqlクライアント必須**
   - RDS初期化（`null_resource`）にはローカル環境に`psql`クライアントが必要
   - 代替案: Lambda関数またはECS Taskでの初期化（より複雑）

2. **自己署名証明書の制限**
   - ブラウザでの警告表示
   - `curl`コマンドには`-k`オプションが必要
   - 本番環境では使用不可（ドキュメントで明記）

3. **Terraformバージョン**
   - Terraform >= 1.0（既存要件）
   - AWS Provider ~> 5.0（既存要件）

4. **Go言語バージョン**
   - Go >= 1.20（Terratest実行用）

### セキュリティ考慮事項

1. **秘密鍵管理**
   - `certs/`ディレクトリを`.gitignore`に追加
   - 証明書ファイルをリポジトリにコミットしない

2. **データベース認証情報**
   - Terraform変数で`sensitive = true`を設定
   - AWS Secrets Managerに保存
   - terraform.tfvars.exampleには警告コメントを記載

3. **テスト環境**
   - `skip_final_snapshot = true`（本番では使用不可）
   - テスト後のリソース削除を徹底

## Testing Strategy

### ユニットテスト（該当なし）
このスペックはインフラストラクチャとエンドツーエンドテストの強化であり、ユニットテストは対象外です。

### 統合テスト（Terratest）

1. **HTTPS エンドポイントテスト**
   - テスト対象: ALB DNS → Bridge `/ok`エンドポイント
   - 検証内容: HTTPステータス200、レスポンスボディ
   - リトライ: 最大5分間、10秒間隔
   - **注**: テストではRDSインスタンスを作成せず（`enable_rds = false`）、Bridge単体のHTTPS疎通確認のみ実施

2. **証明書インポートテスト**
   - テスト対象: `enable_acm_import = true`でACMリソース作成
   - 検証内容: ACM証明書ARNの取得、ALBへの適用

### 手動テスト

1. **証明書生成スクリプト**
   - `./scripts/generate-cert.sh`の実行
   - 生成ファイルの確認（`certs/`ディレクトリ）

2. **RDSシードデータ**
   - psqlクライアントでRDSに接続
   - `SELECT * FROM users;`でレコード確認

3. **ブラウザでのHTTPSアクセス**
   - `https://[ALB_DNS]/ok`にアクセス
   - 証明書警告の表示確認

## Dependencies

### 外部ツール依存

- **OpenSSL**: 証明書生成スクリプト
- **psql**: RDS初期化（PostgreSQLクライアント）
- **Go >= 1.20**: Terratest実行
- **Terraform >= 1.0**: インフラストラクチャプロビジョニング

### Goモジュール依存

```go
require (
	github.com/gruntwork-io/terratest v0.43.0  // 既存
	github.com/stretchr/testify v1.8.4         // 既存
	github.com/aws/aws-sdk-go v1.44.0          // 既存
)
```

**注**: TerratestではRDS接続テストを行わないため、`github.com/lib/pq`は不要です。

## Deployment Strategy

### デプロイ順序

1. **証明書生成**（オプション）
   ```bash
   cd examples/aws-ecs-fargate
   ./scripts/generate-cert.sh
   ```

2. **terraform.tfvarsの設定**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # database_username, database_passwordを編集
   ```

3. **Terraformデプロイ**
   ```bash
   terraform init
   terraform plan -var="enable_rds=true" -var="enable_acm_import=true"
   terraform apply
   ```

4. **RDS初期化確認**
   ```bash
   psql -h <RDS_ENDPOINT> -U <USERNAME> -d bridgedb -c "SELECT * FROM users;"
   ```

5. **HTTPS動作確認**
   ```bash
   curl -k https://<ALB_DNS>/ok
   ```

### ロールバック戦略

1. **Terraform destroy**
   ```bash
   terraform destroy
   ```
   - RDS: `skip_final_snapshot = true`のため即座に削除
   - ACM証明書: インポートされた証明書は削除

2. **手動クリーンアップ**
   - Secrets Managerシークレット（必要に応じて）
   - CloudWatch Logs（ログ保持期間後に自動削除）

## Migration Plan

既存のexampleとテストは引き続き動作するため、破壊的変更はありません。

### 後方互換性

1. **既存変数のデフォルト値維持**
   - 新規変数はすべてオプション（`enable_rds`, `enable_acm_import`）
   - デフォルト値により既存の動作を保持

2. **既存出力値の保持**
   - 新規出力値を追加するのみ
   - 既存出力値は変更なし

3. **既存テストコードの保持**
   - 既存テスト関数は変更なし
   - 新規テスト関数を追加

### 移行手順（ユーザー向け）

1. **最小限の変更で動作確認**
   ```bash
   # 既存の動作（RDS/証明書なし）
   terraform apply
   ```

2. **RDSのみ追加**
   ```bash
   # RDSを有効化
   terraform apply -var="enable_rds=true" \
     -var="database_username=dbadmin" \
     -var="database_password=ChangeMe123!"
   ```

3. **証明書も追加**
   ```bash
   # 証明書生成
   ./scripts/generate-cert.sh

   # RDSと証明書を有効化
   terraform apply -var="enable_rds=true" \
     -var="enable_acm_import=true" \
     -var="database_username=dbadmin" \
     -var="database_password=ChangeMe123!"
   ```

## Performance Considerations

### リソース使用量

- **RDS**: db.t3.micro（1 vCPU、1GB RAM、20GB storage）
- **追加コスト**: 月額約$15-20（us-east-1、24時間稼働時）
- **テスト時間**: 既存テスト + 3-5分（RDS作成、初期化、検証）

### 最適化

1. **RDS起動時間短縮**
   - スナップショットからの復元（将来的な改善）
   - テスト専用の常時稼働RDSインスタンス

2. **並列テスト実行**
   - HTTPS検証とRDS検証を並列実行
   - 現在の実装では順次実行

## Risks and Mitigations

### リスク

1. **psqlクライアント未インストール**
   - **影響**: RDS初期化失敗
   - **対策**: READMEでインストール手順を明記、エラーメッセージを分かりやすく

2. **自己署名証明書の本番利用**
   - **影響**: セキュリティリスク
   - **対策**: READMEで警告を明記、terraform.tfvars.exampleにコメント追加

3. **データベース認証情報の漏洩**
   - **影響**: セキュリティリスク
   - **対策**: `.gitignore`でtfvarsを除外、Secrets Manager使用を推奨

4. **テスト環境の残存リソース**
   - **影響**: 予期しないコスト発生
   - **対策**: CI/CDパイプラインでterraform destroy自動実行

### 軽減策

- すべての変数を`sensitive = true`に設定（該当する場合）
- ドキュメントでセキュリティベストプラクティスを明記
- CI/CDでのリソースクリーンアップ自動化
