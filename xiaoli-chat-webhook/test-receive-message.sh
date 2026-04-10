#!/usr/bin/env bash
set -euo pipefail

# 配置
XIAOLI_TOKEN="${XIAOLI_TOKEN:-test-token-12345}"
WEBHOOK_URL="${WEBHOOK_URL:-http://localhost:8088}"

# 检查参数
if [ $# -lt 1 ]; then
    cat <<EOF
用法: $0 <回复内容> [频道ID]

示例:
  $0 "你好！我是 OpenClaw AI 助手"
  $0 "收到你的消息了" "xiaoli-chat"

环境变量:
  XIAOLI_TOKEN - Xiaoli Chat API token (默认: test-token-12345)
  WEBHOOK_URL  - Webhook 基础地址 (默认: http://localhost:8088)
EOF
    exit 1
fi

REPLY_TEXT="$1"
CHAT_ID="${2:-xiaoli-chat}"

# 构造 OpenClaw 回复消息体
REPLY_BODY=$(cat <<EOF
{
  "chatId": "$CHAT_ID",
  "text": "$REPLY_TEXT",
  "threadId": "thread-$(date +%s)"
}
EOF
)

echo "模拟 OpenClaw 发送回复到 Webhook 服务器..."
echo "频道: $CHAT_ID"
echo "回复: $REPLY_TEXT"
echo ""

# 发送请求到 /messages 端点
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL/messages" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $XIAOLI_TOKEN" \
  -d "$REPLY_BODY")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

echo "HTTP 状态码: $HTTP_CODE"
echo "响应: $BODY"

if [ "$HTTP_CODE" = "200" ]; then
    echo ""
    echo "✓ 回复接收成功!"
else
    echo ""
    echo "✗ 回复接收失败"
    exit 1
fi
