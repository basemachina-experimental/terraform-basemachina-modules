# ========================================
# Load Balancer Configuration
# ========================================
# Cloud Load BalancerとServerless NEGを使用して
# Cloud RunサービスへのHTTPS/HTTPトラフィックをルーティング

# ========================================
# Local Variables
# ========================================
# Cloud Armor IP範囲の計算
# - "*" が指定されている場合は ["*"] のみ使用
# - それ以外の場合は BaseMachina IP (34.85.43.93/32) を自動追加

locals {
  # "*" が含まれているかチェック
  has_wildcard = contains(var.allowed_ip_ranges, "*")

  # Cloud Armor用のIP範囲を計算
  # "*" が指定されている場合は ["*"] のみ、それ以外はBaseMachina IPを追加
  cloud_armor_ip_ranges = local.has_wildcard ? ["*"] : concat(["34.85.43.93/32"], var.allowed_ip_ranges)
}

# ========================================
# Global External IP Address
# ========================================
# Load Balancer用の静的外部IPアドレスを予約

resource "google_compute_global_address" "default" {
  count   = var.domain_name != null ? 1 : 0
  name    = "${var.service_name}-lb-ip"
  project = var.project_id
}

# ========================================
# Serverless Network Endpoint Group (NEG)
# ========================================
# Cloud RunサービスをLoad Balancerのバックエンドとして構成

resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  count                 = var.domain_name != null ? 1 : 0
  name                  = "${var.service_name}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  project               = var.project_id

  cloud_run {
    service = google_cloud_run_v2_service.bridge.name
  }
}

# ========================================
# Backend Service
# ========================================
# Serverless NEGをバックエンドとして持つBackend Serviceを作成
# Cloud Armorセキュリティポリシーを適用可能

resource "google_compute_backend_service" "default" {
  count       = var.domain_name != null ? 1 : 0
  name        = "${var.service_name}-backend"
  protocol    = "HTTPS"
  port_name   = "http"
  timeout_sec = 30
  enable_cdn  = false
  project     = var.project_id

  backend {
    group = google_compute_region_network_endpoint_group.cloud_run_neg[0].id
  }

  # Cloud Armorセキュリティポリシーを適用（オプション）
  security_policy = var.enable_cloud_armor ? google_compute_security_policy.default[0].id : null

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# ========================================
# Cloud Armor Security Policy
# ========================================
# BaseMachinaのIPアドレスからのアクセスのみを許可

resource "google_compute_security_policy" "default" {
  count   = var.domain_name != null && var.enable_cloud_armor ? 1 : 0
  name    = "${var.service_name}-policy"
  project = var.project_id

  # 特定IPからのアクセスを許可（ワイルドカード以外の場合のみ）
  # BaseMachina IP (34.85.43.93/32) はデフォルトで含まれる
  dynamic "rule" {
    for_each = local.has_wildcard ? [] : [1]
    content {
      action   = "allow"
      priority = 1000
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = local.cloud_armor_ip_ranges
        }
      }
      description = "Allow access from BaseMachina (34.85.43.93/32) and additional IPs"
    }
  }

  # デフォルトルール（必須 - 優先度2147483647）
  # "*" が指定された場合は全て許可、それ以外は拒否
  rule {
    action   = local.has_wildcard ? "allow" : "deny(403)"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = local.has_wildcard ? "Default allow all IPs" : "Default deny all other IPs"
  }
}

# ========================================
# URL Map (HTTPS)
# ========================================
# Backend Serviceにトラフィックをルーティング

resource "google_compute_url_map" "default" {
  count           = var.domain_name != null ? 1 : 0
  name            = "${var.service_name}-url-map"
  default_service = google_compute_backend_service.default[0].id
  project         = var.project_id
}

# ========================================
# Google-managed SSL Certificate
# ========================================
# カスタムドメイン用のSSL証明書を自動発行

resource "google_compute_managed_ssl_certificate" "default" {
  count   = var.domain_name != null ? 1 : 0
  name    = "${var.service_name}-cert"
  project = var.project_id

  managed {
    domains = [var.domain_name]
  }
}

# ========================================
# HTTPS Target Proxy
# ========================================
# SSL証明書を適用したHTTPS Target Proxy

resource "google_compute_target_https_proxy" "default" {
  count            = var.domain_name != null ? 1 : 0
  name             = "${var.service_name}-https-proxy"
  url_map          = google_compute_url_map.default[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.default[0].id]
  project          = var.project_id
}

# ========================================
# Global Forwarding Rule (HTTPS)
# ========================================
# ポート443でHTTPSトラフィックを受け付け

resource "google_compute_global_forwarding_rule" "https" {
  count      = var.domain_name != null ? 1 : 0
  name       = "${var.service_name}-https-rule"
  target     = google_compute_target_https_proxy.default[0].id
  port_range = "443"
  ip_address = google_compute_global_address.default[0].address
  project    = var.project_id
}

# ========================================
# HTTP to HTTPS Redirect (Optional)
# ========================================
# HTTPトラフィックをHTTPSにリダイレクト

resource "google_compute_url_map" "https_redirect" {
  count   = var.domain_name != null && var.enable_https_redirect ? 1 : 0
  name    = "${var.service_name}-https-redirect"
  project = var.project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "default" {
  count   = var.domain_name != null && var.enable_https_redirect ? 1 : 0
  name    = "${var.service_name}-http-proxy"
  url_map = google_compute_url_map.https_redirect[0].id
  project = var.project_id
}

resource "google_compute_global_forwarding_rule" "http" {
  count      = var.domain_name != null && var.enable_https_redirect ? 1 : 0
  name       = "${var.service_name}-http-rule"
  target     = google_compute_target_http_proxy.default[0].id
  port_range = "80"
  ip_address = google_compute_global_address.default[0].address
  project    = var.project_id
}
