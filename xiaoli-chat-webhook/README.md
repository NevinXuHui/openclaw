# Xiaoli Chat Webhook 服务器

这是一个用于接收 Xiaoli Chat webhook 并转发到 OpenClaw 的 Go 服务器。

## 功能特性

- ✅ 接收 Xiaoli Chat webhook 请求
- ✅ HMAC-SHA256 签名验证
- ✅ 消息转发到 OpenClaw Gateway
- ✅ 健康检查端点
- ✅ 环境变量配置

## 快速开始

### 1. 配置环境变量

复制示例配置文件并修改：

```bash
cp .env.example .env
```

编辑 `.env` 文件，设置以下变量：

```bash
WEBHOOK_SECRET=your-webhook-secret-here  # 与 Xiaoli Chat 配置一致
OPENCLAW_URL=http://localhost:18789      # OpenClaw Gateway 地址
OPENCLAW_TOKEN=                          # OpenClaw API Token（可选）
PORT=8080                                # 服务器监听端口
```

### 2. 运行服务器

```bash
chmod +x run.sh
./run.sh
```

或者手动运行：

```bash
go build -o webhook-server main.go
./webhook-server
```

### 3. 测试服务器

健康检查：
```bash
curl http://localhost:8080/health
```

测试 webhook（需要正确的签名）：
```bash
curl -X POST http://localhost:8080/webhook \
  -H "Content-Type: application/json" \
  -H "X-Signature: your-signature" \
  -d '{
    "event": "message",
    "timestamp": 1234567890,
    "data": {
      "user": "test-user",
      "channel": "xiaoli-chat",
      "message": "Hello OpenClaw!"
    }
  }'
```

## API 端点

### POST /webhook

接收 Xiaoli Chat webhook 请求。

**请求头：**
- `Content-Type: application/json`
- `X-Signature: <HMAC-SHA256 签名>`

**请求体：**
```json
{
  "event": "message",
  "timestamp": 1234567890,
  "data": {
    "user": "username",
    "channel": "channel-id",
    "message": "消息内容"
  }
}
```

### GET /health

健康检查端点。

**响应：**
```json
{
  "status": "healthy",
  "time": "2026-04-09T10:00:00Z"
}
```

## 签名验证

服务器使用 HMAC-SHA256 验证 webhook 请求的签名：

```
signature = HMAC-SHA256(webhook_secret, request_body)
```

Xiaoli Chat 需要在请求头中包含 `X-Signature` 字段。

## 部署建议

### 使用 systemd

创建 `/etc/systemd/system/xiaoli-webhook.service`：

```ini
[Unit]
Description=Xiaoli Chat Webhook Server
After=network.target

[Service]
Type=simple
User=xuhui
WorkingDirectory=/home/xuhui/xiaoli-chat-webhook
EnvironmentFile=/home/xuhui/xiaoli-chat-webhook/.env
ExecStart=/home/xuhui/xiaoli-chat-webhook/webhook-server
Restart=always

[Install]
WantedBy=multi-user.target
```

启动服务：
```bash
sudo systemctl daemon-reload
sudo systemctl enable xiaoli-webhook
sudo systemctl start xiaoli-webhook
```

### 使用 Docker

创建 `Dockerfile`：

```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o webhook-server main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/webhook-server .
EXPOSE 8080
CMD ["./webhook-server"]
```

构建并运行：
```bash
docker build -t xiaoli-webhook .
docker run -d -p 8080:8080 --env-file .env xiaoli-webhook
```

## 配置 OpenClaw

在 OpenClaw 中配置 xiaoli-chat 频道：

```bash
openclaw config set channels.xiaoli-chat.enabled true
openclaw config set channels.xiaoli-chat.token "your-token"
openclaw config set channels.xiaoli-chat.baseUrl "https://your-xiaoli-server.com"
openclaw config set channels.xiaoli-chat.webhookSecret "your-webhook-secret"
```

重启 OpenClaw Gateway：
```bash
openclaw gateway restart
```

## 故障排查

### 签名验证失败

确保 `WEBHOOK_SECRET` 与 Xiaoli Chat 配置完全一致。

### 无法连接到 OpenClaw

检查 `OPENCLAW_URL` 是否正确，确保 OpenClaw Gateway 正在运行。

### 查看日志

服务器会输出详细的日志信息，包括接收到的请求和转发状态。

## 许可证

MIT
