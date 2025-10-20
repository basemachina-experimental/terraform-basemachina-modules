#!/bin/bash
set -e

# ========================================
# ACM Certificate DNS Validation Diagnosis Script
# ========================================
# このスクリプトはACM証明書のDNS検証が失敗した場合の
# 診断情報を収集します。

if [ -z "$1" ]; then
    echo "Usage: $0 <domain-name> [route53-zone-id]"
    echo "Example: $0 bridge.example.com Z1234567890ABC"
    exit 1
fi

DOMAIN_NAME="$1"
ZONE_ID="${2:-}"

echo "========================================="
echo "ACM Certificate DNS Validation Diagnosis"
echo "========================================="
echo "Domain: $DOMAIN_NAME"
echo "Zone ID: ${ZONE_ID:-<not provided>}"
echo ""

# ========================================
# 1. Check if domain exists in Route53
# ========================================
echo "### 1. Checking Route53 Hosted Zone ###"
if [ -n "$ZONE_ID" ]; then
    echo "Checking zone: $ZONE_ID"
    aws route53 get-hosted-zone --id "$ZONE_ID" 2>/dev/null || {
        echo "ERROR: Zone $ZONE_ID not found!"
        exit 1
    }
    echo "✓ Zone exists"
else
    echo "No zone ID provided, skipping zone check"
fi
echo ""

# ========================================
# 2. List all DNS records for the domain
# ========================================
echo "### 2. DNS Records in Route53 ###"
if [ -n "$ZONE_ID" ]; then
    echo "Listing records in zone $ZONE_ID:"
    aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
        --query "ResourceRecordSets[?contains(Name, '$DOMAIN_NAME')]" \
        --output table
else
    echo "No zone ID provided, skipping record listing"
fi
echo ""

# ========================================
# 3. Check DNS propagation
# ========================================
echo "### 3. DNS Propagation Check ###"
echo "Checking if DNS records are resolvable:"

# Check A record
echo -n "A record for $DOMAIN_NAME: "
dig +short "$DOMAIN_NAME" A || echo "Not found"

# Check CNAME records (for validation)
echo -n "CNAME records for _acm-challenge.$DOMAIN_NAME: "
dig +short "_acm-challenge.$DOMAIN_NAME" CNAME || echo "Not found"

echo ""

# ========================================
# 4. Check ACM certificates
# ========================================
echo "### 4. ACM Certificates ###"
echo "Listing ACM certificates for domain $DOMAIN_NAME:"
aws acm list-certificates \
    --query "CertificateSummaryList[?contains(DomainName, '$DOMAIN_NAME')]" \
    --output table

echo ""
echo "Certificate details (if any):"
CERT_ARN=$(aws acm list-certificates \
    --query "CertificateSummaryList[?DomainName=='$DOMAIN_NAME'].CertificateArn | [0]" \
    --output text)

if [ "$CERT_ARN" != "None" ] && [ -n "$CERT_ARN" ]; then
    echo "Found certificate: $CERT_ARN"
    echo ""
    echo "Certificate status:"
    aws acm describe-certificate --certificate-arn "$CERT_ARN" \
        --query "Certificate.{Status:Status,DomainName:DomainName,ValidationMethod:DomainValidationOptions[0].ValidationMethod}" \
        --output table
    
    echo ""
    echo "Validation records:"
    aws acm describe-certificate --certificate-arn "$CERT_ARN" \
        --query "Certificate.DomainValidationOptions[*].ResourceRecord" \
        --output table
else
    echo "No certificate found for $DOMAIN_NAME"
fi
echo ""

# ========================================
# 5. Common issues and solutions
# ========================================
echo "### 5. Common Issues and Solutions ###"
echo ""
echo "If DNS validation is failing, check:"
echo ""
echo "1. Route53 Zone ID is correct:"
echo "   aws route53 list-hosted-zones --query \"HostedZones[?Name=='example.com.'].Id\" --output text"
echo ""
echo "2. Domain name matches the zone:"
echo "   - Zone: example.com"
echo "   - Domain: bridge.example.com (✓ correct)"
echo "   - Domain: bridge.different.com (✗ wrong zone)"
echo ""
echo "3. DNS propagation time:"
echo "   - Initial creation: 5-10 minutes"
echo "   - Subsequent updates: 1-2 minutes"
echo ""
echo "4. Validation record exists in Route53:"
echo "   aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID \\"
echo "     --query \"ResourceRecordSets[?Type=='CNAME' && contains(Name, '_acm-challenge')]\""
echo ""
echo "========================================="
