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

# 复制必要文件到安装目录
echo "复制文件到 $INSTALL_DIR..."
cp "$SCRIPT_DIR/.env" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/.env.example" "$INSTALL_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/run.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/$BINARY_NAME" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/README.md" "$INSTALL_DIR/" 2>/dev/null || true

# 设置权限
chmod +x "$INSTALL_DIR/run.sh"
chmod +x "$INSTALL_DIR/$BINARY_NAME"

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
