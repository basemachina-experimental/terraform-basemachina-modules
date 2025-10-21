# BaseMachina Terraform Modules

BaseMachina BridgeをAWS・GCPクラウド環境に簡単にデプロイするためのTerraformモジュール集です。

## プロジェクト概要

BaseMachina Bridgeは、BaseMachinaからお客様のプライベートデータソース（RDS、内部API等）へ安全にアクセスするための認証機能付きゲートウェイです。このリポジトリでは、Infrastructure as Code（IaC）の原則に基づき、Terraformモジュールを使ってBridgeのインフラストラクチャを自動的にプロビジョニングします。

### 主要なユースケース

- **プライベートデータソースへの安全なアクセス**: VPC内のプライベートRDS、Cloud SQL、社内APIへのセキュアな接続
- **コンプライアンス要件への対応**: データを外部に出さず、IPホワイトリストやネットワークセグメンテーションが必要な環境
- **エンタープライズ導入**: Infrastructure as Codeによるガバナンスとバージョン管理、複数環境への標準化されたデプロイ

## 主要機能

- **マルチクラウド対応**: AWS（ECS Fargate）とGoogle Cloud（Cloud Run）をサポート（AWS完全実装済み）
- **簡単なデプロイ**: Terraformモジュールによる自動的なインフラストラクチャプロビジョニング
- **Route53統合によるDNS管理**: カスタムドメインとDNSレコードの自動作成
- **DNS検証によるACM証明書の自動発行**: Route53統合により、手動での証明書管理が不要
- **複数の証明書オプション**: DNS検証、自己署名証明書、既存証明書、HTTPのみ構成をサポート
- **VPCエンドポイント + NAT Gatewayのハイブリッド構成**: コスト効率とセキュリティのバランス
- **ECRプルスルーキャッシュ**: Public ECRイメージの自動キャッシュによる可用性向上
- **Terratestによる包括的な統合テスト**: HTTPS疎通確認、ヘルスチェック、DNS検証を含む自動化テスト
- **セキュアなアクセス**: 認証機能付きゲートウェイ、IPホワイトリスト、HTTPS通信の強制
- **ヘルスチェック機能**: `/ok`エンドポイントによる監視
- **柔軟な設定**: 環境変数によるカスタマイズ（認証更新間隔、タイムアウト、ポート、テナントID）

## クイックスタート

### 前提条件

- Terraform >= 1.0
- AWS CLI v2.x（AWS環境の場合）
- 既存のVPCとサブネット（パブリック・プライベート）
- BaseMachinaテナントID
- Route53 Hosted Zone（DNS検証を使用する場合）

### 基本的な使用方法

```hcl
module "bridge" {
  source = "github.com/basemachina/terraform-basemachina-modules//modules/aws/ecs-fargate"

  # ネットワーク設定
  vpc_id             = "vpc-xxxxx"
  private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
  public_subnet_ids  = ["subnet-aaaaa", "subnet-bbbbb"]

  # SSL/TLS証明書（ACM）
  certificate_arn = "arn:aws:acm:ap-northeast-1:123456789012:certificate/xxxxx"

  # カスタムドメイン設定
  domain_name      = "bridge.example.com"
  route53_zone_id  = "Z1234567890ABC"

  # Bridge環境変数
  tenant_id      = "your-tenant-id"
  fetch_interval = "1h"
  fetch_timeout  = "10s"

  name_prefix = "prod"
}
```

詳細な使用例とデプロイ手順については、[examples/aws-ecs-fargate/](examples/aws-ecs-fargate/) を参照してください。

## ディレクトリ構造

```
terraform-basemachina-modules/
├── modules/                   # 再利用可能なTerraformモジュール
│   └── aws/
│       └── ecs-fargate/       # AWS ECS Fargateモジュール（実装済み）
├── examples/                  # サンプル実装とデプロイ例
│   └── aws-ecs-fargate/       # AWS ECS Fargateデプロイ例（実装済み）
│       ├── scripts/           # ユーティリティスクリプト
│       │   ├── generate-cert.sh           # 自己署名証明書生成
│       │   ├── diagnose-dns-validation.sh # DNS検証診断
│       │   └── cleanup-failed-resources.sh # リソースクリーンアップ
│       └── README.md          # 詳細なデプロイ手順
├── test/                      # Terratest統合テスト
│   ├── aws/                   # AWS関連テスト
│   └── README.md              # テスト実行手順
└── README.md                  # このファイル
```

### 各ディレクトリの役割

- **modules/**: 再利用可能なTerraformモジュール（VPC、サブネット、証明書ARNを受け取り、Bridge環境を構築）
- **examples/**: 実際のデプロイ例（ACM証明書、Route53レコード、RDS、Bastionホストを含む完全な動作例）
- **test/**: Terratestによる自動化された統合テスト（HTTPS疎通確認、ヘルスチェック、DNS検証）

## ドキュメント

- **モジュールドキュメント**: [modules/aws/ecs-fargate/README.md](modules/aws/ecs-fargate/README.md)
  - 入力変数、出力値、証明書オプション、ネットワーク構成の詳細
- **デプロイ手順**: [examples/aws-ecs-fargate/README.md](examples/aws-ecs-fargate/README.md)
  - 前提条件、デプロイ手順、証明書設定、RDS統合、トラブルシューティング
- **テスト手順**: [test/README.md](test/README.md)
  - Terratest実行方法、環境変数、実行時間、トラブルシューティング

## テスト

Terratestによる自動化された統合テストが含まれています。

```bash
cd test
go test -v ./aws -timeout 60m
```

詳細は [test/README.md](test/README.md) を参照してください。

## サポートされるクラウドプロバイダー

- **AWS**: ECS Fargate（実装済み）
  - Application Load Balancer、ACM証明書、Route53、VPCエンドポイント、ECRプルスルーキャッシュ
- **Google Cloud**: Cloud Run（予定）

## セキュリティ

- **HTTPS通信の強制**: ALBでHTTPS（ポート443）のみを受け付け
- **IPホワイトリスト**: BaseMachina IP（34.85.43.93/32）からのアクセスのみを許可
- **プライベートサブネット配置**: Bridgeタスクはプライベートサブネットに配置
- **認証機能**: 公開鍵による認証とテナントIDによるマルチテナント分離
- **機密情報管理**: AWS Secrets Manager / Systems Manager Parameter Storeの使用を推奨

## ライセンス

このプロジェクトはBaseMachinaプロジェクトの一部です。

## リンク

- [BaseMachina公式ドキュメント](https://docs.basemachina.com/)
- [BaseMachina Bridge FAQ](https://docs.basemachina.com/faq/what_is_bridge/)
- [AWS ECS Fargate ドキュメント](https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
