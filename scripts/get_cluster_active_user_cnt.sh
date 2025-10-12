#!/usr/bin/env bash
#===============================================
# Script Name   : get_cluster_active_user_cnt.sh
# Description   : Clusterのパブリックアクティブユーザー数を取得してdata.jsonを更新
# Developer     : inea
#===============================================

set -e

REPO_DIR="$(dirname "$(dirname "$0")")"
DATA_FILE="$REPO_DIR/data.json"
DELETE_AFTER_DAYS=90

URL1="https://api.cluster.mu/v1/live_activity/spaces/hots"
URL2="https://api.cluster.mu/v1/events/in_session?pageSize=100"
URL3="https://api.cluster.mu/v1/events/"

HEADERS=(
    -H "x-cluster-app-version: 3.55.2510011744"
    -H "x-cluster-build-version: 2510101302"
    -H "x-cluster-device: Web"
    -H "x-cluster-platform: Web"
)

# data.json が存在しない場合は初期化
if [ ! -f "$DATA_FILE" ]; then
  echo "[]" > "$DATA_FILE"
fi

# 6回ループ（5分おきに30分間）
for i in {1..6}; do
  TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # --- Cluster APIからデータ取得 ---
  SPACE_USER_CNT=$(curl -s "${HEADERS[@]}" "$URL1" | jq '[.contents[].playerCount] | add // 0')

  EVENT_IDS=$(curl -s "${HEADERS[@]}" "$URL2" | jq -r '.events.summary[].id')
  EVENT_USER_CNT=0
  for EVENT_ID in $EVENT_IDS; do
    CNT=$(curl -s "${HEADERS[@]}" "${URL3}${EVENT_ID}" | jq '.liveEntry.users | length')
    EVENT_USER_CNT=$((EVENT_USER_CNT + CNT))
  done

  USER_CNT=$((SPACE_USER_CNT + EVENT_USER_CNT))

  echo "[$TIME] userCnt: $USER_CNT"

  # --- 古いデータ削除 & 新データ追加 ---
  TMP_JSON=$(mktemp)

  # 古いデータ削除
  jq --arg cutoff "$(date -u -d "-${DELETE_AFTER_DAYS} days" +"%Y-%m-%dT%H:%M:%SZ")" \
     'map(select(.time > $cutoff))' "$DATA_FILE" > "$TMP_JSON"

  # 新しいデータ追加
  jq --arg time "$TIME" --argjson cnt "$USER_CNT" \
     '. += [{time:$time, userCnt:$cnt}]' "$TMP_JSON" > "$DATA_FILE"

  rm "$TMP_JSON"

  # 5分待機（最後はスキップ）
  if [ $i -lt 6 ]; then
    sleep 300
  fi
done
