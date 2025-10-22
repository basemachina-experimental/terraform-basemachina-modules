# ========================================
# Cloud DNS Managed Zone
# ========================================
# 既存のCloud DNS Managed Zoneへの参照

data "google_dns_managed_zone" "main" {
  count   = var.dns_zone_name != null ? 1 : 0
  name    = var.dns_zone_name
  project = var.project_id
}
