# ========================================
# BaseMachina Bridge Deployment Example
# ========================================
# このファイルは、BaseMachina BridgeをAWS ECS Fargateにデプロイする
# 実装例を示します。

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# AWSプロバイダーの設定
# リージョンは環境変数AWS_REGIONまたはAWS設定ファイルから取得されます
provider "aws" {
  # region = "ap-northeast-1"  # 必要に応じてコメント解除
}

# ========================================
# BaseMachina Bridgeモジュールの呼び出し
# ========================================

module "basemachina_bridge" {
  source = "../../modules/aws/ecs-fargate"

  # ========================================
  # ネットワーク設定
  # ========================================
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  public_subnet_ids  = var.public_subnet_ids
  nat_gateway_id     = var.nat_gateway_id

  # ========================================
  # SSL/TLS証明書
  # ========================================
  # ACMインポートと外部証明書ARNの両方に対応
  # - enable_acm_import = true の場合: acm.tfで定義されたlocals.certificate_arnを使用
  # - enable_acm_import = false の場合: var.certificate_arnを使用
  certificate_arn = local.certificate_arn

  # Ensure ACM certificate is created before module resources
  depends_on = [
    aws_acm_certificate.self_signed
  ]

  # ========================================
  # セキュリティ設定
  # ========================================
  additional_alb_ingress_cidrs = var.additional_alb_ingress_cidrs

  # ========================================
  # Bridge環境変数
  # ========================================
  tenant_id      = var.tenant_id
  fetch_interval = var.fetch_interval
  fetch_timeout  = var.fetch_timeout
  port           = var.port

  # ========================================
  # リソース設定
  # ========================================
  cpu                = var.cpu
  memory             = var.memory
  desired_count      = var.desired_count
  log_retention_days = var.log_retention_days

  # ========================================
  # タグ
  # ========================================
  tags = var.tags

  name_prefix = var.name_prefix
}

# ========================================
# データベース接続の例
# ========================================
# このexampleでは、rds.tfでRDS PostgreSQLインスタンスを作成し、
# Bridgeからの接続を許可するセキュリティグループルールを自動設定しています。
#
# 独自のデータベースに接続する場合の例:
# resource "aws_security_group_rule" "bridge_to_custom_db" {
#   type                     = "ingress"
#   from_port                = 3306  # MySQLの場合
#   to_port                  = 3306
#   protocol                 = "tcp"
#   source_security_group_id = module.basemachina_bridge.bridge_security_group_id
#   security_group_id        = "sg-xxxxx"  # 接続先DBのセキュリティグループID
#   description              = "Allow Bridge to access MySQL"
# }
