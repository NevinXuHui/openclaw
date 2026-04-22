#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
PLUGIN_DIR="${SCRIPT_DIR}"
PLUGIN_ID="xiaoli-chat"
INSTALL_MODE="local"

# 检测 OpenClaw 配置目录
if [[ -n "${OPENCLAW_CONFIG_DIR:-}" ]]; then
  OPENCLAW_DIR="${OPENCLAW_CONFIG_DIR}"
elif [[ -d "${HOME}/.openclaw" ]]; then
  OPENCLAW_DIR="${HOME}/.openclaw"
else
  printf 'OpenClaw config directory not found. Tried:\n' >&2
  printf '  - OPENCLAW_CONFIG_DIR env var\n' >&2
  printf '  - %s/.openclaw\n' "${HOME}" >&2
  exit 1
fi

OPENCLAW_CONFIG="${OPENCLAW_DIR}/openclaw.json"

# 帮助信息
show_help() {
  cat <<'EOF'
Usage: ./install-load.sh [OPTIONS]

Builds the local Xiaoli Chat plugin, installs it into OpenClaw, enables it, and restarts the gateway.

Options:
  --local     Install from local path (development mode, default)
  --copy      Copy to ~/.openclaw/extensions/ (production mode)
  -h, --help  Show this help message

Install Modes:
  --local: Direct reference to source directory (best for development)
           - Changes take effect after rebuild + gateway restart
           - installPath = sourcePath = /mine/Code/ai-tools/openclaw/extensions/xiaoli-chat

  --copy:  Copy to ~/.openclaw/extensions/ (simulates npm install)
           - Independent copy in user directory
           - installPath = ~/.openclaw/extensions/xiaoli-chat
EOF
}

# 检查命令是否存在
check_command() {
  local cmd="$1"
  local msg="${2:-$cmd command not found in PATH}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf '%s\n' "$msg" >&2
    exit 1
  fi
}

# 检查文件是否存在
check_file() {
  local file="$1"
  local msg="${2:-File not found: $file}"
  if [[ ! -f "$file" ]]; then
    printf '%s\n' "$msg" >&2
    exit 1
  fi
}

# 检查目录是否存在
check_dir() {
  local dir="$1"
  local msg="${2:-Directory not found: $dir}"
  if [[ ! -d "$dir" ]]; then
    printf '%s\n' "$msg" >&2
    exit 1
  fi
}

# 检查文件是否可执行
check_executable() {
  local file="$1"
  if [[ ! -x "$file" ]]; then
    printf 'File is not executable: %s\n' "$file" >&2
    exit 1
  fi
}

# 检查文件是否可写
check_writable() {
  local file="$1"
  if [[ ! -w "$file" ]]; then
    printf 'File is not writable: %s\n' "$file" >&2
    exit 1
  fi
}

# 解析命令行参数
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      show_help
      exit 0
      ;;
    --local)
      INSTALL_MODE="local"
      ;;
    --copy)
      INSTALL_MODE="copy"
      ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      exit 1
      ;;
  esac
done

# 预检查：命令可用性
printf 'Checking commands...\n'
check_command openclaw
check_command pnpm

# 预检查：核心文件和目录
printf 'Checking plugin structure...\n'
check_dir "${PLUGIN_DIR}"
check_dir "${PLUGIN_DIR}/src"
check_file "${PLUGIN_DIR}/package.json"
check_file "${PLUGIN_DIR}/openclaw.plugin.json"
check_file "${PLUGIN_DIR}/index.ts"
check_file "${PLUGIN_DIR}/tsconfig.json"
check_file "${PLUGIN_DIR}/tsconfig.build.json"
check_file "${PLUGIN_DIR}/build.sh"
check_executable "${PLUGIN_DIR}/build.sh"

# 预检查：源文件
printf 'Checking source files...\n'
for src_file in webhook.ts channel.ts config.ts runtime.ts inbound-runtime.ts outbound.ts types.ts client.ts inbound.ts webhook.test.ts; do
  check_file "${PLUGIN_DIR}/src/${src_file}"
done

# 预检查：仓库结构
printf 'Checking repository structure...\n'
check_dir "${REPO_ROOT}"
check_file "${REPO_ROOT}/package.json"
check_file "${REPO_ROOT}/pnpm-workspace.yaml"
check_file "${REPO_ROOT}/pnpm-lock.yaml"
check_dir "${REPO_ROOT}/node_modules" "repo node_modules not found; run pnpm install first"

# 预检查：测试辅助文件
check_dir "${REPO_ROOT}/test/helpers"
check_file "${REPO_ROOT}/test/helpers/mock-incoming-request.ts"

# 预检查：Plugin SDK
check_file "${REPO_ROOT}/src/plugin-sdk/core.ts"
check_file "${REPO_ROOT}/src/plugin-sdk/webhook-ingress.ts"

# 预检查：OpenClaw 配置
printf 'Checking OpenClaw configuration...\n'
check_dir "${OPENCLAW_DIR}"
check_writable "${OPENCLAW_DIR}"
check_file "${OPENCLAW_CONFIG}"
check_writable "${OPENCLAW_CONFIG}"

# 预检查：OpenClaw 命令可用性
printf 'Checking OpenClaw commands...\n'
if ! openclaw --version >/dev/null 2>&1; then
  printf 'openclaw command is not runnable; check your installation\n' >&2
  exit 1
fi

if ! pnpm --version >/dev/null 2>&1; then
  printf 'pnpm command is not runnable; check your installation\n' >&2
  exit 1
fi

if ! openclaw plugins list >/dev/null 2>&1; then
  printf 'openclaw plugins list failed; verify your OpenClaw environment first\n' >&2
  exit 1
fi

for cmd in "gateway restart" "plugins enable" "plugins install"; do
  if ! openclaw $cmd --help >/dev/null 2>&1; then
    printf 'openclaw %s is unavailable on this host\n' "$cmd" >&2
    exit 1
  fi
done

if ! pnpm exec tsc --version >/dev/null 2>&1; then
  printf 'TypeScript compiler is unavailable; run pnpm install first\n' >&2
  exit 1
fi

# 检查插件是否已安装
if ! openclaw plugins inspect "${PLUGIN_ID}" >/dev/null 2>&1; then
  printf 'Plugin %s is not yet installed; install will proceed and create it\n' "${PLUGIN_ID}"
fi

printf 'Preflight checks passed.\n\n'

# 修复所有权问题（如果以 root 运行）
if [[ $EUID -eq 0 ]]; then
  printf '[0/6] Fixing ownership (running as root)...\n'
  chown -R root:root "${PLUGIN_DIR}"
  printf 'Plugin directory ownership set to root:root\n'
fi

# 构建插件
cd "${REPO_ROOT}"
printf '[1/6] Building %s...\n' "${PLUGIN_ID}"
"${PLUGIN_DIR}/build.sh"

# 配置插件白名单
printf '[2/6] Configuring plugin allowlist...\n'
CURRENT_ALLOW=$(openclaw config get plugins.allow 2>/dev/null || echo "[]")
if [[ "${CURRENT_ALLOW}" == "[]" ]] || ! echo "${CURRENT_ALLOW}" | grep -q "${PLUGIN_ID}"; then
  printf 'Adding %s to plugins.allow...\n' "${PLUGIN_ID}"
  # 获取现有的允许列表
  EXISTING_PLUGINS=$(openclaw config get plugins.allow 2>/dev/null | grep -oP '"\K[^"]+' | tr '\n' ',' | sed 's/,$//')
  if [[ -n "${EXISTING_PLUGINS}" ]]; then
    NEW_ALLOW="[\"${EXISTING_PLUGINS}\",\"${PLUGIN_ID}\"]"
  else
    NEW_ALLOW="[\"${PLUGIN_ID}\"]"
  fi
  openclaw config set plugins.allow "${NEW_ALLOW}"
else
  printf '%s already in plugins.allow\n' "${PLUGIN_ID}"
fi

# 安装插件
if [[ "${INSTALL_MODE}" == "copy" ]]; then
  INSTALL_TARGET="${OPENCLAW_DIR}/extensions/${PLUGIN_ID}"
  TEMP_TARGET="${INSTALL_TARGET}.tmp.$$"

  # 卸载现有配置
  if openclaw plugins inspect "${PLUGIN_ID}" >/dev/null 2>&1; then
    printf '[3/6] Uninstalling existing %s configuration...\n' "${PLUGIN_ID}"
    openclaw plugins uninstall "${PLUGIN_ID}" -y 2>/dev/null || true
  fi

  # 删除旧安装
  if [[ -d "${INSTALL_TARGET}" ]]; then
    printf '[3/6] Removing old installation at %s...\n' "${INSTALL_TARGET}"
    rm -rf "${INSTALL_TARGET}"
  fi

  # 清理临时目录
  rm -rf "${TEMP_TARGET}"

  printf '[3/6] Preparing files in temporary directory...\n'
  mkdir -p "${TEMP_TARGET}"

  # 复制编译后的文件
  cp -r "${PLUGIN_DIR}/dist/"* "${TEMP_TARGET}/"
  cp "${PLUGIN_DIR}/openclaw.plugin.json" "${TEMP_TARGET}/"

  # 修正 package.json 入口路径
  sed 's|"./index.ts"|"./index.js"|g' "${PLUGIN_DIR}/package.json" > "${TEMP_TARGET}/package.json"

  # 移动到最终位置
  mv "${TEMP_TARGET}" "${INSTALL_TARGET}"

  printf '[4/6] Plugin copied to %s\n' "${INSTALL_TARGET}"
  printf '[4/6] OpenClaw will auto-discover it on next restart\n'

  # 清除 plugins.load.paths（copy 模式不需要）
  printf '[4/6] Clearing plugins.load.paths (not needed in copy mode)...\n'
  openclaw config set plugins.load.paths "[]"

  printf '[4/6] Enabling %s...\n' "${PLUGIN_ID}"
  openclaw plugins enable "${PLUGIN_ID}"
else
  # 本地路径模式
  if openclaw plugins inspect "${PLUGIN_ID}" >/dev/null 2>&1; then
    printf '[3/6] Uninstalling existing %s...\n' "${PLUGIN_ID}"
    openclaw plugins uninstall "${PLUGIN_ID}" -y 2>/dev/null || true
  fi

  printf '[3/6] Installing %s from local path (development mode)...\n' "${PLUGIN_ID}"
  openclaw plugins install -l "${PLUGIN_DIR}"

  # 确保 plugins.load.paths 包含插件路径（local 模式需要）
  printf '[4/6] Ensuring %s is in plugins.load.paths...\n' "${PLUGIN_ID}"
  CURRENT_PATHS=$(openclaw config get plugins.load.paths 2>/dev/null || echo "[]")
  if ! echo "${CURRENT_PATHS}" | grep -q "${PLUGIN_DIR}"; then
    printf 'Adding %s to plugins.load.paths...\n' "${PLUGIN_DIR}"
    openclaw config set plugins.load.paths "[\"${PLUGIN_DIR}\"]"
  else
    printf '%s already in plugins.load.paths\n' "${PLUGIN_DIR}"
  fi

  printf '[4/6] Enabling %s...\n' "${PLUGIN_ID}"
  openclaw plugins enable "${PLUGIN_ID}"
fi

# 配置通道
printf '[5/6] Configuring %s channel...\n' "${PLUGIN_ID}"

# 生成 webhook secret
WEBHOOK_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")

# 配置 OpenClaw
printf 'Setting up channel configuration...\n'
openclaw config set channels.xiaoli-chat.enabled true
openclaw config set channels.xiaoli-chat.token "test-token-placeholder"
openclaw config set channels.xiaoli-chat.baseUrl "http://localhost:8088"
openclaw config set channels.xiaoli-chat.webhookSecret "${WEBHOOK_SECRET}"
openclaw config set channels.xiaoli-chat.dmSecurity "allowlist"

# 配置 webhook 服务器
WEBHOOK_DIR="${REPO_ROOT}/xiaoli-chat-webhook"
if [[ -d "${WEBHOOK_DIR}" ]]; then
  printf 'Configuring xiaoli-chat-webhook server...\n'

  # 获取 OpenClaw Gateway token
  OPENCLAW_TOKEN=$(openclaw config get gateway.auth.token 2>/dev/null || echo "")

  # 创建 .env 文件
  cat > "${WEBHOOK_DIR}/.env" <<EOF
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

  printf 'Webhook server configuration saved to %s/.env\n' "${WEBHOOK_DIR}"
  printf '\nTo start the webhook server, run:\n'
  printf '  cd %s\n' "${WEBHOOK_DIR}"
  printf '  ./run.sh\n'
else
  printf 'Warning: xiaoli-chat-webhook directory not found at %s\n' "${WEBHOOK_DIR}"
  printf 'Webhook server configuration skipped.\n'
fi

# 重启 gateway
printf '\n[6/6] Restarting gateway...\n'
if command -v systemctl >/dev/null 2>&1 && systemctl --user is-active openclaw-gateway.service >/dev/null 2>&1; then
  printf 'Using systemctl to restart gateway...\n'
  openclaw gateway restart
else
  printf 'Manually restarting gateway...\n'
  pkill -9 -f openclaw-gateway || true
  sleep 2
  nohup openclaw gateway run --bind loopback --port 18789 --force > /tmp/openclaw-gateway.log 2>&1 &
  sleep 3
fi

# 完成
printf '\n✅ Installation complete!\n\n'
printf 'Configuration summary:\n'
printf '  - Channel: xiaoli-chat\n'
printf '  - Webhook endpoint: http://localhost:18789/hooks/xiaoli-chat/webhook\n'
printf '  - Webhook secret: %s\n' "${WEBHOOK_SECRET}"
printf '  - Base URL: http://localhost:8088\n'
printf '\nVerify installation:\n'
printf '  openclaw plugins list\n'
printf '  openclaw plugins inspect %s\n' "${PLUGIN_ID}"
printf '  openclaw channels status\n'
printf '\nNext steps:\n'
printf '  1. Start the webhook server: cd %s && ./run.sh\n' "${WEBHOOK_DIR}"
printf '  2. Test webhook endpoint: curl http://localhost:18789/hooks/xiaoli-chat/webhook\n'
