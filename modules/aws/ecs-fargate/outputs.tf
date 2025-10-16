# ========================================
# ALB Outputs
# ========================================
# Application Load BalancerのDNS名とARN
# Route 53レコード作成や他のリソース参照に使用

output "alb_dns_name" {
  description = "ALBのDNS名（Route 53レコード作成用）"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ALBのARN（リソース参照用）"
  value       = aws_lb.main.arn
}

output "alb_security_group_id" {
  description = "ALBセキュリティグループのID（通信ルール設定用）"
  value       = aws_security_group.alb.id
}

# ========================================
# ECS Outputs
# ========================================
# ECSクラスターとサービスの情報
# モニタリングやスケーリング設定に使用

output "ecs_cluster_name" {
  description = "ECSクラスター名（AWS CLIやモニタリング用）"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ECSクラスターARN（リソース参照用）"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_service_name" {
  description = "ECSサービス名（デプロイやスケーリング用）"
  value       = aws_ecs_service.bridge.name
}

# ========================================
# Security Group Outputs
# ========================================
# Bridgeセキュリティグループの情報
# データベースやAPIへのアクセス許可設定に使用

output "bridge_security_group_id" {
  description = "BridgeセキュリティグループのID（他リソースとの通信ルール設定用）"
  value       = aws_security_group.bridge.id
}

# ========================================
# CloudWatch Logs Outputs
# ========================================
# ロググループ情報
# ログストリーム確認やメトリクスフィルター設定に使用

output "cloudwatch_log_group_name" {
  description = "CloudWatch Logsロググループ名（ログ確認用）"
  value       = aws_cloudwatch_log_group.bridge.name
}

# ========================================
# IAM Role Outputs
# ========================================
# タスク実行ロールとタスクロールのARN
# 権限の追加や参照に使用

output "task_execution_role_arn" {
  description = "タスク実行ロールARN（権限管理用）"
  value       = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  description = "タスクロールARN（アプリケーション権限管理用）"
  value       = aws_iam_role.task.arn
}
