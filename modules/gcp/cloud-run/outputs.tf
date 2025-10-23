# ========================================
# Cloud Run Service Outputs
# ========================================

output "service_url" {
  description = "Cloud Run service URL"
  value       = google_cloud_run_v2_service.bridge.uri
}

output "service_name" {
  description = "Cloud Run service name"
  value       = google_cloud_run_v2_service.bridge.name
}

output "service_id" {
  description = "Cloud Run service ID"
  value       = google_cloud_run_v2_service.bridge.id
}

# ========================================
# Service Account Outputs
# ========================================

output "service_account_email" {
  description = "Service account email used by Cloud Run"
  value       = google_service_account.bridge.email
}

# ========================================
# Bridge Image Outputs
# ========================================

output "bridge_image_uri" {
  description = "Bridge container image URI used by Cloud Run service"
  value       = "gcr.io/basemachina/bridge:${var.bridge_image_tag}"
}

# ========================================
# Load Balancer Outputs
# ========================================

output "load_balancer_ip" {
  description = "Load balancer external IP address"
  value       = var.domain_name != null ? google_compute_global_address.default[0].address : null
}

output "ssl_certificate_id" {
  description = "Managed SSL certificate ID"
  value       = var.domain_name != null ? google_compute_managed_ssl_certificate.default[0].id : null
}

output "backend_service_id" {
  description = "Backend service ID"
  value       = var.domain_name != null ? google_compute_backend_service.default[0].id : null
}

# ========================================
# DNS Outputs
# ========================================

output "dns_record_name" {
  description = "DNS record name"
  value       = var.domain_name != null && var.dns_zone_name != null ? google_dns_record_set.default[0].name : null
}

output "dns_record_fqdn" {
  description = "Fully qualified domain name"
  value       = var.domain_name
}
