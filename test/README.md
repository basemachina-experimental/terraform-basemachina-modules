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

### 3. 必要なAWSリソース

テストを実行する前に、以下のリソースが必要です：

- VPC
- プライベートサブネット（複数AZ）
- パブリックサブネット（複数AZ）
- ACM証明書
- BaseMachinaテナントID

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

5. **自動クリーンアップ**
   - テスト終了後に`terraform destroy`で自動的にリソースが削除されること

## 実行時間

テストの実行には約10〜15分かかります：
- Terraform apply: 5〜7分
- ヘルスチェック待機: 3〜5分
- Terraform destroy: 2〜3分

## トラブルシューティング

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
