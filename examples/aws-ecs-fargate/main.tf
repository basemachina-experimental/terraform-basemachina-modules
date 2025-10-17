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

  # ========================================
  # SSL/TLS証明書
  # ========================================
  certificate_arn = var.certificate_arn

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
  assign_public_ip   = var.assign_public_ip
  log_retention_days = var.log_retention_days

  # ========================================
  # タグ
  # ========================================
  tags = var.tags

  name_prefix = var.name_prefix
}

# ========================================
# データベース接続の例（オプション）
# ========================================
# モジュールのbridge_security_group_id出力値を使って、
# 接続したいリソースのセキュリティグループルールを追加します
#
# 例: RDSへの接続を許可
# resource "aws_security_group_rule" "bridge_to_rds" {
#   type                     = "ingress"
#   from_port                = 5432
#   to_port                  = 5432
#   protocol                 = "tcp"
#   source_security_group_id = module.basemachina_bridge.bridge_security_group_id
#   security_group_id        = var.rds_security_group_id
#   description              = "Allow Bridge to access RDS"
# }
