#!/bin/bash

# 加载环境变量
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# 停止旧的进程
echo "检查并停止旧的 webhook 进程..."
pkill -f webhook-server 2>/dev/null
sleep 1

# 构建并运行
echo "构建 Go 服务器..."
go build -o webhook-server main.go

if [ $? -eq 0 ]; then
    echo "启动 Webhook 服务器..."
    ./webhook-server
else
    echo "构建失败"
    exit 1
fi
