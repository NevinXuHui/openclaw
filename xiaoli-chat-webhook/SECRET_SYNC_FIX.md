# Webhook Secret 同步问题修复 - 2026-04-23

## 问题描述

使用 `install.sh` 安装后，webhook 服务生成了新的随机 `WEBHOOK_SECRET`，但 speech-client 使用的是旧的 secret，导致认证失败：

```
ERROR - POST 到 OpenClaw 失败: HTTP Error 401: Unauthorized
```

## 根本原因

`install.sh` 每次都生成新的随机 secret，而 speech-client 配置文件中使用的是固定的旧 secret：

- **speech-client**: `10fb375bbc497575342f6ecd45321259e09f306946bd3fac174231fa914b46d6`
- **webhook 服务**: `25e73965fa00670da33d398be10102f4f35f38a67e48a04d5458b5c1dfb9e8e6` (新生成)

## 修复方案

### 方案 1：使用 speech-client 的 secret（已采用）

```bash
# 更新 webhook 服务使用 speech-client 的 secret
sudo sed -i 's/WEBHOOK_SECRET=.*/WEBHOOK_SECRET=10fb375bbc497575342f6ecd45321259e09f306946bd3fac174231fa914b46d6/' /opt/xiaoli-webhook/.env

# 重启服务
sudo systemctl restart xiaoli-webhook
```

### 方案 2：更新 install.sh 自动检测（已实现）

修改 `install.sh`，优先使用 speech-client 的现有 secret：

```bash
# 优先使用 speech-client 的 secret（如果存在）
SPEECH_CLIENT_CONFIG="/usr/bin/cmcc_robot/install/speech_client/share/speech_client/config/openclaw_bridge.yaml"
if [ -f "$SPEECH_CLIENT_CONFIG" ]; then
    WEBHOOK_SECRET=$(grep "openclaw_secret:" "$SPEECH_CLIENT_CONFIG" | sed "s/.*openclaw_secret: '\([^']*\)'.*/\1/")
    if [ -n "$WEBHOOK_SECRET" ]; then
        echo "使用 speech-client 的现有 secret"
    fi
fi

# 如果没有找到，生成新的 secret
if [ -z "$WEBHOOK_SECRET" ]; then
    WEBHOOK_SECRET=$(openssl rand -hex 32)
    echo "生成新的 webhook secret"
fi
```

## 验证步骤

### 1. 检查 secret 是否匹配

```bash
# speech-client 配置
grep "openclaw_secret:" /usr/bin/cmcc_robot/install/speech_client/share/speech_client/config/openclaw_bridge.yaml

# webhook 服务配置
grep WEBHOOK_SECRET /opt/xiaoli-webhook/.env

# 应该显示相同的值
```

### 2. 测试服务

```bash
# 重启服务
sudo systemctl restart xiaoli-webhook

# 查看状态
sudo systemctl status xiaoli-webhook

# 从 speech-client 发送测试消息
# 应该不再出现 401 错误
```

## 完整的问题链

这个问题实际上是三个问题的组合：

### 1. Token 混淆问题
- `openclaw config get` 返回 `__OPENCLAW_REDACTED__`
- **修复**: 直接从配置文件读取

### 2. Secret 不匹配问题
- `install.sh` 生成新的随机 secret
- speech-client 使用固定的旧 secret
- **修复**: 优先使用 speech-client 的 secret

### 3. 文件完整性问题
- 缺少源码文件和测试脚本
- **修复**: 复制完整文件集

## 最终配置

### /opt/xiaoli-webhook/.env
```bash
WEBHOOK_SECRET=10fb375bbc497575342f6ecd45321259e09f306946bd3fac174231fa914b46d6
OPENCLAW_URL=http://localhost:18789
XIAOLI_TOKEN=test-token-placeholder
OPENCLAW_TOKEN=fd4d9df0428a0c5bfa9647c9792d5841c873359a536acf46
PORT=8088
```

### speech-client 配置
```yaml
/openclaw_bridge:
  ros__parameters:
    openclaw_url: 'http://127.0.0.1:8088'
    openclaw_channel: 'xiaoli-chat'
    openclaw_secret: '10fb375bbc497575342f6ecd45321259e09f306946bd3fac174231fa914b46d6'
```

## 相关文档

- `TOKEN_FIX.md` - Token 获取问题修复
- `ENV_FIX.md` - .env 配置修复
- `INSTALL_FIX.md` - 文件完整性修复
- `SECRET_SYNC_FIX.md` - Secret 同步问题修复（本文档）

## 总结

- ✅ 修复了 WEBHOOK_SECRET 不匹配问题
- ✅ install.sh 现在会自动检测并使用 speech-client 的 secret
- ✅ 服务能正常处理 speech-client 的请求
- ✅ 不再出现 401 Unauthorized 错误
