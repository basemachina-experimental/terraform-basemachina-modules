# ========================================
# ACM Certificate with DNS Validation
# ========================================
# カスタムドメインに対してACM証明書をDNS検証で自動発行します。
#
# 必須変数:
# - bridge_domain_name: Bridgeのドメイン名（例: bridge.example.com）
# - route53_zone_id: 既存のRoute53 Hosted Zone ID
#
# ACM証明書のDNS検証レコードとALBへのAレコードが自動的に作成されます。

# ========================================
# ACM Certificate
# ========================================
# DNS検証方式でACM証明書を発行

resource "aws_acm_certificate" "bridge" {
  domain_name       = var.bridge_domain_name
  validation_method = "DNS"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-bridge-cert"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ========================================
# DNS Validation Records
# ========================================
# ACM証明書のDNS検証用レコードをRoute53に自動作成

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.bridge.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

# ========================================
# Certificate Validation
# ========================================
# 自動作成した検証レコードでvalidation完了を待つ

resource "aws_acm_certificate_validation" "bridge" {
  certificate_arn         = aws_acm_certificate.bridge.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "15m"
  }
}

# ========================================
# Local Values
# ========================================

locals {
  # ACM証明書ARNを使用（DNS検証完了後に利用可能）
  final_certificate_arn = aws_acm_certificate.bridge.arn

  # Route53設定をモジュールに渡す
  final_domain_name     = var.bridge_domain_name
  final_route53_zone_id = var.route53_zone_id
}
