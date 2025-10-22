# 要件定義書

## イントロダクション

このプロジェクトでは、BaseMachina Bridge Terraform Modulesのドキュメント（README.md、モジュールREADME、exampleのREADME、テストドキュメント等）を現状の実装に合わせて調査・修正します。

AWS ECS FargateとGCP Cloud Runの両モジュールが実装完了していますが、ドキュメントが最新の実装を正確に反映していない箇所が存在します。特に、必須/オプションのパラメータ、テスト手順、前提条件、ネットワーク構成などで不整合が見られます。

このドキュメント整合化により、ユーザーが正確な情報に基づいてモジュールを利用できるようにし、トラブルシューティングの時間を削減し、プロジェクトの信頼性を向上させます。

## 要件

### 要件1: 実装コードの調査と分析

**目的:** 開発者として、現在の実装状態を正確に把握したい。その結果、ドキュメント修正の基準となる信頼できる情報源を確保できる。

#### 受入基準

1. WHEN 実装調査を開始する THEN ドキュメント調査システム SHALL 全モジュールのvariables.tfファイルを読み込む
2. WHEN 実装調査を開始する THEN ドキュメント調査システム SHALL 全モジュールのoutputs.tfファイルを読み込む
3. WHEN 実装調査を開始する THEN ドキュメント調査システム SHALL 全テストコード（test/aws/、test/gcp/）を分析する
4. WHEN 実装調査を開始する THEN ドキュメント調査システム SHALL 各変数の必須/オプション属性、デフォルト値、バリデーションルールを記録する
5. WHEN 実装調査を開始する THEN ドキュメント調査システム SHALL テストで使用される環境変数と実行手順を記録する
6. WHEN 実装調査を開始する THEN ドキュメント調査システム SHALL ネットワーク構成（VPCエンドポイント、NAT Gateway、Direct VPC Egress等）の実装詳細を記録する

### 要件2: ドキュメントと実装の差分検出

**目的:** 開発者として、ドキュメントと実装の不整合箇所を特定したい。その結果、修正が必要な箇所を優先順位付けして対応できる。

#### 受入基準

1. WHEN ドキュメント分析を実行する THEN ドキュメント調査システム SHALL ルートREADME.mdの使用例と実際のvariables.tfを比較する
2. WHEN ドキュメント分析を実行する THEN ドキュメント調査システム SHALL modules/aws/ecs-fargate/README.mdと実装を比較する
3. WHEN ドキュメント分析を実行する THEN ドキュメント調査システム SHALL modules/gcp/cloud-run/README.mdと実装を比較する
4. WHEN ドキュメント分析を実行する THEN ドキュメント調査システム SHALL examples/aws-ecs-fargate/README.mdと実装を比較する
5. WHEN ドキュメント分析を実行する THEN ドキュメント調査システム SHALL examples/gcp-cloud-run/README.mdと実装を比較する
6. WHEN ドキュメント分析を実行する THEN ドキュメント調査システム SHALL test/README.mdと実際のテスト実装を比較する
7. WHEN 不整合を検出する THEN ドキュメント調査システム SHALL 各不整合に対して影響度（Critical/High/Medium/Low）を評価する
8. WHERE 変数の必須/オプション属性が異なる THE ドキュメント調査システム SHALL 影響度をCriticalと評価する
9. WHERE デフォルト値が異なる THE ドキュメント調査システム SHALL 影響度をHighと評価する
10. WHERE 説明文が不正確または古い THE ドキュメント調査システム SHALL 影響度をMediumと評価する

### 要件3: AWS ECS Fargateモジュールドキュメント修正

**目的:** ユーザーとして、AWS ECS Fargateモジュールの正確なドキュメントを参照したい。その結果、正しいパラメータでモジュールをデプロイできる。

#### 受入基準

1. WHEN ドキュメントを修正する THEN AWS ECS Fargateモジュールドキュメント SHALL certificate_arnが必須であることを明記する
2. WHEN ドキュメントを修正する THEN AWS ECS Fargateモジュールドキュメント SHALL domain_nameとroute53_zone_idが必須であることを明記する
3. WHEN ドキュメントを修正する THEN AWS ECS Fargateモジュールドキュメント SHALL nat_gateway_idがオプション（デフォルト: 新規NAT Gateway作成）であることを明記する
4. WHEN ドキュメントを修正する THEN AWS ECS Fargateモジュールドキュメント SHALL VPCエンドポイント + NAT Gatewayのハイブリッド構成を推奨構成として記載する
5. WHEN ドキュメントを修正する THEN AWS ECS Fargateモジュールドキュメント SHALL Public ECR (public.ecr.aws) からのイメージpullにNAT Gatewayが必須であることを明記する
6. WHEN ドキュメントを修正する THEN AWS ECS Fargateモジュールドキュメント SHALL ECRプルスルーキャッシュ機能について説明する
7. WHEN ドキュメントを修正する THEN AWS ECS Fargateモジュールドキュメント SHALL すべての入力変数と出力値が実装と一致することを確認する

### 要件4: GCP Cloud Runモジュールドキュメント修正

**目的:** ユーザーとして、GCP Cloud Runモジュールの正確なドキュメントを参照したい。その結果、正しいパラメータでモジュールをデプロイできる。

#### 受入基準

1. WHEN ドキュメントを修正する THEN GCP Cloud Runモジュールドキュメント SHALL project_idとtenant_idが必須であることを明記する
2. WHEN ドキュメントを修正する THEN GCP Cloud Runモジュールドキュメント SHALL domain_nameがオプション（HTTPS使用時は必須）であることを明記する
3. WHEN ドキュメントを修正する THEN GCP Cloud Runモジュールドキュメント SHALL allowed_ip_rangesのデフォルト動作（BaseMachina IP自動追加）を正確に記載する
4. WHEN ドキュメントを修正する THEN GCP Cloud Runモジュールドキュメント SHALL Direct VPC Egress（推奨）とVPC Connector（レガシー）の違いを説明する
5. WHEN ドキュメントを修正する THEN GCP Cloud Runモジュールドキュメント SHALL vpc_network_idとvpc_subnetwork_idの要件（Direct VPC Egress使用時は必須）を明記する
6. WHEN ドキュメントを修正する THEN GCP Cloud Runモジュールドキュメント SHALL Cloud Armorのセキュリティポリシー動作を説明する
7. WHEN ドキュメントを修正する THEN GCP Cloud Runモジュールドキュメント SHALL すべての入力変数と出力値が実装と一致することを確認する

### 要件5: テストドキュメント修正

**目的:** テスト実行者として、正確なテスト手順とセットアップ情報を参照したい。その結果、テストを正しくセットアップして実行できる。

#### 受入基準

1. WHEN テストドキュメントを修正する THEN test/README.md SHALL AWS ECS Fargateテストに必要な環境変数リストを実装と一致させる
2. WHEN テストドキュメントを修正する THEN test/README.md SHALL GCP Cloud Runテストに必要な環境変数リストを実装と一致させる
3. WHEN テストドキュメントを修正する THEN test/README.md SHALL NAT Gateway必須の理由（Public ECR access）を明記する
4. WHEN テストドキュメントを修正する THEN test/README.md SHALL VPCエンドポイント + NAT Gatewayハイブリッド構成の利点を説明する
5. WHEN テストドキュメントを修正する THEN test/README.md SHALL テスト実行時間の見積もり（AWS: 30-45分、GCP: 20-30分）を記載する
6. WHEN テストドキュメントを修正する THEN test/README.md SHALL テストクリーンアップ手順（terraform destroy）を記載する
7. WHEN テストドキュメントを修正する THEN test/README.md SHALL トラブルシューティングセクションを実際のエラーケースに基づいて更新する

### 要件6: Exampleドキュメント修正

**目的:** ユーザーとして、動作するexampleの正確なセットアップ手順を参照したい。その結果、exampleを使って迅速にBridgeをデプロイできる。

#### 受入基準

1. WHEN exampleドキュメントを修正する THEN examples/aws-ecs-fargate/README.md SHALL 前提条件セクションに必須リソース（VPC、サブネット、Route53 Hosted Zone）を明記する
2. WHEN exampleドキュメントを修正する THEN examples/aws-ecs-fargate/README.md SHALL terraform.tfvars.exampleと実際の変数定義が一致することを確認する
3. WHEN exampleドキュメントを修正する THEN examples/aws-ecs-fargate/README.md SHALL ACM証明書のDNS検証が自動実行されることを説明する
4. WHEN exampleドキュメントを修正する THEN examples/gcp-cloud-run/README.md SHALL 前提条件セクションに必須API有効化手順を記載する
5. WHEN exampleドキュメントを修正する THEN examples/gcp-cloud-run/README.md SHALL terraform.tfvars.exampleと実際の変数定義が一致することを確認する
6. WHEN exampleドキュメントを修正する THEN examples/gcp-cloud-run/README.md SHALL Cloud SQL接続方法（Cloud SQL Proxy、VPC経由）を説明する
7. WHEN exampleドキュメントを修正する THEN 両exampleドキュメント SHALL デプロイ後の検証手順（HTTPS疎通確認、ヘルスチェック）を記載する

### 要件7: ルートREADME修正

**目的:** プロジェクトの初見ユーザーとして、プロジェクト全体の正確な概要を把握したい。その結果、適切なクラウドプロバイダーとモジュールを選択できる。

#### 受入基準

1. WHEN ルートREADMEを修正する THEN README.md SHALL 両クラウドプロバイダー（AWS、GCP）が実装済みであることを明記する
2. WHEN ルートREADMEを修正する THEN README.md SHALL クイックスタートセクションの使用例が最新の必須変数を含むことを確認する
3. WHEN ルートREADMEを修正する THEN README.md SHALL 主要機能リストが実装済み機能（ECRプルスルーキャッシュ、Cloud Armor等）を含むことを確認する
4. WHEN ルートREADMEを修正する THEN README.md SHALL ディレクトリ構造セクションが現在のファイル構成と一致することを確認する
5. WHEN ルートREADMEを修正する THEN README.md SHALL ドキュメントリンクセクションが存在する全READMEへのリンクを含むことを確認する
6. WHEN ルートREADMEを修正する THEN README.md SHALL セキュリティベストプラクティスが最新のネットワーク構成を反映することを確認する

### 要件8: ドキュメント品質検証

**目的:** プロジェクトメンテナーとして、修正後のドキュメントが高品質であることを確認したい。その結果、長期的にメンテナンスしやすいドキュメントを維持できる。

#### 受入基準

1. WHEN ドキュメント修正が完了する THEN ドキュメント品質検証システム SHALL 全markdownファイルの構文エラーをチェックする
2. WHEN ドキュメント修正が完了する THEN ドキュメント品質検証システム SHALL 全コードブロックの言語指定（```hcl、```bash等）が正しいことを確認する
3. WHEN ドキュメント修正が完了する THEN ドキュメント品質検証システム SHALL 内部リンク（ファイルパス）が正しいことを確認する
4. WHEN ドキュメント修正が完了する THEN ドキュメント品質検証システム SHALL terraform-docs生成セクション（BEGIN_TF_DOCS～END_TF_DOCS）が実装と一致することを確認する
5. WHEN ドキュメント修正が完了する THEN ドキュメント品質検証システム SHALL 日本語と英語の混在が適切であることを確認する
6. WHERE ドキュメントに技術用語を含む THE ドキュメント品質検証システム SHALL 用語の一貫性（例: "NAT Gateway"の表記統一）を確認する
7. WHERE ドキュメントに手順を含む THE ドキュメント品質検証システム SHALL 手順の完全性と実行可能性を確認する
