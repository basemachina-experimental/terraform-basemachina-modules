# 実装タスク

## はじめに

本ドキュメントは、AWS ECS FargateでBaseMachina bridgeをデプロイするTerraformモジュールの実装タスクを定義します。各タスクは1-3時間で完了可能な単位に分解されており、要件とトレーサビリティが明記されています。

## タスク一覧

### 1. プロジェクト構造とバージョン管理ファイルの作成

_Requirements: 1.1, 1.2, 1.4_

Terraformモジュールの基本構造を作成し、プロバイダーのバージョン制約を定義します。

#### 実装内容
- `modules/aws/ecs-fargate/`ディレクトリの作成
- `versions.tf`ファイルの作成（Terraform 1.0以上、AWS Provider 5.0以上の制約を定義）
- `README.md`ファイルのテンプレート作成（モジュール概要、使用方法、要件のセクション）

#### 完了条件
- [x] ディレクトリ構造が存在する
- [x] `versions.tf`にTerraformとAWS Providerのバージョン制約が定義されている
- [x] `README.md`に基本的なセクションが含まれている

---

### 2. 入力変数の定義とバリデーション

_Requirements: 3.1, 3.2, 4.1, 4.3, 5.3, 5.9, 8.1, 10.1-10.6, 11.1, 11.3_

すべての入力変数を定義し、バリデーションルールを実装します。

#### 実装内容
- `variables.tf`ファイルの作成
- ネットワーク関連変数の定義（`vpc_id`, `private_subnet_ids`, `public_subnet_ids`）
- Bridge環境変数の定義（`fetch_interval`, `fetch_timeout`, `port`, `tenant_id`）
- リソース設定変数の定義（`cpu`, `memory`, `desired_count`, `log_retention_days`）
- セキュリティ関連変数の定義（`certificate_arn`, `database_security_group_id`, `database_port`）
- タグ付けと命名変数の定義（`tags`, `name_prefix`）
- 各変数にvalidationブロックを追加
  - `port != 4321`
  - `desired_count >= 1`
  - `private_subnet_ids`と`public_subnet_ids`が空でないこと
  - `cpu`が許可された値（256, 512, 1024, 2048, 4096）のいずれか
- すべての変数に明確な説明（description）を追加
- 適切なデフォルト値の設定

#### 完了条件
- [x] すべての変数が`variables.tf`に定義されている
- [x] バリデーションルールが実装され、無効な入力を検出できる
- [x] `terraform validate`が成功する

---

### 3. IAMロールとポリシーの実装

_Requirements: 6.1-6.6_

ECSタスク実行ロールとタスクロールを作成し、必要な権限を付与します。

#### 実装内容
- `iam.tf`ファイルの作成（または`main.tf`内に実装）
- タスク実行ロール（Task Execution Role）の作成
  - `ecs-tasks.amazonaws.com`を信頼するAssumeRoleポリシー
  - `AmazonECSTaskExecutionRolePolicy`マネージドポリシーのアタッチ
  - CloudWatch Logsへの書き込み権限を持つインラインポリシーの追加
- タスクロール（Task Role）の作成
  - `ecs-tasks.amazonaws.com`を信頼するAssumeRoleポリシー
  - 現時点では追加の権限なし（将来的な拡張用）
- タグの適用

#### 完了条件
- [x] タスク実行ロールが作成され、必要なポリシーがアタッチされている
- [x] タスクロールが作成されている
- [x] `terraform plan`でエラーが発生しない

---

### 4. CloudWatch Logsロググループの作成

_Requirements: 7.1-7.6_

Bridgeコンテナのログを集約するためのCloudWatch Logsロググループを作成します。

#### 実装内容
- `logs.tf`ファイルの作成（または`main.tf`内に実装）
- ロググループリソースの作成
  - ロググループ名: `/ecs/basemachina-bridge`
  - 保持期間: `var.log_retention_days`（デフォルト7日）
- タグの適用

#### 完了条件
- [x] ロググループが作成される
- [x] 保持期間が変数で設定可能
- [x] `terraform plan`でエラーが発生しない

---

### 5. セキュリティグループの作成

_Requirements: 4.5-4.7, 5.4, 8.2, 8.3_

ALBとBridgeタスク用のセキュリティグループを作成し、適切なルールを設定します。

#### 実装内容
- `security_groups.tf`ファイルの作成（または`main.tf`内に実装）
- ALBセキュリティグループの作成
  - インバウンド: HTTPS:443を34.85.43.93/32から許可
  - アウトバウンド: 全トラフィックを許可
- Bridgeセキュリティグループの作成
  - インバウンド: `var.port`をALBセキュリティグループから許可
  - アウトバウンド: 全トラフィックを許可
- データベースセキュリティグループルールの作成（条件付き）
  - `var.database_security_group_id`が指定された場合のみ作成
  - Bridgeセキュリティグループから`var.database_port`へのインバウンドルールを追加
- タグの適用

#### 完了条件
- [x] ALBセキュリティグループが作成され、正しいルールが設定されている
- [x] Bridgeセキュリティグループが作成され、正しいルールが設定されている
- [x] データベース接続用のルールが条件付きで作成される
- [x] `terraform plan`でエラーが発生しない

---

### 6. Application Load Balancerの作成

_Requirements: 5.1-5.3_

インターネット向けのALBをパブリックサブネットに作成します。

#### 実装内容
- `alb.tf`ファイルの作成（または`main.tf`内に実装）
- ALBリソースの作成
  - 名前: `${var.name_prefix}-basemachina-bridge`
  - タイプ: `application`
  - スキーム: `internet-facing`
  - セキュリティグループ: ALBセキュリティグループのID
  - サブネット: `var.public_subnet_ids`
  - 削除保護: 無効（開発環境用）
- タグの適用

#### 完了条件
- [x] ALBが作成される
- [x] パブリックサブネットに配置される
- [x] 正しいセキュリティグループが適用される
- [x] `terraform plan`でエラーが発生しない

---

### 7. ALBターゲットグループとヘルスチェックの設定

_Requirements: 5.5-5.7_

BridgeタスクをターゲットとするALBターゲットグループを作成し、ヘルスチェックを設定します。

#### 実装内容
- `alb.tf`ファイルにターゲットグループリソースを追加
- ターゲットグループの作成
  - 名前: `${var.name_prefix}-bridge-tg`
  - ポート: `var.port`
  - プロトコル: `HTTP`
  - ターゲットタイプ: `ip`
  - VPC: `var.vpc_id`
- ヘルスチェックの設定
  - パス: `/ok`
  - プロトコル: `HTTP`
  - ポート: `var.port`
  - 間隔: 30秒
  - タイムアウト: 5秒
  - 健全閾値: 2回
  - 非健全閾値: 2回
  - マッチャー: `200`
- タグの適用

#### 完了条件
- [x] ターゲットグループが作成される
- [x] ヘルスチェックが正しく設定される
- [x] ターゲットタイプが`ip`である
- [x] `terraform plan`でエラーが発生しない

---

### 8. ALB HTTPSリスナーの作成

_Requirements: 5.8-5.10_

HTTPS:443でリクエストを受け付けるALBリスナーを作成し、ターゲットグループにルーティングします。

#### 実装内容
- `alb.tf`ファイルにリスナーリソースを追加
- HTTPSリスナーの作成
  - ポート: `443`
  - プロトコル: `HTTPS`
  - SSL/TLSポリシー: `ELBSecurityPolicy-TLS-1-2-2017-01`
  - 証明書ARN: `var.certificate_arn`
  - デフォルトアクション: Bridgeターゲットグループへのフォワード

#### 完了条件
- [x] HTTPSリスナーが作成される
- [x] ACM証明書が正しく参照される
- [x] ターゲットグループへのルーティングが設定される
- [x] `terraform plan`でエラーが発生しない

---

### 9. ECSクラスターの作成

_Requirements: 2.1_

ECS Fargateタスクを実行するためのクラスターを作成します。

#### 実装内容
- `ecs.tf`ファイルの作成（または`main.tf`内に実装）
- ECSクラスターリソースの作成
  - 名前: `${var.name_prefix}-basemachina-bridge`
  - Container Insightsの有効化
- タグの適用

#### 完了条件
- [x] ECSクラスターが作成される
- [x] Container Insightsが有効化される
- [x] `terraform plan`でエラーが発生しない

---

### 10. ECSタスク定義の作成

_Requirements: 2.2-2.4, 3.1-3.6, 7.3, 7.4_

Bridgeコンテナの実行仕様を定義するタスク定義を作成します。

#### 実装内容
- `ecs.tf`ファイルにタスク定義リソースを追加
- タスク定義の作成
  - ファミリー: `${var.name_prefix}-basemachina-bridge`
  - ネットワークモード: `awsvpc`
  - 互換性: `FARGATE`
  - CPU: `var.cpu`
  - メモリ: `var.memory`
  - タスク実行ロールARN: タスク実行ロールのARN
  - タスクロールARN: タスクロールのARN
- コンテナ定義の作成（JSON形式）
  - コンテナ名: `bridge`
  - イメージ: `public.ecr.aws/basemachina/bridge:latest`
  - ポートマッピング: `var.port`
  - 環境変数:
    - `FETCH_INTERVAL`: `var.fetch_interval`
    - `FETCH_TIMEOUT`: `var.fetch_timeout`
    - `PORT`: `var.port`（文字列に変換）
    - `TENANT_ID`: `var.tenant_id`
  - ログ設定:
    - ログドライバー: `awslogs`
    - オプション: ロググループ名、リージョン、ストリームプレフィックス
- タグの適用

#### 完了条件
- [x] タスク定義が作成される
- [x] Bridgeコンテナイメージが正しく参照される
- [x] 環境変数が正しく設定される
- [x] CloudWatch Logsへのログ転送が設定される
- [x] `terraform plan`でエラーが発生しない

---

### 11. ECSサービスの作成

_Requirements: 2.2, 2.5, 2.6, 4.2, 4.6_

ECS Fargateサービスを作成し、タスクのライフサイクルを管理します。

#### 実装内容
- `ecs.tf`ファイルにECSサービスリソースを追加
- ECSサービスの作成
  - 名前: `${var.name_prefix}-basemachina-bridge`
  - クラスター: ECSクラスターのID
  - タスク定義: タスク定義のARN
  - 起動タイプ: `FARGATE`
  - desired_count: `var.desired_count`
- ネットワーク構成
  - サブネット: `var.private_subnet_ids`
  - セキュリティグループ: BridgeセキュリティグループのID
  - パブリックIP割り当て: `false`
- ロードバランサー構成
  - ターゲットグループARN: BridgeターゲットグループのARN
  - コンテナ名: `bridge`
  - コンテナポート: `var.port`
- 依存関係: HTTPSリスナーに依存
- タグの適用

#### 完了条件
- [x] ECSサービスが作成される
- [x] Fargateタスクがプライベートサブネットに配置される
- [x] ALBターゲットグループに登録される
- [x] desired_countが正しく設定される
- [x] `terraform plan`でエラーが発生しない

---

### 12. 出力値の定義

_Requirements: 9.1-9.3_

デプロイ後に必要な情報を出力値として定義します。

#### 実装内容
- `outputs.tf`ファイルの作成
- 以下の出力値を定義
  - `alb_dns_name`: ALBのDNS名
  - `alb_arn`: ALBのARN
  - `alb_security_group_id`: ALBセキュリティグループのID
  - `ecs_cluster_name`: ECSクラスター名
  - `ecs_cluster_arn`: ECSクラスターARN
  - `ecs_service_name`: ECSサービス名
  - `bridge_security_group_id`: BridgeセキュリティグループのID
  - `cloudwatch_log_group_name`: CloudWatch Logsロググループ名
  - `task_execution_role_arn`: タスク実行ロールARN
  - `task_role_arn`: タスクロールARN
- 各出力値に明確な説明（description）を追加

#### 完了条件
- [x] すべての出力値が`outputs.tf`に定義されている
- [x] 各出力値に説明が含まれている
- [x] `terraform plan`でエラーが発生しない

---

### 13. モジュールREADMEの作成

_Requirements: 13.1-13.4_

モジュールの使用方法を詳細に記載したREADMEを作成します。

#### 実装内容
- `modules/aws/ecs-fargate/README.md`ファイルの更新
- 以下のセクションを含める
  - モジュール概要（BaseMachina Bridgeの説明）
  - 使用方法（基本的なモジュール呼び出し例）
  - 要件（Terraformバージョン、AWSプロバイダーバージョン、前提条件）
  - 入力変数セクション（terraform-docs用のプレースホルダー）
  - 出力値セクション（terraform-docs用のプレースホルダー）
  - 例（`examples/aws-ecs-fargate/`へのリンク）
  - セキュリティベストプラクティス
    - プライベートサブネット配置の推奨
    - IPホワイトリストの重要性
    - 機密情報の管理（Secrets Manager推奨）
    - CloudWatch Logsの監視
- terraform-docsの設定ファイル（`.terraform-docs.yml`）の作成

#### 完了条件
- [x] READMEにすべての必須セクションが含まれている
- [x] セキュリティベストプラクティスが明記されている
- [x] terraform-docsで自動生成できる設定がある

---

### 14. 実装例の作成

_Requirements: 12.1-12.4_

モジュールの使用例を`examples/aws-ecs-fargate/`ディレクトリに作成します。

#### 実装内容
- `examples/aws-ecs-fargate/`ディレクトリの作成
- `main.tf`ファイルの作成
  - モジュールの呼び出し例（ローカルパス参照）
  - 必須変数の設定例
- `variables.tf`ファイルの作成
  - カスタマイズ可能な変数の定義
- `outputs.tf`ファイルの作成
  - モジュールの出力値を再エクスポート
- `terraform.tfvars.example`ファイルの作成
  - 変数の設定例（VPC ID、サブネットID、証明書ARN、テナントIDなど）
- `README.md`ファイルの作成
  - 前提条件（VPC、サブネット、ACM証明書、データベース等の事前準備）
  - デプロイ手順（terraform init、plan、apply）
  - カスタマイズ方法
  - クリーンアップ手順（terraform destroy）

#### 完了条件
- [x] `examples/aws-ecs-fargate/`ディレクトリにすべてのファイルが存在する
- [x] サンプルが最小限の変数設定でデプロイ可能
- [x] READMEに明確な手順が記載されている

---

### 15. Terraformモジュールのフォーマットと検証

_Requirements: 1.3, 10.1_

コードフォーマットと構文検証を実施し、Terraformのベストプラクティスに準拠します。

#### 実装内容
- `terraform fmt -recursive`の実行
- `terraform validate`の実行
- 必要に応じてコード修正

#### 完了条件
- [x] すべてのTerraformファイルがフォーマットされている
- [x] `terraform validate`が成功する
- [x] コードが読みやすく、一貫性がある

---

### 16. tfsecセキュリティスキャン

_Requirements: なし（セキュリティ品質保証）_

tfsecを使用してTerraformコードのセキュリティ脆弱性をスキャンし、修正します。

#### 実装内容
- tfsecのインストール確認（`tfsec --version`）
- モジュールディレクトリでtfsecを実行（`tfsec modules/aws/ecs-fargate/`）
- 検出された問題の確認と分類
  - CRITICAL/HIGH: 必須修正
  - MEDIUM: 推奨修正
  - LOW: 任意修正
- セキュリティ問題の修正
  - セキュリティグループルールの過度な許可の確認
  - IAMロールの最小権限原則の検証
  - 暗号化設定の確認（CloudWatch Logs等）
  - リソースへのタグ付けの確認
- 正当な警告への対応
  - `.tfsec/config.yml`または`tfsec:ignore`コメントで抑制
  - 抑制理由を明記
- 再スキャンで問題がないことを確認

#### 完了条件
- [x] tfsecスキャンが実行され、結果が確認されている
- [x] CRITICAL/HIGH問題がすべて修正されている
- [x] 正当な警告には抑制設定と理由が記載されている
- [x] 最終スキャンでCRITICAL/HIGH問題が0件である

---

### 17. Terratest統合テストの作成

_Requirements: なし（品質保証）_

実環境でのデプロイをテストするためのTerratestコードを作成します。

#### 実装内容
- `test/aws/ecs_fargate_test.go`ファイルの作成
- テストケースの実装
  - モジュールのapplyが成功すること
  - すべての出力値が空でないこと
  - ECS Serviceがdesired_countのタスクを実行していること
  - ALBのヘルスチェックがhealthyであること
- `terraform destroy`による自動クリーンアップの実装

#### 完了条件
- [x] Terratestコードが実装されている
- [x] テストが実行可能である（AWS認証情報が設定済みの環境）
- [x] テスト後にリソースが自動的に削除される

---

### 18. ドキュメントの最終レビューとterraform-docs実行

_Requirements: 13.2_

terraform-docsを実行し、READMEの変数と出力セクションを自動生成します。

#### 実装内容
- terraform-docsのインストール確認
- `terraform-docs markdown table modules/aws/ecs-fargate/`の実行
- 生成されたマークダウンをREADMEに統合
- ドキュメント全体の整合性確認

#### 完了条件
- [x] READMEに変数と出力の詳細情報が自動生成されている
- [x] ドキュメントが完全で、誤りがない
- [x] すべてのリンクが正しい

---

## タスク実行順序の推奨

以下の順序で実装することを推奨します：

1. タスク1（プロジェクト構造）
2. タスク2（入力変数）
3. タスク3（IAMロール）
4. タスク4（CloudWatch Logs）
5. タスク5（セキュリティグループ）
6. タスク6（ALB）
7. タスク7（ターゲットグループ）
8. タスク8（HTTPSリスナー）
9. タスク9（ECSクラスター）
10. タスク10（タスク定義）
11. タスク11（ECSサービス）
12. タスク12（出力値）
13. タスク13（モジュールREADME）
14. タスク14（実装例）
15. タスク15（フォーマットと検証）
16. タスク16（tfsecセキュリティスキャン）
17. タスク17（Terratestテスト）
18. タスク18（terraform-docs実行）

各タスクの依存関係を考慮し、前のタスクが完了してから次のタスクに進むことで、スムーズな実装が可能です。

## 進捗追跡

各タスクの進捗は、`/kiro:spec-status aws-ecs-fargate-bridge`コマンドで確認できます。タスクが完了したら、チェックボックスにチェックを入れ、進捗を更新してください。
