#!/bin/bash
set -e

# ========================================
# Failed Resources Cleanup Script
# ========================================
# terraform destroyが失敗した際に残ったリソースを手動でクリーンアップします

echo "========================================="
echo "Failed Resources Cleanup"
echo "========================================="
echo ""

# Parse command line arguments
RESOURCE_PREFIX="${1:-test-}"
REGION="${AWS_DEFAULT_REGION:-ap-northeast-1}"

echo "Region: $REGION"
echo "Resource prefix: $RESOURCE_PREFIX"
echo ""

# ========================================
# 1. Delete RDS instances
# ========================================
echo "### 1. Checking for RDS instances ###"
RDS_INSTANCES=$(aws rds describe-db-instances \
    --region "$REGION" \
    --query "DBInstances[?starts_with(DBInstanceIdentifier, '$RESOURCE_PREFIX')].DBInstanceIdentifier" \
    --output text)

if [ -n "$RDS_INSTANCES" ]; then
    echo "Found RDS instances:"
    for instance in $RDS_INSTANCES; do
        echo "  - $instance"
        echo "    Deleting (skip final snapshot)..."
        aws rds delete-db-instance \
            --region "$REGION" \
            --db-instance-identifier "$instance" \
            --skip-final-snapshot \
            2>/dev/null || echo "    Failed to delete (may already be deleting)"
    done
    
    echo "Waiting for RDS instances to be deleted (this may take 5-10 minutes)..."
    for instance in $RDS_INSTANCES; do
        aws rds wait db-instance-deleted \
            --region "$REGION" \
            --db-instance-identifier "$instance" \
            2>/dev/null || echo "  Instance $instance already deleted"
    done
    echo "✓ All RDS instances deleted"
else
    echo "No RDS instances found"
fi
echo ""

# ========================================
# 2. Delete RDS subnet groups
# ========================================
echo "### 2. Checking for RDS subnet groups ###"
SUBNET_GROUPS=$(aws rds describe-db-subnet-groups \
    --region "$REGION" \
    --query "DBSubnetGroups[?starts_with(DBSubnetGroupName, '$RESOURCE_PREFIX')].DBSubnetGroupName" \
    --output text)

if [ -n "$SUBNET_GROUPS" ]; then
    echo "Found subnet groups:"
    for group in $SUBNET_GROUPS; do
        echo "  - $group"
        echo "    Deleting..."
        aws rds delete-db-subnet-group \
            --region "$REGION" \
            --db-subnet-group-name "$group" \
            2>/dev/null || echo "    Failed to delete (may be in use or already deleted)"
    done
    echo "✓ All subnet groups deleted"
else
    echo "No subnet groups found"
fi
echo ""

# ========================================
# 3. Delete security groups
# ========================================
echo "### 3. Checking for security groups ###"
SECURITY_GROUPS=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --filters "Name=group-name,Values=${RESOURCE_PREFIX}*" \
    --query "SecurityGroups[?GroupName != 'default'].GroupId" \
    --output text)

if [ -n "$SECURITY_GROUPS" ]; then
    echo "Found security groups:"
    for sg in $SECURITY_GROUPS; do
        echo "  - $sg"
        
        # Wait a bit for ENIs to detach
        echo "    Waiting 30 seconds for ENIs to detach..."
        sleep 30
        
        echo "    Deleting..."
        aws ec2 delete-security-group \
            --region "$REGION" \
            --group-id "$sg" \
            2>/dev/null || echo "    Failed to delete (may have dependencies)"
    done
else
    echo "No security groups found"
fi
echo ""

# ========================================
# 4. Delete ACM certificates
# ========================================
echo "### 4. Checking for ACM certificates ###"
CERTIFICATES=$(aws acm list-certificates \
    --region "$REGION" \
    --query "CertificateSummaryList[?starts_with(DomainName, '${RESOURCE_PREFIX}') || contains(DomainName, '.bm-tftest.com')].CertificateArn" \
    --output text)

if [ -n "$CERTIFICATES" ]; then
    echo "Found certificates:"
    for cert in $CERTIFICATES; do
        echo "  - $cert"
        echo "    Deleting..."
        aws acm delete-certificate \
            --region "$REGION" \
            --certificate-arn "$cert" \
            2>/dev/null || echo "    Failed to delete (may be in use)"
    done
    echo "✓ All certificates deleted"
else
    echo "No certificates found"
fi
echo ""

echo "========================================="
echo "Cleanup complete"
echo "========================================="
echo ""
echo "If terraform destroy still fails, you may need to:"
echo "1. Wait a few more minutes for AWS resources to fully detach"
echo "2. Check the AWS Console for any remaining resources"
echo "3. Remove the terraform state: rm -rf terraform.tfstate*"
echo ""
