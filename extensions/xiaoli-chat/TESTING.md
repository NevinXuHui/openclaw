# Xiaoli Chat 插件测试指南

## 架构概览

```
Xiaoli Chat 平台
    ↓ (webhook)
xiaoli-chat-webhook (Go 服务器)
    ↓ (HTTP POST)
OpenClaw Gateway
    ↓
xiaoli-chat 插件
    ↓
AI 处理
    ↓ (回复)
Xiaoli Chat API
```

## 测试前准备

### 1. 确认插件已安装

```bash
cd /mine/Code/ai-tools/openclaw/extensions/xiaoli-chat

# 检查插件状态
openclaw plugins inspect xiaoli-chat

# 应该看到:
# Status: loaded
# Source: ~/.openclaw/extensions/xiaoli-chat/index.js (复制模式)
#    或: /mine/Code/ai-tools/openclaw/extensions/xiaoli-chat/index.ts (本地模式)
# Version: 2026.4.9-beta.1
```

### 2. 配置 OpenClaw

编辑 `~/.openclaw/openclaw.json`:

```json
{
  "channels": {
    "xiaoli-chat": {
      "enabled": true,
      "token": "your-xiaoli-chat-api-token",
      "baseUrl": "https://api.xiaoli-chat.com",
      "webhookSecret": "your-webhook-secret",
      "allowFrom": ["*"],
      "dmSecurity": "allowlist"
    }
  }
}
```

**配置说明**:

- `token`: Xiaoli Chat API 令牌
- `baseUrl`: Xiaoli Chat API 地址
- `webhookSecret`: Webhook 签名密钥 (与 webhook 服务器共享)
- `allowFrom`: 允许的用户 ID 列表 (`["*"]` 表示允许所有)
- `dmSecurity`: 私聊安全策略 (`allowlist` 或 `open`)

### 3. 配置 Webhook 服务器

```bash
cd /mine/Code/ai-tools/openclaw/xiaoli-chat-webhook

# 编辑 .env 文件
cat > .env << 'EOF'
PORT=8088
OPENCLAW_URL=http://localhost:18789
WEBHOOK_SECRET=your-webhook-secret
XIAOLI_API_TOKEN=your-xiaoli-chat-api-token
XIAOLI_API_BASE_URL=https://api.xiaoli-chat.com
EOF
```

**配置说明**:

- `PORT`: Webhook 服务器监听端口
- `OPENCLAW_URL`: OpenClaw Gateway 地址
- `WEBHOOK_SECRET`: 与 OpenClaw 配置中的 `webhookSecret` 相同
- `XIAOLI_API_TOKEN`: Xiaoli Chat API 令牌
- `XIAOLI_API_BASE_URL`: Xiaoli Chat API 地址

## 启动服务

### 1. 启动 OpenClaw Gateway

```bash
# 如果使用 systemd
openclaw gateway restart

# 或手动启动
openclaw gateway run --bind loopback --port 18789
```

### 2. 启动 Webhook 服务器

```bash
cd /mine/Code/ai-tools/openclaw/xiaoli-chat-webhook

# 使用启动脚本
./run.sh

# 或直接运行
./webhook-server
```

**验证启动**:

```bash
# 检查进程
ps aux | grep webhook-server

# 检查端口
ss -ltnp | grep 8088

# 查看日志
tail -f webhook.log
```

## 测试流程

### 1. 健康检查

```bash
# 测试 webhook 服务器
curl http://localhost:8088/health

# 应该返回:
# {"status":"ok"}
```

### 2. 测试 Webhook 接收

```bash
# 模拟 Xiaoli Chat 发送消息
curl -X POST http://localhost:8088/webhook \
  -H "Content-Type: application/json" \
  -H "X-Xiaoli-Signature: <计算的签名>" \
  -d '{
    "messageId": "test-123",
    "userId": "user-456",
    "content": "你好",
    "timestamp": 1234567890
  }'
```

### 3. 查看日志

**Webhook 服务器日志**:

```bash
tail -f /mine/Code/ai-tools/openclaw/xiaoli-chat-webhook/webhook.log
```

**OpenClaw Gateway 日志**:

```bash
openclaw gateway logs
```

### 4. 端到端测试

1. 在 Xiaoli Chat 平台配置 Webhook URL:

   ```
   http://your-server:8088/webhook
   ```
2. 在 Xiaoli Chat 发送消息给机器人
3. 观察日志:

   - Webhook 服务器收到消息
   - 转发到 OpenClaw
   - OpenClaw 处理并生成回复
   - 回复发送到 Xiaoli Chat API

## 故障排查

### 插件未加载

```bash
# 检查插件状态
openclaw plugins inspect xiaoli-chat

# 查看 gateway 日志
openclaw gateway logs | grep xiaoli-chat

# 重新安装
cd /mine/Code/ai-tools/openclaw/extensions/xiaoli-chat
./install-load.sh --copy
```

### Webhook 服务器无法启动

```bash
# 检查端口占用
ss -ltnp | grep 8088

# 检查配置文件
cat .env

# 查看错误日志
tail -50 webhook.log
```

### 消息无法转发

```bash
# 检查 OpenClaw Gateway 是否运行
curl http://localhost:18789/health

# 检查 webhook 路径
curl http://localhost:18789/hooks/xiaoli-chat/webhook

# 验证签名配置
# WEBHOOK_SECRET 必须与 OpenClaw 配置中的 webhookSecret 一致
```

### 回复无法发送

```bash
# 检查 API 令牌
echo $XIAOLI_API_TOKEN

# 测试 API 连接
curl -H "Authorization: Bearer $XIAOLI_API_TOKEN" \
  https://api.xiaoli-chat.com/messages

# 查看 webhook 服务器日志中的 API 错误
grep "API error" webhook.log
```

## 调试技巧

### 启用详细日志

**OpenClaw**:

```bash
# 设置日志级别
export OPENCLAW_LOG_LEVEL=debug
openclaw gateway restart
```

**Webhook 服务器**:

```bash
# 修改 main.go 中的日志级别
# 或查看 webhook.log
tail -f webhook.log
```

### 手动测试签名

```bash
# 计算 HMAC-SHA256 签名
echo -n '{"test":"data"}' | openssl dgst -sha256 -hmac "your-webhook-secret"
```

### 测试 API 调用

```bash
# 测试发送消息
curl -X POST https://api.xiaoli-chat.com/messages \
  -H "Authorization: Bearer $XIAOLI_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user-456",
    "content": "测试消息"
  }'
```

## 性能监控

```bash
# 查看 webhook 服务器资源使用
top -p $(pgrep webhook-server)

# 查看请求统计
grep "POST /webhook" webhook.log | wc -l

# 查看错误率
grep "error" webhook.log | wc -l
```

## 生产部署建议

1. **使用 systemd 管理 webhook 服务器**
2. **配置日志轮转**
3. **设置监控和告警**
4. **使用 HTTPS 和反向代理**
5. **限制请求速率**
6. **定期备份配置**

## 相关文档

- [ARCHITECTURE.md](../../ARCHITECTURE.md) - 完整架构说明
- [INSTALL.md](./INSTALL.md) - 安装指南
- [BUILD.md](./BUILD.md) - 构建说明
- [xiaoli-chat-webhook/README.md](../../xiaoli-chat-webhook/README.md) - Webhook 服务器文档
