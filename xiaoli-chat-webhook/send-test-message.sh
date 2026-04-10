#!/usr/bin/env bash
set -euo pipefail

# 配置
WEBHOOK_SECRET="${WEBHOOK_SECRET:-test-secret-12345}"
WEBHOOK_URL="${WEBHOOK_URL:-http://localhost:8088/webhook}"

# 检查参数
if [ $# -lt 1 ]; then
    cat <<EOF
用法: $0 <消息内容> [用户ID] [频道ID]

示例:
  $0 "你好,OpenClaw!"
  $0 "介绍一下你自己" "user-123" "xiaoli-chat"

环境变量:
  WEBHOOK_SECRET - Webhook 签名密钥 (默认: test-secret-12345)
  WEBHOOK_URL    - Webhook 地址 (默认: http://localhost:8088/webhook)
EOF
    exit 1
fi

MESSAGE="$1"
USER_ID="${2:-user-test-$(date +%s)}"
CHANNEL_ID="${3:-xiaoli-chat}"

# 构造消息体
MESSAGE_BODY=$(cat <<EOF
{
  "event": "message",
  "timestamp": $(date +%s),
  "data": {
    "user": "$USER_ID",
    "message": "$MESSAGE",
    "channel": "$CHANNEL_ID"
  }
}
EOF
)

# 计算签名
SIGNATURE=$(echo -n "$MESSAGE_BODY" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" | awk '{print $2}')

echo "发送消息到 Xiaoli Chat Webhook..."
echo "用户: $USER_ID"
echo "频道: $CHANNEL_ID"
echo "消息: $MESSAGE"
echo ""

# 发送请求
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "x-xiaoli-signature: $SIGNATURE" \
  -d "$MESSAGE_BODY")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

echo "HTTP 状态码: $HTTP_CODE"
echo "响应: $BODY"

if [ "$HTTP_CODE" = "200" ]; then
    echo ""
    echo "✓ 消息发送成功!"
else
    echo ""
    echo "✗ 消息发送失败"
    exit 1
fi
