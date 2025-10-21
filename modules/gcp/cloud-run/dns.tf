# ========================================
# Cloud DNS Configuration
# ========================================
# カスタムドメインをLoad BalancerのIPアドレスにマッピング

# ========================================
# DNS A Record
# ========================================
# Load BalancerのIPアドレスをカスタムドメインに紐付け

resource "google_dns_record_set" "default" {
  count        = var.domain_name != null && var.dns_zone_name != null ? 1 : 0
  name         = "${var.domain_name}."
  managed_zone = var.dns_zone_name
  type         = "A"
  ttl          = 300
  project      = var.project_id

  rrdatas = [google_compute_global_address.default[0].address]

  # Load Balancerのグローバルアドレスが作成された後にDNSレコードを作成
  depends_on = [google_compute_global_address.default]
}
