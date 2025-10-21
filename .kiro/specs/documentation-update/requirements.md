# Requirements Document

## Introduction

このプロジェクトは、BaseMachina Terraform Modulesプロジェクトのドキュメント（README.md等）を、現在の実装に合わせて正確かつ包括的に更新することを目的としています。

最近の実装変更（Route53統合、DNS検証によるACM証明書発行、複数の証明書オプション、テスト強化など）により、ドキュメントと実装の間にギャップが生じています。これらのギャップを解消し、ユーザーが最新の機能と正確な使用方法を理解できるようにします。

## Requirements

### Requirement 1: モジュールドキュメントの正確性

**Objective:** モジュール利用者として、modules/aws/ecs-fargate/README.mdに記載されている変数、オプション、使用例が現在の実装と完全に一致していることを期待する。これにより、モジュールを正しく使用し、予期しないエラーを回避できる。

#### Acceptance Criteria

1. WHEN モジュールREADME（modules/aws/ecs-fargate/README.md）を参照する THEN ドキュメント SHALL variables.tfに定義されているすべての入力変数を正確に記載する
2. WHEN 使用例を参照する THEN ドキュメント SHALL 以下の必須変数を含む完全な例を提供する:
   - `certificate_arn`（必須）
   - `domain_name`と`route53_zone_id`（Route53統合用、必須）
   - その他のネットワーク関連変数
3. WHEN ドメイン設定のセクションを読む THEN ドキュメント SHALL Route53 Hosted Zoneとの統合方法を説明する
4. WHEN 証明書オプションのセクションを読む THEN ドキュメント SHALL 以下の証明書設定パターンを明確に説明する:
   - DNS検証によるACM証明書自動発行（推奨）
   - 自己署名証明書のACMインポート
   - 既存のACM証明書の利用
   - HTTPのみの構成（非推奨）
5. WHEN ネットワーク要件のセクションを読む THEN ドキュメント SHALL NAT Gateway、VPCエンドポイント、ECRプルスルーキャッシュの役割と設定を説明する

### Requirement 2: Exampleドキュメントの完全性

**Objective:** Example利用者として、examples/aws-ecs-fargate/README.mdに記載されているデプロイ手順、オプション、前提条件が現在の実装と完全に一致していることを期待する。これにより、スムーズにBridgeをデプロイできる。

#### Acceptance Criteria

1. WHEN 前提条件のセクションを読む THEN ドキュメント SHALL 以下のリソースの必要性を説明する:
   - VPCとサブネット（パブリック・プライベート）
   - Route53 Hosted Zone（DNS検証を使用する場合、必須）
   - BaseMachinaテナントID
   - AWS認証情報
2. WHEN デプロイ手順のセクションを読む THEN ドキュメント SHALL 以下のステップを含む:
   - terraform.tfvarsの設定（bridge_domain_nameとroute53_zone_idを含む）
   - terraform init、plan、applyの実行
   - DNS検証待機時間（5-15分）の説明
   - デプロイ後の確認方法
3. WHEN 証明書設定のセクションを読む THEN ドキュメント SHALL 3つの証明書オプションの設定方法を説明する:
   - DNS検証による自動発行（bridge_domain_nameとroute53_zone_idの設定）
   - 自己署名証明書（enable_acm_import = trueの設定）
   - 既存のACM証明書（certificate_arnの設定）
4. WHEN RDS統合のセクションを読む THEN ドキュメント SHALL RDS variables（database_username、database_passwordなど）の設定方法とBastion hostの使用方法を説明する
5. WHEN トラブルシューティングのセクションを読む THEN ドキュメント SHALL 以下の一般的な問題の解決方法を提供する:
   - ACM証明書のDNS検証が完了しない
   - ECSタスクが起動しない
   - ALBヘルスチェックが失敗する

### Requirement 3: テストドキュメントの正確性

**Objective:** テスト実行者として、test/README.mdに記載されているテスト手順、環境変数、実行時間が現在の実装と完全に一致していることを期待する。これにより、テストを正しく実行し、予期しない失敗を回避できる。

#### Acceptance Criteria

1. WHEN 環境変数のセクションを読む THEN ドキュメント SHALL 以下の環境変数を正確に記載する:
   - TEST_VPC_ID、TEST_PRIVATE_SUBNET_IDS、TEST_PUBLIC_SUBNET_IDS（必須）
   - TEST_TENANT_ID（必須）
   - TEST_BRIDGE_DOMAIN_NAME、TEST_ROUTE53_ZONE_ID（DNS検証オプション）
   - TEST_ENABLE_ACM_IMPORT（自己署名証明書オプション）
   - TEST_CERTIFICATE_ARN（既存証明書オプション）
2. WHEN テスト実行コマンドのセクションを読む THEN ドキュメント SHALL 正しいタイムアウト値（60m）を含むコマンド例を提供する
3. WHEN 実行時間のセクションを読む THEN ドキュメント SHALL DNS検証を使用する場合の所要時間（15-20分）を記載する
4. WHEN トラブルシューティングのセクションを読む THEN ドキュメント SHALL ACM証明書のDNS検証問題の診断方法（diagnose-dns-validation.shスクリプトの使用）を説明する
5. WHEN テスト内容のセクションを読む THEN ドキュメント SHALL 以下のテスト項目を記載する:
   - Route53 Hosted Zoneの存在確認（DNS検証使用時）
   - ACM証明書のDNS検証（最大15分タイムアウト）
   - ECSタスクの起動確認
   - ALBヘルスチェック
   - HTTPS エンドポイントの疎通確認

### Requirement 4: プロジェクトルートドキュメントの概要性

**Objective:** プロジェクト初見者として、README.mdに記載されているプロジェクト概要、主要機能、クイックスタートが現在の実装の主要な機能を反映していることを期待する。これにより、プロジェクトの全体像を素早く理解できる。

#### Acceptance Criteria

1. WHEN プロジェクト概要のセクションを読む THEN ドキュメント SHALL プロジェクトの目的と主要なユースケースを簡潔に説明する
2. WHEN 主要機能のセクションを読む THEN ドキュメント SHALL 以下の最新機能を列挙する:
   - Route53統合によるDNS管理
   - DNS検証によるACM証明書の自動発行
   - 複数の証明書オプション（DNS検証、自己署名、既存証明書、HTTP）
   - VPCエンドポイント + NAT Gatewayのハイブリッド構成
   - Terratestによる包括的な統合テスト
3. WHEN クイックスタートのセクションを読む THEN ドキュメント SHALL examples/aws-ecs-fargateへの明確なリンクとステップを提供する
4. WHEN ディレクトリ構造のセクションを読む（存在する場合） THEN ドキュメント SHALL modules/、examples/、test/ディレクトリの役割を説明する

### Requirement 5: ドキュメント間の一貫性

**Objective:** ドキュメント利用者として、複数のREADMEファイル（ルート、モジュール、example、test）間で用語、オプション名、説明が一貫していることを期待する。これにより、混乱を避け、スムーズに理解を進められる。

#### Acceptance Criteria

1. WHEN 複数のドキュメントで同じ変数を参照する THEN ドキュメント SHALL すべての箇所で同じ変数名と説明を使用する
2. WHEN 複数のドキュメントで証明書オプションを説明する THEN ドキュメント SHALL 一貫した用語（DNS検証、自己署名証明書、既存証明書、HTTP）を使用する
3. WHEN 複数のドキュメントでネットワーク構成を説明する THEN ドキュメント SHALL NAT Gateway、VPCエンドポイント、ECRプルスルーキャッシュの役割について一貫した説明を提供する
4. WHEN ドキュメント間でコマンド例を参照する THEN ドキュメント SHALL 同じフォーマットとオプションを使用する

### Requirement 6: 変更履歴とバージョン情報（オプション）

**Objective:** ドキュメント利用者として、最近の変更点やバージョン情報を確認できることを期待する。これにより、以前のバージョンからの移行や新機能の把握が容易になる。

#### Acceptance Criteria

1. IF ドキュメントに変更履歴セクションが存在する THEN ドキュメント SHALL 最近の主要な変更（Route53統合、DNS検証、テスト強化など）を記載する
2. IF モジュールがバージョン管理されている THEN ドキュメント SHALL 推奨バージョンや互換性情報を提供する
