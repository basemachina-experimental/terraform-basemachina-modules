# BaseMachina Bridge - AWS ECS Fargate Module

## モジュール概要

このTerraformモジュールは、BaseMachina Bridgeを AWS ECS Fargate 環境に自動的にデプロイします。BridgeはBaseMachinaからお客様のプライベートデータソース（RDS、内部API等）への安全なアクセスを実現する認証機能付きゲートウェイです。

### 主な機能

- **サーバーレスコンテナ実行**: ECS Fargateによるインフラ管理不要の運用
- **セキュアなネットワーク**: プライベートサブネット配置、IPホワイトリスト、HTTPS通信
- **自動ヘルスチェック**: ALBによる健全性監視とタスク自動復旧
- **ログ集約**: CloudWatch Logsによる一元的なログ管理
- **柔軟な設定**: 変数による環境変数、リソースサイズ、タグのカスタマイズ

## 使用方法

### 基本的な使用例

```hcl
module "bridge" {
  source = "../../modules/aws/ecs-fargate"

  # ネットワーク設定
  vpc_id             = "vpc-xxxxx"
  private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
  public_subnet_ids  = ["subnet-aaaaa", "subnet-bbbbb"]

  # SSL/TLS証明書
  certificate_arn = "arn:aws:acm:ap-northeast-1:123456789012:certificate/xxxxx"

  # Bridge環境変数
  tenant_id      = "your-tenant-id"
  fetch_interval = "1h"
  fetch_timeout  = "10s"
  port           = 8080

  # リソース設定
  cpu            = 256
  memory         = 512
  desired_count  = 1

  # タグ
  tags = {
    Environment = "production"
    Project     = "basemachina-bridge"
  }

  name_prefix = "prod"
}
```

## 要件

### Terraformバージョン

- Terraform: >= 1.0

### プロバイダー

- AWS Provider: ~> 5.0

### 前提条件

デプロイ前に、以下のリソースが既に存在している必要があります：

1. **VPC**: 既存のVPCとサブネット（パブリック・プライベート）
2. **NAT Gateway**: プライベートサブネットからのインターネットアクセス用
3. **ACM証明書**: HTTPS通信用のSSL/TLS証明書
4. **AWS認証情報**: Terraformを実行するためのIAM権限

詳細な前提条件については、[examples/aws-ecs-fargate/README.md](../../examples/aws-ecs-fargate/README.md) を参照してください。

## 入力変数

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docsで自動生成される予定 -->
<!-- END_TF_DOCS -->

## 出力値

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docsで自動生成される予定 -->
<!-- END_TF_DOCS -->

## 例

実際の使用例は [examples/aws-ecs-fargate/](../../examples/aws-ecs-fargate/) ディレクトリを参照してください。

## セキュリティベストプラクティス

### プライベートサブネット配置

Bridgeタスクは必ずプライベートサブネットに配置してください。これにより、インターネットからの直接アクセスを防止し、攻撃面を最小化します。

### IPホワイトリスト

ALBのセキュリティグループは、BaseMachinaのIPアドレス（34.85.43.93/32）からのアクセスのみを許可するように設定されています。この設定を維持してください。

### 機密情報の管理

テナントIDやその他の機密情報は、以下の方法で安全に管理してください：

- **AWS Secrets Manager**: 推奨される方法
- **Systems Manager Parameter Store**: 代替方法
- **Terraform変数の暗号化**: terraform.tfvarsファイルをGitにコミットしない

### HTTPS通信の強制

ALBはHTTPS（ポート443）のみを受け付けます。ACM証明書を使用してTLS 1.2以上で通信を暗号化します。

### CloudWatch Logsの監視

Bridgeコンテナのログは CloudWatch Logs（`/ecs/basemachina-bridge`）に集約されます。定期的にログを確認し、以下の監視を推奨します：

- エラーログのフィルタリングとアラート設定
- 認証失敗（401エラー）の監視
- ALBヘルスチェック失敗の検知

## ライセンス

このモジュールはBaseMachinaプロジェクトの一部です。
