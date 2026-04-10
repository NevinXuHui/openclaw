#!/usr/bin/env bash
set -euo pipefail

# 配置
WEBHOOK_URL="${WEBHOOK_URL:-http://localhost:8088}"
CHANNEL_ID="${CHANNEL_ID:-xiaoli-chat}"
THINKING_LEVEL="${THINKING_LEVEL:-}"  # 默认不设置，可选: off, low, medium, high, xhigh

# 检查是否指定了用户ID
if [ $# -gt 0 ]; then
    USER_ID="$1"
    shift
else
    USER_ID="user-autotest-$(date +%s)"
fi

echo "=== Xiaoli Chat 自动化多轮测试 ==="
echo ""

# 如果提供了额外参数，作为测试消息
if [ $# -gt 0 ]; then
    declare -a TEST_MESSAGES=("$@")
else
    # 默认测试对话列表
    declare -a TEST_MESSAGES=(
        "你好，我是测试用户"
        "你能做什么？"
        "帮我写一个 Hello World"
        "谢谢，再见"
    )
fi

echo "测试配置:"
echo "  用户ID: $USER_ID"
echo "  频道ID: $CHANNEL_ID"
echo "  消息数: ${#TEST_MESSAGES[@]}"
if [ -n "$THINKING_LEVEL" ]; then
    echo "  思考模式: $THINKING_LEVEL"
fi
echo ""
echo "提示: 使用相同的用户ID可以保持对话上下文"
echo "用法: $0 [用户ID] [消息1] [消息2] ..."
echo "示例: $0 user-123 \"第一条消息\" \"第二条消息\""
echo "环境变量:"
echo "  THINKING_LEVEL - 思考模式 (off/low/medium/high/xhigh)"
echo ""
echo "---"
echo ""

# 发送消息函数
send_message() {
    local message="$1"
    local webhook_secret="${WEBHOOK_SECRET:-test-secret-12345}"

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

    # 如果设置了 thinking 参数，添加到消息体
    if [ -n "$THINKING_LEVEL" ]; then
        message_body=$(echo "$message_body" | jq --arg thinking "$THINKING_LEVEL" '.data.thinking = $thinking')
    fi

    local signature=$(echo -n "$message_body" | openssl dgst -sha256 -hmac "$webhook_secret" | awk '{print $2}')

    curl -s -X POST "$WEBHOOK_URL/webhook" \
      -H "Content-Type: application/json" \
      -H "x-xiaoli-signature: $signature" \
      -d "$message_body" > /dev/null

    return $?
}

# 获取最新回复
get_latest_reply() {
    curl -s "$WEBHOOK_URL/replies?chatId=$CHANNEL_ID&limit=1" | jq -r '.replies[0].text // empty'
}

# 执行测试
ROUND=1
for message in "${TEST_MESSAGES[@]}"; do
    echo "[$ROUND/${#TEST_MESSAGES[@]}] 💬 你: $message"

    if send_message "$message"; then
        echo "    ✓ 发送成功"
    else
        echo "    ✗ 发送失败"
        continue
    fi

    # 等待回复（最多 30 秒）
    echo "    ⏳ 等待 AI 回复..."

    REPLY=""
    for i in {1..30}; do
        sleep 1
        REPLY=$(get_latest_reply)
        if [ -n "$REPLY" ]; then
            break
        fi
    done

    if [ -n "$REPLY" ]; then
        echo "    🤖 AI: $REPLY"
    else
        echo "    ⏱ 超时，未收到回复"
    fi

    echo ""
    ROUND=$((ROUND + 1))

    # 轮次间隔
    if [ $ROUND -le ${#TEST_MESSAGES[@]} ]; then
        sleep 2
    fi
done

echo "---"
echo "测试完成！共 ${#TEST_MESSAGES[@]} 轮对话"
