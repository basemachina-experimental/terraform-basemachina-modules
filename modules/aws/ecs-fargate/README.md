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
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | ACM certificate ARN for HTTPS listener | `string` | n/a | yes |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | CPU units for ECS task (256, 512, 1024, 2048, 4096) | `number` | `256` | no |
| <a name="input_database_port"></a> [database\_port](#input\_database\_port) | Database port (e.g., 5432 for PostgreSQL, 3306 for MySQL) | `number` | `5432` | no |
| <a name="input_database_security_group_id"></a> [database\_security\_group\_id](#input\_database\_security\_group\_id) | Security group ID of the database (optional) | `string` | `null` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Number of ECS tasks to run | `number` | `1` | no |
| <a name="input_fetch_interval"></a> [fetch\_interval](#input\_fetch\_interval) | Interval for fetching public keys (e.g., 1h, 30m) | `string` | `"1h"` | no |
| <a name="input_fetch_timeout"></a> [fetch\_timeout](#input\_fetch\_timeout) | Timeout for fetching public keys (e.g., 10s, 30s) | `string` | `"10s"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch Logs retention period (days) | `number` | `7` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Memory (MiB) for ECS task | `number` | `512` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | `""` | no |
| <a name="input_port"></a> [port](#input\_port) | Port number for Bridge container (cannot be 4321) | `number` | `8080` | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | List of private subnet IDs for ECS tasks | `list(string)` | n/a | yes |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | List of public subnet IDs for ALB | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_tenant_id"></a> [tenant\_id](#input\_tenant\_id) | Tenant ID for authentication | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where the resources will be created | `string` | n/a | yes |
<!-- END_TF_DOCS -->

## 出力値

<!-- BEGIN_TF_DOCS -->
| Name | Description |
|------|-------------|
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ALBのARN（リソース参照用） |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | ALBのDNS名（Route 53レコード作成用） |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | ALBセキュリティグループのID（通信ルール設定用） |
| <a name="output_bridge_security_group_id"></a> [bridge\_security\_group\_id](#output\_bridge\_security\_group\_id) | BridgeセキュリティグループのID（他リソースとの通信ルール設定用） |
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | CloudWatch Logsロググループ名（ログ確認用） |
| <a name="output_ecs_cluster_arn"></a> [ecs\_cluster\_arn](#output\_ecs\_cluster\_arn) | ECSクラスターARN（リソース参照用） |
| <a name="output_ecs_cluster_name"></a> [ecs\_cluster\_name](#output\_ecs\_cluster\_name) | ECSクラスター名（AWS CLIやモニタリング用） |
| <a name="output_ecs_service_name"></a> [ecs\_service\_name](#output\_ecs\_service\_name) | ECSサービス名（デプロイやスケーリング用） |
| <a name="output_task_execution_role_arn"></a> [task\_execution\_role\_arn](#output\_task\_execution\_role\_arn) | タスク実行ロールARN（権限管理用） |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | タスクロールARN（アプリケーション権限管理用） |
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
