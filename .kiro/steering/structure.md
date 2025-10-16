# プロジェクト構造

## ルートディレクトリ構成

```
terraform-basemachina-modules/
├── .kiro/                      # Kiroスペック駆動開発ディレクトリ
│   ├── steering/              # ステアリングドキュメント（プロジェクトコンテキスト）
│   └── specs/                 # 機能仕様書
├── .claude/                   # Claude Codeスラッシュコマンド
│   └── commands/              # カスタムコマンド定義
├── modules/                   # Terraformモジュール（予定）
│   ├── aws/                   # AWSモジュール
│   └── gcp/                   # GCPモジュール
├── examples/                  # サンプル実装（予定）
│   ├── aws-ecs-fargate/       # AWS ECS Fargateデプロイ例
│   └── gcp-cloud-run/         # GCP Cloud Runデプロイ例
├── test/                      # テストコード（予定）
├── docs/                      # ドキュメント（予定）
├── README.md                  # プロジェクト概要
├── spec.md                    # 要件仕様書（日本語）
└── CLAUDE.md                  # Claude Code設定とガイドライン
```

## サブディレクトリ構造

### `.kiro/` ディレクトリ

Kiro-style Spec Driven Developmentのための構造化されたディレクトリです。

```
.kiro/
├── steering/                  # プロジェクト全体のガイダンス
│   ├── product.md            # プロダクト概要と価値提案
│   ├── tech.md               # 技術スタック
│   └── structure.md          # このファイル
└── specs/                    # 機能別の仕様書
    └── [feature-name]/       # 機能ごとのディレクトリ
        ├── requirements.md   # 要件定義
        ├── design.md         # 技術設計
        └── tasks.md          # 実装タスク
```

### `modules/` ディレクトリ（予定）

再利用可能なTerraformモジュールを格納します。

```
modules/
├── aws/
│   ├── ecs-fargate/          # ECS Fargateモジュール
│   │   ├── main.tf           # メインリソース定義
│   │   ├── variables.tf      # 入力変数
│   │   ├── outputs.tf        # 出力値
│   │   ├── versions.tf       # プロバイダーバージョン
│   │   └── README.md         # モジュールドキュメント
│   ├── networking/           # VPC、サブネット、セキュリティグループ
│   ├── alb/                  # Application Load Balancer
│   └── route53/              # DNSレコード管理
└── gcp/
    ├── cloud-run/            # Cloud Runモジュール
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── versions.tf
    │   └── README.md
    ├── networking/           # VPC、Serverless VPC Access
    └── load-balancer/        # Cloud Load Balancing
```

### `examples/` ディレクトリ（予定）

実際のデプロイ例を提供します。

```
examples/
├── aws-ecs-fargate/
│   ├── main.tf               # モジュールの使用例
│   ├── variables.tf          # カスタマイズ可能な変数
│   ├── outputs.tf            # 出力例
│   ├── terraform.tfvars.example  # 設定例
│   └── README.md             # デプロイ手順
└── gcp-cloud-run/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── terraform.tfvars.example
    └── README.md
```

### `test/` ディレクトリ（予定）

自動化テストコードを配置します。

```
test/
├── aws/
│   └── ecs_fargate_test.go   # Terratestによる統合テスト
└── gcp/
    └── cloud_run_test.go     # Terratestによる統合テスト
```

## コード構成パターン

### Terraformモジュール構造

各Terraformモジュールは以下の標準的なファイル構成に従います：

```
module-name/
├── main.tf           # リソース定義
├── variables.tf      # 入力変数定義
├── outputs.tf        # 出力値定義
├── versions.tf       # プロバイダーバージョン制約
├── locals.tf         # （オプション）ローカル変数
├── data.tf           # （オプション）データソース
└── README.md         # モジュールドキュメント
```

### ファイルの役割

- **main.tf**: 主要なリソース定義（ECSタスク、Cloud Runサービスなど）
- **variables.tf**: モジュールへの入力パラメータ（型、説明、デフォルト値を含む）
- **outputs.tf**: モジュールからの出力値（エンドポイントURL、ARNなど）
- **versions.tf**: Terraformおよびプロバイダーのバージョン制約
- **locals.tf**: 複雑な計算やタグの定義に使用するローカル変数
- **data.tf**: 既存リソースの参照（AMI、VPCなど）

## ファイル命名規則

### Terraformファイル

- **スネークケース**: すべて小文字、単語間はアンダースコア（例: `ecs_fargate.tf`）
- **機能別ファイル分割**: 大きなモジュールは機能ごとにファイルを分割
  - `ecs.tf`: ECS関連リソース
  - `alb.tf`: ALB関連リソース
  - `security_groups.tf`: セキュリティグループ
  - `iam.tf`: IAMロールとポリシー

### ディレクトリ

- **ケバブケース**: 小文字、単語間はハイフン（例: `aws-ecs-fargate/`）
- **明確な命名**: ディレクトリ名から内容が推測できること

### ドキュメント

- **大文字開始**: README.md、CLAUDE.md
- **小文字**: その他のマークダウンファイル（例: `spec.md`）

## Import構成

### Terraformモジュールの参照

```hcl
# ローカルモジュールの使用
module "bridge_aws" {
  source = "../../modules/aws/ecs-fargate"
  # ...
}

# リモートモジュールの使用（将来的に）
module "bridge_aws" {
  source  = "basemachina/bridge/aws"
  version = "~> 1.0"
  # ...
}
```

### プロバイダーの構成

```hcl
# AWSプロバイダー
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# GCPプロバイダー
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
```

## 主要なアーキテクチャ原則

### 1. モジュール化

- **単一責任**: 各モジュールは1つの責任のみを持つ
- **再利用性**: 異なるプロジェクトで再利用可能な設計
- **組み合わせ可能**: 小さなモジュールを組み合わせて複雑なシステムを構築

### 2. Infrastructure as Code原則

- **冪等性**: 同じ設定を何度実行しても同じ結果
- **宣言的**: 「どのようにするか」ではなく「何であるべきか」を記述
- **バージョン管理**: すべてのインフラコードをGitで管理

### 3. セキュリティファースト

- **最小権限の原則**: 必要最小限のIAM権限
- **暗号化**: データの暗号化（転送中・保存時）
- **機密情報の分離**: シークレットをコードから分離

### 4. マルチクラウド対応

- **プロバイダー抽象化**: クラウド固有の実装は各モジュール内に隠蔽
- **共通インターフェース**: AWS/GCPモジュールで可能な限り同じ変数名と出力を使用
- **ベストプラクティス**: 各クラウドプロバイダーの推奨パターンに従う

### 5. ドキュメント駆動

- **自己文書化コード**: 変数やリソースに明確な説明を付ける
- **READMEの充実**: 各モジュールに使用方法を記載
- **terraform-docs**: ドキュメント自動生成ツールの活用

### 6. テスト可能性

- **統合テスト**: Terratestによる実際のデプロイテスト
- **バリデーション**: terraform validateによる構文チェック
- **静的解析**: tflintによるベストプラクティスチェック

### 7. Spec-Driven Development

- **要件ファースト**: 実装前に要件を明確化
- **設計レビュー**: 技術設計の承認プロセス
- **タスク分解**: 実装を小さなタスクに分割
- **進捗追跡**: `/kiro:spec-status`による進捗確認

## 開発ワークフロー

### 1. 新機能開発

```
1. /kiro:spec-init [feature-name] で仕様を初期化
2. /kiro:spec-requirements [feature-name] で要件を生成
3. /kiro:spec-design [feature-name] で設計を作成
4. /kiro:spec-tasks [feature-name] でタスクを生成
5. /kiro:spec-impl [feature-name] [task-numbers] で実装
```

### 2. コード変更

```
1. ブランチ作成（feature/xxx）
2. Terraformコードの編集
3. terraform fmt でフォーマット
4. terraform validate で検証
5. terraform plan で変更確認
6. Git commitとpush
7. プルリクエスト作成
```

### 3. レビューとマージ

```
1. コードレビュー
2. terraform planの出力確認
3. CI/CDパイプラインのテスト通過
4. マージ
5. terraform apply（本番環境は慎重に）
```
