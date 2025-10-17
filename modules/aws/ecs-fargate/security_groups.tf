# ========================================
# ALBセキュリティグループ
# ========================================
# Application Load BalancerへのHTTPSアクセスを制御
# - インバウンド: HTTPS:443をBaseMachina (34.85.43.93/32)から許可
# - アウトバウンド: 全トラフィックを許可

resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  description = "Security group for BaseMachina Bridge ALB"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-alb"
    }
  )
}

# ALBへのHTTPインバウンドルール（テスト環境用、certificate_arnが未指定の場合のみ）
resource "aws_security_group_rule" "alb_ingress_http" {
  count             = var.certificate_arn == null ? 1 : 0
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTP from anywhere (test only)"
  security_group_id = aws_security_group.alb.id
}

# ALBへのHTTPSインバウンドルール（本番環境用、certificate_arnが指定された場合のみ）
resource "aws_security_group_rule" "alb_ingress_https" {
  count             = var.certificate_arn != null ? 1 : 0
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["34.85.43.93/32"]
  description       = "HTTPS from BaseMachina"
  security_group_id = aws_security_group.alb.id
}

# ALBからのアウトバウンドルール（全トラフィック許可）
#tfsec:ignore:AWS007
resource "aws_security_group_rule" "alb_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "All outbound traffic"
  security_group_id = aws_security_group.alb.id
}

# ========================================
# Bridgeセキュリティグループ
# ========================================
# Bridge Fargateタスクへのアクセスを制御
# - インバウンド: var.portをALBセキュリティグループから許可
# - アウトバウンド: 全トラフィックを許可

resource "aws_security_group" "bridge" {
  name_prefix = "${var.name_prefix}-bridge-"
  description = "Security group for BaseMachina Bridge tasks"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-bridge"
    }
  )
}

# BridgeへのHTTPインバウンドルール（ALBからのみ）
resource "aws_security_group_rule" "bridge_ingress_http" {
  type                     = "ingress"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "HTTP from ALB"
  security_group_id        = aws_security_group.bridge.id
}

# Bridgeからのアウトバウンドルール（全トラフィック許可）
#tfsec:ignore:AWS007
resource "aws_security_group_rule" "bridge_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "All outbound traffic"
  security_group_id = aws_security_group.bridge.id
}

# ========================================
# データベースセキュリティグループルール（条件付き）
# ========================================
# Bridgeからデータベースへのアクセスを許可
# var.database_security_group_idが指定された場合のみ作成

resource "aws_security_group_rule" "database_ingress" {
  count                    = var.database_security_group_id != null ? 1 : 0
  type                     = "ingress"
  from_port                = var.database_port
  to_port                  = var.database_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bridge.id
  security_group_id        = var.database_security_group_id
  description              = "Allow Bridge to access database"
}
