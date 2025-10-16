# BaseMachina Bridge - AWS ECS Fargate デプロイ例

このディレクトリには、BaseMachina BridgeをAWS ECS Fargateにデプロイするための実装例が含まれています。

## 前提条件

デプロイを開始する前に、以下のリソースが準備されている必要があります。

### 1. VPCとサブネット

- **VPC**: 既存のVPCが必要です
- **プライベートサブネット**: Bridgeタスクを配置するため、複数のアベイラビリティゾーン（AZ）にまたがるプライベートサブネットが必要
- **パブリックサブネット**: ALBを配置するため、複数のAZにまたがるパブリックサブネットが必要
- **NAT Gateway**: プライベートサブネットからインターネットへアクセスするため、NAT Gatewayが各AZに設定されている必要があります

### 2. ACM証明書

- HTTPS通信用のSSL/TLS証明書がAWS Certificate Manager (ACM)で作成されている必要があります
- 証明書はデプロイ先のリージョンに存在する必要があります
- 証明書のARNが必要です

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

## トラブルシューティング

### タスクが起動しない

1. CloudWatch Logsでエラーメッセージを確認
2. ECSサービスのイベントタブを確認
3. セキュリティグループのルールを確認（ALB → Bridge、Bridge → Database）

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
