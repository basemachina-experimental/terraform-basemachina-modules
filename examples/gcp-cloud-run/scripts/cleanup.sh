#!/bin/bash
#
# GCP リソース強制クリーンアップスクリプト
#
# 使用方法:
#   ./cleanup.sh <project-id> [service-name-prefix]
#
# 例:
#   ./cleanup.sh my-gcp-project basemachina-bridge-example
#   ./cleanup.sh my-gcp-project  # デフォルト: basemachina-bridge-example
#

set -e

# ========================================
# 引数チェック
# ========================================

if [ $# -lt 1 ]; then
    echo "使用方法: $0 <project-id> [service-name-prefix]"
    echo ""
    echo "例:"
    echo "  $0 my-gcp-project basemachina-bridge-example"
    echo "  $0 my-gcp-project  # デフォルト: basemachina-bridge-example"
    exit 1
fi

PROJECT_ID=$1
SERVICE_NAME_PREFIX=${2:-"basemachina-bridge-example"}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "GCP リソース強制クリーンアップ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "プロジェクト: $PROJECT_ID"
echo "サービス名プレフィックス: $SERVICE_NAME_PREFIX"
echo ""

# ========================================
# 確認
# ========================================

read -p "本当にリソースを削除しますか？ (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "キャンセルしました。"
    exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ 1: Cloud Run サービスの削除"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cloud Runサービスを検索して削除
for region in asia-northeast1 us-central1 europe-west1; do
    echo "リージョン $region のCloud Runサービスを確認中..."
    SERVICES=$(gcloud run services list --project=$PROJECT_ID --region=$region --format="value(metadata.name)" --filter="metadata.name:${SERVICE_NAME_PREFIX}*" 2>/dev/null || true)

    if [ -n "$SERVICES" ]; then
        for service in $SERVICES; do
            echo "  削除中: $service (リージョン: $region)"
            gcloud run services delete $service --project=$PROJECT_ID --region=$region --quiet || true
        done
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ 2: Cloud SQL インスタンスの削除"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cloud SQLインスタンスを検索して削除
echo "  Cloud SQLインスタンスを検索中..."
SQL_INSTANCES=$(timeout 30 gcloud sql instances list --project=$PROJECT_ID --format="value(name)" --filter="name:${SERVICE_NAME_PREFIX}*" 2>/dev/null || true)

if [ -n "$SQL_INSTANCES" ]; then
    for instance in $SQL_INSTANCES; do
        echo "  削除を開始: $instance"
        echo "  注意: Cloud SQL削除には5-10分かかる場合があります"

        # バックグラウンドで削除を開始
        gcloud sql instances delete $instance --project=$PROJECT_ID --quiet &
        DELETE_PID=$!

        # 削除の進捗を表示
        echo "  削除中（PID: $DELETE_PID）... 最大10分待機します"

        # 10分間待機（削除が完了するまで）
        for i in {1..20}; do
            if ps -p $DELETE_PID > /dev/null 2>&1; then
                echo "  ... ${i}0秒経過（削除進行中）"
                sleep 30
            else
                echo "  削除完了"
                break
            fi
        done

        # プロセスがまだ実行中の場合は強制終了
        if ps -p $DELETE_PID > /dev/null 2>&1; then
            echo "  警告: 削除が10分経過しても完了しませんでした"
            echo "  バックグラウンドで削除が続行されます"
            kill $DELETE_PID 2>/dev/null || true
        fi
    done

    # 追加の待機時間
    echo "  削除完了を確認中（30秒）..."
    sleep 30
else
    echo "  Cloud SQLインスタンスが見つかりませんでした。"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ 3: VPC Peering 接続の削除"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# VPCネットワークを検索
NETWORKS=$(gcloud compute networks list --project=$PROJECT_ID --format="value(name)" --filter="name:${SERVICE_NAME_PREFIX}*" 2>/dev/null || true)

if [ -n "$NETWORKS" ]; then
    for network in $NETWORKS; do
        echo "  VPC Peering接続を削除中: $network"
        gcloud services vpc-peerings delete \
            --service=servicenetworking.googleapis.com \
            --network=$network \
            --project=$PROJECT_ID \
            --quiet || true

        # VPC Peering削除完了まで待機
        echo "  VPC Peering削除完了を待機中（30秒）..."
        sleep 30
    done
else
    echo "  VPCネットワークが見つかりませんでした。"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ 4: Load Balancer の削除"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# URL Mapを削除
URL_MAPS=$(gcloud compute url-maps list --project=$PROJECT_ID --format="value(name)" --filter="name:${SERVICE_NAME_PREFIX}*" 2>/dev/null || true)
for map in $URL_MAPS; do
    echo "  削除中: URL Map $map"
    gcloud compute url-maps delete $map --project=$PROJECT_ID --global --quiet || true
done

# Target HTTPS Proxyを削除
HTTPS_PROXIES=$(gcloud compute target-https-proxies list --project=$PROJECT_ID --format="value(name)" --filter="name:${SERVICE_NAME_PREFIX}*" 2>/dev/null || true)
for proxy in $HTTPS_PROXIES; do
    echo "  削除中: Target HTTPS Proxy $proxy"
    gcloud compute target-https-proxies delete $proxy --project=$PROJECT_ID --global --quiet || true
done

# Target HTTP Proxyを削除
HTTP_PROXIES=$(gcloud compute target-http-proxies list --project=$PROJECT_ID --format="value(name)" --filter="name:${SERVICE_NAME_PREFIX}*" 2>/dev/null || true)
for proxy in $HTTP_PROXIES; do
    echo "  削除中: Target HTTP Proxy $proxy"
    gcloud compute target-http-proxies delete $proxy --project=$PROJECT_ID --global --quiet || true
done

# SSL証明書を削除
SSL_CERTS=$(gcloud compute ssl-certificates list --project=$PROJECT_ID --format="value(name)" --filter="name:${SERVICE_NAME_PREFIX}*" 2>/dev/null || true)
for cert in $SSL_CERTS; do
    echo "  削除中: SSL Certificate $cert"
    gcloud compute ssl-certificates delete $cert --project=$PROJECT_ID --global --quiet || true
done

# Forwarding Ruleを削除
FORWARDING_RULES=$(gcloud compute forwarding-rules list --project=$PROJECT_ID --global --format="value(name)" --filter="name:${SERVICE_NAME_PREFIX}*" 2>/dev/null || true)
for rule in $FORWARDING_RULES; do
    echo "  削除中: Forwarding Rule $rule"
    gcloud compute forwarding-rules delete $rule --project=$PROJECT_ID --global --quiet || true
done

# Backend Serviceを削除
BACKEND_SERVICES=$(gcloud compute backend-services list --project=$PROJECT_ID --global --format="value(name)" --filter="name:${SERVICE_NAME_PREFIX}*" 2>/dev/null || true)
for service in $BACKEND_SERVICES; do
    echo "  削除中: Backend Service $service"
    gcloud compute backend-services delete $service --project=$PROJECT_ID --global --quiet || true
done

# Network Endpoint Groupを削除
for region in asia-northeast1 us-central1 europe-west1; do
    NEGS=$(gcloud compute network-endpoint-groups list --project=$PROJECT_ID --format="value(name)" --filter="name:${SERVICE_NAME_PREFIX}*" 2>/dev/null || true)
    for neg in $NEGS; do
        echo "  削除中: Network Endpoint Group $neg (リージョン: $region)"
        gcloud compute network-endpoint-groups delete $neg --project=$PROJECT_ID --region=$region --quiet || true
    done
done

# Global Addressを削除
ADDRESSES=$(gcloud compute addresses list --project=$PROJECT_ID --global --format="value(name)" --filter="name:${SERVICE_NAME_PREFIX}*" 2>/dev/null || true)
for address in $ADDRESSES; do
    echo "  削除中: Global Address $address"
    gcloud compute addresses delete $address --project=$PROJECT_ID --global --quiet || true
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ステップ 5: VPC ネットワークとサブネットの削除"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# サブネットを削除
SUBNETS=$(gcloud compute networks subnets list --project=$PROJECT_ID --format="value(name,region)" --filter="name:${SERVICE_NAME_PREFIX}*" 2>/dev/null || true)
if [ -n "$SUBNETS" ]; then
    echo "$SUBNETS" | while read subnet region; do
        if [ -n "$subnet" ] && [ -n "$region" ]; then
            echo "  削除中: Subnet $subnet (リージョン: $region)"
            gcloud compute networks subnets delete $subnet --project=$PROJECT_ID --region=$region --quiet || true
        fi
    done
fi

# グローバルアドレスを削除
GLOBAL_ADDRESSES=$(gcloud compute addresses list --project=$PROJECT_ID --global --format="value(name)" --filter="name:${SERVICE_NAME_PREFIX}*" 2>/dev/null || true)
if [ -n "$GLOBAL_ADDRESSES" ]; then
    for address in $GLOBAL_ADDRESSES; do
        echo "  削除中: Global Address $address"
        gcloud compute addresses delete $address --project=$PROJECT_ID --global --quiet || true
    done
fi

# VPCネットワークを削除
if [ -n "$NETWORKS" ]; then
    for network in $NETWORKS; do
        echo "  削除中: VPC Network $network"
        gcloud compute networks delete $network --project=$PROJECT_ID --quiet || true
    done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ クリーンアップ完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "すべてのリソースの削除を試みました。"
echo "GCPコンソールで残存リソースがないことを確認してください。"
echo ""
