# ========================================
# Bridge Outputs
# ========================================

output "bridge_service_url" {
  description = "Cloud Run service URL"
  value       = module.basemachina_bridge.service_url
}

output "bridge_service_name" {
  description = "Cloud Run service name"
  value       = module.basemachina_bridge.service_name
}

output "bridge_load_balancer_ip" {
  description = "Load Balancer external IP address"
  value       = module.basemachina_bridge.load_balancer_ip
}

output "bridge_domain_url" {
  description = "Bridge domain URL (if domain_name is configured)"
  value       = var.domain_name != null ? "https://${var.domain_name}" : null
}

output "bridge_service_account_email" {
  description = "Service account email used by Cloud Run"
  value       = module.basemachina_bridge.service_account_email
}

# ========================================
# Network Outputs
# ========================================

output "vpc_network_id" {
  description = "VPC network ID"
  value       = google_compute_network.main.id
}

output "vpc_network_name" {
  description = "VPC network name"
  value       = google_compute_network.main.name
}

output "subnet_id" {
  description = "Subnet ID"
  value       = google_compute_subnetwork.main.id
}

# ========================================
# Cloud SQL Outputs
# ========================================

output "cloud_sql_instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.main.name
}

output "cloud_sql_connection_name" {
  description = "Cloud SQL connection name"
  value       = google_sql_database_instance.main.connection_name
}

output "cloud_sql_private_ip" {
  description = "Cloud SQL private IP address"
  value       = google_sql_database_instance.main.private_ip_address
}

output "database_name" {
  description = "Database name"
  value       = google_sql_database.database.name
}

output "database_user" {
  description = "Database user name"
  value       = google_sql_user.user.name
}

output "database_password" {
  description = "Database password (sensitive)"
  value       = random_password.db_password.result
  sensitive   = true
}

# ========================================
# DNS Outputs
# ========================================

output "dns_zone_name" {
  description = "DNS Managed Zone name"
  value       = var.dns_zone_name
}

output "dns_record_fqdn" {
  description = "Fully qualified domain name"
  value       = module.basemachina_bridge.dns_record_fqdn
}
