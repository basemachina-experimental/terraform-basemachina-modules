# ========================================
# BaseMachina Bridge Module
# ========================================
# Cloud Runモジュールを使用してBridgeをデプロイ

module "basemachina_bridge" {
  source = "../../modules/gcp/cloud-run"

  # プロジェクトとリージョン
  project_id   = var.project_id
  region       = var.region
  service_name = var.service_name

  # Bridge環境変数
  tenant_id      = var.tenant_id
  fetch_interval = var.fetch_interval
  fetch_timeout  = var.fetch_timeout
  port           = var.port

  # リソース設定
  cpu           = var.cpu
  memory        = var.memory
  min_instances = var.min_instances
  max_instances = var.max_instances

  # VPCネットワーク設定（Direct VPC Egress）
  vpc_network_id    = google_compute_network.main.id
  vpc_subnetwork_id = google_compute_subnetwork.main.id
  vpc_egress        = var.vpc_egress

  # Load Balancer設定（カスタムドメインが指定されている場合）
  domain_name           = var.domain_name
  enable_https_redirect = var.enable_https_redirect
  enable_cloud_armor    = var.enable_cloud_armor
  allowed_ip_ranges     = var.allowed_ip_ranges

  # Cloud DNS統合
  dns_zone_name = var.dns_zone_name

  # ラベル
  labels = var.labels

  # 注意: VPCネットワークとサブネットへの依存関係は、
  # vpc_network_id と vpc_subnetwork_id パラメータによって暗黙的に処理されます。
  # Cloud SQLやVPC Peering接続への明示的な depends_on は不要です。
}
