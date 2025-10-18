# BaseMachina Bridge - AWS ECS Fargate デプロイ例

このディレクトリには、BaseMachina BridgeをAWS ECS Fargateにデプロイするための実装例が含まれています。

## 前提条件

デプロイを開始する前に、以下のリソースが準備されている必要があります。

### 1. VPCとサブネット

- **VPC**: 既存のVPCが必要です
- **プライベートサブネット**: Bridgeタスクを配置するため、複数のアベイラビリティゾーン（AZ）にまたがるプライベートサブネットが必要
- **パブリックサブネット**: ALBを配置するため、複数のAZにまたがるパブリックサブネットが必要

#### インターネットアクセス方法

このモジュールは、**デフォルトでVPCエンドポイントとECRプルスルーキャッシュを使用**してプライベートサブネットからAWSサービスにアクセスします。NAT GatewayもパブリックIPも不要です。

**ECRプルスルーキャッシュ（デフォルト、推奨）**:
- **仕組み**:
  - Public ECR (`public.ecr.aws`) のイメージを自動的にPrivate ECRにキャッシュ
  - AWS のマネージドインフラがPublic ECRからイメージを取得（ECSタスクではない）
  - ECSタスクはPrivate ECRからVPCエンドポイント経由で取得
  - `public.ecr.aws/basemachina/bridge:latest` → `<account-id>.dkr.ecr.<region>.amazonaws.com/ecr-public/basemachina/bridge:latest`
- **メリット**:
  - NAT Gateway不要（コスト削減: 約$32/月）
  - パブリックIP不要（セキュリティ向上）
  - ECSタスクにインターネット接続不要
  - 初回デプロイから完全にプライベートネットワークのみで動作
- **設定**: デフォルトで有効（`enable_ecr_pull_through_cache = true`）

**VPCエンドポイント（デフォルト、Private ECR対応）**:
- **メリット**:
  - NAT Gatewayのデータ転送料が不要
  - AWSバックボーン経由で高速
  - トラフィックがインターネットを経由しない
- **設定**: デフォルトで有効（`enable_vpc_endpoints = true`）
- **必要なVPCエンドポイント**:
  - ECR API（インターフェース型、約$7/月）
  - ECR Docker（インターフェース型、約$7/月）
  - S3（ゲートウェイ型、無料）
  - CloudWatch Logs（インターフェース型、約$7/月、オプション）
- **コスト**: 約$21/月（S3エンドポイントは無料）

**代替構成: NAT Gateway使用**:
VPCエンドポイントとECRプルスルーキャッシュを無効にする場合:
```hcl
enable_vpc_endpoints          = false
enable_ecr_pull_through_cache = false
# NAT Gatewayが各AZに設定されている必要があります
```
**コスト**: 約$32/月（NAT Gateway料金） + データ転送料

### 2. ACM証明書（オプション）

**本番環境向け**: 信頼されたCA（Let's Encrypt、AWS Certificate Manager等）から取得した証明書を使用してください。

**テスト環境向け**: 自己署名証明書を生成してACMにインポートすることも可能です（後述）。

本番環境の場合:
- HTTPS通信用のSSL/TLS証明書がAWS Certificate Manager (ACM)で作成されている必要があります
- 証明書はデプロイ先のリージョンに存在する必要があります
- 証明書のARNが必要です

テスト環境の場合:
- 自己署名証明書を生成してACMにインポート可能（[テスト環境向けHTTPS設定](#テスト環境向けhttps設定自己署名証明書)を参照）
- HTTPのみでテストする場合は証明書不要（HTTPリスナーが自動使用されます）

### 3. BaseMachinaテナントID

- BaseMachinaから提供されるテナントIDが必要です

### 4. AWS認証情報

- Terraformを実行するためのAWS認証情報（アクセスキー、シークレットキー、またはIAMロール）
- 必要なIAM権限:
  - VPC、サブネット、セキュリティグループの作成・変更
  - ECS（クラスター、タスク定義、サービス）の作成・変更
  - ALB（ロードバランサー、ターゲットグループ、リスナー）の作成・変更
  - IAMロールとポリシーの作成・アタッチ
  - CloudWatch Logsロググループの作成・変更

### 5. データベース（オプション）

Bridgeからデータベースにアクセスする場合:
- データベースインスタンス（RDS、Aurora等）が同じVPC内に存在すること
- データベースのセキュリティグループIDが必要
- データベースのポート番号（例: PostgreSQL 5432、MySQL 3306）

## デプロイ手順

### ステップ1: 設定ファイルの準備

1. `terraform.tfvars.example`をコピーして`terraform.tfvars`を作成:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. `terraform.tfvars`を編集して、実際の値を設定:

```hcl
vpc_id             = "vpc-0123456789abcdef0"
private_subnet_ids = ["subnet-xxx", "subnet-yyy"]
public_subnet_ids  = ["subnet-aaa", "subnet-bbb"]
certificate_arn    = "arn:aws:acm:ap-northeast-1:123456789012:certificate/..."
tenant_id          = "your-tenant-id"
```

**重要**: `terraform.tfvars`には機密情報が含まれるため、Gitにコミットしないでください。

### ステップ2: Terraformの初期化

```bash
terraform init
```

このコマンドは、必要なプロバイダー（AWS Provider）をダウンロードし、バックエンドを初期化します。

### ステップ3: デプロイ計画の確認

```bash
terraform plan
```

このコマンドで、作成されるリソースを事前に確認できます。エラーがないことを確認してください。

### ステップ4: デプロイの実行

```bash
terraform apply
```

確認プロンプトで`yes`と入力すると、デプロイが開始されます。完了までに5〜10分程度かかります。

**注**: ECRプルスルーキャッシュを使用する場合（デフォルト）、AWSのマネージドインフラが自動的にPublic ECRからイメージを取得してキャッシュします。ECSタスク自体にはインターネット接続は不要です。

### ステップ5: デプロイ後の確認

デプロイが完了すると、以下の出力値が表示されます:

```
Outputs:

alb_dns_name = "prod-basemachina-bridge-1234567890.ap-northeast-1.elb.amazonaws.com"
ecs_cluster_name = "prod-basemachina-bridge"
ecs_service_name = "prod-basemachina-bridge"
...
```

`alb_dns_name`の値を使用して、Route 53でDNSレコードを作成できます。

## カスタマイズ方法

### リソースサイズの変更

`terraform.tfvars`で以下の値を調整できます:

```hcl
# CPU/メモリの変更（パフォーマンス調整）
cpu    = 512
memory = 1024

# タスク数の変更（高可用性）
desired_count = 2
```

### ログ保持期間の変更

```hcl
# CloudWatch Logsの保持期間を30日に変更
log_retention_days = 30
```

### データベース接続の有効化

```hcl
# データベースへのアクセスを許可
database_security_group_id = "sg-0123456789abcdef0"
database_port              = 5432  # PostgreSQLの場合
```

### タグのカスタマイズ

```hcl
tags = {
  Environment = "production"
  Project     = "basemachina-bridge"
  ManagedBy   = "terraform"
  Owner       = "platform-team"
  CostCenter  = "engineering"
}
```

## 運用

### ログの確認

CloudWatch Logsでログを確認:

```bash
aws logs tail /ecs/basemachina-bridge --follow
```

### ECSサービスの状態確認

```bash
aws ecs describe-services \
  --cluster prod-basemachina-bridge \
  --services prod-basemachina-bridge
```

### タスク数のスケーリング

`terraform.tfvars`で`desired_count`を変更して、`terraform apply`を実行:

```hcl
desired_count = 3  # 3タスクに増やす
```

## クリーンアップ手順

リソースを削除する場合:

```bash
terraform destroy
```

確認プロンプトで`yes`と入力すると、すべてのリソースが削除されます。

**注意**: この操作は元に戻せません。実行前に必ずバックアップを取得してください。

## テスト環境向けHTTPS設定（自己署名証明書）

テスト環境でHTTPS通信を検証したい場合、自己署名証明書を生成してACMにインポートできます。

### ステップ1: 自己署名証明書の生成

```bash
cd examples/aws-ecs-fargate
./scripts/generate-cert.sh
```

このスクリプトは以下のファイルを`certs/`ディレクトリに生成します:
- `private-key.pem` - 2048ビットRSA秘密鍵
- `certificate.pem` - 自己署名証明書（有効期限365日）
- `certificate-chain.pem` - 証明書チェーン

**ドメイン名**: 証明書のCommon Name (CN)は`bridge.example.local`に設定されます。

**注**: 既存の証明書ファイルがある場合、上書き確認プロンプトが表示されます。自動テストやCI/CDで使用する場合は`-f`オプションを使用してください：
```bash
./scripts/generate-cert.sh -f  # 確認なしで上書き
```

### ステップ2: ACMへのインポート設定

`terraform.tfvars`で以下を設定:

```hcl
enable_acm_import = true  # 自己署名証明書をACMにインポート
# certificate_arn は不要（自動的にインポートされた証明書が使用されます）
```

### ステップ3: デプロイ

```bash
terraform apply
```

Terraformが自動的に証明書をACMにインポートし、ALBのHTTPSリスナーに設定します。

### 重要な注意事項

⚠️ **自己署名証明書は本番環境では使用しないでください**

- ブラウザでアクセスすると「この接続ではプライバシーが保護されません」という警告が表示されます
- curlコマンドでテストする場合は`-k`オプションを使用してください:
  ```bash
  curl -k https://[ALB_DNS]/ok
  ```
- 本番環境では必ず信頼されたCA（Certificate Authority）から発行された証明書を使用してください

### 既存の証明書ARNを使用する場合

自己署名証明書ではなく、既にACMにある証明書を使用する場合:

```hcl
enable_acm_import = false  # デフォルト
certificate_arn   = "arn:aws:acm:ap-northeast-1:123456789012:certificate/xxxxx"
```

## RDSデータベース付き環境のデプロイ

この例では、PostgreSQL RDSインスタンスをシードデータ付きでデプロイすることもできます。

### 前提条件

- **psqlクライアント**: データベース初期化に必要です
  ```bash
  # macOS
  brew install postgresql

  # Ubuntu/Debian
  sudo apt-get install postgresql-client

  # Amazon Linux 2
  sudo yum install postgresql
  ```

### ステップ1: RDS設定の有効化

`terraform.tfvars`で以下を設定:

```hcl
# RDSデプロイを有効化
enable_rds = true

# データベース認証情報（必須）
database_name     = "bridgedb"
database_username = "dbadmin"
database_password = "ChangeMe123!"  # 強力なパスワードを設定してください

# オプション: RDS設定のカスタマイズ
database_instance_class     = "db.t3.micro"
database_allocated_storage  = 20
database_engine_version     = "14.7"
```

**セキュリティ警告**:
- terraform.tfvarsに平文パスワードを保存するのは開発環境のみにしてください
- 本番環境ではAWS Secrets Managerまたは環境変数を使用してください
- terraform.tfvarsをGitにコミットしないでください（.gitignoreで除外されています）

### ステップ2: デプロイ

```bash
terraform apply
```

Terraformは以下を自動的に実行します:
1. RDS PostgreSQLインスタンスを作成
2. セキュリティグループでBridgeからの5432ポート接続を許可
3. データベース認証情報をAWS Secrets Managerに保存
4. `scripts/init.sql`スクリプトを実行してシードデータを投入

### ステップ3: シードデータの確認

デプロイ後、以下のコマンドでデータを確認できます:

```bash
# RDSエンドポイントを取得
RDS_ENDPOINT=$(terraform output -raw rds_address)

# psqlで接続
PGPASSWORD='ChangeMe123!' psql \
  -h $RDS_ENDPOINT \
  -U dbadmin \
  -d bridgedb \
  -c "SELECT * FROM users;"
```

### シードデータの内容

`scripts/init.sql`により、以下のテーブルとデータが自動作成されます:

**usersテーブル構造**:
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**サンプルレコード（5件）**:
- Alice Johnson (alice@example.com)
- Bob Smith (bob@example.com)
- Charlie Brown (charlie@example.com)
- Diana Prince (diana@example.com)
- Ethan Hunt (ethan@example.com)

### Bridgeからのデータベース接続

RDSインスタンスはプライベートサブネットに配置され、Bridgeのセキュリティグループからのみアクセス可能です。

**接続情報の取得**:
```bash
terraform output rds_endpoint  # ホスト名:ポート
terraform output rds_address   # ホスト名のみ
terraform output rds_port      # ポート番号
terraform output rds_database_name  # データベース名
```

**Bridge環境変数での設定例**:
```bash
DATABASE_URL=postgresql://dbadmin:ChangeMe123!@${RDS_ENDPOINT}/bridgedb
```

### RDSのカスタマイズ

`terraform.tfvars`でRDS設定を調整できます:

```hcl
# より大きなインスタンス
database_instance_class = "db.t3.small"

# より大きなストレージ
database_allocated_storage = 50

# 異なるPostgreSQLバージョン
database_engine_version = "15.3"
```

### シードデータのカスタマイズ

`scripts/init.sql`を編集して、独自のテーブルとデータを追加できます:

```sql
-- 追加のテーブル
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);

-- 追加のデータ
INSERT INTO products (name, price) VALUES
    ('Product A', 29.99),
    ('Product B', 49.99);
```

変更後、`terraform apply`を実行すると自動的に再実行されます（SQLファイルのハッシュが変更されたため）。

## トラブルシューティング

### タスクが起動しない

デフォルトでVPCエンドポイントを使用しているため、NAT Gatewayが不要です。タスクが起動しない場合は以下を確認してください：

1. **VPCエンドポイントの状態確認**（デフォルト構成の場合）：
   ```bash
   # VPCエンドポイントの一覧を取得
   terraform output vpc_endpoint_ecr_api_id
   terraform output vpc_endpoint_ecr_dkr_id
   terraform output vpc_endpoint_s3_id

   # エンドポイントの状態を確認
   aws ec2 describe-vpc-endpoints --vpc-endpoint-ids vpce-xxxxx
   ```
   - `State`が`available`であることを確認

2. **CloudWatch Logsでエラーメッセージを確認**：
   ```bash
   aws logs tail /ecs/basemachina-bridge --follow
   ```

3. **ECSサービスのイベントタブを確認**：
   ```bash
   aws ecs describe-services \
     --cluster prod-basemachina-bridge \
     --services prod-basemachina-bridge \
     --query 'services[0].events[0:5]'
   ```

4. **セキュリティグループのルールを確認**：
   - ALB → Bridge: ポート8080（またはカスタムポート）
   - Bridge → VPCエンドポイント: ポート443（HTTPS）
   - Bridge → Database: データベースポート（例: 5432）

5. **VPCエンドポイントを無効化してNAT Gatewayを使用する場合**：
   ```hcl
   # terraform.tfvars
   enable_vpc_endpoints = false
   ```
   この場合、プライベートサブネットにNAT Gatewayが必要です

### ALBヘルスチェックが失敗する

1. Bridgeコンテナが正常に起動しているか確認
2. `/ok`エンドポイントが応答しているか確認
3. ターゲットグループのヘルスチェック設定を確認

### 証明書エラー

1. ACM証明書が正しいリージョンにあるか確認
2. 証明書のステータスが「発行済み」であるか確認
3. 証明書ARNが正しいか確認

## 参考リンク

- [モジュールドキュメント](../../modules/aws/ecs-fargate/README.md)
- [AWS ECS Fargate ドキュメント](https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Terraform AWS Provider ドキュメント](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
