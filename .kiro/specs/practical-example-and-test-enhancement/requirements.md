# Requirements Document

## Project Description (Input)

ECS Fargateのexample, およびテストをより実践的にしたい。具体的には証明書つきのHTTPSリクエストを使った動作確認や、シードデータつきのRDSへの接続を行いたい。証明書はローカルで自己署名証明書を作って、ACM にインポートして使う。　@test/aws/ecs_fargate_test.go はALBの裏のbridgeのヘルスチェックエンドポイントにcurlでのHTTPSリクエストを行い、レスポンスが200 OKであることを確認する。 @examples/aws-ecs-fargate/ で用意される環境にはそれに加えて裏側にRDSもシードデータ付きで置くようにしたい。

## Introduction

このスペックは、ECS Fargateモジュールのexampleとテストをより実践的で現実的なシナリオに強化することを目的としています。現在のexampleとテストは最小限の構成で動作確認を行っていますが、本番環境に近い構成（HTTPS通信、データベース接続）を検証できるようにします。

これにより、以下の価値が提供されます：
- **実践的な検証**: HTTPS証明書を使った本番環境に近い構成での動作確認
- **エンドツーエンドテスト**: ALB → Bridge → RDSの接続経路全体の検証
- **ドキュメント強化**: 実際のユースケースを示すexampleコードの提供
- **テスト品質向上**: HTTPSエンドポイントへの実際のリクエスト検証

## Requirements

### Requirement 1: 自己署名証明書の生成とACMインポート機構

**Objective:** 開発者として、ローカル環境で自己署名証明書を生成しACMにインポートする仕組みを用意したい、そうすることでHTTPS通信の動作確認を行えるようにする

#### Acceptance Criteria

1. WHEN 開発者がexampleディレクトリで証明書生成スクリプトを実行する THEN スクリプト SHALL ローカル環境に自己署名証明書（秘密鍵、証明書、証明書チェーン）を生成する
2. WHEN 開発者が証明書インポートコマンドを実行する THEN Terraform構成 SHALL 生成された証明書をAWS ACMにインポートする
3. WHERE 証明書生成スクリプト THE スクリプト SHALL OpenSSLを使用して2048ビットRSA鍵ペアと有効期限365日の自己署名証明書を生成する
4. WHERE 証明書生成処理 THE スクリプト SHALL 証明書のCommon Name（CN）にexampleドメイン名（例: bridge.example.local）を設定する
5. WHEN 証明書ファイルが既に存在する THEN スクリプト SHALL 既存ファイルを上書きせず、確認プロンプトを表示する
6. WHERE 生成された証明書ファイル THE ファイル群 SHALL exampleディレクトリ内の`certs/`サブディレクトリに保存される
7. WHERE 証明書ディレクトリ THE `.gitignore` SHALL `certs/`ディレクトリを無視リストに追加し、秘密鍵がGitリポジトリにコミットされないようにする

### Requirement 2: Example環境へのRDSインスタンス追加

**Objective:** インフラ担当者として、exampleにシードデータ付きRDSインスタンスを追加したい、そうすることでBridgeからデータベースへの接続を検証できるようにする

#### Acceptance Criteria

1. WHEN Terraform applyを実行する THEN example構成 SHALL Amazon RDS PostgreSQLインスタンス（db.t3.micro）をプライベートサブネットに作成する
2. WHERE RDS構成 THE RDSインスタンス SHALL パブリックアクセスを無効化（publicly_accessible = false）し、プライベートネットワーク内でのみアクセス可能とする
3. WHEN RDSインスタンスが作成される THEN Terraform構成 SHALL Bridgeセキュリティグループからの5432ポート（PostgreSQL）インバウンドアクセスを許可するセキュリティグループルールを作成する
4. WHERE データベース初期化 THE Terraform構成 SHALL `init.sql`スクリプトを使用してRDSインスタンスにシードデータ（テーブル作成、サンプルレコード挿入）を投入する
5. WHEN データベース認証情報が必要な場合 THEN example構成 SHALL マスターユーザー名とパスワードをTerraform変数として受け取り、AWS Secrets Managerに保存する
6. WHERE RDS出力値 THE Terraform outputs.tf SHALL RDSエンドポイント、ポート、データベース名を出力し、接続情報を取得可能にする
7. IF RDSインスタンスがテスト専用である THEN RDS構成 SHALL `skip_final_snapshot = true`を設定し、terraform destroy時に最終スナップショットを作成しないようにする
8. WHERE データベーススキーマ THE `init.sql` SHALL `users`テーブル（id, name, email, created_at列）と最低3件のサンプルレコードを作成する

### Requirement 3: Terratest統合テストのHTTPS検証強化

**Objective:** テスト担当者として、TerratestにHTTPSエンドポイントへの実際のリクエスト検証を追加したい、そうすることでALB → Bridge間のHTTPS通信が正しく動作することを確認できるようにする

#### Acceptance Criteria

1. WHEN テストがALB DNS名を取得する THEN Terratest SHALL Terraform出力値からALB DNSエンドポイントを取得する
2. WHEN テストがHTTPSリクエストを送信する THEN Terratest SHALL `https://[ALB_DNS]/ok`にHTTP GETリクエストを送信する
3. IF 自己署名証明書を使用している THEN HTTPSクライアント SHALL TLS証明書検証をスキップ（InsecureSkipVerify）し、接続を許可する
4. WHEN HTTPSリクエストが成功する THEN Bridgeヘルスチェックエンドポイント SHALL HTTPステータスコード200を返す
5. WHERE リクエストタイムアウト THE HTTPクライアント SHALL 30秒のタイムアウトを設定し、長時間の待機を防ぐ
6. WHEN ヘルスチェックエンドポイントがまだ準備できていない THEN テスト SHALL 最大5分間、10秒間隔でリトライを行う
7. WHEN HTTPSリクエストがタイムアウトまたはエラーになる THEN テスト SHALL エラー詳細（ステータスコード、レスポンスボディ）をログに出力し、テストを失敗させる
8. WHERE テストログ THE Terratest SHALL リクエストURL、レスポンスステータス、レスポンスタイム、リトライ回数をログに記録する

### Requirement 4: Terratest統合テストのスコープ制限

**Objective:** テスト担当者として、TerratestではBridge単体のHTTPS疎通確認のみを行いたい、そうすることでテスト環境でRDSインスタンスを作成せず、コストとテスト時間を削減できるようにする

#### Acceptance Criteria

1. WHEN Terratestを実行する THEN テスト SHALL `enable_rds = false`変数を設定し、RDSインスタンスを作成しない
2. WHEN Terratestを実行する THEN テスト SHALL Bridge、ALB、セキュリティグループのみをデプロイする
3. WHERE テスト構成 THE テスト SHALL RDS接続検証を実施せず、HTTPS エンドポイントテストのみを実行する
4. WHERE テストドキュメント THE README SHALL Terratestの実行にはRDS関連の環境変数（`TEST_DATABASE_USERNAME`, `TEST_DATABASE_PASSWORD`, `TEST_PRIVATE_SUBNET_IDS`）が不要であることを明記する

### Requirement 5: Example READMEとドキュメント強化

**Objective:** ユーザーとして、exampleの使用方法とRDS接続の構成方法を理解したい、そうすることで実践的なデプロイを自分の環境で再現できるようにする

#### Acceptance Criteria

1. WHERE example README THE ドキュメント SHALL 自己署名証明書生成スクリプトの実行手順を記載する
2. WHERE example README THE ドキュメント SHALL ACMへの証明書インポート手順（Terraformコマンド、必要な変数）を記載する
3. WHERE example README THE ドキュメント SHALL RDSインスタンスのデプロイ手順と必須変数（データベース認証情報、サブネット構成）を記載する
4. WHERE example README THE ドキュメント SHALL シードデータの内容（テーブル構造、サンプルレコード）を記載する
5. WHERE example README THE ドキュメント SHALL Bridgeからのデータベース接続方法（環境変数、接続文字列形式）を記載する
6. WHERE example README THE ドキュメント SHALL テスト実行手順（必要な環境変数、goコマンド）を記載する
7. WHERE example README THE ドキュメント SHALL 自己署名証明書を使う際の注意事項（ブラウザの警告、curl -kオプション）を記載する
8. WHERE terraform.tfvars.example THE ファイル SHALL RDS関連の変数（database_username, database_password, database_name）のサンプル値を含む

### Requirement 6: テスト環境変数とCI/CD対応

**Objective:** CI/CD担当者として、テスト実行に必要な環境変数を明確化したい、そうすることで自動テストパイプラインを構築できるようにする

#### Acceptance Criteria

1. WHERE テスト環境変数 THE ドキュメント SHALL HTTPSテストに必要な環境変数（`TEST_VPC_ID`, `TEST_PUBLIC_SUBNET_IDS`, `TEST_TENANT_ID`, `TEST_CERTIFICATE_ARN`）をリストアップする
2. WHERE テスト環境変数 THE ドキュメント SHALL TerratestではRDS環境変数（`TEST_DATABASE_USERNAME`, `TEST_DATABASE_PASSWORD`, `TEST_PRIVATE_SUBNET_IDS`）が不要であることを明記する
3. IF 環境変数が未設定の場合 THEN テスト SHALL 明確なエラーメッセージと必須変数名を出力し、テストをスキップまたは失敗させる
4. WHERE CI/CD環境 THE テスト構成 SHALL GitHub ActionsまたはCI/CDツールでシークレットとして環境変数を設定できるように変数名を標準化する
5. WHERE セキュリティ THE ドキュメント SHALL データベース認証情報やテナントIDをリポジトリに直接コミットしないよう警告する
6. WHERE テストREADME THE ドキュメント SHALL `.env.example`ファイルを提供し、ローカル開発環境での環境変数設定例を示す（ただしRDS変数は含めない）

### Requirement 7: Terraform変数とモジュール統合

**Objective:** インフラ担当者として、RDS構成を柔軟にカスタマイズできるTerraform変数を用意したい、そうすることで異なる環境（開発、ステージング）に対応できるようにする

#### Acceptance Criteria

1. WHERE example variables.tf THE ファイル SHALL `database_name`変数（デフォルト: "bridgedb"）を定義する
2. WHERE example variables.tf THE ファイル SHALL `database_username`変数（デフォルト値なし、必須）を定義する
3. WHERE example variables.tf THE ファイル SHALL `database_password`変数（デフォルト値なし、必須、sensitive = true）を定義する
4. WHERE example variables.tf THE ファイル SHALL `database_instance_class`変数（デフォルト: "db.t3.micro"）を定義する
5. WHERE example variables.tf THE ファイル SHALL `database_allocated_storage`変数（デフォルト: 20GB）を定義する
6. WHERE example variables.tf THE ファイル SHALL `database_engine_version`変数（デフォルト: "14.7"、PostgreSQL）を定義する
7. WHERE example variables.tf THE ファイル SHALL `enable_rds`変数（デフォルト: true、RDSデプロイの有効/無効切り替え）を定義する
8. WHEN `enable_rds = false`の場合 THEN Terraform構成 SHALL RDS関連リソースを作成せず、Bridgeのみをデプロイする
9. WHERE RDSリソース定義 THE Terraform構成 SHALL `count`または`for_each`を使用して`enable_rds`変数に基づく条件付きリソース作成を実装する
