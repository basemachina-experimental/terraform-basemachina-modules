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

オプション環境変数（証明書設定）：
- `TEST_CERTIFICATE_ARN`: 既存のACM証明書ARN（設定された場合、その証明書を使用します）
- `TEST_ENABLE_ACM_IMPORT`: 自己署名証明書を生成してACMにインポートする場合は`true`に設定（推奨）
- 証明書を使用しない場合: 上記2つとも未設定にしてください（HTTPリスナーが使用されます）

その他のオプション環境変数：
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

**証明書オプション（3つのうち1つを選択）**：
1. **自己署名証明書（推奨）**: `TEST_ENABLE_ACM_IMPORT=true`を設定（テストが自動生成してACMにインポート）
2. **既存のACM証明書**: `TEST_CERTIFICATE_ARN`に証明書ARNを設定
3. **証明書なし**: 両方とも未設定（HTTPリスナーのみ、HTTPS検証はスキップ）

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
go test -v ./aws -timeout 30m
```

### 特定のテストを実行

```bash
cd test
go test -v ./aws -run TestECSFargateModule -timeout 30m
```

## テストの内容

### TestECSFargateModule

このテストは以下を検証します：

1. **モジュールのデプロイ成功**
   - `terraform init`と`terraform apply`が成功すること

2. **出力値の確認**
   - すべての出力値（ALB、ECS、IAM等）が空でないこと

3. **ECSサービスの状態**
   - ECSサービスが`desired_count`の数のタスクを実行していること

4. **ALBヘルスチェック**
   - ALBのターゲットグループでヘルスチェックがhealthyであること

5. **HTTPS エンドポイントテスト**（証明書ARNが提供された場合のみ）
   - `https://[ALB_DNS]/ok`へのHTTPSリクエストが成功すること
   - HTTPステータスコード200が返されること
   - 自己署名証明書に対応するためTLS検証をスキップ（`InsecureSkipVerify: true`）
   - 最大5分間、10秒間隔でリトライを実行

6. **自動クリーンアップ**
   - テスト終了後に`terraform destroy`で自動的にリソースが削除されること

**注**: RDS接続テストはTerratestでは実施しません。Bridge単体のHTTPS疎通確認のみ行います。

## 実行時間

テストの実行には約10〜15分かかります：
- Terraform apply: 5〜7分
- ヘルスチェック待機: 3〜5分
- Terraform destroy: 2〜3分

## トラブルシューティング

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

2. **NAT Gateway構成を使用している場合**（`TEST_USE_NAT_GATEWAY=true`）：
   ```bash
   # プライベートサブネットのルートテーブルを確認
   aws ec2 describe-route-tables \
     --filters "Name=association.subnet-id,Values=subnet-xxxxx" \
     --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`]'
   ```
   - `NatGatewayId`が存在すれば正常

3. **一時的にパブリックサブネット構成でテスト**：
   ```bash
   export TEST_USE_NAT_GATEWAY=false
   export TEST_ENABLE_VPC_ENDPOINTS=false
   go test -v ./aws -run TestECSFargateModule -timeout 30m
   ```

4. **ECSタスクのエラーログを確認**：
   テストログに`Stopped task reason`と`Container reason`が表示されます

**よくある原因**：
- VPCエンドポイントのセキュリティグループでHTTPS（443）通信が許可されていない
- プライベートサブネットのルートテーブルにS3ゲートウェイエンドポイントが設定されていない
- NAT Gateway構成の場合: NAT Gatewayがプライベートサブネットのルートテーブルに設定されていない

### テストがタイムアウトする

デフォルトのタイムアウトは30分です。長い場合は`-timeout`フラグを調整してください：

```bash
go test -v ./aws -timeout 45m
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
  run: |
    cd test
    go test -v ./aws -timeout 30m
```

## 注意事項

- テストは実際のAWSリソースを作成するため、**コストが発生します**
- テストは並列実行可能です（`t.Parallel()`を使用）
- テスト用のリソースには一意のプレフィックスが自動的に付与されます
- テスト失敗時はログを確認してトラブルシューティングを行ってください
