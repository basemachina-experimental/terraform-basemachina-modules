# AWS ECS Fargate Module Test

このディレクトリには、AWS ECS Fargateモジュールの統合テストが含まれています。

## 前提条件

### 1. AWS環境の準備

テストを実行する前に、以下のAWSリソースを準備してください：

- **VPC**: 既存のVPC（パブリック・プライベートサブネット付き）
- **Route53 Hosted Zone**: ドメイン管理用の既存のHosted Zone

### 2. Route53 Hosted Zoneの作成

まだHosted Zoneがない場合は、以下のコマンドで作成してください：

```bash
# Hosted Zoneを作成
aws route53 create-hosted-zone \
  --name example.com \
  --caller-reference $(date +%s)

# Zone IDを確認
aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='example.com.'].Id" \
  --output text
```

出力例: `Z1234567890ABC`

## 環境変数の設定

テストを実行する前に、以下の環境変数を設定してください：

### 必須の環境変数

```bash
# AWSクレデンシャル
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="ap-northeast-1"

# ネットワーク設定
export TEST_VPC_ID="vpc-xxxxx"
export TEST_PRIVATE_SUBNET_IDS="subnet-xxxxx,subnet-yyyyy"
export TEST_PUBLIC_SUBNET_IDS="subnet-aaaaa,subnet-bbbbb"

# BaseMachina設定
export TEST_TENANT_ID="your-tenant-id"

# ドメイン設定（必須）
export TEST_BRIDGE_DOMAIN_NAME="bridge-test.example.com"
export TEST_ROUTE53_ZONE_ID="Z1234567890ABC"
```

### オプションの環境変数

```bash
# タスク数（デフォルト: 1）
export TEST_DESIRED_COUNT="1"
```

## テストの実行

### すべてのテストを実行

```bash
cd test/aws
go test -v -timeout 60m
```

### 特定のテストを実行

```bash
cd test/aws
go test -v -timeout 60m -run TestECSFargateModule
```

## テストの流れ

1. **事前検証**: Route53 Hosted Zoneの存在確認
2. **初期化**: Terraformで環境を初期化
3. **リソース作成**:
   - ECS Cluster、Task Definition、Service
   - ALB (Application Load Balancer)
   - NAT Gateway（Bridge初期化用）
   - VPC Endpoints (ECR, S3, CloudWatch Logs)
   - ACM Certificate（DNS検証で自動発行、最大15分タイムアウト）
   - Route53 A Record（ALBへのエイリアス）
4. **ヘルスチェック**:
   - ECSタスクの起動確認（最大5分待機）
   - ALBターゲットグループのヘルスチェック（最大5分待機）
   - HTTPS エンドポイントの疎通確認（最大10分待機）
5. **クリーンアップ**: terraform destroyでリソースを削除

## テスト所要時間

- **初回実行**: 約15-20分
  - Route53検証: 30秒
  - ACM証明書のDNS検証: 5-10分（タイムアウト: 15分）
  - Bridge初期化: 2-5分
  - その他のリソース作成: 5分
- **2回目以降**: 約10-15分（証明書が再利用される場合）

**注意**: ACM証明書のDNS検証が15分以内に完了しない場合、テストは失敗します。

## トラブルシューティング

### ACM証明書の検証が完了しない

DNS検証レコードが正しく作成されているか確認してください：

```bash
# 診断スクリプトを実行（推奨）
cd ../../examples/aws-ecs-fargate
./scripts/diagnose-dns-validation.sh $TEST_BRIDGE_DOMAIN_NAME $TEST_ROUTE53_ZONE_ID

# または手動で確認
# ACM証明書のステータス確認
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:REGION:ACCOUNT:certificate/CERT_ID \
  --query 'Certificate.Status'

# Route53のレコード確認
aws route53 list-resource-record-sets \
  --hosted-zone-id $TEST_ROUTE53_ZONE_ID \
  --query "ResourceRecordSets[?Type=='CNAME']"

# DNS検証レコードの確認
dig _acm-challenge.$TEST_BRIDGE_DOMAIN_NAME CNAME
```

**よくある原因**:
1. **Zone IDが間違っている**: ドメイン名と一致するZone IDか確認
2. **ドメインが別のZoneに属している**: `aws.bm-tftest.com`は`bm-tftest.com`のZoneが必要
3. **DNSの伝播待ち**: 初回は5-10分、通常は1-2分必要
4. **権限不足**: Route53への書き込み権限を確認

### ECSタスクが起動しない

ネットワーク設定を確認してください：

```bash
# プライベートサブネットのルートテーブル確認
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=subnet-xxxxx"

# NAT Gatewayのステータス確認
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$TEST_VPC_ID"
```

### テスト環境のクリーンアップ

テストが失敗した場合、手動でクリーンアップが必要な場合があります：

```bash
cd test/aws
terraform destroy -auto-approve \
  -var="name_prefix=test-UNIQUE_ID" \
  -var="vpc_id=$TEST_VPC_ID" \
  -var="private_subnet_ids=[\"subnet-xxxxx\"]" \
  -var="public_subnet_ids=[\"subnet-aaaaa\"]" \
  -var="tenant_id=$TEST_TENANT_ID" \
  -var="bridge_domain_name=$TEST_BRIDGE_DOMAIN_NAME" \
  -var="route53_zone_id=$TEST_ROUTE53_ZONE_ID"
```

## 注意事項

1. **コスト**: テスト実行には以下のAWSリソースが作成されます：
   - NAT Gateway: 約$0.045/時間 + データ転送料
   - ALB: 約$0.0225/時間
   - ECS Fargate: vCPU/メモリ使用量に応じた課金
   - Route53: クエリ数に応じた課金（Hosted Zoneは$0.50/月）

2. **並列実行**: 複数のテストを並列実行する場合、`TEST_BRIDGE_DOMAIN_NAME`にユニークな値を設定してください（例: `bridge-test-1.example.com`, `bridge-test-2.example.com`）

3. **Hosted Zoneの管理**: テストではHosted Zone自体は作成・削除しません。事前に作成し、テスト後も残しておいてください。Route53レコード（A、CNAMEレコード）は自動的にクリーンアップされます。

4. **証明書のキャッシュ**: ACM証明書は自動的に作成されますが、同じドメインで複数回テストを実行する場合、証明書の検証時間が短縮されることがあります。

## 参考資料

- [Terratest公式ドキュメント](https://terratest.gruntwork.io/)
- [AWS ECS Fargate料金](https://aws.amazon.com/jp/fargate/pricing/)
- [AWS Route53料金](https://aws.amazon.com/jp/route53/pricing/)
