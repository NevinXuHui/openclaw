# Xiaoli Chat Webhook 服务器

这是一个用于接收 Xiaoli Chat webhook 并转发到 OpenClaw 的 Go 服务器。

## 功能特性

- ✅ 接收 Xiaoli Chat webhook 请求
- ✅ HMAC-SHA256 签名验证
- ✅ 消息转发到 OpenClaw Gateway
- ✅ 图片/文件媒体附件支持（入站和出站）
- ✅ SSE 实时推送（含媒体字段）
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

测试带图片的 webhook：

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
      "message": "看看这张图",
      "media": [
        {"url": "https://example.com/photo.jpg", "type": "image/jpeg", "name": "photo.jpg"}
      ]
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
    "message": "消息内容",
    "media": [
      {
        "url": "https://example.com/photo.jpg",
        "type": "image/jpeg",
        "name": "photo.jpg"
      }
    ]
  }
}
```

> `media` 字段为可选数组。每个附件包含 `url`（必填）、`type`（MIME 类型，可选）、`name`（文件名，可选）。

### GET /health

健康检查端点。

**响应：**

```json
{
  "status": "healthy",
  "time": "2026-04-09T10:00:00Z"
}
```

### POST /messages

接收来自 OpenClaw 的回复。

**请求头：**

- `Content-Type: application/json`
- `Authorization: Bearer <token>`

**请求体：**

```json
{
  "chatId": "channel-id",
  "text": "回复内容",
  "threadId": "可选",
  "mediaUrl": "https://example.com/generated-image.png",
  "mediaType": "image/png"
}
```

> `mediaUrl` 和 `mediaType` 为可选字段。当 AI 生成了图片或文件时，OpenClaw 会通过这两个字段传递媒体 URL。

**响应：**

```json
{
  "id": "message-id"
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

### 流式输出问题（已修复 2026-04-14）

**症状**：只收到最后一条消息，第一条消息丢失。

**原因**：之前使用异步处理（`go func()`）导致消息竞态条件。

**解决方案**：已改为同步处理消息存储和广播，确保所有消息按顺序完整到达。

**验证方法**：

1. 发送需要工具调用的消息（如"查询天气"）
2. 应该收到两条独立的消息：
   - 第一条："正在查询..."（5-7 秒后到达）
   - 第二条：查询结果（20-30 秒后到达）
3. 消息间隔应该是 4-9ms（LLM 生成间隔）

## 性能优化

### 消息处理

- **同步处理**：消息存储和广播采用同步方式，确保顺序性和完整性
- **轻量级操作**：内存操作 + channel 发送，延迟 <1ms
- **无阻塞风险**：处理逻辑简单，不会造成 HTTP 响应延迟

### 并发安全

- `recentReplies`：使用 `sync.RWMutex` 保护
- `sseClients`：使用 `sync.Mutex` 保护
- HTTP 客户端：全局复用，60 秒超时

## 许可证

MIT
