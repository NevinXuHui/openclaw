# Xiaoli Chat 集成部署总结

本文档总结了 xiaoli-chat 插件和 webhook 服务器的完整部署过程。

## 系统架构

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

## 多架构支持

所有组件已更新，支持以下架构：
- ✅ x86-64 (AMD64)
- ✅ ARM64 (aarch64)

### 自动架构检测

**xiaoli-chat-webhook/run.sh**：
- 自动检测系统架构
- 选择对应的二进制文件
- 如果不存在则自动编译

**extensions/xiaoli-chat/build.sh**：
- 优先使用全局 esbuild（支持多架构）
- 回退到本地 node_modules
- 自动跳过不可用的工具

## 部署状态

### 1. OpenClaw Gateway

**状态**: ✅ 运行中
- PID: 210916
- 端口: 18789 (loopback)
- 健康检查: http://localhost:18789/health

**配置文件**: `~/.openclaw/openclaw.json`
```json
{
  "channels": {
    "xiaoli-chat": {
      "enabled": true,
      "token": "test-token-12345",
      "baseUrl": "https://api.xiaoli-chat.com",
      "webhookSecret": "test-secret-12345",
      "allowFrom": ["*"],
      "dmSecurity": "allowlist"
    }
  }
}
```

### 2. xiaoli-chat 插件

**状态**: ✅ 已加载
- 版本: 2026.4.9-beta.1
- 安装路径: `~/.openclaw/extensions/xiaoli-chat`
- 频道: xiaoli-chat (已启用并配置)

**构建工具**:
- esbuild: 全局安装 (ARM64)
- TypeScript: 可选

### 3. Webhook 服务器

**状态**: ✅ 运行中
- PID: 237699
- 架构: ARM64
- 端口: 8088
- 健康检查: http://localhost:8088/health

**配置文件**: `/mine/Code/ai-tools/openclaw/xiaoli-chat-webhook/.env`
```bash
WEBHOOK_SECRET=test-secret-12345
OPENCLAW_URL=http://localhost:18789
XIAOLI_TOKEN=test-token-12345
PORT=8088
```

## 快速命令

### 启动服务

```bash
# 启动 OpenClaw Gateway
openclaw gateway restart

# 启动 Webhook 服务器
cd /mine/Code/ai-tools/openclaw/xiaoli-chat-webhook
./run.sh
```

### 检查状态

```bash
# 检查 Gateway
openclaw gateway status --deep
openclaw channels status --probe

# 检查插件
openclaw plugins inspect xiaoli-chat

# 检查 Webhook
curl http://localhost:8088/health
ps aux | grep webhook-server
ss -ltnp | grep 8088
```

### 查看日志

```bash
# Gateway 日志
openclaw gateway logs

# Webhook 日志
tail -f /mine/Code/ai-tools/openclaw/xiaoli-chat-webhook/webhook.log
```

### 重新编译

```bash
# 编译插件
cd /mine/Code/ai-tools/openclaw/extensions/xiaoli-chat
./build.sh

# 编译 Webhook（如果需要）
cd /mine/Code/ai-tools/openclaw/xiaoli-chat-webhook
go build -o webhook-server-$(uname -m) main.go
```

## 测试流程

### 1. 健康检查

```bash
# 测试 Gateway
curl http://localhost:18789/health
# 预期: {"ok":true,"status":"live"}

# 测试 Webhook
curl http://localhost:8088/health
# 预期: {"status":"healthy","time":"..."}
```

### 2. 发送测试消息

```bash
cd /mine/Code/ai-tools/openclaw/xiaoli-chat-webhook
./send-test-message.sh
```

### 3. 端到端测试

1. 在 Xiaoli Chat 平台配置 Webhook URL
2. 发送消息给机器人
3. 观察日志确认消息流转
4. 验证回复是否正确发送

## 生产部署建议

### 1. 使用真实凭证

替换测试 token 和 secret：

```bash
# 编辑 OpenClaw 配置
openclaw config set channels.xiaoli-chat.token "your-real-token"
openclaw config set channels.xiaoli-chat.webhookSecret "your-real-secret"
openclaw gateway restart

# 编辑 Webhook 配置
cd /mine/Code/ai-tools/openclaw/xiaoli-chat-webhook
nano .env
# 更新 XIAOLI_TOKEN 和 WEBHOOK_SECRET
pkill -f webhook-server
./run.sh
```

### 2. 使用 systemd 管理服务

**OpenClaw Gateway**：
```bash
# 已通过 systemd 管理
systemctl --user status openclaw-gateway
```

**Webhook 服务器**：
```bash
# 创建 systemd 服务
sudo nano /etc/systemd/system/xiaoli-webhook.service

# 内容参考 xiaoli-chat-webhook/README.md

# 启动服务
sudo systemctl daemon-reload
sudo systemctl enable xiaoli-webhook
sudo systemctl start xiaoli-webhook
```

### 3. 配置日志轮转

```bash
# 创建 logrotate 配置
sudo nano /etc/logrotate.d/xiaoli-webhook

# 内容:
/mine/Code/ai-tools/openclaw/xiaoli-chat-webhook/webhook.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        pkill -HUP webhook-server
    endscript
}
```

### 4. 配置监控

```bash
# 使用 systemd 监控
systemctl --user status openclaw-gateway
sudo systemctl status xiaoli-webhook

# 或使用监控工具（如 Prometheus + Grafana）
```

### 5. 安全加固

- 使用 HTTPS 和反向代理（nginx/caddy）
- 限制请求速率
- 配置防火墙规则
- 定期更新依赖和系统

## 故障排查

### Gateway 无法启动

```bash
# 查看日志
openclaw gateway logs | tail -50

# 运行诊断
openclaw doctor --fix

# 检查配置
openclaw config get
```

### 插件未加载

```bash
# 检查插件状态
openclaw plugins inspect xiaoli-chat

# 重新安装
cd /mine/Code/ai-tools/openclaw/extensions/xiaoli-chat
openclaw plugins uninstall xiaoli-chat
openclaw plugins install .
openclaw plugins enable xiaoli-chat
openclaw gateway restart
```

### Webhook 服务器问题

```bash
# 检查架构
uname -m
file webhook-server*

# 重新编译
go build -o webhook-server-$(uname -m) main.go

# 查看日志
tail -f webhook.log
```

### 架构不匹配

```bash
# 错误: cannot execute binary file: Exec format error

# 解决方案：使用正确的二进制或重新编译
./run.sh  # 自动检测架构
```

## 更新记录

### 2026-04-15
- ✅ 添加多架构支持（x86-64 和 ARM64）
- ✅ 更新 run.sh 自动检测架构
- ✅ 更新 build.sh 优先使用全局工具
- ✅ 完成完整部署和测试
- ✅ 更新所有相关文档

## 相关文档

- [extensions/xiaoli-chat/BUILD.md](../extensions/xiaoli-chat/BUILD.md) - 插件构建指南
- [extensions/xiaoli-chat/INSTALL.md](../extensions/xiaoli-chat/INSTALL.md) - 插件安装指南
- [extensions/xiaoli-chat/TESTING.md](../extensions/xiaoli-chat/TESTING.md) - 插件测试指南
- [xiaoli-chat-webhook/README.md](../xiaoli-chat-webhook/README.md) - Webhook 服务器文档

## 联系方式

如有问题，请查看相关文档或提交 Issue。
