# 実装計画

## Overview

本実装計画は、ECS Fargate Bridgeモジュールの完全な実装を目的としています。既存の機能別ファイル（alb.tf、ecs.tf、iam.tf、logs.tf、security_groups.tf）にリソース定義を追加し、outputs.tfで参照されている全リソースを定義します。

## Implementation Tasks

- [x] 1. IAMロールとCloudWatch Logsの基盤を構築する
- [x] 1.1 タスク実行ロールとタスクロールを実装する
  - タスク実行ロールを作成し、ECSタスク起動に必要な権限を設定する
  - AmazonECSTaskExecutionRolePolicyをアタッチする
  - タスクロールを作成し、Bridgeアプリケーションの実行権限を設定する
  - 最小権限の原則に従い、タスクロールには現時点で追加ポリシーをアタッチしない
  - リソース名はoutputs.tfとの整合性を保つ（task_execution、task）
  - _Requirements: 6.1, 6.2, 6.3, 6.5, 6.6, 6.7, 8.9, 8.10_

- [x] 1.2 CloudWatch Logsロググループを作成する
  - Bridgeコンテナのログを集約するロググループを作成する
  - ログ保持期間を変数から取得し、デフォルト7日間とする
  - ロググループ名にname_prefixを反映する
  - リソース名はoutputs.tfとの整合性を保つ（bridge）
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 8.8, 11.3_

- [x] 1.3 CloudWatch Logs書き込み権限をタスク実行ロールに追加する
  - タスク実行ロールにCloudWatch Logsへの書き込み権限を付与するインラインポリシーを作成する
  - logs:CreateLogStreamとlogs:PutEventsを許可する
  - ロググループのARNを正確に参照する
  - _Requirements: 6.4_

- [x] 2. セキュリティグループを実装してネットワークアクセスを制御する
- [x] 2.1 ALBセキュリティグループを作成する
  - ALB用のセキュリティグループを作成する
  - BaseMachina SaaS（34.85.43.93/32）からのHTTPS（443）インバウンドを許可する
  - 全てのアウトバウンドトラフィック（0.0.0.0/0）を許可する
  - リソース名はoutputs.tfとの整合性を保つ（alb）
  - name_prefixとtagsを適用する
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 8.3, 11.3_

- [x] 2.2 Bridgeセキュリティグループを作成する
  - Bridge用のセキュリティグループを作成する
  - ALBセキュリティグループからのHTTP（var.port）インバウンドを許可する
  - 全てのアウトバウンドトラフィック（0.0.0.0/0）を許可する（BaseMachina API、データソースへのアクセス）
  - リソース名はoutputs.tfとの整合性を保つ（bridge）
  - name_prefixとtagsを適用する
  - bridge_security_group_id出力値としてユーザーが接続先リソースへのルールを追加できるようにする
  - _Requirements: 5.5, 5.6, 5.7, 5.8, 5.9, 8.7, 9.5, 11.3_

- [x] 3. Application Load Balancerを実装してHTTPS終端とルーティングを行う
- [x] 3.1 ALBとターゲットグループを作成する
  - インターネット向けALBを作成する（internal = false）
  - パブリックサブネットに配置する
  - ALBセキュリティグループを適用する
  - Fargate用のターゲットグループを作成する（target_type = ip）
  - ターゲットグループのポート、プロトコル、VPC IDを設定する
  - ヘルスチェックを設定する（path: /ok、protocol: HTTP、matcher: 200、interval: 30、timeout: 5）
  - リソース名はoutputs.tfとの整合性を保つ（main）
  - name_prefixとtagsを適用する
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10, 8.1, 8.2, 11.3_

- [x] 3.2 HTTPSリスナーを作成する
  - ALBのHTTPSリスナー（ポート443）を作成する
  - SSL証明書ARNを変数から取得する
  - TLS 1.3/1.2セキュリティポリシーを設定する
  - デフォルトアクションとしてターゲットグループへのフォワードを設定する
  - _Requirements: 4.11, 4.12, 4.13, 4.14, 11.3, 12.1_

- [x] 4. ECS Fargateクラスター、サービス、タスク定義を実装する
- [x] 4.1 ECSクラスターを作成する
  - ECSクラスターを作成する
  - Container Insightsを有効化する
  - クラスター名にname_prefixを反映する
  - リソース名はoutputs.tfとの整合性を保つ（main）
  - tagsを適用する
  - _Requirements: 2.1, 2.2, 8.4, 8.5, 11.3_

- [x] 4.2 タスク定義を作成する
  - Fargate用のタスク定義を作成する（network_mode: awsvpc、requires_compatibilities: FARGATE）
  - CPUとメモリを変数から取得する
  - タスク実行ロールとタスクロールを適用する
  - Bridgeコンテナイメージ（public.ecr.aws/basemachina/bridge:latest）を指定する
  - 環境変数を設定する（FETCH_INTERVAL、FETCH_TIMEOUT、PORT、TENANT_ID）
  - ポートマッピングを設定する（containerPort: var.port）
  - CloudWatch Logsログ設定を追加する（awslogsドライバー）
  - 現在のAWSリージョンを取得するデータソースを追加する
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 11.3_

- [x] 4.3 ECSサービスを作成する
  - Fargate起動タイプのECSサービスを作成する
  - desired_countを変数から取得する
  - プライベートサブネットに配置する
  - Bridgeセキュリティグループを適用する
  - assign_public_ip設定を変数から取得する
  - ALBターゲットグループにロードバランサー設定を追加する
  - HTTPSリスナーへの依存関係を明示する（depends_on）
  - リソース名はoutputs.tfとの整合性を保つ（bridge）
  - サービス名にname_prefixを反映する
  - tagsを適用する
  - _Requirements: 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 8.6, 11.3_

- [x] 5. モジュール全体の統合と検証を行う
- [x] 5.1 全変数がリソース定義で正しく使用されていることを確認する
  - variables.tfで定義された全14変数がリソース定義で使用されることを確認する
  - vpc_id、サブネットID、certificate_arn、tenant_id、fetch_interval、fetch_timeout、port、cpu、memory、desired_count、assign_public_ip、log_retention_days、tags、name_prefixの使用を確認する
  - 未使用の変数や参照エラーがないことを確認する
  - _Requirements: 11.1, 11.2, 11.3_

- [x] 5.2 オプション変数のハンドリングを確認する
  - certificate_arnがnullの場合の動作を確認する（エラーメッセージまたは条件付き処理）
  - name_prefixが空文字列の場合にリソース名が正しく生成されることを確認する
  - tagsが空のmapの場合にリソースが作成されることを確認する
  - _Requirements: 12.1, 12.2, 12.3_

- [x] 5.3 outputs.tfとの整合性を検証する
  - outputs.tfで参照されている全10リソースが正しく定義されていることを確認する
  - aws_lb.main、aws_security_group.alb、aws_ecs_cluster.main、aws_ecs_service.bridge、aws_security_group.bridge、aws_cloudwatch_log_group.bridge、aws_iam_role.task_execution、aws_iam_role.taskの定義を確認する
  - terraform planが成功し、エラーが発生しないことを確認する
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9, 8.10_

- [x] 6. Terraformコードの品質チェックとフォーマットを実行する
- [x] 6.1 Terraformコードのフォーマットと構文検証を行う
  - terraform fmtでコードフォーマットを実行する
  - terraform validateで構文を検証する
  - 全てのバリデーションブロックが正しく動作することを確認する（port != 4321、desired_count >= 1、サブネットリストが空でない）
  - _Requirements: 全要件に対する基本的な品質保証_

- [x] 6.2 機能別ファイルの責任境界を確認する
  - alb.tfにALB、ターゲットグループ、リスナーが定義されていることを確認する
  - ecs.tfにECSクラスター、サービス、タスク定義が定義されていることを確認する
  - security_groups.tfにALBとBridgeのセキュリティグループが定義されていることを確認する
  - iam.tfにタスク実行ロール、タスクロール、ポリシーアタッチメントが定義されていることを確認する
  - logs.tfにCloudWatch Logsロググループが定義されていることを確認する
  - main.tfが空のまま維持されていることを確認する
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 7. Exampleとテストの動作確認を行う
- [x] 7.1 Exampleが最小限の変数でデプロイ可能であることを確認する
  - examples/aws-ecs-fargate/main.tfがモジュールを正しく呼び出していることを確認する
  - 必須変数（vpc_id、private_subnet_ids、public_subnet_ids、tenant_id）のみでデプロイ可能であることを確認する
  - certificate_arnがオプションであることを確認する
  - モジュールが全リソース（ALB、ECS、セキュリティグループなど）を自動的に作成することを確認する
  - terraform outputで全10出力値が取得可能であることを確認する
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [x] 7.2 Terratestによる統合テストの実行準備を確認する
  - test/aws/ecs_fargate_test.goがモジュールを正しくapplyできることを確認する
  - テストがECSサービスのタスク数（desired_count）を検証できることを確認する
  - テストがALBターゲットグループのヘルスチェック（healthy状態）を検証できることを確認する
  - テストが全10出力値を取得できることを確認する
  - terraform destroyで全リソースがクリーンアップされることを確認する
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

## Requirements Coverage

全12要件がタスクでカバーされています：

- **Requirement 1**: ファイル構造の整理 → Task 6.2
- **Requirement 2**: ECSクラスターとサービス → Task 4.1, 4.3
- **Requirement 3**: ECSタスク定義 → Task 4.2
- **Requirement 4**: ALB → Task 3.1, 3.2
- **Requirement 5**: セキュリティグループ → Task 2.1, 2.2
- **Requirement 6**: IAMロール → Task 1.1, 1.3
- **Requirement 7**: CloudWatch Logs → Task 1.2
- **Requirement 8**: outputs.tfとの整合性 → Task 5.3
- **Requirement 9**: Exampleの簡略化 → Task 7.1
- **Requirement 10**: テストの実行可能化 → Task 7.2
- **Requirement 11**: variables.tfとの整合性 → Task 5.1
- **Requirement 12**: オプション変数のハンドリング → Task 5.2

## Implementation Notes

- **実装順序**: IAMとロググループ → セキュリティグループ → ALB → ECS の順に実装することで、依存関係を満たします
- **リソース名の厳守**: outputs.tfで参照されているリソース名を変更しないでください
- **機能別ファイルの活用**: 既存のファイル構造（alb.tf、ecs.tf、iam.tf、logs.tf、security_groups.tf）を使用し、main.tfは空のまま維持します
- **データベース接続**: モジュールは`bridge_security_group_id`を出力し、ユーザーが接続先リソースへのセキュリティグループルールを自分で追加します
- **タグとname_prefix**: 全リソースに`var.tags`と`var.name_prefix`を適用してください

## Next Steps

タスクの実装を開始するには、以下のコマンドを使用してください：

```bash
/kiro:spec-impl ecs-fargate-implementation          # 全タスクを実行
/kiro:spec-impl ecs-fargate-implementation 1.1      # 特定のタスクを実行
/kiro:spec-impl ecs-fargate-implementation 1,2,3    # 複数のタスクを実行
```
