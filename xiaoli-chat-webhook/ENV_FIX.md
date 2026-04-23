# Webhook Install Script Fix - 2026-04-22

## 问题描述

`xiaoli-chat-webhook/install.sh` 存在两个关键问题：

1. **直接复制开发环境的 .env 文件**
   - 包含开发环境的敏感信息
   - 不适合生产环境部署
   - 每次安装使用相同的配置

2. **缺少必要的文件**
   - 缺少源码文件（`main.go`, `go.mod`）
   - 缺少测试脚本
   - 与 `run.sh` 的逻辑不一致

## 修复内容

### 1. 动态生成 .env 配置文件

**修复前：**
```bash
cp "$SCRIPT_DIR/.env" "$INSTALL_DIR/"
```

**修复后：**
```bash
# 生成 webhook secret
WEBHOOK_SECRET=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p -c 32)

# 获取 OpenClaw Gateway token
OPENCLAW_TOKEN=""
if command -v openclaw &> /dev/null; then
    OPENCLAW_TOKEN=$(openclaw config get gateway.auth.token 2>/dev/null || echo "")
fi

# 创建 .env 文件
cat > "$INSTALL_DIR/.env" <<EOF
# Xiaoli Chat Webhook 配置

# Webhook 验证密钥（必须与 Xiaoli Chat 配置一致）
WEBHOOK_SECRET=${WEBHOOK_SECRET}

# OpenClaw Gateway 地址
OPENCLAW_URL=http://localhost:18789

# Xiaoli Chat API Token（必须设置）
XIAOLI_TOKEN=test-token-placeholder

# OpenClaw API Token（如果需要）
OPENCLAW_TOKEN=${OPENCLAW_TOKEN}

# 服务器监听端口
PORT=8088
EOF
```

### 2. 复制完整的文件集

新增复制的文件：
- `main.go` - Go 源码
- `go.mod` - Go 模块定义
- 所有测试脚本（`send-test-message.sh` 等）
- `uninstall.sh` - 卸载脚本

### 3. 改进安装完成提示

显示关键配置信息：
```bash
=== 重要配置信息 ===
Webhook Secret: <生成的随机密钥>
服务端口: 8088
OpenClaw Gateway: http://localhost:18789

下一步操作：
1. 配置 OpenClaw 通道（如果还未配置）
2. 修改 Xiaoli Token（必需）
```

## 与 extensions/xiaoli-chat/install-load.sh 的一致性

现在两个安装脚本的逻辑完全一致：

| 功能 | extensions/xiaoli-chat/install-load.sh | xiaoli-chat-webhook/install.sh |
|------|----------------------------------------|-------------------------------|
| 动态生成 .env | ✓ | ✓（修复后） |
| 生成随机 WEBHOOK_SECRET | ✓ | ✓（修复后） |
| 获取 OPENCLAW_TOKEN | ✓ | ✓（修复后） |
| 复制源码文件 | ✓ | ✓（修复后） |
| 复制测试脚本 | ✓ | ✓（修复后） |
| 显示配置信息 | ✓ | ✓（修复后） |

## 安全改进

1. **每次安装生成唯一的 WEBHOOK_SECRET**
   - 使用 `openssl rand -hex 32` 或 `/dev/urandom`
   - 避免使用固定的开发密钥

2. **自动获取 OPENCLAW_TOKEN**
   - 从 OpenClaw 配置中读取
   - 避免手动复制粘贴

3. **明确提示用户修改 XIAOLI_TOKEN**
   - 安装完成后显示警告
   - 提供修改步骤

## 使用流程

### 安装
```bash
cd /mine/Code/ai-tools/openclaw/xiaoli-chat-webhook
sudo ./install.sh
```

### 配置
```bash
# 1. 编辑配置文件
sudo nano /opt/xiaoli-webhook/.env
# 修改 XIAOLI_TOKEN=your-actual-token

# 2. 配置 OpenClaw 通道
openclaw config set channels.xiaoli-chat.enabled true
openclaw config set channels.xiaoli-chat.webhookSecret "<安装时显示的密钥>"
openclaw config set channels.xiaoli-chat.baseUrl "http://localhost:8088"

# 3. 重启服务
sudo systemctl restart xiaoli-webhook
openclaw gateway restart
```

### 验证
```bash
# 检查服务状态
sudo systemctl status xiaoli-webhook

# 查看日志
sudo journalctl -u xiaoli-webhook -f

# 测试 webhook
curl http://localhost:8088/health
```

## 文件对比

### 修复前的问题
```bash
# 开发环境的 .env（不应该用于生产）
WEBHOOK_SECRET=10fb375bbc497575342f6ecd45321259e09f306946bd3fac174231fa914b46d6
XIAOLI_TOKEN=test-token-placeholder
OPENCLAW_TOKEN=__OPENCLAW_REDACTED__
```

### 修复后的行为
```bash
# 每次安装生成新的随机密钥
WEBHOOK_SECRET=<64位随机十六进制字符串>
XIAOLI_TOKEN=test-token-placeholder  # 提示用户修改
OPENCLAW_TOKEN=<自动从 OpenClaw 配置读取>
```

## 验证清单

- [x] 脚本语法检查通过
- [x] 动态生成 .env 文件
- [x] 生成随机 WEBHOOK_SECRET
- [x] 自动获取 OPENCLAW_TOKEN
- [x] 复制所有必要文件（源码、测试脚本）
- [x] 显示配置信息和下一步操作
- [x] 与 extensions/xiaoli-chat/install-load.sh 逻辑一致
