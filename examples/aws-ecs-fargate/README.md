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
  curl -k https://$(terraform output -raw alb_dns_name)/ok
  ```
- 本番環境では必ず信頼されたCA（Certificate Authority）から発行された証明書を使用してください

### 既存の証明書ARNを使用する場合

自己署名証明書ではなく、既にACMにある証明書を使用する場合:

```hcl
enable_acm_import = false  # デフォルト
certificate_arn   = "arn:aws:acm:ap-northeast-1:123456789012:certificate/xxxxx"
```

## カスタムドメインとACM証明書の自動発行（推奨）

動作確認で信頼された証明書が必要な場合、カスタムドメインを設定してACM証明書をDNS検証で自動発行できます。

### 概要

以下が自動的に構成されます:
- **ACM証明書**: DNS検証による信頼された証明書の自動発行
- **DNS検証レコード**: 既存のRoute53 Hosted Zoneに自動作成
- **ALBドメイン紐付け**: 指定したドメインでBridgeにアクセス可能

### 前提条件

- Route53 Hosted Zoneを事前に作成済み
- ドメインを取得済み（Route53、お名前.com、Square Space、GoDaddy、Namecheap等）

### ステップ1: Route53 Hosted Zoneの準備

既にHosted Zoneがある場合はスキップしてください。

```bash
# 新しいHosted Zoneを作成
aws route53 create-hosted-zone \
  --name example.com \
  --caller-reference $(date +%s)

# Zone IDを確認
aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='example.com.'].Id" \
  --output text
```

**外部レジストラでドメインを取得している場合**:

1. 上記コマンドで作成されたHosted Zoneのネームサーバーを取得:
   ```bash
   aws route53 get-hosted-zone --id Z1234567890ABC \
     --query "DelegationSet.NameServers"
   ```

2. 外部レジストラ（お名前.com、Squarespace等）でネームサーバーをRoute53のNSに変更

3. DNS伝播を待つ（最大48時間、通常は数時間）

### ステップ2: terraform.tfvarsで設定

```hcl
# ドメイン設定（必須）
bridge_domain_name = "bridge.example.com"
route53_zone_id    = "Z1234567890ABC"  # ステップ1で取得したZone ID

# 他の必須設定
vpc_id             = "vpc-xxxxx"
private_subnet_ids = ["subnet-xxx", "subnet-yyy"]
public_subnet_ids  = ["subnet-aaa", "subnet-bbb"]
tenant_id          = "your-tenant-id"
```

### ステップ3: デプロイ

```bash
terraform apply
```

デプロイ完了後、ACM証明書のDNS検証レコードとALBへのAレコードが自動的にRoute53に作成されます。
証明書の検証は通常5-10分で完了します。

### ステップ4: 検証完了の確認

```bash
# 証明書ステータスを確認
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw certificate_arn) \
  --query 'Certificate.Status'

# 出力: "ISSUED" になれば完了
```

### ステップ5: Bridgeにアクセス

```bash
# BridgeのURLを取得
terraform output bridge_url

# アクセステスト
curl https://bridge.example.com/ok
```

### メリット

- **信頼された証明書**: Let's Encryptスタイルの自動DNS検証
- **証明書エラーなし**: ブラウザ・ライブラリで警告が出ない
- **自動更新**: ACMが証明書を自動的に更新
- **本番環境と同じ**: HTTPS環境で正確にテスト可能
- **完全自動化**: DNS検証レコードとALBレコードが自動作成

### コスト

- Route53 Hosted Zone: 約$0.50/月
- ACM証明書: 無料
- DNS クエリ料金: 最初の10億クエリで $0.40

## RDSデータベース付き環境のデプロイ

この例には、PostgreSQL RDSインスタンスとBridgeからの接続設定が含まれています。

### 概要

`rds.tf`により、以下が自動的に構成されます:
- **RDS PostgreSQLインスタンス**: プライベートサブネットに配置
- **セキュリティグループ**: Bridgeからの5432ポート接続を許可
- **Secrets Manager**: データベース認証情報を安全に保存

**重要**: RDSインスタンスはプライベートサブネット内にあるため、ローカル環境から直接アクセスできません。データベース初期化（`scripts/init.sql`の実行）は手動で行う必要があります（後述）。

### ステップ1: デプロイ

通常通り`terraform apply`を実行するだけで、RDSインスタンスも自動的に作成されます:

```bash
terraform apply
```

**自動構成される内容**:
- RDS PostgreSQL 15.14インスタンス（db.t3.micro）
- ランダム生成された32文字のマスターパスワード
- データベース名: `bridge_example`
- ユーザー名: `postgres`
- 暗号化ストレージ（20GB、最大100GBまで自動拡張）
- 7日間のバックアップ保持
- Enhanced Monitoring有効
- Performance Insights有効

**セキュリティ**:
- パスワードはTerraformによりランダム生成されます
- 認証情報はAWS Secrets Managerに自動保存されます
- RDSインスタンスはプライベートサブネットに配置され、インターネットからアクセスできません

### ステップ2: Bastionホストの準備

このexampleでは、Bastionホストが自動的に作成されます（`enable_bastion = true`）。BastionホストはパブリックサブネットにEC2インスタンス（Amazon Linux 2023 t3.micro）が起動され、PostgreSQL 15クライアントがプリインストールされています。

#### オプションA: SSH公開鍵を使用する場合（推奨）

1. SSH鍵ペアを生成（まだない場合）:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/bastion-key -N ""
```

2. `terraform.tfvars`に公開鍵を設定:

```hcl
bastion_ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQD..."  # ~/.ssh/bastion-key.pub の内容
bastion_allowed_ssh_cidrs = ["YOUR_IP/32"]  # あなたのIPアドレスのみ許可（セキュリティ向上）
```

3. デプロイ後、SSH接続:

```bash
# BastionホストのパブリックIPを取得
BASTION_IP=$(terraform output -raw bastion_public_ip)

# SSH接続
ssh -i ~/.ssh/bastion-key ec2-user@$BASTION_IP
```

#### オプションB: AWS Systems Manager Session Manager経由（SSH鍵不要）

SSH鍵を設定せず、Session Manager経由でアクセスすることも可能です:

```bash
# BastionホストのインスタンスIDを取得
BASTION_ID=$(terraform output -raw bastion_instance_id)

# Session Manager経由で接続
aws ssm start-session --target $BASTION_ID
```

**利点**:
- SSH鍵の管理が不要
- インバウンドポート22を開放する必要がない
- CloudTrailでアクセスログが記録される

### ステップ3: データベース初期化

Bastionホストから`scripts/init.sql`を実行してRDSを初期化します:

```bash
# 1. Bastionホストに接続（SSH または Session Manager）
ssh -i ~/.ssh/bastion-key ec2-user@$(terraform output -raw bastion_public_ip)
# または
aws ssm start-session --target $(terraform output -raw bastion_instance_id)

# 2. ローカル環境でSecrets Managerから認証情報を取得
SECRET_ARN=$(terraform output -raw rds_credentials_secret_arn)
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query 'SecretString' --output text | jq -r '.password')

# RDSエンドポイントを取得
RDS_ADDRESS=$(terraform output -raw rds_address)

# 3. init.sqlの内容をBastionホストに渡す
cat scripts/init.sql | ssh -i ~/.ssh/bastion-key ec2-user@$(terraform output -raw bastion_public_ip) \
  "PGPASSWORD='$DB_PASSWORD' psql -h $RDS_ADDRESS -U postgres -d bridge_example"
```

### ステップ3: シードデータの確認

デプロイ後、以下のコマンドでデータを確認できます:

```bash
ssh -i ~/.ssh/bastion-key ec2-user@$(terraform output -raw bastion_public_ip) \
  "PGPASSWORD='$DB_PASSWORD' psql -h $RDS_ADDRESS -U postgres -d bridge_example -c 'SELECT * FROM users;'";
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

**Bridgeアプリケーションからの接続**:

接続文字列はSecrets Managerに保存されています:

```bash
# 接続文字列を取得
aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query 'SecretString' --output text | jq -r '.connection_string'

# 出力例:
# postgresql://postgres:RandomPassword@hostname.rds.amazonaws.com:5432/bridge_example
```

### シードデータのカスタマイズ

`scripts/init.sql`を編集して、独自のテーブルとデータを追加できます。現在のスクリプトは5人のユーザーを作成します。

変更後は以下のコマンドで手動で再実行できます:

```bash
PGPASSWORD="$DB_PASSWORD" psql \
  -h "$RDS_ADDRESS" \
  -U postgres \
  -d bridge_example \
  -f scripts/init.sql
```

### RDSリソースの削除

RDSインスタンスは`terraform destroy`で自動的に削除されます。テスト環境のため、削除保護は無効になっており、最終スナップショットもスキップされます。

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
