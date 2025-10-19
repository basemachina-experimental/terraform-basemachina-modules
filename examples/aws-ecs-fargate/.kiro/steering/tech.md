# Technology Stack

## Architecture

### Overall Architecture
```
インターネット
    ↓
Application Load Balancer (パブリックサブネット)
    ↓ HTTPS
ECS Fargate タスク (プライベートサブネット)
    ↓ TCP 5432
RDS PostgreSQL (プライベートサブネット)
    ↓
VPCエンドポイント (ECR API, ECR Docker, S3, CloudWatch Logs)
    ↓
NAT Gateway (オプション、Bridge初期化用)
```

### Infrastructure as Code
- **Terraform**: v1.0以上
- **プロバイダー**:
  - AWS Provider: ~> 5.0
  - Null Provider: ~> 3.0
  - Random Provider: ~> 3.0

### AWS Services

#### Compute
- **Amazon ECS Fargate**: サーバーレスコンテナ実行
  - タスクCPU: 256-4096 CPU units
  - タスクメモリ: 512-30720 MB
  - ネットワークモード: awsvpc

#### Networking
- **Application Load Balancer (ALB)**: HTTPS終端とルーティング
  - セキュリティポリシー: ELBSecurityPolicy-TLS13-1-2-2021-06
  - ターゲットタイプ: ip（Fargate対応）
- **VPC Endpoints**:
  - ECR API (Interface): コンテナイメージメタデータ
  - ECR Docker (Interface): イメージレイヤー取得
  - S3 (Gateway): ECRストレージアクセス（無料）
  - CloudWatch Logs (Interface): ログ送信
- **NAT Gateway**: プライベートサブネットからのインターネットアクセス
  - Elastic IP付き
  - Bridge初期化に必要

#### Database
- **Amazon RDS PostgreSQL**: 15.14
  - インスタンスクラス: db.t3.micro（デフォルト）
  - ストレージ: gp3, 暗号化有効
  - バックアップ: 7日間保持
  - Enhanced Monitoring: 60秒間隔
  - Performance Insights: 有効

#### Security & IAM
- **AWS Secrets Manager**: RDS認証情報管理
- **AWS Certificate Manager (ACM)**: TLS/SSL証明書管理
- **Security Groups**:
  - ALB: HTTPS (443) インバウンド
  - Bridge: ALBから8080ポートインバウンド
  - RDS: Bridgeから5432ポートインバウンド
  - VPC Endpoints: Bridgeから443ポートインバウンド
- **IAM Roles**:
  - Task Execution Role: ECR/CloudWatch Logsアクセス
  - Task Role: アプリケーション権限
  - RDS Monitoring Role: Enhanced Monitoring

#### Monitoring & Logging
- **CloudWatch Logs**: ECSタスクログ
  - 保持期間: 7日（デフォルト、カスタマイズ可能）
- **CloudWatch Metrics**: ECS/RDSメトリクス

#### Container Registry
- **Amazon ECR**:
  - Pull Through Cache: Public ECRイメージのキャッシュ
  - プライベートリポジトリ: `ecr-public/basemachina/bridge`

## Development Environment

### Required Tools
```bash
# Terraform
terraform version
# Terraform v1.0+

# AWS CLI
aws --version
# aws-cli/2.x

# Go (テスト実行用)
go version
# go version go1.21+

# PostgreSQL Client (RDS初期化用、オプション)
psql --version
# psql (PostgreSQL) 15.x
```

### Optional Tools
```bash
# jq (JSON処理)
jq --version

# tfsec (Terraformセキュリティスキャン)
tfsec --version

# terraform-docs (ドキュメント生成)
terraform-docs --version
```

## Common Commands

### Terraform Operations
```bash
# 初期化
terraform init

# フォーマット
terraform fmt -recursive

# バリデーション
terraform validate

# プラン確認
terraform plan

# デプロイ
terraform apply

# 削除
terraform destroy

# 出力値取得
terraform output
terraform output -json
terraform output -raw rds_address
```

### Testing
```bash
# テスト実行（要: AWS認証情報と環境変数）
cd test/aws
go test -v -timeout 30m

# 特定のテスト実行
go test -v -timeout 30m -run TestECSFargateModule
```

### AWS CLI Operations
```bash
# ECSサービス確認
aws ecs describe-services \
  --cluster <cluster-name> \
  --services <service-name>

# タスク一覧
aws ecs list-tasks \
  --cluster <cluster-name> \
  --service-name <service-name>

# ログ確認
aws logs tail /ecs/<log-group-name> --follow

# Secrets Manager から認証情報取得
aws secretsmanager get-secret-value \
  --secret-id <secret-arn> \
  --query 'SecretString' --output text

# RDS接続
PGPASSWORD='<password>' psql \
  -h <rds-endpoint> \
  -U postgres \
  -d bridge_example
```

## Environment Variables

### Terraform Variables (terraform.tfvars)
```hcl
# 必須
vpc_id             = "vpc-xxxxx"
private_subnet_ids = ["subnet-xxx", "subnet-yyy"]
public_subnet_ids  = ["subnet-aaa", "subnet-bbb"]
tenant_id          = "your-tenant-id"

# オプション（証明書）
certificate_arn    = "arn:aws:acm:..."  # 本番環境
enable_acm_import  = true                # テスト環境

# オプション（リソース設定）
cpu                = 256
memory             = 512
desired_count      = 1
log_retention_days = 7

# オプション（NAT Gateway）
nat_gateway_id     = null  # 既存を使う場合

# オプション（セキュリティ）
additional_alb_ingress_cidrs = ["0.0.0.0/0"]  # テスト環境のみ

# オプション（タグ）
tags = {
  Environment = "production"
  Project     = "basemachina-bridge"
  ManagedBy   = "terraform"
}
```

### Test Environment Variables
```bash
# AWS認証
export AWS_ACCESS_KEY_ID="xxx"
export AWS_SECRET_ACCESS_KEY="xxx"
export AWS_DEFAULT_REGION="ap-northeast-1"

# テスト設定（必須）
export TEST_VPC_ID="vpc-xxxxx"
export TEST_PRIVATE_SUBNET_IDS="subnet-xxx,subnet-yyy"
export TEST_PUBLIC_SUBNET_IDS="subnet-aaa,subnet-bbb"
export TEST_TENANT_ID="your-tenant-id"

# テスト設定（オプション）
export TEST_CERTIFICATE_ARN="arn:aws:acm:..."
export TEST_ENABLE_ACM_IMPORT="true"
export TEST_DESIRED_COUNT="1"
export TEST_ADDITIONAL_CIDRS="0.0.0.0/0"
```

### Bridge Application Environment Variables
```bash
# Bridge設定（ECSタスク定義内で設定）
TENANT_ID="your-tenant-id"
FETCH_INTERVAL="1h"
FETCH_TIMEOUT="10s"
PORT="8080"
```

## Port Configuration

### Standard Ports
- **443 (HTTPS)**: ALB リスナー
- **8080 (HTTP)**: Bridge コンテナ（デフォルト、カスタマイズ可能）
  - 注意: ポート4321は使用禁止
- **5432 (PostgreSQL)**: RDS インスタンス

### Security Group Rules
```
ALB Security Group:
  Ingress: 443 from 34.85.43.93/32 (BaseMachina)
  Ingress: 443 from additional_alb_ingress_cidrs (テスト環境)
  Egress: All

Bridge Security Group:
  Ingress: 8080 from ALB Security Group
  Egress: All

RDS Security Group:
  Ingress: 5432 from Bridge Security Group
  Egress: All

VPC Endpoints Security Group:
  Ingress: 443 from Bridge Security Group
  Egress: All
```

## Architecture Decisions

### Why ECS Fargate?
- サーバーレス: EC2インスタンス管理不要
- 小規模デプロイに最適: コスト効率が良い
- セキュリティ: タスクレベルのネットワーク分離

### Why VPC Endpoints?
- コスト削減: NAT Gateway不要（約$32/月削減）
- セキュリティ: トラフィックがインターネットを経由しない
- パフォーマンス: AWSバックボーン経由で高速

### Why ECR Pull Through Cache?
- シンプル: Public ECRイメージを自動キャッシュ
- 信頼性: Private ECR経由で安定したイメージ取得
- 完全プライベート: ECSタスクはインターネット接続不要

### Why NAT Gateway (Bridge初期化用)?
- 必須要件: BridgeがBaseMachina認証サーバーにアクセス必要
- VPCエンドポイント対象外: 外部サービスのためVPCエンドポイント不可
- 限定的使用: 初期化時のみ、通常運用では使用しない

### Why PostgreSQL 15.14?
- 安定性: 実績のあるバージョン
- パフォーマンス: 最新機能とパフォーマンス改善
- サポート: AWS RDSでサポートされているPostgreSQL 15系の最新バージョン
