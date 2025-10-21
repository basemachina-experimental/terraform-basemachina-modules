# ========================================
# ECR Pull Through Cache Configuration
# ========================================
# ECRプルスルーキャッシュを使用して、Public ECRイメージをPrivate ECRにキャッシュ
# これにより、VPCエンドポイントのみでPublic ECRイメージにアクセス可能になり、
# NAT Gatewayが不要になります。
#
# 仕組み:
# 1. ECSタスクが <account-id>.dkr.ecr.<region>.amazonaws.com/ecr-public/basemachina/bridge:latest を参照
# 2. ECRが自動的にpublic.ecr.aws/basemachina/bridge:latestからイメージを取得してキャッシュ
# 3. AWSのマネージドインフラがPublic ECRから取得（ECSタスクではない）
# 4. VPCエンドポイント経由でキャッシュされたイメージにアクセス

# ========================================
# Data Source: Caller Identity
# ========================================
# AWS アカウントIDを取得

data "aws_caller_identity" "current" {}

# ========================================
# ECR Pull Through Cache Rule
# ========================================
# Public ECR用のプルスルーキャッシュルールを作成

resource "aws_ecr_pull_through_cache_rule" "public_ecr" {
  ecr_repository_prefix = "ecr-public"
  upstream_registry_url = "public.ecr.aws"

  # Note: credentialArnは不要（Public ECRは認証不要のため）
}
