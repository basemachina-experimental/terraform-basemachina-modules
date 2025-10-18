# 実装計画

## Overview

ECS Fargateモジュールのexampleとテストを実践的に強化するための実装計画です。ユーザーの指示により、まず手順が少ない`test/aws/ecs_fargate_test.go`のHTTPS検証強化から開始し、その後exampleの拡張（証明書生成、RDS追加、ドキュメント強化）を行います。

## Implementation Tasks

- [x] 1. Terratest統合テストにHTTPS検証機能を追加する
- [x] 1.1 TerratestにHTTPSヘルスチェック検証関数を実装する
  - ALB DNSエンドポイントからHTTPS URLを構築する機能を追加する
  - TLS証明書検証をスキップするHTTPクライアント（自己署名証明書対応）を作成する
  - `/ok`エンドポイントへのHTTP GETリクエストを送信する機能を実装する
  - HTTPステータスコード200の検証ロジックを追加する
  - 最大5分間、10秒間隔でリトライする仕組みを実装する
  - リクエストURL、レスポンスステータス、レスポンスタイム、リトライ回数をログに記録する
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

- [x] 1.2 Terratestメイン関数からHTTPS検証を呼び出す
  - メインテスト関数から新しいHTTPS検証関数を呼び出すロジックを追加する
  - `enable_rds = false`変数を設定し、RDSインスタンスを作成しないようにする
  - テスト実行時にRDS関連リソースを除外する構成を確認する
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 1.3 テストドキュメントと環境変数設定を更新する
  - test/README.mdにHTTPSテスト用環境変数をドキュメント化する
  - RDS環境変数が不要であることを明記する
  - test/.env.exampleファイルを更新し、環境変数設定例を提供する（RDS変数を含めない）
  - 環境変数が未設定の場合のエラーメッセージを実装する（既存のmustGetenv関数で対応済み）
  - _Requirements: 6.1, 6.2, 6.3, 6.6, 4.4_

- [x] 2. 自己署名証明書生成スクリプトを実装する
- [x] 2.1 証明書生成シェルスクリプトを作成する
  - examples/aws-ecs-fargate/scripts/generate-cert.shを作成する
  - OpenSSLを使用して2048ビットRSA鍵ペアを生成する機能を実装する
  - 有効期限365日の自己署名証明書を生成する機能を実装する
  - Common Name（CN）に`bridge.example.local`を設定する
  - 既存ファイルがある場合の上書き確認プロンプトを実装する
  - 生成ファイルをcerts/サブディレクトリに保存する
  - _Requirements: 1.1, 1.3, 1.4, 1.5, 1.6_

- [x] 2.2 .gitignoreに証明書ディレクトリを追加する
  - ルートの.gitignoreファイルにcerts/ディレクトリを追加する
  - 秘密鍵ファイル（*.pem, *.key, *.crt）をGitリポジトリから除外する
  - _Requirements: 1.7_

- [x] 3. Example環境にACM証明書インポート機能を追加する
- [x] 3.1 ACM証明書インポートTerraformリソースを実装する
  - examples/aws-ecs-fargate/acm.tfを作成する
  - ローカル証明書ファイルを読み込むTerraformリソースを実装する
  - 条件付きリソース作成（enable_acm_import変数）を実装する
  - 証明書ARNをlocals経由でモジュールに渡す仕組みを追加する
  - _Requirements: 1.2_

- [x] 3.2 ACM関連Terraform変数を追加する
  - examples/aws-ecs-fargate/variables.tfにenable_acm_import変数を追加する
  - 変数のデフォルト値をfalseに設定する
  - _Requirements: 1.2_

- [x] 3.3 main.tfで証明書ARN参照をlocalsに変更する
  - examples/aws-ecs-fargate/main.tfでcertificate_arnの参照をlocal.certificate_arnに変更する
  - ACMインポートと外部証明書ARNの両方に対応する
  - _Requirements: 1.2_

- [x] 4. Example環境にRDS PostgreSQLインスタンスを追加する
- [x] 4.1 RDSセキュリティグループとサブネットグループを実装する
  - examples/aws-ecs-fargate/rds.tfを作成する
  - RDS用セキュリティグループを作成する
  - Bridgeセキュリティグループからの5432ポートインバウンドアクセスを許可するルールを追加する
  - RDSサブネットグループを作成し、プライベートサブネットに配置する
  - 条件付きリソース作成（enable_rds変数）を実装する
  - _Requirements: 2.1, 2.2, 2.3_

- [x] 4.2 RDSインスタンスとSecrets Managerを実装する
  - PostgreSQL RDSインスタンス（db.t3.micro）を作成する
  - パブリックアクセスを無効化（publicly_accessible = false）する
  - データベース認証情報をAWS Secrets Managerに保存する
  - skip_final_snapshot = trueを設定し、テスト環境向けに最適化する
  - ストレージ暗号化（gp3、20GB）を設定する
  - _Requirements: 2.2, 2.5, 2.7_

- [x] 4.3 データベースシードスクリプトを作成する
  - examples/aws-ecs-fargate/scripts/init.sqlを作成する
  - usersテーブル（id, name, email, created_at列）のCREATE TABLE文を実装する
  - 5件のサンプルレコードのINSERT文を実装する
  - _Requirements: 2.4, 2.8_

- [x] 4.4 null_resourceでデータベース初期化を自動化する
  - rds.tfにnull_resourceリソースを追加する
  - psqlクライアントを使ってinit.sqlを実行するprovisioner local-execを実装する
  - RDSインスタンス作成後に初期化が実行されるようdepends_onを設定する
  - SQLファイルのハッシュをtriggerに設定し、変更時に再実行されるようにする
  - _Requirements: 2.4_

- [x] 4.5 RDS関連Terraform変数と出力値を追加する
  - examples/aws-ecs-fargate/variables.tfにRDS関連変数を追加する（enable_rds、database_name、database_username、database_password、database_instance_class、database_allocated_storage、database_engine_version）
  - 必須変数（database_username、database_password）をsensitive = trueで定義する
  - examples/aws-ecs-fargate/outputs.tfにRDS関連出力値を追加する（rds_endpoint、rds_address、rds_port、rds_database_name）
  - _Requirements: 2.5, 2.6, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9_

- [x] 5. ドキュメントとサンプル設定を拡張する
- [x] 5.1 Example READMEを拡張する
  - examples/aws-ecs-fargate/README.mdに自己署名証明書生成手順を追加する
  - ACM証明書インポート手順を追加する
  - RDSデプロイ手順と必須変数の説明を追加する
  - シードデータ内容（usersテーブル構造、サンプルレコード）を記載する
  - Bridgeからのデータベース接続方法を記載する
  - 自己署名証明書使用時の注意事項（ブラウザ警告、curl -kオプション）を追加する
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

- [x] 5.2 terraform.tfvars.exampleを拡張する
  - examples/aws-ecs-fargate/terraform.tfvars.exampleにRDS関連変数のサンプル値を追加する
  - ACM関連変数のサンプル値を追加する
  - 本番環境での警告コメントを追加する（データベース認証情報管理）
  - _Requirements: 5.8, 6.5_

- [x] 6. 統合テストとドキュメントの最終検証を行う
- [x] 6.1 全体の統合確認を実施する
  - 証明書生成スクリプトの動作を手動確認する
  - Terraformコードの構文チェック（terraform fmt、terraform validate）を実行する
  - terraform planで全リソースの作成計画を確認する
  - _Requirements: すべての要件の統合確認_

- [x] 6.2 ドキュメントの完全性を確認する
  - 全てのREADMEファイルが最新情報を反映していることを確認する
  - terraform.tfvars.exampleが全変数をカバーしていることを確認する
  - test/.env.exampleが適切な環境変数例を提供していることを確認する
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 6.1, 6.2, 6.6_

## Requirements Coverage

全7要件がタスクでカバーされています：

- **Requirement 1**: 自己署名証明書の生成とACMインポート → Task 2, 3
- **Requirement 2**: Example環境へのRDSインスタンス追加 → Task 4
- **Requirement 3**: Terratest統合テストのHTTPS検証強化 → Task 1.1
- **Requirement 4**: Terratest統合テストのスコープ制限 → Task 1.2, 1.3
- **Requirement 5**: Example READMEとドキュメント強化 → Task 5.1, 5.2
- **Requirement 6**: テスト環境変数とCI/CD対応 → Task 1.3, 5.2
- **Requirement 7**: Terraform変数とモジュール統合 → Task 4.5

## Implementation Notes

- **実装順序**: ユーザーの指示により、まずTerratest（Task 1）から開始し、その後証明書生成（Task 2）、ACMインポート（Task 3）、RDS（Task 4）、ドキュメント（Task 5）、最終検証（Task 6）の順に実装します
- **後方互換性**: 既存のexampleとテストは引き続き動作します（新規変数はすべてオプション）
- **テスト戦略**: TerratestではRDSインスタンスを作成せず、Bridge単体のHTTPS疎通確認のみ実施します
- **psqlクライアント**: RDS初期化には実行環境に`psql`がインストールされている必要があります

## Next Steps

タスクの実装を開始するには、以下のコマンドを使用してください：

```bash
/kiro:spec-impl practical-example-and-test-enhancement          # 全タスクを実行
/kiro:spec-impl practical-example-and-test-enhancement 1.1      # 特定のタスクを実行
/kiro:spec-impl practical-example-and-test-enhancement 1,2,3    # 複数のタスクを実行
```
