# 技術スタック

## アーキテクチャ

### システム全体の設計

このプロジェクトは、Infrastructure as Code（IaC）の原則に基づき、Terraformを使用してBaseMachina bridgeをマルチクラウド環境にデプロイします。

```
[BaseMachina] --HTTPS--> [Load Balancer] ---> [Bridge Container] ---> [Customer DB/API]
                            ↑                        ↑
                        Public DNS              Private Network
```

### 主要コンポーネント

1. **Terraformモジュール**: インフラストラクチャのプロビジョニング
2. **Bridgeコンテナ**: 認証ゲートウェイ（Go言語で実装）
3. **ロードバランサー**: HTTPS終端とルーティング
4. **コンテナランタイム**: AWS ECS Fargate / GCP Cloud Run

## インフラストラクチャ

### Terraform

- **バージョン**: >= 1.0（ECS Fargateモジュールで要求）
- **プロバイダー**:
  - AWS Provider: ~> 5.0（ECS Fargateモジュールで使用）
  - Google Cloud Provider（GCPモジュール用、予定）

### クラウドプラットフォーム

#### AWS（推奨環境: ECS Fargate）

- **コンテナオーケストレーション**: Amazon ECS Fargate
- **ロードバランサー**: Application Load Balancer (ALB)
- **証明書管理**: AWS Certificate Manager (ACM)
  - DNS検証による自動発行（Route53統合、推奨）
  - 自己署名証明書のインポート
  - 既存証明書の利用
- **DNS管理**: Amazon Route 53
  - ACM証明書のDNS検証レコード自動作成
  - BridgeエンドポイントのAレコード自動作成
- **コンテナレジストリ**: Amazon ECR Public（イメージ取得元）
- **IAM権限管理**: タスク実行ロール、タスクロール
- **ロギング**: Amazon CloudWatch Logs
- **ネットワーキング**: VPC、サブネット、セキュリティグループ、NAT Gateway（必須）
- **データベース**: Amazon RDS（接続先、exampleで使用）

#### Google Cloud（推奨環境: Cloud Run）

- **コンピューティング**: Cloud Run（フルマネージド）
- **ロードバランサー**: Cloud Load Balancing
- **DNS管理**: Cloud DNS
- **コンテナレジストリ**: GitHub Container Registry（イメージ取得元）
- **ネットワーキング**: VPC、Serverless VPC Access
- **データベース**: Cloud SQL（接続先）

### Bridgeコンテナイメージ

#### AWS用イメージ
```
public.ecr.aws/basemachina/bridge
```

#### GCP用イメージ
```
ghcr.io/basemachina/bridge
```

## 開発環境

### 必須ツール

- **Terraform CLI**: v1.0以上
- **AWS CLI**: AWSモジュール開発時（v2.x推奨）
- **Go**: v1.20以上（Terratest実行用）
- **gcloud CLI**: GCPモジュール開発時（予定）
- **Git**: バージョン管理

### 推奨ツール

- **tfenv**: Terraformバージョン管理
- **pre-commit**: コードフォーマットとリンティング
- **tflint**: Terraformリンター
- **tfsec**: セキュリティスキャン
- **terraform-docs**: ドキュメント自動生成
- **Terratest**: インフラストラクチャテストフレームワーク（Go）

### セットアップ手順

```bash
# Terraformのインストール確認
terraform version

# AWSクレデンシャルの設定（AWS環境の場合）
aws configure

# GCPクレデンシャルの設定（GCP環境の場合）
gcloud auth application-default login

# リポジトリのクローン
git clone https://github.com/basemachina/terraform-basemachina-modules.git
cd terraform-basemachina-modules
```

## 一般的なコマンド

### Terraformワークフロー

```bash
# 初期化（モジュールとプロバイダーのダウンロード）
terraform init

# フォーマットチェック
terraform fmt -check -recursive

# 構文検証
terraform validate

# 実行プランの確認
terraform plan

# インフラストラクチャのデプロイ
terraform apply

# インフラストラクチャの削除
terraform destroy

# ステート確認
terraform show
```

### モジュール開発

```bash
# ドキュメント生成
terraform-docs markdown table . > README.md

# リンティング
tflint

# セキュリティスキャン
tfsec .

# モジュールのテスト（Terratest）
cd test
go test -v ./aws -timeout 60m

# テスト実行に必要な環境変数
export TEST_VPC_ID="vpc-xxxxx"
export TEST_PRIVATE_SUBNET_IDS="subnet-xxxxx,subnet-yyyyy"
export TEST_PUBLIC_SUBNET_IDS="subnet-aaaaa,subnet-bbbbb"
export TEST_TENANT_ID="your-tenant-id"

# 証明書オプション（いずれか1つを選択）
# オプション1: DNS検証によるACM証明書発行（推奨）
export TEST_BRIDGE_DOMAIN_NAME="bridge-test.example.com"
export TEST_ROUTE53_ZONE_ID="Z1234567890ABC"

# オプション2: 自己署名証明書
export TEST_ENABLE_ACM_IMPORT="true"

# オプション3: 既存のACM証明書
export TEST_CERTIFICATE_ARN="arn:aws:acm:region:account:certificate/xxxxx"
```

## 環境変数

### Bridge実行時の環境変数

| 変数名 | 説明 | デフォルト | 必須 |
|--------|------|-----------|------|
| `FETCH_INTERVAL` | 認可処理に利用する公開鍵を更新する間隔（ns/us/ms/s/m/h） | - | Yes |
| `FETCH_TIMEOUT` | 認可処理に利用する公開鍵を更新するタイムアウト（ns/us/ms/s/m/h） | - | Yes |
| `PORT` | BridgeがHTTPでサーブするポート（文字列、4321以外） | `8080` | Yes |
| `TENANT_ID` | テナントID（指定されたテナントID以外からのリクエストを拒否） | - | Yes |

#### 設定例

```bash
export FETCH_INTERVAL=1h
export FETCH_TIMEOUT=10s
export PORT=8080
export TENANT_ID=your-tenant-id
```

### Terraform実行時の環境変数

```bash
# AWSクレデンシャル
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-northeast-1"

# GCPクレデンシャル
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
export GOOGLE_PROJECT="your-project-id"
```

## ポート設定

| サービス | ポート | プロトコル | 用途 |
|---------|--------|----------|------|
| Bridge Container | 8080（可変） | HTTP | アプリケーションサーバー |
| Load Balancer | 443 | HTTPS | 外部からのアクセス |
| Health Check | 8080 | HTTP | `/ok`エンドポイント |

## ネットワーク要件

### インバウンド

- **BaseMachinaからのアクセス**: IPアドレス `34.85.43.93` をホワイトリストに追加
- **HTTPS接続**: ロードバランサーのポート443で受け付け

### アウトバウンド

- **インターネットアクセス**: Bridgeから外部インターネットへの全アクセスを許可
  - BaseMachina APIから認証用公開鍵を取得するために必要
- **データベース接続**: プライベートネットワーク内のRDS/Cloud SQLへの接続

## セキュリティ考慮事項

### 認証・認可

- Bridgeは公開鍵を使った認証機能を実装
- テナントIDによるマルチテナント分離

### ネットワークセキュリティ

- HTTPS通信の強制
- IPホワイトリストによるアクセス制御
- プライベートサブネット内でのBridge配置（推奨）

### IAM権限管理

#### タスク実行ロール（Task Execution Role）

ECS Fargateがタスクを起動する際に必要な権限を提供します：

- **AmazonECSTaskExecutionRolePolicy**: 基本的なECS実行権限
- **AmazonEC2ContainerRegistryReadOnly**: ECR（パブリック/プライベート）からのイメージpull
- **CloudWatch Logsへの書き込み権限**: コンテナログの集約

#### タスクロール（Task Role）

Bridge コンテナ内のアプリケーションが AWS サービスにアクセスする際の権限を提供します（将来的な拡張用、現時点では最小権限）。

### 機密情報管理

- **AWS**: AWS Secrets Manager または Systems Manager Parameter Store
- **GCP**: Secret Manager
- Terraform変数として機密情報を直接コミットしないこと

## ユーティリティスクリプト

### examples/aws-ecs-fargate/scripts/

プロジェクトには以下のユーティリティスクリプトが含まれています：

#### generate-cert.sh
自己署名証明書を生成します（テスト環境用）。

```bash
./scripts/generate-cert.sh bridge-test.example.com
```

生成される証明書は`certs/`ディレクトリに保存されます。

#### diagnose-dns-validation.sh
ACM証明書のDNS検証問題を診断します。

```bash
./scripts/diagnose-dns-validation.sh bridge-test.example.com Z1234567890ABC
```

以下をチェックします：
- Route53 Hosted Zoneの存在
- DNS検証レコード（CNAME）の作成状態
- DNSの伝播状況

#### cleanup-failed-resources.sh
テスト失敗時に残ったリソースをクリーンアップします。

```bash
./scripts/cleanup-failed-resources.sh
```

#### init.sql
RDSデータベース初期化用のSQLスクリプト（example用）。

```sql
-- サンプルデータベースとテーブルを作成
```
