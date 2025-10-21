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

# ========================================
# VPC Endpoints関連の出力
# ========================================

output "vpc_endpoint_ecr_api_id" {
  description = "ECR API VPCエンドポイントID"
  value       = module.basemachina_bridge.vpc_endpoint_ecr_api_id
}

output "vpc_endpoint_ecr_dkr_id" {
  description = "ECR Docker VPCエンドポイントID"
  value       = module.basemachina_bridge.vpc_endpoint_ecr_dkr_id
}

output "vpc_endpoint_s3_id" {
  description = "S3 VPCエンドポイントID"
  value       = module.basemachina_bridge.vpc_endpoint_s3_id
}

output "vpc_endpoint_logs_id" {
  description = "CloudWatch Logs VPCエンドポイントID"
  value       = module.basemachina_bridge.vpc_endpoint_logs_id
}

output "vpc_endpoints_security_group_id" {
  description = "VPCエンドポイント用セキュリティグループID"
  value       = module.basemachina_bridge.vpc_endpoints_security_group_id
}

# ========================================
# ECR Pull Through Cache関連の出力
# ========================================

output "bridge_image_uri" {
  description = "使用されているBridgeコンテナイメージURI"
  value       = module.basemachina_bridge.bridge_image_uri
}

# ========================================
# NAT Gateway関連の出力
# ========================================

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = module.basemachina_bridge.nat_gateway_id
}

output "nat_gateway_public_ip" {
  description = "NAT GatewayのパブリックIPアドレス"
  value       = module.basemachina_bridge.nat_gateway_public_ip
}

# ========================================
# RDS関連の出力
# ========================================

output "rds_endpoint" {
  description = "RDS PostgreSQLインスタンスのエンドポイント"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "RDS PostgreSQLインスタンスのアドレス（ポート番号なし）"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "RDS PostgreSQLインスタンスのポート番号"
  value       = aws_db_instance.postgres.port
}

output "rds_database_name" {
  description = "RDSデータベース名"
  value       = aws_db_instance.postgres.db_name
}

output "rds_username" {
  description = "RDSマスターユーザー名"
  value       = aws_db_instance.postgres.username
  sensitive   = true
}

output "rds_security_group_id" {
  description = "RDSセキュリティグループID"
  value       = aws_security_group.rds.id
}

output "rds_credentials_secret_arn" {
  description = "RDS接続情報を格納したSecrets Manager ARN"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

output "rds_connection_command" {
  description = "RDSへの接続コマンド例"
  value       = "psql -h ${aws_db_instance.postgres.address} -U ${aws_db_instance.postgres.username} -d ${aws_db_instance.postgres.db_name}"
}

# ========================================
# Bastion Host関連の出力
# ========================================

output "bastion_instance_id" {
  description = "BastionホストのインスタンスID"
  value       = var.enable_bastion ? aws_instance.bastion[0].id : null
}

output "bastion_public_ip" {
  description = "BastionホストのパブリックIPアドレス（SSH接続用）"
  value       = var.enable_bastion ? aws_instance.bastion[0].public_ip : null
}

output "bastion_security_group_id" {
  description = "BastionホストのセキュリティグループID"
  value       = var.enable_bastion ? aws_security_group.bastion[0].id : null
}

output "bastion_ssh_command" {
  description = "BastionホストへのSSH接続コマンド例（SSH公開鍵が設定されている場合）"
  value       = var.enable_bastion && var.bastion_ssh_public_key != "" ? "ssh -i ~/.ssh/your-private-key ec2-user@${aws_instance.bastion[0].public_ip}" : "Session Manager経由でアクセスしてください"
}

output "bastion_session_manager_command" {
  description = "BastionホストへのSession Manager接続コマンド"
  value       = var.enable_bastion ? "aws ssm start-session --target ${aws_instance.bastion[0].id}" : null
}

# ========================================
# ドメインとACM証明書関連の出力
# ========================================

output "bridge_domain_name" {
  description = "BridgeのFQDN"
  value       = var.bridge_domain_name
}

output "bridge_url" {
  description = "BridgeのHTTPS URL"
  value       = "https://${var.bridge_domain_name}"
}

output "certificate_arn" {
  description = "使用中のACM証明書ARN"
  value       = local.final_certificate_arn
}

output "certificate_status" {
  description = "ACM証明書のステータス"
  value       = aws_acm_certificate.bridge.status
}

output "route53_zone_id" {
  description = "使用されたRoute53 Hosted Zone ID"
  value       = var.route53_zone_id
}

output "dns_setup_instructions" {
  description = "DNS設定手順"
  value       = <<-EOT

    ========================================
    DNS設定完了
    ========================================

    ACM証明書のDNS検証レコードとALBへのAレコードは
    既存のRoute53 Hosted Zone (${var.route53_zone_id}) に
    自動的に作成されました。

    証明書検証の完了を確認（通常5-10分）:
      aws acm describe-certificate --certificate-arn ${aws_acm_certificate.bridge.arn} --query 'Certificate.Status'

    Bridgeにアクセス:
      https://${var.bridge_domain_name}

    ========================================
  EOT
}
