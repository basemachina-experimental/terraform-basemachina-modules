# ========================================
# NAT Gateway for Private Subnet Internet Access
# ========================================
# NAT Gatewayを使用してプライベートサブネットからインターネットへのアクセスを提供
# - Bridge初期化に必要な認証サーバーへの接続を可能にする
# - コスト: 約$32/月（$0.045/時間 + データ転送料）
#
# Note: NAT GatewayなしではBridgeは初期化できません
# VPCエンドポイントだけではBaseMachinaの認証サーバーにアクセスできないため
#
# 既存のNAT Gatewayを使用する場合は var.nat_gateway_id を指定
# 指定しない場合は新しいNAT Gatewayが作成されます

locals {
  # 既存のNAT Gatewayを使用するか、新規作成するかを判定
  create_nat_gateway = var.nat_gateway_id == null
  nat_gateway_id     = local.create_nat_gateway ? aws_nat_gateway.bridge[0].id : var.nat_gateway_id
}

# ========================================
# Elastic IP for NAT Gateway
# ========================================
# NAT Gatewayに割り当てる静的パブリックIPアドレス
# 1つのNAT Gatewayで複数のプライベートサブネットをカバー

resource "aws_eip" "nat" {
  count  = local.create_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}bridge-nat-gateway-eip"
    }
  )
}

# ========================================
# NAT Gateway
# ========================================
# パブリックサブネットに配置し、プライベートサブネットからのトラフィックを中継

resource "aws_nat_gateway" "bridge" {
  count         = local.create_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = var.public_subnet_ids[0]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}bridge-nat-gateway"
    }
  )

  # NAT Gatewayの作成前にInternet Gatewayが必要
  # パブリックサブネットのルートテーブルにIGWルートがあることを想定
}

# ========================================
# Route Table for Private Subnets
# ========================================
# プライベートサブネット用のルートテーブル
# NAT Gateway経由でインターネットへのデフォルトルートを追加

# 各プライベートサブネットのルートテーブルを個別に取得
data "aws_route_table" "private_subnet" {
  for_each  = toset(var.private_subnet_ids)
  subnet_id = each.value
}

# 各プライベートサブネットのルートテーブルにNAT Gatewayへのデフォルトルートを追加
resource "aws_route" "private_nat_gateway" {
  for_each = data.aws_route_table.private_subnet

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = local.nat_gateway_id
}
