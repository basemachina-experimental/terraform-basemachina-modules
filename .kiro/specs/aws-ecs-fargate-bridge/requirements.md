# Requirements Document

## Introduction

本ドキュメントは、AWS ECS FargateでBaseMachina bridgeをデプロイするTerraformモジュールの要件を定義します。このモジュールは、BaseMachinaのbridgeサービス（認証機能付きゲートウェイ）をAWSクラウド環境に自動的にプロビジョニングし、セキュアで運用しやすいインフラストラクチャを提供します。

bridgeは、BaseMachinaからお客様のプライベートデータソース（RDS、内部API等）への安全なアクセスを実現する重要なコンポーネントです。このTerraformモジュールにより、インフラストラクチャをコードとして管理し、再現可能で監査可能なデプロイを実現します。

## Requirements

### Requirement 1: Terraformモジュール構造
**Objective:** Terraformユーザーとして、標準的なモジュール構造に従った再利用可能なモジュールを使用したい。これにより、既存のTerraformワークフローに容易に統合できる。

#### Acceptance Criteria

1. WHEN ユーザーがモジュールディレクトリを確認する THEN Terraformモジュールは `modules/aws/ecs-fargate/` ディレクトリに配置されなければならない
2. WHEN ユーザーがモジュールの内容を確認する THEN モジュールは以下の標準ファイルを含まなければならない：
   - `main.tf`（リソース定義）
   - `variables.tf`（入力変数）
   - `outputs.tf`（出力値）
   - `versions.tf`（プロバイダーバージョン制約）
   - `README.md`（モジュールドキュメント）
3. WHEN ユーザーが `terraform init` を実行する THEN モジュールはAWS Provider 5.0以上を要求しなければならない
4. WHEN ユーザーがモジュールをインポートする THEN モジュールはローカルパス参照（`source = "../../modules/aws/ecs-fargate"`）で利用可能でなければならない

### Requirement 2: ECS Fargateクラスターとサービス
**Objective:** インフラ管理者として、ECS FargateでBridgeコンテナを実行したい。これにより、サーバー管理の負担なくコンテナをデプロイできる。

#### Acceptance Criteria

1. WHEN モジュールがapplyされる THEN Terraformモジュールは ECS クラスターリソースを作成しなければならない
2. WHEN ECSサービスが作成される THEN サービスは起動タイプとして `FARGATE` を使用しなければならない
3. WHEN Fargateタスク定義が作成される THEN タスクは `public.ecr.aws/basemachina/bridge` コンテナイメージを使用しなければならない
4. WHEN タスクにCPUとメモリが設定される THEN タスク定義は適切なCPU（256、512、1024、2048、4096のいずれか）とメモリの組み合わせを変数から受け取れなければならない
5. WHEN サービスが起動される THEN 少なくとも1つのタスクが実行されなければならない（desired_count >= 1）
6. IF ユーザーがタスク数を指定する THEN モジュールは `desired_count` 変数を通じてタスク数を設定可能でなければならない

### Requirement 3: Bridge環境変数の設定
**Objective:** システム運用者として、Bridgeコンテナに必要な環境変数を設定したい。これにより、認証設定やテナント分離が正しく機能する。

#### Acceptance Criteria

1. WHEN タスク定義が作成される THEN 以下の環境変数が設定されなければならない：
   - `FETCH_INTERVAL`（認可処理の公開鍵更新間隔）
   - `FETCH_TIMEOUT`（認可処理の公開鍵更新タイムアウト）
   - `PORT`（Bridgeのリスニングポート、デフォルト8080）
   - `TENANT_ID`（テナントID）
2. WHEN ユーザーがモジュール変数を設定する THEN 各環境変数は対応する変数（`fetch_interval`, `fetch_timeout`, `port`, `tenant_id`）から値を受け取れなければならない
3. WHEN `FETCH_INTERVAL` が設定される THEN 有効な時間単位（ns/us/ms/s/m/h）の文字列を受け入れなければならない
4. WHEN `FETCH_TIMEOUT` が設定される THEN 有効な時間単位（ns/us/ms/s/m/h）の文字列を受け入れなければならない
5. WHEN `PORT` が設定される THEN 4321以外のポート番号を文字列として受け入れなければならない
6. IF `TENANT_ID` が指定される THEN Bridgeは指定されたテナントID以外からのリクエストを拒否しなければならない

### Requirement 4: ネットワーク構成
**Objective:** セキュリティ管理者として、Bridgeをプライベートサブネットに配置し、適切なネットワーク分離を実現したい。これにより、セキュリティベストプラクティスに準拠できる。

#### Acceptance Criteria

1. WHEN モジュールがVPC設定を受け取る THEN モジュールは既存VPC IDを変数（`vpc_id`）として受け入れなければならない
2. WHEN Fargateタスクが配置される THEN タスクはプライベートサブネットに配置されなければならない
3. WHEN プライベートサブネットが指定される THEN モジュールはサブネットIDのリスト（`private_subnet_ids`）を変数として受け入れなければならない
4. WHEN Fargateタスクがインターネットアクセスを必要とする THEN プライベートサブネットにはNATゲートウェイが設定されていなければならない（前提条件）
5. WHEN セキュリティグループが作成される THEN Bridgeタスク用のセキュリティグループが作成されなければならない
6. WHEN ALBからのトラフィックを受け付ける THEN セキュリティグループはALBセキュリティグループからのインバウンドトラフィック（ポート8080）を許可しなければならない
7. WHEN Bridgeが外部APIにアクセスする THEN セキュリティグループは全ての送信トラフィックを許可しなければならない（BaseMachina API、データソースへのアクセス）

### Requirement 5: Application Load Balancer（ALB）
**Objective:** インフラ管理者として、HTTPS終端とルーティングを行うALBを構成したい。これにより、セキュアな通信とヘルスチェックを実現できる。

#### Acceptance Criteria

1. WHEN モジュールがapplyされる THEN Application Load Balancer（ALB）が作成されなければならない
2. WHEN ALBが作成される THEN ALBはインターネット向け（`internet-facing`）として設定されなければならない
3. WHEN ALBがサブネットに配置される THEN ALBはパブリックサブネット（`public_subnet_ids`変数）に配置されなければならない
4. WHEN ALBセキュリティグループが作成される THEN セキュリティグループは以下のインバウンドルールを持たなければならない：
   - ポート443（HTTPS）を特定のIPアドレス（34.85.43.93/32、BaseMachina）から許可
5. WHEN ALBターゲットグループが作成される THEN ターゲットタイプは `ip` でなければならない（Fargate用）
6. WHEN ターゲットグループのヘルスチェックが設定される THEN ヘルスチェックパスは `/ok` でなければならない
7. WHEN ヘルスチェックが実行される THEN HTTP GET リクエストがポート8080に送信されなければならない
8. WHEN ALBリスナーが作成される THEN HTTPSリスナー（ポート443）が作成されなければならない
9. WHEN HTTPSリスナーが証明書を必要とする THEN モジュールはACM証明書ARN（`certificate_arn`変数）を受け入れなければならない
10. WHEN HTTPSリクエストが受信される THEN リクエストはBridgeターゲットグループにルーティングされなければならない

### Requirement 6: IAMロールと権限
**Objective:** セキュリティ管理者として、最小権限の原則に基づいたIAMロールを設定したい。これにより、セキュリティリスクを最小化できる。

#### Acceptance Criteria

1. WHEN ECSタスクが実行される THEN タスク実行ロール（Task Execution Role）が作成されなければならない
2. WHEN タスク実行ロールが作成される THEN ロールは `ecs-tasks.amazonaws.com` をプリンシパルとして信頼しなければならない
3. WHEN タスクがECRからイメージをpullする THEN タスク実行ロールは `AmazonECSTaskExecutionRolePolicy` マネージドポリシーをアタッチされなければならない
4. WHEN タスクがCloudWatch Logsに書き込む THEN タスク実行ロールはCloudWatch Logsへの書き込み権限を持たなければならない
5. IF シークレット管理が有効化される THEN タスク実行ロールはSecrets ManagerまたはSystems Manager Parameter Storeへのアクセス権限を持たなければならない
6. WHEN アプリケーションがAWSサービスにアクセスする THEN タスクロール（Task Role）が作成されなければならない

### Requirement 7: CloudWatch Logsとモニタリング
**Objective:** システム運用者として、Bridgeコンテナのログを一元管理したい。これにより、トラブルシューティングと運用監視が容易になる。

#### Acceptance Criteria

1. WHEN モジュールがapplyされる THEN CloudWatch Logsロググループが作成されなければならない
2. WHEN ロググループが作成される THEN ログストリームプレフィックスは `/ecs/basemachina-bridge` でなければならない
3. WHEN タスク定義にログ設定が追加される THEN タスクは `awslogs` ログドライバーを使用しなければならない
4. WHEN コンテナがログを出力する THEN 標準出力（stdout）と標準エラー出力（stderr）がCloudWatch Logsに転送されなければならない
5. IF ユーザーがログ保持期間を指定する THEN モジュールは `log_retention_days` 変数を通じて保持期間を設定可能でなければならない
6. WHEN ログ保持期間が指定されない THEN デフォルトで7日間保持されなければならない

### Requirement 8: データベース接続設定
**Objective:** インフラ管理者として、Bridgeからプライベートデータベースへのアクセスをセキュアに設定したい。これにより、データソースとの通信が確立される。

#### Acceptance Criteria

1. WHEN ユーザーがデータベース接続先を指定する THEN モジュールはデータベースセキュリティグループID（`database_security_group_id`変数）を受け入れられなければならない
2. IF データベースセキュリティグループIDが指定される THEN Bridgeセキュリティグループからデータベースへのアウトバウンド通信を許可するルールが追加されなければならない
3. WHEN データベースがRDSの場合 AND データベースセキュリティグループが指定される THEN データベースセキュリティグループにBridgeセキュリティグループからのインバウンドルール（適切なポート）が追加されなければならない
4. WHEN Bridgeとデータベースが同じVPCにある THEN Bridgeはプライベート通信でデータベースにアクセスできなければならない

### Requirement 9: 出力値（Outputs）
**Objective:** Terraformユーザーとして、デプロイ後に必要な情報をモジュールから取得したい。これにより、他のリソース構成や外部システムへの登録が可能になる。

#### Acceptance Criteria

1. WHEN モジュールがapplyされる THEN 以下の出力値が提供されなければならない：
   - `alb_dns_name`（ALBのDNS名）
   - `alb_arn`（ALBのARN）
   - `ecs_cluster_name`（ECSクラスター名）
   - `ecs_service_name`（ECSサービス名）
   - `bridge_security_group_id`（Bridgeセキュリティグループのセキュリティグループ ID）
   - `cloudwatch_log_group_name`（CloudWatch Logsのロググループ名）
2. WHEN ユーザーがDNS設定を行う THEN `alb_dns_name` を使用してRoute 53レコードを作成できなければならない
3. WHEN 他のモジュールがBridgeセキュリティグループを参照する THEN `bridge_security_group_id` を使用して通信ルールを設定できなければならない

### Requirement 10: 入力変数のバリデーション
**Objective:** Terraformユーザーとして、無効な設定でデプロイが失敗する前にエラーを検出したい。これにより、デプロイの信頼性が向上する。

#### Acceptance Criteria

1. WHEN 必須変数が指定されない THEN Terraformは明確なエラーメッセージを表示しなければならない
2. WHEN `desired_count` が指定される THEN 値は1以上の整数でなければならない
3. WHEN `port` が指定される AND 値が4321である THEN バリデーションエラーが発生しなければならない
4. WHEN サブネットIDリストが空である THEN バリデーションエラーが発生しなければならない
5. WHEN 各変数が定義される THEN 明確な説明（description）が含まれなければならない
6. IF 変数にデフォルト値がある THEN デフォルト値は推奨設定を反映していなければならない

### Requirement 11: タグ付けとリソース命名
**Objective:** インフラ管理者として、一貫したタグ付けと命名規則でリソースを管理したい。これにより、コスト追跡とリソース管理が容易になる。

#### Acceptance Criteria

1. WHEN ユーザーが共通タグを指定する THEN モジュールは `tags` 変数（map型）を受け入れなければならない
2. WHEN リソースが作成される THEN すべてのタグ対応リソースに共通タグが適用されなければならない
3. WHEN ユーザーがリソース名プレフィックスを指定する THEN モジュールは `name_prefix` 変数を受け入れなければならない
4. WHEN `name_prefix` が指定される THEN 作成されるリソース名は `${name_prefix}-basemachina-bridge-*` の形式でなければならない
5. WHEN リソースに自動生成された名前が必要な場合 THEN Terraform の `name_prefix` 引数を使用して衝突を回避しなければならない

### Requirement 12: 実装例の提供
**Objective:** Terraformユーザーとして、実際の使用方法を示す例を参照したい。これにより、モジュールの利用方法を迅速に理解できる。

#### Acceptance Criteria

1. WHEN リポジトリ構造を確認する THEN `examples/aws-ecs-fargate/` ディレクトリが存在しなければならない
2. WHEN examplesディレクトリを確認する THEN 以下のファイルが含まれなければならない：
   - `main.tf`（モジュールの使用例）
   - `variables.tf`（カスタマイズ可能な変数）
   - `outputs.tf`（出力例）
   - `terraform.tfvars.example`（設定例）
   - `README.md`（デプロイ手順）
3. WHEN ユーザーがサンプルをデプロイする THEN 例は最小限の変数設定でデプロイ可能でなければならない
4. WHEN README.mdを参照する THEN 以下の情報が含まれなければならない：
   - 前提条件（VPC、サブネット、ACM証明書等）
   - デプロイ手順
   - カスタマイズ方法
   - クリーンアップ手順

### Requirement 13: モジュールドキュメント
**Objective:** Terraformユーザーとして、モジュールの使用方法を詳細に理解したい。これにより、適切な設定でモジュールを利用できる。

#### Acceptance Criteria

1. WHEN モジュールディレクトリのREADME.mdを参照する THEN 以下のセクションが含まれなければならない：
   - モジュール概要
   - 使用方法
   - 要件（Terraformバージョン、プロバイダー）
   - 入力変数（terraform-docsで自動生成）
   - 出力値（terraform-docsで自動生成）
   - 例
2. WHEN terraform-docsが実行される THEN README.mdの変数と出力のセクションが自動更新されなければならない
3. WHEN ユーザーが各変数の用途を確認する THEN variables.tfの各変数に明確な説明が記載されていなければならない
4. WHEN ユーザーがセキュリティ要件を確認する THEN README.mdにセキュリティベストプラクティスが記載されていなければならない
