# 実装計画

## 概要

このドキュメント整合化プロジェクトでは、BaseMachina Bridge Terraform Modulesの実装とドキュメントの不整合を系統的に検出・修正します。全8つの要件をカバーする以下のタスクを、影響度（Critical → High → Medium）の順に実行します。

## 実装タスク

- [ ] 1. AWS ECS Fargateモジュールの実装調査と分析
- [ ] 1.1 AWS ECS Fargateモジュールの変数定義を分析する
  - modules/aws/ecs-fargate/variables.tfを読み込む
  - 各変数の必須/オプション属性（defaultの有無）を記録する
  - デフォルト値、型、バリデーションルールを抽出する
  - certificate_arn、domain_name、route53_zone_idの必須属性を確認する
  - nat_gateway_idのオプション属性（デフォルト: null）を確認する
  - _要件: 1.1, 1.4_

- [ ] 1.2 AWS ECS Fargateモジュールの出力定義を分析する
  - modules/aws/ecs-fargate/outputs.tfを読み込む
  - 各出力の説明、機密フラグを記録する
  - ALB関連出力（alb_dns_name、alb_arn等）の存在を確認する
  - NAT Gateway関連出力（nat_gateway_id、nat_gateway_public_ip）の存在を確認する
  - VPCエンドポイント関連出力の存在を確認する
  - _要件: 1.2_

- [ ] 1.3 AWS ECS Fargateモジュールのネットワーク構成を分析する
  - modules/aws/ecs-fargate/alb.tf、ecs.tf、security_groups.tfを読み込む
  - VPCエンドポイント（ECR API、ECR DKR、S3、CloudWatch Logs）の実装を確認する
  - NAT Gateway作成ロジック（新規作成/既存利用）を確認する
  - ECRプルスルーキャッシュの実装を確認する
  - Public ECR (public.ecr.aws) へのアクセス要件を記録する
  - _要件: 1.6_

- [ ] 2. GCP Cloud Runモジュールの実装調査と分析
- [ ] 2.1 GCP Cloud Runモジュールの変数定義を分析する
  - modules/gcp/cloud-run/variables.tfを読み込む
  - 各変数の必須/オプション属性を記録する
  - project_id、tenant_idの必須属性を確認する
  - domain_nameのオプション属性（デフォルト: null）を確認する
  - allowed_ip_rangesのデフォルト値（空リスト）を確認する
  - vpc_network_id、vpc_subnetwork_idの条件付き必須要件を確認する
  - _要件: 1.1, 1.4_

- [ ] 2.2 GCP Cloud Runモジュールの出力定義を分析する
  - modules/gcp/cloud-run/outputs.tfを読み込む
  - 各出力の説明を記録する
  - Cloud Run関連出力（service_url、service_name等）の存在を確認する
  - Load Balancer関連出力（load_balancer_ip）の存在を確認する
  - SSL証明書関連出力の存在を確認する
  - _要件: 1.2_

- [ ] 2.3 GCP Cloud Runモジュールのネットワーク構成を分析する
  - modules/gcp/cloud-run/cloud_run.tf、load_balancer.tfを読み込む
  - Direct VPC Egress実装を確認する
  - VPC Connector（レガシー）との違いを記録する
  - Cloud Armorセキュリティポリシーの実装を確認する
  - allowed_ip_rangesのデフォルト動作（BaseMachina IP自動追加ロジック）を確認する
  - _要件: 1.6_

- [ ] 3. テスト実装の調査と分析
- [ ] 3.1 AWS ECS Fargateテストの環境変数を抽出する
  - test/aws/ecs_fargate_test.goを読み込む
  - 使用される環境変数（TEST_VPC_ID、TEST_PRIVATE_SUBNET_IDS等）をリストアップする
  - 各環境変数の必須/オプション属性を記録する
  - 証明書オプション（TEST_BRIDGE_DOMAIN_NAME、TEST_ROUTE53_ZONE_ID等）を記録する
  - NAT Gateway関連環境変数を確認する
  - _要件: 1.5_

- [ ] 3.2 GCP Cloud Runテストの環境変数を抽出する
  - test/gcp/cloud_run_test.goを読み込む
  - 使用される環境変数（TEST_GCP_PROJECT_ID、TEST_TENANT_ID等）をリストアップする
  - 各環境変数の必須/オプション属性を記録する
  - ドメイン設定関連環境変数（TEST_DOMAIN_NAME、TEST_DNS_ZONE_NAME）を確認する
  - VPC設定関連環境変数を確認する
  - _要件: 1.5_

- [ ] 4. AWS ECS Fargateモジュールドキュメントの差分検出
- [ ] 4.1 modules/aws/ecs-fargate/README.mdの変数セクションを分析する
  - BEGIN_TF_DOCS～END_TF_DOCSセクションの変数テーブルを読み込む
  - 各変数のRequired列が実装と一致するか確認する
  - certificate_arnのRequired列がyesであることを確認する
  - domain_nameとroute53_zone_idのRequired列がyesであることを確認する
  - nat_gateway_idのRequired列がnoであることを確認する
  - 不一致をCritical差分として記録する
  - _要件: 2.2, 2.8_

- [ ] 4.2 modules/aws/ecs-fargate/README.mdのデフォルト値を検証する
  - 変数テーブルのDefault列が実装と一致するか確認する
  - cpu、memory、desired_count、log_retention_daysのデフォルト値を確認する
  - fetch_interval、fetch_timeout、portのデフォルト値を確認する
  - 不一致をHigh差分として記録する
  - _要件: 2.9_

- [ ] 4.3 modules/aws/ecs-fargate/README.mdの説明セクションを検証する
  - 使用方法セクションのHCLコード例を確認する
  - ネットワーク構成の説明セクション（VPCエンドポイント、NAT Gateway）を確認する
  - 証明書オプションセクション（DNS検証、自己署名等）を確認する
  - 説明文が実装と一致しない箇所をMedium差分として記録する
  - _要件: 2.10_

- [ ] 5. GCP Cloud Runモジュールドキュメントの差分検出
- [ ] 5.1 modules/gcp/cloud-run/README.mdの変数セクションを分析する
  - BEGIN_TF_DOCS～END_TF_DOCSセクションの変数テーブルを読み込む
  - project_idとtenant_idのRequired列がyesであることを確認する
  - domain_nameのRequired列がnoであることを確認する
  - allowed_ip_rangesのDefault列が空リスト表記であることを確認する
  - 不一致をCritical差分として記録する
  - _要件: 2.3, 2.8_

- [ ] 5.2 modules/gcp/cloud-run/README.mdの説明セクションを検証する
  - 使用例セクションのHCLコード例を確認する
  - VPC統合セクション（Direct VPC Egress、VPC Connector）の説明を確認する
  - Cloud Armorセキュリティポリシーの説明を確認する
  - allowed_ip_rangesのデフォルト動作（BaseMachina IP自動追加）の説明を確認する
  - 説明文が実装と一致しない箇所をMedium差分として記録する
  - _要件: 2.10_

- [ ] 6. test/README.mdの差分検出
- [ ] 6.1 test/README.mdのAWS環境変数セクションを検証する
  - 必須環境変数リスト（TEST_VPC_ID、TEST_PRIVATE_SUBNET_IDS等）が完全か確認する
  - TEST_BRIDGE_DOMAIN_NAMEとTEST_ROUTE53_ZONE_IDの説明を確認する
  - NAT Gateway必須要件の説明を確認する
  - VPCエンドポイント + NAT Gatewayハイブリッド構成の説明を確認する
  - 不一致をCritical/High差分として記録する
  - _要件: 2.1, 2.3_

- [ ] 6.2 test/README.mdのGCP環境変数セクションを検証する
  - 必須環境変数リスト（TEST_GCP_PROJECT_ID、TEST_TENANT_ID等）が完全か確認する
  - ドメイン設定関連環境変数（TEST_DOMAIN_NAME、TEST_DNS_ZONE_NAME）の説明を確認する
  - VPC設定関連環境変数の説明を確認する
  - 不一致をCritical/High差分として記録する
  - _要件: 2.2, 2.3_

- [ ] 6.3 test/README.mdのテスト手順セクションを検証する
  - テスト実行時間の見積もり（AWS: 30-45分、GCP: 20-30分）の記載を確認する
  - テストクリーンアップ手順（terraform destroy）の記載を確認する
  - トラブルシューティングセクションの実用性を確認する
  - 不一致をMedium差分として記録する
  - _要件: 2.10_

- [ ] 7. examples/README.mdの差分検出
- [ ] 7.1 examples/aws-ecs-fargate/README.mdの前提条件セクションを検証する
  - 必須リソース（VPC、サブネット、Route53 Hosted Zone）の記載を確認する
  - terraform.tfvars.exampleと実際の変数定義の一致を確認する
  - ACM証明書のDNS検証自動実行の説明を確認する
  - 不一致をCritical/High差分として記録する
  - _要件: 2.4_

- [ ] 7.2 examples/gcp-cloud-run/README.mdの前提条件セクションを検証する
  - 必須API有効化手順（run.googleapis.com、compute.googleapis.com等）の記載を確認する
  - terraform.tfvars.exampleと実際の変数定義の一致を確認する
  - Cloud SQL接続方法（Cloud SQL Proxy、VPC経由）の説明を確認する
  - 不一致をCritical/High差分として記録する
  - _要件: 2.5_

- [ ] 7.3 examples/README.mdのデプロイ後検証セクションを検証する
  - HTTPS疎通確認手順（curl -v https://bridge.example.com/ok）の記載を確認する
  - ヘルスチェック確認手順の記載を確認する
  - デプロイ成功の判定基準を確認する
  - 不一致をMedium差分として記録する
  - _要件: 2.10_

- [ ] 8. ルートREADME.mdの差分検出
- [ ] 8.1 README.mdの概要セクションを検証する
  - 両クラウドプロバイダー（AWS、GCP）が実装済みであることの記載を確認する
  - 主要機能リスト（ECRプルスルーキャッシュ、Cloud Armor等）が最新か確認する
  - プロジェクト概要が実装の現状を反映しているか確認する
  - 不一致をHigh差分として記録する
  - _要件: 2.1_

- [ ] 8.2 README.mdのクイックスタートセクションを検証する
  - AWS ECS Fargateの使用例HCLコードが最新の必須変数を含むか確認する
  - GCP Cloud Runの使用例HCLコードが最新の必須変数を含むか確認する
  - 両使用例が実際にデプロイ可能であることを確認する
  - 不一致をCritical差分として記録する
  - _要件: 2.2_

- [ ] 8.3 README.mdのディレクトリ構造セクションを検証する
  - ディレクトリツリー表記が現在のファイル構成と一致するか確認する
  - 各ディレクトリの説明が正確か確認する
  - 新しいファイル（cleanup.sh等）が記載されているか確認する
  - 不一致をMedium差分として記録する
  - _要件: 2.4_

- [ ] 9. Critical差分の修正（必須/オプション属性）
- [ ] 9.1 AWS ECS Fargateモジュールの必須変数を修正する
  - modules/aws/ecs-fargate/README.mdのcertificate_arnの説明を修正する
  - "ACM certificate ARN for HTTPS listener (required)"と明記する
  - domain_nameとroute53_zone_idの説明に"(required)"を追加する
  - 使用例セクションでこれらの変数が必須であることを強調する
  - terraform-docs管理領域（BEGIN_TF_DOCS内）は手動編集せず、コメントで注意喚起する
  - _要件: 3.1, 3.2_

- [ ] 9.2 GCP Cloud Runモジュールの必須変数を修正する
  - modules/gcp/cloud-run/README.mdのproject_idとtenant_idの説明を確認する
  - domain_nameの説明を"Custom domain name for the Bridge (optional, required for HTTPS)"に修正する
  - vpc_network_idとvpc_subnetwork_idの説明に条件付き必須要件を追加する
  - "required if using Direct VPC Egress"と明記する
  - _要件: 4.1, 4.5_

- [ ] 9.3 test/README.mdの必須環境変数を修正する
  - AWS環境変数セクションに不足している環境変数を追加する
  - TEST_BRIDGE_DOMAIN_NAMEとTEST_ROUTE53_ZONE_IDを必須として記載する
  - GCP環境変数セクションにTEST_GCP_PROJECT_IDを必須として追加する
  - 各環境変数の必須/オプション属性を明確に区別する
  - _要件: 5.1, 5.2_

- [ ] 9.4 examples/README.mdの前提条件を修正する
  - examples/aws-ecs-fargate/README.mdの前提条件セクションを更新する
  - Route53 Hosted Zoneが必須リソースであることを明記する
  - ACM証明書のDNS検証が自動実行されることを説明する
  - examples/gcp-cloud-run/README.mdの必須API有効化手順を詳細化する
  - _要件: 6.1, 6.4_

- [ ] 9.5 README.mdのクイックスタート使用例を修正する
  - AWS ECS Fargateの使用例にcertificate_arn、domain_name、route53_zone_idを追加する
  - GCP Cloud Runの使用例にproject_idとtenant_idが含まれることを確認する
  - 両使用例が実際にterraform planで検証可能であることを確認する
  - コメントで必須変数を強調する
  - _要件: 7.2_

- [ ] 10. High差分の修正（デフォルト値）
- [ ] 10.1 AWS ECS Fargateモジュールのデフォルト値を修正する
  - modules/aws/ecs-fargate/README.mdの変数説明でデフォルト値を確認する
  - nat_gateway_idのデフォルト値（null）の動作を説明する
  - "If not specified, a new NAT Gateway will be created"と追記する
  - cpu、memory、desired_countのデフォルト値が正しく記載されているか確認する
  - _要件: 3.3_

- [ ] 10.2 GCP Cloud Runモジュールのデフォルト値を修正する
  - modules/gcp/cloud-run/README.mdの変数説明でデフォルト値を確認する
  - allowed_ip_rangesのデフォルト動作を詳細に説明する
  - "BaseMachina IP (34.85.43.93/32) is automatically included"と明記する
  - region、service_name、min_instances等のデフォルト値を確認する
  - _要件: 4.3_

- [ ] 11. Medium差分の修正（説明文と追加情報）
- [ ] 11.1 AWS ECS Fargateモジュールのネットワーク構成説明を拡充する
  - modules/aws/ecs-fargate/README.mdにVPCエンドポイント + NAT Gatewayハイブリッド構成の説明を追加する
  - Public ECR (public.ecr.aws) からのイメージpullにNAT Gatewayが必須であることを明記する
  - ECRプルスルーキャッシュ機能について新しいセクションを追加する
  - VPCエンドポイント（ECR API、ECR DKR、S3、CloudWatch Logs）の利点を説明する
  - _要件: 3.4, 3.5, 3.6_

- [ ] 11.2 GCP Cloud Runモジュールのネットワーク構成説明を拡充する
  - modules/gcp/cloud-run/README.mdにDirect VPC Egress（推奨）とVPC Connector（レガシー）の違いを説明する
  - Direct VPC Egressの利点（簡単な設定、低レイテンシ、コスト削減）を記載する
  - Cloud Armorセキュリティポリシーの動作を詳細に説明する
  - IPホワイトリスト設定の例を追加する
  - _要件: 4.4, 4.6_

- [ ] 11.3 test/README.mdのテスト手順を拡充する
  - AWS ECS Fargateテストの実行時間見積もり（30-45分）を記載する
  - GCP Cloud Runテストの実行時間見積もり（20-30分）を記載する
  - テストクリーンアップ手順（terraform destroy -auto-approve）を詳細化する
  - トラブルシューティングセクションに実際のエラーケースと対処法を追加する
  - _要件: 5.3, 5.4, 5.5, 5.6, 5.7_

- [ ] 11.4 examples/README.mdのデプロイ後検証手順を拡充する
  - examples/aws-ecs-fargate/README.mdにHTTPS疎通確認の詳細手順を追加する
  - "curl -v https://bridge.example.com/ok"の期待される出力を記載する
  - ヘルスチェック確認コマンドを追加する
  - examples/gcp-cloud-run/README.mdにCloud SQL接続テスト手順を追加する
  - _要件: 6.7_

- [ ] 11.5 README.mdの主要機能リストを更新する
  - ルートREADME.mdの主要機能セクションにECRプルスルーキャッシュを追加する
  - Cloud Armor（GCP）を主要機能として追加する
  - VPCエンドポイント + NAT Gatewayハイブリッド構成（AWS）を追加する
  - Direct VPC Egress（GCP）を追加する
  - 各機能の簡潔な説明を記載する
  - _要件: 7.3_

- [ ] 12. ドキュメント品質検証
- [ ] 12.1 Markdown構文とコードブロックを検証する
  - 全修正済みREADMEファイルのMarkdown構文エラーをチェックする
  - コードブロックの言語指定（```hcl、```bash、```json等）が正しいか確認する
  - リスト、テーブル、見出しのフォーマットが統一されているか確認する
  - 不正な構文があれば修正する
  - _要件: 8.1, 8.2_

- [ ] 12.2 内部リンクを検証する
  - 全READMEファイル間の内部リンク（相対パス）を抽出する
  - 各リンクの参照先ファイルが存在するか確認する
  - 存在しないファイルへのリンクを修正または削除する
  - リンク先のアンカー（#セクション名）が存在するか確認する
  - _要件: 8.3_

- [ ] 12.3 terraform-docs生成セクションの一致性を検証する
  - modules/aws/ecs-fargate/README.mdのBEGIN_TF_DOCS～END_TF_DOCSセクションを確認する
  - terraform-docs markdown table . コマンドの出力と比較する
  - 不一致がある場合は、手動編集を警告するコメントを追加する
  - modules/gcp/cloud-run/README.mdでも同様の検証を実施する
  - _要件: 8.4_

- [ ] 12.4 用語統一を検証する
  - 全READMEファイルで技術用語の表記揺れを検出する
  - "NAT Gateway"（×"NAT gateway"、×"NAT-Gateway"）の統一を確認する
  - "VPCエンドポイント"（×"VPC エンドポイント"、×"VPC Endpoint"）の統一を確認する
  - "Cloud Run"、"Cloud SQL"等のGoogle Cloud用語の表記を確認する
  - 不統一があれば修正する
  - _要件: 8.6_

- [ ] 12.5 手順の完全性と実行可能性を検証する
  - test/README.mdのテスト実行手順を実際に実行してみる（ドライラン）
  - examples/README.mdのデプロイ手順を検証する
  - 不足しているステップや前提条件があれば追加する
  - エラーが発生する手順があれば修正する
  - _要件: 8.7_

- [ ] 13. 最終統合と承認準備
- [ ] 13.1 全修正内容を統合レビューする
  - 全差分修正が適用されたことを確認する
  - Critical差分（9件）、High差分（5件）、Medium差分（15件）の修正完了を確認する
  - 各READMEファイルの一貫性を確認する
  - 修正前後の差分サマリーを生成する
  - _要件: 全要件_

- [ ] 13.2 ドキュメント修正のコミットを準備する
  - 修正されたREADMEファイルのリストを作成する
  - Git diffで各ファイルの変更内容を確認する
  - コミットメッセージのドラフトを作成する
  - "docs: align documentation with implementation (Critical/High/Medium fixes)"
  - 承認レビューの準備を完了する
  - _要件: 全要件_
