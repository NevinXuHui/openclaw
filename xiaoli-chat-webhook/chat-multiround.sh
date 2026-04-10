#!/usr/bin/env bash
set -euo pipefail

# 配置
WEBHOOK_SECRET="${WEBHOOK_SECRET:-test-secret-12345}"
WEBHOOK_URL="${WEBHOOK_URL:-http://localhost:8088}"
CHANNEL_ID="${CHANNEL_ID:-xiaoli-chat}"
USER_ID="${USER_ID:-user-multiround-$(date +%s)}"

echo "=== Xiaoli Chat 多轮对话测试 ==="
echo ""
echo "配置信息:"
echo "  用户ID: $USER_ID"
echo "  频道ID: $CHANNEL_ID"
echo "  Webhook: $WEBHOOK_URL"
echo ""
echo "使用说明:"
echo "  - 输入消息后按回车发送"
echo "  - 输入 'exit' 或 'quit' 退出"
echo "  - 输入 'clear' 清空屏幕"
echo ""
echo "---"
echo ""

# SSE 连接函数
start_sse_listener() {
    curl -N -s "$WEBHOOK_URL/stream?chatId=$CHANNEL_ID" | while IFS= read -r line; do
        if [[ "$line" =~ ^data:\ (.*)$ ]]; then
            DATA="${BASH_REMATCH[1]}"
            TYPE=$(echo "$DATA" | jq -r '.type // empty' 2>/dev/null || echo "")

            if [ "$TYPE" = "connected" ]; then
                echo "[系统] SSE 连接成功" >&2
            else
                # 收到回复消息
                TEXT=$(echo "$DATA" | jq -r '.text' 2>/dev/null || echo "$DATA")
                TIMESTAMP=$(echo "$DATA" | jq -r '.timestamp' 2>/dev/null || date -Iseconds)

                echo "" >&2
                echo "🤖 AI: $TEXT" >&2
                echo "" >&2
                echo -n "💬 你: " >&2
            fi
        fi
    done
}

# 发送消息函数
send_message() {
    local message="$1"

    # 构造消息体
    local message_body=$(cat <<EOF
{
  "event": "message",
  "timestamp": $(date +%s),
  "data": {
    "user": "$USER_ID",
    "message": "$message",
    "channel": "$CHANNEL_ID"
  }
}
EOF
)

    # 计算签名
    local signature=$(echo -n "$message_body" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" | awk '{print $2}')

    # 发送请求
    local response=$(curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL/webhook" \
      -H "Content-Type: application/json" \
      -H "x-xiaoli-signature: $signature" \
      -d "$message_body")

    local http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" != "200" ]; then
        echo "[错误] 消息发送失败: HTTP $http_code" >&2
        return 1
    fi
}

# 启动 SSE 监听（后台）
start_sse_listener &
SSE_PID=$!

# 等待 SSE 连接建立
sleep 2

# 清理函数
cleanup() {
    echo ""
    echo "[系统] 正在退出..."
    kill $SSE_PID 2>/dev/null || true
    exit 0
}

trap cleanup SIGINT SIGTERM

# 主循环
echo -n "💬 你: "
while IFS= read -r message; do
    # 处理特殊命令
    case "$message" in
        exit|quit)
            cleanup
            ;;
        clear)
            clear
            echo "=== Xiaoli Chat 多轮对话测试 ==="
            echo ""
            echo -n "💬 你: "
            continue
            ;;
        "")
            echo -n "💬 你: "
            continue
            ;;
    esac

    # 发送消息
    if send_message "$message"; then
        echo "[发送成功] 等待 AI 回复..."
    else
        echo "[发送失败]"
    fi

    echo -n "💬 你: "
done

cleanup
