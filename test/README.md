# Terratest Integration Tests

このディレクトリには、BaseMachina Terraform モジュールの統合テストが含まれています。

## 前提条件

### 1. Go 1.21以上

```bash
go version
```

### 2. AWS認証情報

テストを実行するには、AWS認証情報が必要です。以下のいずれかの方法で設定してください：

#### 環境変数

```bash
cp .env.example .env
# .envを編集して実際の値を設定
```

必須環境変数：
- `AWS_ACCESS_KEY_ID`: AWSアクセスキー
- `AWS_SECRET_ACCESS_KEY`: AWSシークレットキー
- `AWS_DEFAULT_REGION`: AWSリージョン（例: `ap-northeast-1`）
- `TEST_VPC_ID`: テスト用VPC ID
- `TEST_PRIVATE_SUBNET_IDS`: プライベートサブネットIDのカンマ区切りリスト（例: `subnet-xxx,subnet-yyy`）
- `TEST_PUBLIC_SUBNET_IDS`: パブリックサブネットIDのカンマ区切りリスト（例: `subnet-aaa,subnet-bbb`）
- `TEST_TENANT_ID`: BaseMachinaテナントID
- `TEST_BRIDGE_DOMAIN_NAME`: BridgeのFQDN（例: `bridge-test.example.com`）
- `TEST_ROUTE53_ZONE_ID`: Route53 Hosted Zone ID（例: `Z1234567890ABC`）
  - ACM証明書がDNS検証で自動発行されます
  - Route53にAレコードが自動作成されます

オプション環境変数（ネットワークアクセス構成）：
- `TEST_ENABLE_VPC_ENDPOINTS`: VPCエンドポイントを使用してPrivate ECR/S3/CloudWatch Logsにアクセス（デフォルト: `true`、推奨）
  - 未設定または`false`以外（デフォルト）: VPCエンドポイント有効（コスト効率的）
  - `false`: VPCエンドポイント無効（NAT Gatewayのみ使用）

**重要**: BaseMachina Bridgeイメージは**Public ECR (public.ecr.aws)** でホストされており、Public ECRはVPCエンドポイントをサポートしていません。したがって、**NAT Gatewayが必須**です。

**ネットワーク構成**:
- **デフォルト構成（推奨）**: VPCエンドポイント + NAT Gateway
  - VPCエンドポイント: Private ECR、S3、CloudWatch Logs用（コスト削減）
  - NAT Gateway: Public ECR (public.ecr.aws) 用（必須）
  - 必要なリソース: プライベートサブネット + NAT Gateway

- **NAT Gatewayのみ**: TEST_ENABLE_VPC_ENDPOINTS=false
  - すべてのインターネットアクセスにNAT Gatewayを使用
  - 必要なリソース: プライベートサブネット + NAT Gateway

オプション環境変数：
- `TEST_DESIRED_COUNT`: デプロイするECSタスク数（デフォルト: 1）

**注**: 以下のRDS関連環境変数はTerratestでは不要です（Bridge単体テストのため）：
- `TEST_DATABASE_USERNAME`
- `TEST_DATABASE_PASSWORD`

### 3. 必要なAWSリソース

テストを実行する前に、以下のリソースが必要です：

**必須構成（VPCエンドポイント + NAT Gateway）**：
- **VPC**: テスト用のVPC
- **プライベートサブネット**（複数AZ）: ECSタスク配置用
- **パブリックサブネット**（複数AZ）: ALB配置用、NAT Gateway配置用
- **NAT Gateway**: **必須**（各AZに推奨）
  - Public ECR (public.ecr.aws) からイメージをpullするために必要
  - プライベートサブネットのルートテーブルに0.0.0.0/0 → NAT Gatewayのルートが設定されていること
- **BaseMachinaテナントID**: Bridge設定用
- **環境変数設定**: デフォルト（VPCエンドポイント有効）
- **自動作成されるリソース**:
  - VPCエンドポイント: ECR API、ECR Docker、S3、CloudWatch Logs
  - これらはPrivate ECR用で、コスト削減に寄与

**NAT Gatewayのみ構成**：
- 上記と同じリソースが必要
- **環境変数設定**: `TEST_ENABLE_VPC_ENDPOINTS=false`
- VPCエンドポイントを作成せず、すべてNAT Gateway経由でアクセス

**Route53 Hosted Zone（必須）**：
- 既存のRoute53 Hosted Zone
- ドメイン名と一致するZone ID
- Route53への書き込み権限

Hosted Zoneがない場合は、以下のコマンドで作成できます：

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

**注**: Terratestでは、Bridge単体のHTTPS疎通確認のみを実施します。RDSインスタンスは作成せず、以下のRDS関連環境変数は不要です：
- `TEST_DATABASE_USERNAME`
- `TEST_DATABASE_PASSWORD`

### 4. terraform.tfvarsファイル

`examples/aws-ecs-fargate/terraform.tfvars`を作成してください：

```bash
cd examples/aws-ecs-fargate
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvarsを編集して実際の値を設定
```

## テストの実行

### すべてのテストを実行

```bash
cd test
go test -v ./aws -timeout 60m
```

### 特定のテストを実行

```bash
cd test
go test -v ./aws -run TestECSFargateModule -timeout 60m
```

## テストの内容

### TestECSFargateModule

このテストは以下を検証します：

1. **事前検証**
   - Route53 Hosted Zoneの存在確認

2. **モジュールのデプロイ成功**
   - `terraform init`と`terraform apply`が成功すること

3. **リソース作成**
   - ECS Cluster、Task Definition、Service
   - ALB (Application Load Balancer)
   - NAT Gateway（Bridge初期化用、必須）
   - VPC Endpoints (ECR, S3, CloudWatch Logs)（デフォルト構成）
   - ACM Certificate（DNS検証で自動発行、最大15分タイムアウト）
   - Route53 A Record（ALBへのエイリアス）

4. **出力値の確認**
   - すべての出力値（ALB、ECS、IAM等）が空でないこと

5. **ECSサービスの状態**
   - ECSサービスが`desired_count`の数のタスクを実行していること（最大5分待機）

6. **ALBヘルスチェック**
   - ALBのターゲットグループでヘルスチェックがhealthyであること（最大5分待機）

7. **HTTPS エンドポイントテスト**
   - `https://[DOMAIN]/ok`へのHTTPSリクエストが成功すること（DNS検証で発行されたACM証明書を使用）
   - HTTPステータスコード200が返されること
   - 最大10分間、10秒間隔でリトライを実行

8. **自動クリーンアップ**
   - テスト終了後に`terraform destroy`で自動的にリソースが削除されること
   - Route53レコード（A、CNAMEレコード）も自動削除

**注**: RDS接続テストはTerratestでは実施しません。Bridge単体のHTTPS疎通確認のみ行います。

## テストの流れ

1. **事前検証**: Route53 Hosted Zoneの存在確認
2. **初期化**: Terraformで環境を初期化
3. **リソース作成**:
   - ECS Cluster、Task Definition、Service
   - ALB (Application Load Balancer)
   - NAT Gateway（Bridge初期化用、必須）
   - VPC Endpoints (ECR, S3, CloudWatch Logs)（デフォルト構成）
   - ACM Certificate（DNS検証で自動発行）
   - Route53 A Record（ALBへのエイリアス）
4. **ヘルスチェック**:
   - ECSタスクの起動確認（最大5分待機）
   - ALBターゲットグループのヘルスチェック（最大5分待機）
   - HTTPS エンドポイントの疎通確認（最大10分待機）
5. **クリーンアップ**: terraform destroyでリソースを削除

## 実行時間

テストの実行には約15〜20分かかります：

- Route53検証: 30秒
- ACM証明書のDNS検証: 5〜10分（タイムアウト: 15分）
- Bridge初期化: 2〜5分
- その他のリソース作成: 5分
- Terraform destroy: 2〜3分

**注意**: ACM証明書のDNS検証が15分以内に完了しない場合、テストは失敗します。

## トラブルシューティング

### ACM証明書の検証が完了しない

DNS検証レコードが正しく作成されているか確認してください：

```bash
# 診断スクリプトを実行（推奨）
cd ../examples/aws-ecs-fargate
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

### ECSタスクが起動しない（0 running tasks）

デフォルトでVPCエンドポイントを使用しているため、通常は問題なく起動します。起動しない場合は以下を確認してください：

1. **VPCエンドポイントの作成状態を確認**（デフォルト構成の場合）：
   ```bash
   # ECR API エンドポイント
   aws ec2 describe-vpc-endpoints \
     --filters "Name=service-name,Values=com.amazonaws.ap-northeast-1.ecr.api" \
     --query 'VpcEndpoints[0].State'

   # ECR Docker エンドポイント
   aws ec2 describe-vpc-endpoints \
     --filters "Name=service-name,Values=com.amazonaws.ap-northeast-1.ecr.dkr" \
     --query 'VpcEndpoints[0].State'
   ```
   - `State`が`available`であること

2. **NAT Gatewayの設定を確認**（必須）：
   ```bash
   # プライベートサブネットのルートテーブルを確認
   aws ec2 describe-route-tables \
     --filters "Name=association.subnet-id,Values=subnet-xxxxx" \
     --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`]'
   ```
   - `NatGatewayId`が存在すれば正常

3. **ECSタスクのエラーログを確認**：
   テストログに`Stopped task reason`と`Container reason`が表示されます

**よくある原因**：
- VPCエンドポイントのセキュリティグループでHTTPS（443）通信が許可されていない
- プライベートサブネットのルートテーブルにS3ゲートウェイエンドポイントが設定されていない
- NAT Gatewayがプライベートサブネットのルートテーブルに設定されていない（**Public ECRアクセスに必須**）
- NAT Gatewayが存在しない（**Public ECRアクセスに必須**）

### テストがタイムアウトする

デフォルトのタイムアウトは60分です（DNS検証を考慮）。長い場合は`-timeout`フラグを調整してください：

```bash
go test -v ./aws -timeout 90m
```

### AWS認証エラー

```
Error: error configuring Terraform AWS Provider: no valid credential sources
```

AWS認証情報が正しく設定されているか確認してください。

### リソースが残る

テストが異常終了した場合、AWSリソースが残る可能性があります。手動でクリーンアップしてください：

```bash
cd examples/aws-ecs-fargate
terraform destroy
```

## CI/CD統合

GitHub ActionsなどのCI/CDパイプラインで実行する場合：

```yaml
- name: Run Terratest
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    AWS_DEFAULT_REGION: ap-northeast-1
    TEST_VPC_ID: ${{ secrets.TEST_VPC_ID }}
    TEST_PRIVATE_SUBNET_IDS: ${{ secrets.TEST_PRIVATE_SUBNET_IDS }}
    TEST_PUBLIC_SUBNET_IDS: ${{ secrets.TEST_PUBLIC_SUBNET_IDS }}
    TEST_TENANT_ID: ${{ secrets.TEST_TENANT_ID }}
    TEST_BRIDGE_DOMAIN_NAME: ${{ secrets.TEST_BRIDGE_DOMAIN_NAME }}
    TEST_ROUTE53_ZONE_ID: ${{ secrets.TEST_ROUTE53_ZONE_ID }}
  run: |
    cd test
    go test -v ./aws -timeout 60m
```

## 注意事項

1. **コスト**: テスト実行には以下のAWSリソースが作成されます：
   - NAT Gateway: 約$0.045/時間 + データ転送料（**必須**）
   - ALB: 約$0.0225/時間
   - ECS Fargate: vCPU/メモリ使用量に応じた課金
   - VPC Endpoints: 約$0.01/時間/エンドポイント（デフォルト構成）
   - Route53: クエリ数に応じた課金（Hosted Zoneは$0.50/月）

2. **並列実行**: 複数のテストを並列実行する場合、`TEST_BRIDGE_DOMAIN_NAME`にユニークな値を設定してください（例: `bridge-test-1.example.com`, `bridge-test-2.example.com`）

3. **Hosted Zoneの管理**: テストではHosted Zone自体は作成・削除しません。事前に作成し、テスト後も残しておいてください。Route53レコード（A、CNAMEレコード）は自動的にクリーンアップされます。

4. **証明書のキャッシュ**: DNS検証によるACM証明書は自動的に作成されますが、同じドメインで複数回テストを実行する場合、証明書の検証時間が短縮されることがあります。

5. **テストは並列実行可能**: `t.Parallel()`を使用しています

6. **テスト用のリソース**: 一意のプレフィックスが自動的に付与されます

7. **テスト失敗時**: ログを確認してトラブルシューティングを行ってください

## 参考資料

- [Terratest公式ドキュメント](https://terratest.gruntwork.io/)
- [AWS ECS Fargate料金](https://aws.amazon.com/jp/fargate/pricing/)
- [AWS Route53料金](https://aws.amazon.com/jp/route53/pricing/)
- [AWS Certificate Manager料金](https://aws.amazon.com/jp/certificate-manager/pricing/)
