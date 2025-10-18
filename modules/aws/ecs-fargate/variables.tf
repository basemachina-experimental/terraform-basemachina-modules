# ========================================
# ネットワーク関連変数
# ========================================

variable "vpc_id" {
  description = "VPC ID where the resources will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) > 0
    error_message = "At least one private subnet must be specified"
  }
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB and NAT Gateway (if creating new NAT Gateway)"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) > 0
    error_message = "At least one public subnet must be specified"
  }
}

variable "nat_gateway_id" {
  description = "Existing NAT Gateway ID to use (optional). If not specified, a new NAT Gateway will be created for Bridge."
  type        = string
  default     = null
}

# ========================================
# セキュリティ関連変数
# ========================================

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener (required)"
  type        = string
}

variable "additional_alb_ingress_cidrs" {
  description = "Additional CIDR blocks to allow HTTPS access to ALB (for testing or additional clients). BaseMachina IP (34.85.43.93/32) is always included."
  type        = list(string)
  default     = []
}

# ========================================
# Bridge環境変数
# ========================================

variable "fetch_interval" {
  description = "Interval for fetching public keys (e.g., 1h, 30m)"
  type        = string
  default     = "1h"
}

variable "fetch_timeout" {
  description = "Timeout for fetching public keys (e.g., 10s, 30s)"
  type        = string
  default     = "10s"
}

variable "port" {
  description = "Port number for Bridge container (cannot be 4321)"
  type        = number
  default     = 8080

  validation {
    condition     = var.port != 4321
    error_message = "Port 4321 is not allowed"
  }
}

variable "tenant_id" {
  description = "Tenant ID for authentication"
  type        = string
  sensitive   = true
}

# ========================================
# リソース設定変数
# ========================================

variable "cpu" {
  description = "CPU units for ECS task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096"
  }
}

variable "memory" {
  description = "Memory (MiB) for ECS task"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1

  validation {
    condition     = var.desired_count >= 1
    error_message = "Desired count must be at least 1"
  }
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period (days)"
  type        = number
  default     = 7
}

# ========================================
# タグ付けと命名変数
# ========================================

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = ""
}

