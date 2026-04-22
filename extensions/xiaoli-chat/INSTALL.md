# Xiaoli Chat 插件安装指南

## 安装模式

### 1. 本地路径模式 (开发模式, 默认)

```bash
./install-load.sh
# 或
./install-load.sh --local
```

**特点**:
- 直接引用源码目录
- 修改代码后重新编译即可生效
- `installPath` = `sourcePath` = `/mine/Code/ai-tools/openclaw/extensions/xiaoli-chat`
- 适合开发调试

**工作流程**:
1. 修改代码
2. 运行 `./build.sh` 重新编译
3. 运行 `openclaw gateway restart` 重启 gateway
4. 更改生效

### 2. 复制模式 (生产模式)

```bash
./install-load.sh --copy
```

**特点**:
- 复制到 `~/.openclaw/extensions/xiaoli-chat/`
- 独立副本,不受源码目录影响
- 模拟 npm 安装的行为
- 适合测试正式安装流程

**工作流程**:
1. 脚本自动编译并复制到用户目录
2. 从复制的目录安装
3. 更新代码需要重新运行 `./install-load.sh --copy`

## 安装步骤

脚本会自动执行以下步骤:

1. **[1/5] Building** - 编译插件 (调用 `build.sh`)
2. **[2/5] Copying/Installing** - 根据模式复制或直接安装
3. **[3/5] Installing** - 注册插件到 OpenClaw
4. **[4/5] Enabling** - 启用插件
5. **[5/5] Configuring** - 自动配置频道和 webhook 服务器
6. **[6/6] Restarting** - 重启 gateway

## 自动配置

安装脚本会自动完成以下配置:

### OpenClaw 配置

```yaml
channels:
  xiaoli-chat:
    enabled: true
    token: "test-token-placeholder"
    baseUrl: "http://localhost:8088"
    webhookSecret: "<自动生成的64字符密钥>"
    dmSecurity: "allowlist"
```

### Webhook 服务器配置

脚本会自动创建 `xiaoli-chat-webhook/.env` 文件:

```bash
WEBHOOK_SECRET=<与OpenClaw一致的密钥>
OPENCLAW_URL=http://localhost:18789
XIAOLI_TOKEN=test-token-placeholder
OPENCLAW_TOKEN=<自动获取的gateway token>
PORT=8088
```

## 验证安装

```bash
# 查看插件列表
openclaw plugins list

# 查看插件详情
openclaw plugins inspect xiaoli-chat

# 查看频道状态
openclaw channels status

# 测试 webhook 端点
curl http://localhost:18789/hooks/xiaoli-chat/webhook
```

## 启动 Webhook 服务器

安装完成后,启动 webhook 服务器:

```bash
cd /mine/Code/ai-tools/openclaw/xiaoli-chat-webhook
./run.sh
```

服务器会自动:
- 检测系统架构 (x86-64 或 ARM64)
- 选择对应的二进制文件
- 如果二进制不存在,自动编译
- 启动服务器监听 8088 端口

## 配置说明

### 必需修改的配置

安装后需要根据实际情况修改以下配置:

1. **Xiaoli Chat API Token**:
   ```bash
   openclaw config set channels.xiaoli-chat.token "your-real-token"
   ```

2. **Webhook 服务器 Token** (编辑 `xiaoli-chat-webhook/.env`):
   ```bash
   XIAOLI_TOKEN=your-real-token
   ```

3. **重启服务**:
   ```bash
   openclaw gateway restart
   cd xiaoli-chat-webhook && ./run.sh
   ```

### 可选配置

- **Base URL**: 如果 webhook 服务器不在本地,修改:
  ```bash
  openclaw config set channels.xiaoli-chat.baseUrl "http://your-server:8088"
  ```

- **允许的发送者白名单**:
  ```bash
  openclaw config set channels.xiaoli-chat.allowFrom '["user1", "user2"]'
  ```

- **私聊安全策略**:
  ```bash
  openclaw config set channels.xiaoli-chat.dmSecurity "open"  # 或 "allowlist"
  ```

## 卸载

```bash
# 卸载插件 (只删除元数据)
openclaw plugins uninstall xiaoli-chat

# 完全移除 (包括文件)
openclaw plugins uninstall xiaoli-chat
rm -rf ~/.openclaw/extensions/xiaoli-chat  # 仅复制模式需要
openclaw gateway restart
```

## 故障排查

### 插件未加载

```bash
# 检查插件状态
openclaw plugins inspect xiaoli-chat

# 查看 gateway 日志
openclaw gateway logs
```

### 编译失败

```bash
# 检查依赖
cd /mine/Code/ai-tools/openclaw
pnpm install

# 手动编译
cd extensions/xiaoli-chat
./build.sh
```

### Webhook 连接失败

```bash
# 检查 webhook 端点
curl http://localhost:18789/hooks/xiaoli-chat/webhook

# 检查 webhook 服务器状态
cd xiaoli-chat-webhook
./run.sh

# 查看服务器日志
```

### 签名验证失败

确保 OpenClaw 和 webhook 服务器的 `webhookSecret` 完全一致:

```bash
# 查看 OpenClaw 配置
openclaw config get channels.xiaoli-chat.webhookSecret

# 查看 webhook 服务器配置
cat xiaoli-chat-webhook/.env | grep WEBHOOK_SECRET
```

### 权限问题

```bash
# 确保脚本可执行
chmod +x build.sh install-load.sh
```

## 架构说明

```
┌─────────────────┐
│  Xiaoli Chat    │
│   Platform      │
└────────┬────────┘
         │ webhook (POST)
         │ X-Signature: sha256=...
         ▼
┌─────────────────┐
│ xiaoli-chat-    │
│   webhook       │ :8080
│  (Go Server)    │
└────────┬────────┘
         │ POST /hooks/xiaoli-chat/webhook
         │ X-Signature: sha256=...
         ▼
┌─────────────────┐
│   OpenClaw      │
│    Gateway      │ :18789
│  (xiaoli-chat   │
│    plugin)      │
└────────┬────────┘
         │ SSE /stream?chatId=...
         │
         ▼
┌─────────────────┐
│ xiaoli-chat-    │
│   webhook       │
│  (Go Server)    │
└────────┬────────┘
         │ POST /messages
         │
         ▼
┌─────────────────┐
│  Xiaoli Chat    │
│   Platform      │
└─────────────────┘
```

## 相关文档

- [Webhook 服务器文档](../../xiaoli-chat-webhook/README.md)
- [测试指南](./TESTING.md)
- [OpenClaw 插件开发](../../docs/plugins/building-plugins.md)
