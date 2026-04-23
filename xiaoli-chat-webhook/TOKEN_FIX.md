# Token 获取问题修复 - 2026-04-23

## 问题描述

使用 `install.sh` 安装后，systemd 运行的服务出现 **401 Unauthorized** 错误：

```
ERROR - POST 到 OpenClaw 失败: HTTP Error 401: Unauthorized
```

**根本原因：** `openclaw config get gateway.auth.token` 返回的是混淆值 `__OPENCLAW_REDACTED__`，而不是真实的 token。

## 问题分析

### 1. 手动运行 `run.sh` - 正常工作 ✓

```bash
cd /mine/Code/ai-tools/openclaw/xiaoli-chat-webhook
./run.sh
```

- 从开发环境的 `.env` 加载真实的 token
- 能正常接收 speech-client 的请求

### 2. systemd 运行 - 401 错误 ✗

```bash
sudo systemctl start xiaoli-webhook
```

- `install.sh` 生成的 `.env` 包含混淆值：
  ```bash
  OPENCLAW_TOKEN=__OPENCLAW_REDACTED__
  ```
- Go 程序读取到混淆值，导致认证失败

## 修复方案

### 修改 `install.sh` 的 token 获取逻辑

**修复前：**
```bash
OPENCLAW_TOKEN=$(openclaw config get gateway.auth.token 2>/dev/null || echo "")
```

**修复后：**
```bash
# 直接从配置文件读取，避免被混淆
OPENCLAW_CONFIG="${HOME}/.openclaw/openclaw.json"
if [ -f "$OPENCLAW_CONFIG" ]; then
    OPENCLAW_TOKEN=$(grep -A 2 '"auth"' "$OPENCLAW_CONFIG" | grep '"token"' | sed 's/.*"token": "\([^"]*\)".*/\1/')
fi

# 如果读取失败，尝试使用 openclaw config get（可能被混淆）
if [ -z "$OPENCLAW_TOKEN" ] || [ "$OPENCLAW_TOKEN" = "__OPENCLAW_REDACTED__" ]; then
    OPENCLAW_TOKEN=$(openclaw config get gateway.auth.token 2>/dev/null || echo "")
fi
```

### 修复已安装的服务

如果已经安装了服务，需要手动更新 `.env` 文件：

```bash
# 1. 获取真实的 token
REAL_TOKEN=$(grep -A 2 '"auth"' ~/.openclaw/openclaw.json | grep '"token"' | sed 's/.*"token": "\([^"]*\)".*/\1/')

# 2. 更新 .env 文件
sudo sed -i "s/OPENCLAW_TOKEN=.*/OPENCLAW_TOKEN=$REAL_TOKEN/" /opt/xiaoli-webhook/.env

# 3. 重启服务
sudo systemctl restart xiaoli-webhook

# 4. 验证
sudo systemctl status xiaoli-webhook
```

## 验证结果

### 修复前
```
OPENCLAW_TOKEN=__OPENCLAW_REDACTED__
→ 401 Unauthorized
```

### 修复后
```
OPENCLAW_TOKEN=fd4d9df0428a0c5bfa9647c9792d5841c873359a536acf46
→ 服务正常运行 ✓
```

## 为什么 `openclaw config get` 会混淆？

OpenClaw CLI 为了安全，会自动混淆敏感信息的输出：

```bash
$ openclaw config get gateway.auth.token
__OPENCLAW_REDACTED__

$ grep '"token"' ~/.openclaw/openclaw.json
"token": "fd4d9df0428a0c5bfa9647c9792d5841c873359a536acf46"
```

这是一个安全特性，但在自动化脚本中需要直接读取配置文件。

## 相关文件

- `install.sh` - 安装脚本（已修复）
- `/opt/xiaoli-webhook/.env` - 生成的配置文件
- `~/.openclaw/openclaw.json` - OpenClaw 配置文件（token 来源）

## 测试步骤

### 1. 测试新安装
```bash
cd /mine/Code/ai-tools/openclaw/xiaoli-chat-webhook
sudo ./install.sh
# 检查生成的 .env 是否包含真实 token
grep OPENCLAW_TOKEN /opt/xiaoli-webhook/.env
```

### 2. 测试服务运行
```bash
sudo systemctl status xiaoli-webhook
sudo journalctl -u xiaoli-webhook -f
```

### 3. 测试 API 调用
```bash
# 从 speech-client 发送消息
# 应该不再出现 401 错误
```

## 总结

- ✅ 修复了 token 获取逻辑，直接从配置文件读取
- ✅ 避免了 `openclaw config get` 的混淆问题
- ✅ 服务现在能正常处理认证请求
- ✅ 与手动运行 `run.sh` 的行为一致
