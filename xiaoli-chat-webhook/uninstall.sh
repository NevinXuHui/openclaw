#!/bin/bash

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SERVICE_NAME="xiaoli-webhook"
INSTALL_DIR="/opt/xiaoli-webhook"

echo -e "${GREEN}=== Xiaoli Chat Webhook 卸载脚本 ===${NC}"
echo ""

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误: 请使用 root 权限运行此脚本${NC}"
    echo "使用: sudo $0"
    exit 1
fi

# 停止服务
if systemctl is-active --quiet $SERVICE_NAME; then
    echo "停止服务..."
    systemctl stop $SERVICE_NAME
fi

# 禁用服务
if systemctl is-enabled --quiet $SERVICE_NAME 2>/dev/null; then
    echo "禁用服务..."
    systemctl disable $SERVICE_NAME
fi

# 删除 service 文件
if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
    echo "删除 service 文件..."
    rm -f "/etc/systemd/system/$SERVICE_NAME.service"
fi

# 重新加载 systemd
echo "重新加载 systemd..."
systemctl daemon-reload
systemctl reset-failed

echo -e "${GREEN}✓ 服务卸载成功！${NC}"
echo ""
echo "注意: 安装目录未被删除: $INSTALL_DIR"
echo "如需完全删除，请运行: sudo rm -rf $INSTALL_DIR"
