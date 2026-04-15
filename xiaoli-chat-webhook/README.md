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
- ✅ 多架构支持（x86-64 和 ARM64）

## 多架构支持

服务器支持以下架构：
- ✅ x86-64 (AMD64)
- ✅ ARM64 (aarch64)

启动脚本会自动检测系统架构并使用对应的二进制文件。如果二进制文件不存在，会自动编译。

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
XIAOLI_TOKEN=your-xiaoli-token-here      # Xiaoli Chat API Token
PORT=8088                                # 服务器监听端口
```

### 2. 运行服务器

#### 方式 1：使用启动脚本（推荐）

```bash
chmod +x run.sh
./run.sh
```

启动脚本会：
1. 自动检测系统架构（x86-64 或 ARM64）
2. 选择对应的二进制文件
3. 如果二进制文件不存在，自动编译
4. 启动服务器

#### 方式 2：手动运行

**ARM64 系统**：
```bash
./webhook-server-arm64
```

**x86-64 系统**：
```bash
./webhook-server
```

#### 方式 3：从源码编译并运行

```bash
# 确保已安装 Go 1.22+
go version

# 编译
go build -o webhook-server-$(uname -m) main.go

# 运行
./webhook-server-$(uname -m)
```

### 3. 测试服务器

健康检查：

```bash
curl http://localhost:8088/health
# 输出: {"status":"healthy","time":"2026-04-15T11:28:38+08:00"}
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

### GET /stream

**SSE（Server-Sent Events）实时推送端点**

实时接收 OpenClaw 回复消息，支持多条消息流式推送。

**查询参数：**

- `chatId`: 频道 ID（必填）

**示例：**

```bash
curl -N http://localhost:8080/sse?chatId=xiaoli-chat
```

**响应格式（SSE 流）：**

```
data: {"id":"reply-1776148808518524494","text":"好的,我来查询天气。","chatId":"xiaoli-chat","timestamp":1776148808518}

data: {"id":"reply-1776148819508328164","text":"⛅ 多云,24°C","chatId":"xiaoli-chat","timestamp":1776148819508}
```

**字段说明：**

- `id`: 消息唯一 ID（纳秒时间戳）
- `text`: 回复文本内容
- `chatId`: 频道 ID
- `timestamp`: 消息时间戳（毫秒）

**使用场景：**

- ROS2 Bridge 实时接收 OpenClaw 回复
- Web 前端实时显示对话
- 监控和调试工具

**特性：**

- ✅ 持久连接，自动重连
- ✅ 实时推送，延迟 < 100ms
- ✅ 支持多客户端同时连接
- ✅ 自动过滤频道消息

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

**处理流程：**

1. 接收 OpenClaw 回复
2. 存储到内存（`recentReplies`）
3. 通过 SSE 实时推送给所有连接的客户端
4. 返回消息 ID

## 签名验证

服务器使用 HMAC-SHA256 验证 webhook 请求的签名：

```
signature = HMAC-SHA256(webhook_secret, request_body)
```

Xiaoli Chat 需要在请求头中包含 `X-Signature` 字段。

## 部署建议

### 多架构部署

服务器支持 x86-64 和 ARM64 架构：

**x86-64 系统**：
```bash
./webhook-server
```

**ARM64 系统**：
```bash
./webhook-server-arm64
```

**自动检测（推荐）**：
```bash
./run.sh  # 自动检测架构并使用对应二进制
```

**从源码编译**：
```bash
# 编译当前架构
go build -o webhook-server-$(uname -m) main.go

# 交叉编译（在 x86-64 上编译 ARM64）
GOOS=linux GOARCH=arm64 go build -o webhook-server-arm64 main.go

# 交叉编译（在 ARM64 上编译 x86-64）
GOOS=linux GOARCH=amd64 go build -o webhook-server main.go
```

### 使用 systemd

创建 `/etc/systemd/system/xiaoli-webhook.service`：

```ini
[Unit]
Description=Xiaoli Chat Webhook Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/mine/Code/ai-tools/openclaw/xiaoli-chat-webhook
EnvironmentFile=/mine/Code/ai-tools/openclaw/xiaoli-chat-webhook/.env
# 根据系统架构选择对应的二进制文件
# ARM64: webhook-server-arm64
# x86-64: webhook-server
ExecStart=/mine/Code/ai-tools/openclaw/xiaoli-chat-webhook/webhook-server-arm64
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

### 架构相关问题

**问题：cannot execute binary file: Exec format error**

这表示二进制文件的架构与系统不匹配。

```bash
# 检查系统架构
uname -m
# 输出: aarch64 (ARM64) 或 x86_64 (x86-64)

# 检查二进制文件架构
file webhook-server
file webhook-server-arm64

# 解决方案 1：使用正确的二进制文件
# ARM64 系统使用:
./webhook-server-arm64

# x86-64 系统使用:
./webhook-server

# 解决方案 2：使用自动检测脚本
./run.sh

# 解决方案 3：重新编译
go build -o webhook-server-$(uname -m) main.go
```

**问题：Go 未安装**

```bash
# 检查 Go 是否安装
go version

# 安装 Go（ARM64）
wget https://go.dev/dl/go1.22.0.linux-arm64.tar.gz
sudo tar -C /usr/local -xzf go1.22.0.linux-arm64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# 安装 Go（x86-64）
wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
```

**问题：端口被占用**

```bash
# 检查端口占用
ss -ltnp | grep 8088

# 杀死占用进程
pkill -f webhook-server

# 或修改 .env 中的 PORT
```

### 签名验证失败

确保 `WEBHOOK_SECRET` 与 Xiaoli Chat 配置完全一致。

### 无法连接到 OpenClaw

检查 `OPENCLAW_URL` 是否正确，确保 OpenClaw Gateway 正在运行。

### 查看日志

服务器会输出详细的日志信息，包括接收到的请求和转发状态。

### 流式输出问题（已修复 2026-04-14）

**症状 1**：只收到最后一条消息，第一条消息丢失。

**原因**：之前使用异步处理（`go func()`）导致消息竞态条件。

**解决方案**：已改为同步处理消息存储和广播，确保所有消息按顺序完整到达。

**症状 2**：SSE 连接成功但收到的消息 `text` 字段为空。

**原因**：OpenClaw xiaoli-chat 插件配置 `idleMs: 0` 导致流式输出缓冲区永远不会 flush（当 `idleMs <= 0` 时，调度器会跳过 flush）。

**解决方案**：将 `idleMs` 改为 `1`（1毫秒），接近立即发送但仍会触发 flush 逻辑。

**症状 3**：Python ROS2 Bridge 收到 SSE 数据但无法解析（缺少 `id` 字段）。

**原因**：Go Webhook 的 `ReplyMessage` 结构体缺少 `id` 字段，导致 Python 无法正确处理消息。

**解决方案**：

1. 在 `ReplyMessage` 结构体中添加 `ID` 字段（JSON 标签为 `id`）
2. 将 `Timestamp` 从 `time.Time` 改为 `int64`（毫秒时间戳）
3. 在 `handleMessages` 中填充 `ID` 和 `Timestamp` 字段

**症状 4**：消息延迟 15-20 秒，所有消息在 POST 完成后才批量上报。

**原因**：Python ROS2 Bridge 等待 POST 请求完成后才从队列消费消息，导致消息积压。

**解决方案**：

1. 在 `_handle_sse_message` 中实现立即上报机制
2. 使用请求上下文（`_current_event_id`、`_current_device_id`）追踪当前请求
3. SSE 消息到达时，如果有活跃请求上下文，立即调用 `_send_response` 上报
4. 在 `_handle_request` 中使用 try-finally 确保上下文清理

**症状 5**：重复消息发送。

**原因**：消息被立即上报后，又被放入队列再次上报。

**解决方案**：

1. 消息立即上报后，不再放入队列
2. 只有在没有活跃请求上下文时，才将消息放入队列（兼容旧逻辑）
3. 增强日志记录，显示所有重复消息的 ID 和内容
4. 添加 `_max_processed_ids` 限制（1000 条），防止内存泄漏
5. 当记录数超过上限时，自动清理最旧的一半记录
6. 在 `/clear` 信号时清空已处理消息记录

**症状 6**：无法检测响应完成，不知道何时是最后一条消息。

**原因**：OpenClaw 发送多条消息时（如工具调用），消息间隔可能很长（7+ 秒），无法用固定超时判断完成。

**解决方案**：

1. **Go Webhook 端**：
   - 监控 OpenClaw POST 请求完成（收到 202 响应）
   - 等待 200ms 让流式消息通过 SSE 到达
   - 发送一个空文本 + `isFinal: true` 的合成消息作为完成信号
   - 通过 SSE 广播给所有客户端

2. **Python Bridge 端**：
   - 识别空文本 + `isFinal: true` 的完成信号
   - 收到完成信号后，发送一个空消息 + `stopReason: "stop"` 给平台
   - 设置 `_response_complete = True` 结束等待
   - 中间消息不带 `stopReason`，只有最后一条才带

3. **消息格式**：
   - 中间消息：有文本内容，无 `stopReason` 字段
   - 最终消息：空文本，带 `stopReason: "stop"`

**验证方法**：

1. 发送需要工具调用的消息（如"查询天气"）
2. 应该收到多条独立的消息：
   - 第一条：工具调用提示（立即到达，<100ms）
   - 第二条：查询结果（立即到达，<100ms）
   - 最后：完成信号（空消息 + `stopReason: "stop"`）
3. 消息间隔应该是 4-9ms（LLM 生成间隔）或更长（工具调用时可能 7+ 秒）
4. 每条消息的 `text` 字段都应该有内容（除了最后的完成信号）
5. 只有最后一条消息带 `stopReason: "stop"`
6. Python 日志应显示：
   ```
   SSE 接收到数据: {"id":"reply-...","chatId":"xiaoli-chat","text":"...","timestamp":...}
   SSE 收到新消息: id=reply-..., text=...
   [event_id] SSE 消息立即上报: ...
   device_msg_response 发送成功
   SSE 收到响应完成信号: id=final-...
   [event_id] 收到响应完成信号（isFinal=true）
   [event_id] SSE 回复完成（收到 isFinal=true）
   ```
7. 如果有重复消息，日志会显示：
   ```
   跳过重复消息: id=reply-..., text=...
   ```

### SSE 连接问题

**症状**：ROS2 Bridge 无法连接 SSE

**解决方案**：

1. 检查服务器日志，确认 SSE 端点正常运行
2. 测试 SSE 连接：
   ```bash
   curl -N http://localhost:8080/sse?chatId=xiaoli-chat
   ```
3. 检查防火墙设置
4. 确认 `chatId` 参数正确

**症状**：SSE 消息重复

**解决方案**：

1. 检查客户端是否正确去重（使用消息 ID）
2. 确认没有多个客户端连接同一个 chatId
3. 查看服务器日志中的 "广播回复到 N 个 SSE 客户端"

### 消息延迟

**症状**：消息延迟超过 1 秒

**排查步骤**：

1. 检查 Go Webhook 日志，确认接收时间
2. 检查 SSE 推送时间（应该 < 10ms）
3. 检查 ROS2 Bridge 日志，确认队列处理时间
4. 检查网络延迟：`ping localhost`

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
