#!/bin/bash

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="xiaoli-webhook"
INSTALL_DIR="/opt/xiaoli-webhook"
SYSTEMD_DIR="/etc/systemd/system"

echo -e "${GREEN}=== Xiaoli Chat Webhook 安装脚本 ===${NC}"
echo ""

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误: 请使用 root 权限运行此脚本${NC}"
    echo "使用: sudo $0"
    exit 1
fi

# 检查 .env 文件
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${YELLOW}警告: .env 文件不存在${NC}"
    echo "请先创建 .env 文件并配置环境变量"
    echo "参考: cp .env.example .env"
    exit 1
fi

# 检测系统架构
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        BINARY_NAME="webhook-server"
        ;;
    aarch64|arm64)
        BINARY_NAME="webhook-server-arm64"
        ;;
    *)
        echo -e "${RED}不支持的架构: $ARCH${NC}"
        exit 1
        ;;
esac

echo "检测到架构: $ARCH"
echo "目标二进制: $BINARY_NAME"

# 检查并编译二进制文件
if [ ! -f "$SCRIPT_DIR/$BINARY_NAME" ]; then
    echo -e "${YELLOW}二进制文件不存在，开始编译...${NC}"

    # 检查 Go 是否安装
    if ! command -v go &> /dev/null; then
        echo -e "${RED}错误: Go 未安装${NC}"
        echo "请先安装 Go: https://go.dev/dl/"
        exit 1
    fi

    # 检查源码文件
    if [ ! -f "$SCRIPT_DIR/main.go" ]; then
        echo -e "${RED}错误: 找不到源码文件 main.go${NC}"
        exit 1
    fi

    # 编译
    echo "编译 Go 服务器..."
    cd "$SCRIPT_DIR"
    go build -o "$BINARY_NAME" main.go

    if [ $? -ne 0 ]; then
        echo -e "${RED}编译失败${NC}"
        exit 1
    fi

    chmod +x "$BINARY_NAME"
    echo -e "${GREEN}✓ 编译成功${NC}"
else
    echo -e "${GREEN}✓ 二进制文件已存在${NC}"
fi

# 创建安装目录
echo "创建安装目录: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# 生成 .env 配置文件
echo "生成配置文件..."

# 生成 webhook secret
# 优先使用 speech-client 的 secret（如果存在）
SPEECH_CLIENT_CONFIG="/usr/bin/cmcc_robot/install/speech_client/share/speech_client/config/openclaw_bridge.yaml"
if [ -f "$SPEECH_CLIENT_CONFIG" ]; then
    WEBHOOK_SECRET=$(grep "openclaw_secret:" "$SPEECH_CLIENT_CONFIG" | sed "s/.*openclaw_secret: '\([^']*\)'.*/\1/")
    if [ -n "$WEBHOOK_SECRET" ]; then
        echo "使用 speech-client 的现有 secret"
    fi
fi

# 如果没有找到，生成新的 secret
if [ -z "$WEBHOOK_SECRET" ]; then
    WEBHOOK_SECRET=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p -c 32)
    echo "生成新的 webhook secret"
fi

# 获取 OpenClaw Gateway token（如果可用）
OPENCLAW_TOKEN=""
if command -v openclaw &> /dev/null; then
    # 直接从配置文件读取，避免被混淆
    OPENCLAW_CONFIG="${HOME}/.openclaw/openclaw.json"
    if [ -f "$OPENCLAW_CONFIG" ]; then
        OPENCLAW_TOKEN=$(grep -A 2 '"auth"' "$OPENCLAW_CONFIG" | grep '"token"' | sed 's/.*"token": "\([^"]*\)".*/\1/')
    fi
    # 如果读取失败，尝试使用 openclaw config get（可能被混淆）
    if [ -z "$OPENCLAW_TOKEN" ] || [ "$OPENCLAW_TOKEN" = "__OPENCLAW_REDACTED__" ]; then
        OPENCLAW_TOKEN=$(openclaw config get gateway.auth.token 2>/dev/null || echo "")
    fi
fi

# 创建 .env 文件
cat > "$INSTALL_DIR/.env" <<EOF
# Xiaoli Chat Webhook 配置

# Webhook 验证密钥（必须与 Xiaoli Chat 配置一致）
WEBHOOK_SECRET=${WEBHOOK_SECRET}

# OpenClaw Gateway 地址
OPENCLAW_URL=http://localhost:18789

# Xiaoli Chat API Token（必须设置）
XIAOLI_TOKEN=test-token-placeholder

# OpenClaw API Token（如果需要）
OPENCLAW_TOKEN=${OPENCLAW_TOKEN}

# 服务器监听端口
PORT=8088
EOF

echo -e "${GREEN}✓ 配置文件已生成: $INSTALL_DIR/.env${NC}"
echo -e "${YELLOW}注意: 请根据实际情况修改 XIAOLI_TOKEN${NC}"

# 复制必要文件到安装目录
echo "复制文件到 $INSTALL_DIR..."
cp "$SCRIPT_DIR/.env.example" "$INSTALL_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/run.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/$BINARY_NAME" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/README.md" "$INSTALL_DIR/" 2>/dev/null || true

# 复制源码文件（用于 run.sh 自动编译）
echo "复制源码文件..."
cp "$SCRIPT_DIR/main.go" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/go.mod" "$INSTALL_DIR/"

# 复制测试脚本（可选）
echo "复制测试脚本..."
cp "$SCRIPT_DIR/send-test-message.sh" "$INSTALL_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/send-and-wait-reply.sh" "$INSTALL_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/send-with-sse.sh" "$INSTALL_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/test-receive-message.sh" "$INSTALL_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/chat-multiround.sh" "$INSTALL_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/test-multiround-auto.sh" "$INSTALL_DIR/" 2>/dev/null || true

# 复制卸载脚本
cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/" 2>/dev/null || true

# 设置权限
chmod +x "$INSTALL_DIR/run.sh"
chmod +x "$INSTALL_DIR/$BINARY_NAME"
chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true

# 创建 systemd service 文件
echo "创建 systemd service 文件..."
cat > "/tmp/$SERVICE_NAME.service" << EOF
[Unit]
Description=Xiaoli Chat Webhook Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=$INSTALL_DIR/.env
ExecStart=$INSTALL_DIR/run.sh
Restart=always
RestartSec=5
StandardOutput=append:$INSTALL_DIR/webhook.log
StandardError=append:$INSTALL_DIR/webhook.log

[Install]
WantedBy=multi-user.target
EOF

# 停止现有服务（如果正在运行）
if systemctl is-active --quiet $SERVICE_NAME; then
    echo "停止现有服务..."
    systemctl stop $SERVICE_NAME
fi

# 安装 service 文件
echo "安装 systemd service 文件..."
mv "/tmp/$SERVICE_NAME.service" "$SYSTEMD_DIR/$SERVICE_NAME.service"

# 重新加载 systemd
echo "重新加载 systemd..."
systemctl daemon-reload

# 启用服务
echo "启用服务（开机自启）..."
systemctl enable $SERVICE_NAME

# 启动服务
echo "启动服务..."
systemctl start $SERVICE_NAME

# 等待服务启动
sleep 2

# 检查服务状态
if systemctl is-active --quiet $SERVICE_NAME; then
    echo -e "${GREEN}✓ 服务安装并启动成功！${NC}"
    echo ""
    echo "安装位置: $INSTALL_DIR"
    echo ""
    echo -e "${YELLOW}=== 重要配置信息 ===${NC}"
    echo "Webhook Secret: $WEBHOOK_SECRET"
    echo "服务端口: 8088"
    echo "OpenClaw Gateway: http://localhost:18789"
    echo ""
    echo -e "${YELLOW}下一步操作：${NC}"
    echo "1. 配置 OpenClaw 通道（如果还未配置）:"
    echo "   openclaw config set channels.xiaoli-chat.enabled true"
    echo "   openclaw config set channels.xiaoli-chat.webhookSecret \"$WEBHOOK_SECRET\""
    echo "   openclaw config set channels.xiaoli-chat.baseUrl \"http://localhost:8088\""
    echo ""
    echo "2. 修改 Xiaoli Token（必需）:"
    echo "   编辑 $INSTALL_DIR/.env"
    echo "   设置 XIAOLI_TOKEN=your-actual-token"
    echo "   然后重启: sudo systemctl restart $SERVICE_NAME"
    echo ""
    echo "常用命令:"
    echo "  查看状态: sudo systemctl status $SERVICE_NAME"
    echo "  查看日志: sudo journalctl -u $SERVICE_NAME -f"
    echo "  停止服务: sudo systemctl stop $SERVICE_NAME"
    echo "  重启服务: sudo systemctl restart $SERVICE_NAME"
    echo "  禁用服务: sudo systemctl disable $SERVICE_NAME"
    echo ""
    echo "日志文件: $INSTALL_DIR/webhook.log"
    echo "配置文件: $INSTALL_DIR/.env"
else
    echo -e "${RED}✗ 服务启动失败${NC}"
    echo "查看详细错误信息:"
    echo "  sudo systemctl status $SERVICE_NAME"
    echo "  sudo journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi
