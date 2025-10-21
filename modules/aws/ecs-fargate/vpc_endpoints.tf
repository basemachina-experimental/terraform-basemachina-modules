# ========================================
# VPC Endpoints for Private Subnet Access
# ========================================
# VPCエンドポイントを使用することで、NAT Gateway無しでAWSサービスにアクセス可能
# - ECR: コンテナイメージのpull
# - S3: ECRレイヤーストレージ
# - CloudWatch Logs: ログ送信
#
# NAT Gatewayと比較したメリット:
# - コスト削減: NAT Gatewayの時間料金（$0.045/時間）とデータ転送料が不要
# - パフォーマンス向上: AWSバックボーン経由で高速
# - セキュリティ向上: トラフィックがインターネットを経由しない

# ========================================
# Security Group for VPC Endpoints
# ========================================

resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.name_prefix}-vpc-endpoints-"
  description = "Security group for VPC endpoints (ECR, S3, CloudWatch Logs)"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-vpc-endpoints"
    }
  )
}

# Allow HTTPS inbound from Bridge security group
resource "aws_security_group_rule" "vpc_endpoints_ingress_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bridge.id
  description              = "HTTPS from Bridge tasks"
  security_group_id        = aws_security_group.vpc_endpoints.id
}

# Allow all outbound traffic
#tfsec:ignore:AWS007
resource "aws_security_group_rule" "vpc_endpoints_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "All outbound traffic"
  security_group_id = aws_security_group.vpc_endpoints.id
}

# ========================================
# ECR API Endpoint (Interface Endpoint)
# ========================================
# ECR APIへのアクセスを提供（イメージのメタデータ取得用）

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ecr-api-endpoint"
    }
  )
}

# ========================================
# ECR Docker Endpoint (Interface Endpoint)
# ========================================
# ECR Dockerレジストリへのアクセスを提供（イメージのpull用）

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ecr-dkr-endpoint"
    }
  )
}

# ========================================
# S3 Gateway Endpoint
# ========================================
# ECRレイヤーストレージ（S3）へのアクセスを提供
# ゲートウェイエンドポイントは無料
#
# Note: NAT Gatewayと共存させるため、個別のルートテーブルIDを使用
# S3へのトラフィックはVPCエンドポイント経由、その他はNAT Gateway経由でルーティングされます

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [for rt in data.aws_route_table.private_subnet : rt.id]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-s3-endpoint"
    }
  )
}

# ========================================
# CloudWatch Logs Endpoint (Interface Endpoint)
# ========================================
# CloudWatch Logsへのアクセスを提供

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-logs-endpoint"
    }
  )
}

# ========================================
# Data Sources
# ========================================

# Note: aws_region.current is already defined in ecs.tf
# Note: data.aws_route_table.private_subnet is defined in nat_gateway.tf and reused here
