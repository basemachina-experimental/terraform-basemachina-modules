# ========================================
# ネットワーク関連変数
# ========================================

variable "vpc_id" {
  description = "デプロイ先のVPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Bridgeタスクを配置するプライベートサブネットIDのリスト（複数AZ推奨）"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "ALBを配置するパブリックサブネットIDのリスト（複数AZ推奨）"
  type        = list(string)
}

# ========================================
# SSL/TLS証明書
# ========================================

variable "certificate_arn" {
  description = "HTTPS通信用のACM証明書ARN"
  type        = string
}

# ========================================
# Bridge環境変数
# ========================================

variable "tenant_id" {
  description = "BaseMachinaテナントID"
  type        = string
}

variable "fetch_interval" {
  description = "認可処理の公開鍵更新間隔（例: '1h', '30m'）"
  type        = string
  default     = "1h"
}

variable "fetch_timeout" {
  description = "認可処理の公開鍵更新タイムアウト（例: '10s', '30s'）"
  type        = string
  default     = "10s"
}

variable "port" {
  description = "Bridgeのリスニングポート"
  type        = number
  default     = 8080
}

# ========================================
# リソース設定
# ========================================

variable "cpu" {
  description = "Fargateタスクに割り当てるCPUユニット（256, 512, 1024, 2048, 4096）"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargateタスクに割り当てるメモリ（MB）"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "実行するタスクの数"
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch Logsの保持期間（日）"
  type        = number
  default     = 7
}

# ========================================
# データベース接続（オプション）
# ========================================

variable "database_security_group_id" {
  description = "データベースセキュリティグループID（オプション）"
  type        = string
  default     = null
}

variable "database_port" {
  description = "データベースポート（オプション、database_security_group_id指定時に必要）"
  type        = number
  default     = 5432
}

# ========================================
# タグ付けと命名
# ========================================

variable "tags" {
  description = "全リソースに適用するタグ"
  type        = map(string)
  default = {
    Environment = "production"
    Project     = "basemachina-bridge"
    ManagedBy   = "terraform"
  }
}

variable "name_prefix" {
  description = "リソース名のプレフィックス"
  type        = string
  default     = "prod"
}
