#!/usr/bin/env bash
set -euo pipefail

# 配置
WEBHOOK_SECRET="${WEBHOOK_SECRET:-test-secret-12345}"
WEBHOOK_URL="${WEBHOOK_URL:-http://localhost:8088}"

# 检查参数
if [ $# -lt 1 ]; then
    cat <<EOF
用法: $0 <消息内容> [用户ID] [频道ID]

示例:
  $0 "你好,OpenClaw!"
  $0 "介绍一下你自己" "user-123" "xiaoli-chat"

环境变量:
  WEBHOOK_SECRET - Webhook 签名密钥 (默认: test-secret-12345)
  WEBHOOK_URL    - Webhook 地址 (默认: http://localhost:8088)
EOF
    exit 1
fi

MESSAGE="$1"
USER_ID="${2:-user-test-$(date +%s)}"
CHANNEL_ID="${3:-xiaoli-chat}"

echo "=== SSE 实时推送测试 ==="
echo ""

# 在后台启动 SSE 监听
echo "1. 连接 SSE 流..."
curl -N -s "$WEBHOOK_URL/stream?chatId=$CHANNEL_ID" | while IFS= read -r line; do
    if [[ "$line" =~ ^data:\ (.*)$ ]]; then
        DATA="${BASH_REMATCH[1]}"
        TYPE=$(echo "$DATA" | jq -r '.type // empty')

        if [ "$TYPE" = "connected" ]; then
            echo "✓ SSE 连接成功"
            echo ""
        else
            # 收到回复消息
            TEXT=$(echo "$DATA" | jq -r '.text')
            TIMESTAMP=$(echo "$DATA" | jq -r '.timestamp')

            echo ""
            echo "📨 收到 AI 回复 (SSE 推送):"
            echo "时间: $TIMESTAMP"
            echo "---"
            echo "$TEXT"
            echo "---"

            # 收到回复后退出
            exit 0
        fi
    fi
done &

SSE_PID=$!

# 等待 SSE 连接建立
sleep 2

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

echo "2. 发送消息..."
echo "   用户: $USER_ID"
echo "   频道: $CHANNEL_ID"
echo "   消息: $MESSAGE"
echo ""

# 发送请求
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL/webhook" \
  -H "Content-Type: application/json" \
  -H "x-xiaoli-signature: $SIGNATURE" \
  -d "$MESSAGE_BODY")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ 消息发送成功"
    echo ""
    echo "3. 等待 AI 回复（通过 SSE 推送）..."

    # 等待 SSE 进程（最多 60 秒）
    for i in {1..60}; do
        if ! kill -0 $SSE_PID 2>/dev/null; then
            # SSE 进程已退出（收到回复）
            wait $SSE_PID 2>/dev/null || true
            exit 0
        fi
        sleep 1
    done

    # 超时
    kill $SSE_PID 2>/dev/null || true
    echo ""
    echo "⏱ 等待超时"
else
    kill $SSE_PID 2>/dev/null || true
    echo "✗ 消息发送失败: HTTP $HTTP_CODE"
    exit 1
fi
