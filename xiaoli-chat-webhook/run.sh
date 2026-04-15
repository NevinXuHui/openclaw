#!/bin/bash

# 加载环境变量
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# 停止旧的进程
echo "检查并停止旧的 webhook 进程..."
pkill -f webhook-server 2>/dev/null
sleep 1

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
        echo "不支持的架构: $ARCH"
        exit 1
        ;;
esac

echo "检测到架构: $ARCH"
echo "使用二进制文件: $BINARY_NAME"

# 检查二进制文件是否存在
if [ ! -f "$BINARY_NAME" ]; then
    echo "二进制文件不存在，开始编译..."

    # 检查 Go 是否安装
    if ! command -v go &> /dev/null; then
        echo "错误: Go 未安装"
        echo "请安装 Go: https://go.dev/dl/"
        exit 1
    fi

    # 编译
    echo "编译 Go 服务器..."
    go build -o "$BINARY_NAME" main.go

    if [ $? -ne 0 ]; then
        echo "编译失败"
        exit 1
    fi

    chmod +x "$BINARY_NAME"
    echo "编译成功"
fi

# 运行服务器
echo "启动 Webhook 服务器..."
./"$BINARY_NAME"
