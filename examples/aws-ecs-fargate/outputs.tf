# ========================================
# ALB関連の出力
# ========================================

output "alb_dns_name" {
  description = "ALBのDNS名（Route 53レコード作成用）"
  value       = module.basemachina_bridge.alb_dns_name
}

output "alb_arn" {
  description = "ALBのARN"
  value       = module.basemachina_bridge.alb_arn
}

output "alb_security_group_id" {
  description = "ALBセキュリティグループID"
  value       = module.basemachina_bridge.alb_security_group_id
}

# ========================================
# ECS関連の出力
# ========================================

output "ecs_cluster_name" {
  description = "ECSクラスター名"
  value       = module.basemachina_bridge.ecs_cluster_name
}

output "ecs_cluster_arn" {
  description = "ECSクラスターARN"
  value       = module.basemachina_bridge.ecs_cluster_arn
}

output "ecs_service_name" {
  description = "ECSサービス名"
  value       = module.basemachina_bridge.ecs_service_name
}

# ========================================
# セキュリティグループ関連の出力
# ========================================

output "bridge_security_group_id" {
  description = "BridgeセキュリティグループID"
  value       = module.basemachina_bridge.bridge_security_group_id
}

# ========================================
# CloudWatch Logs関連の出力
# ========================================

output "cloudwatch_log_group_name" {
  description = "CloudWatch Logsロググループ名"
  value       = module.basemachina_bridge.cloudwatch_log_group_name
}

# ========================================
# IAM関連の出力
# ========================================

output "task_execution_role_arn" {
  description = "タスク実行ロールARN"
  value       = module.basemachina_bridge.task_execution_role_arn
}

output "task_role_arn" {
  description = "タスクロールARN"
  value       = module.basemachina_bridge.task_role_arn
}
