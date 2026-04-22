# Install Script Fix - 2026-04-22

## 问题描述

使用 `install-load.sh --copy` 安装插件后，配置文件中残留 `plugins.load.paths` 指向源代码路径，导致 OpenClaw 启动时报错：

```
Invalid config at /root/.openclaw/openclaw.json:
- plugins.load.paths: plugin: plugin path not found: /mine/Code/ai-tools/openclaw/extensions/xiaoli-chat
```

## 根本原因

- `--copy` 模式：插件被复制到 `~/.openclaw/extensions/`，OpenClaw 会自动发现，**不需要** `plugins.load.paths`
- `--local` 模式：插件直接从源码目录加载，**需要** 在 `plugins.load.paths` 中指定路径

旧脚本没有区分这两种模式的配置需求。

## 修复内容

### 1. `--copy` 模式（第 262-264 行）

```bash
# 清除 plugins.load.paths（copy 模式不需要）
printf '[4/6] Clearing plugins.load.paths (not needed in copy mode)...\n'
openclaw config set plugins.load.paths "[]"
```

### 2. `--local` 模式（第 278-286 行）

```bash
# 确保 plugins.load.paths 包含插件路径（local 模式需要）
printf '[4/6] Ensuring %s is in plugins.load.paths...\n' "${PLUGIN_ID}"
CURRENT_PATHS=$(openclaw config get plugins.load.paths 2>/dev/null || echo "[]")
if ! echo "${CURRENT_PATHS}" | grep -q "${PLUGIN_DIR}"; then
  printf 'Adding %s to plugins.load.paths...\n' "${PLUGIN_DIR}"
  openclaw config set plugins.load.paths "[\"${PLUGIN_DIR}\"]"
else
  printf '%s already in plugins.load.paths\n' "${PLUGIN_DIR}"
fi
```

## 验证

```bash
# 语法检查
bash -n install-load.sh

# 测试 copy 模式
./install-load.sh --copy

# 验证配置
openclaw config get plugins.load.paths  # 应该返回 []
openclaw plugins list | grep xiaoli-chat
openclaw channels status --probe
```

## 手动修复（如果已经遇到问题）

```bash
# 清除错误的 load.paths 配置
openclaw config set plugins.load.paths "[]"

# 重启 gateway
pkill -9 -f openclaw-gateway
nohup openclaw gateway run --bind loopback --port 18789 --force > /tmp/openclaw-gateway.log 2>&1 &

# 验证
openclaw channels status --probe
```
