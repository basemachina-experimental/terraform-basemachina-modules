# ========================================
# CloudWatch Logsロググループ
# ========================================
# Bridgeコンテナの標準出力・標準エラー出力を集約

resource "aws_cloudwatch_log_group" "bridge" {
  name              = "/ecs/basemachina-bridge"
  retention_in_days = var.log_retention_days

  tags = var.tags
}
