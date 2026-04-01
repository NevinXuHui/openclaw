#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
PLUGIN_DIR="${SCRIPT_DIR}"
PLUGIN_ID="xiaoli-chat"

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      cat <<'EOF'
Usage: ./install-load.sh

Builds the local Xiaoli Chat plugin, installs it into OpenClaw from the local path,
enables it, and restarts the gateway.
EOF
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      exit 1
      ;;
  esac
done

if ! command -v openclaw >/dev/null 2>&1; then
  printf 'openclaw command not found in PATH\n' >&2
  exit 1
fi

if ! command -v pnpm >/dev/null 2>&1; then
  printf 'pnpm command not found in PATH\n' >&2
  exit 1
fi

if [[ ! -x "${PLUGIN_DIR}/build.sh" ]]; then
  printf 'build.sh is not executable: %s\n' "${PLUGIN_DIR}/build.sh" >&2
  exit 1
fi

if [[ ! -f "${PLUGIN_DIR}/openclaw.plugin.json" ]]; then
  printf 'openclaw.plugin.json not found under %s\n' "${PLUGIN_DIR}" >&2
  exit 1
fi

if [[ ! -f "${PLUGIN_DIR}/package.json" ]]; then
  printf 'package.json not found under %s\n' "${PLUGIN_DIR}" >&2
  exit 1
fi

if [[ ! -f "${PLUGIN_DIR}/tsconfig.build.json" ]]; then
  printf 'tsconfig.build.json not found under %s\n' "${PLUGIN_DIR}" >&2
  exit 1
fi

if [[ ! -f "${PLUGIN_DIR}/tsconfig.json" ]]; then
  printf 'tsconfig.json not found under %s\n' "${PLUGIN_DIR}" >&2
  exit 1
fi

if [[ ! -d "${PLUGIN_DIR}/src" ]]; then
  printf 'src directory not found under %s\n' "${PLUGIN_DIR}" >&2
  exit 1
fi

if [[ ! -f "${PLUGIN_DIR}/index.ts" ]]; then
  printf 'index.ts not found under %s\n' "${PLUGIN_DIR}" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/package.json" ]]; then
  printf 'repo root package.json not found under %s\n' "${REPO_ROOT}" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/pnpm-workspace.yaml" ]]; then
  printf 'pnpm-workspace.yaml not found under %s\n' "${REPO_ROOT}" >&2
  exit 1
fi

if [[ ! -d "${REPO_ROOT}/node_modules" ]]; then
  printf 'repo node_modules not found under %s; run pnpm install first\n' "${REPO_ROOT}" >&2
  exit 1
fi

if [[ ! -d "${REPO_ROOT}/extensions/xiaoli-chat" ]]; then
  printf 'expected plugin directory missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/package.json" ]]; then
  printf 'expected plugin package.json missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/package.json" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/openclaw.plugin.json" ]]; then
  printf 'expected plugin manifest missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/openclaw.plugin.json" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/build.sh" ]]; then
  printf 'expected build script missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/build.sh" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/tsconfig.build.json" ]]; then
  printf 'expected build tsconfig missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/tsconfig.build.json" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/tsconfig.json" ]]; then
  printf 'expected typecheck tsconfig missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/tsconfig.json" >&2
  exit 1
fi

if [[ ! -d "${REPO_ROOT}/extensions/xiaoli-chat/src" ]]; then
  printf 'expected plugin src missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/index.ts" ]]; then
  printf 'expected plugin index missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/index.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/install-load.sh" ]]; then
  printf 'expected install script missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/install-load.sh" >&2
  exit 1
fi

if [[ ! -x "${REPO_ROOT}/extensions/xiaoli-chat/install-load.sh" ]]; then
  printf 'install-load.sh is not executable: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/install-load.sh" >&2
  exit 1
fi

if [[ ! -x "${REPO_ROOT}/extensions/xiaoli-chat/build.sh" ]]; then
  printf 'repo build.sh is not executable: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/build.sh" >&2
  exit 1
fi

if [[ ! -d "/home/xuhui/.openclaw" ]]; then
  printf 'OpenClaw config directory not found: /home/xuhui/.openclaw\n' >&2
  exit 1
fi

if [[ ! -w "/home/xuhui/.openclaw" ]]; then
  printf 'OpenClaw config directory is not writable: /home/xuhui/.openclaw\n' >&2
  exit 1
fi

if [[ ! -f "/home/xuhui/.openclaw/openclaw.json" ]]; then
  printf 'OpenClaw config file not found: /home/xuhui/.openclaw/openclaw.json\n' >&2
  exit 1
fi

if [[ ! -w "/home/xuhui/.openclaw/openclaw.json" ]]; then
  printf 'OpenClaw config file is not writable: /home/xuhui/.openclaw/openclaw.json\n' >&2
  exit 1
fi

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

if ! openclaw gateway restart --help >/dev/null 2>&1; then
  printf 'openclaw gateway restart is unavailable on this host\n' >&2
  exit 1
fi

if ! openclaw plugins enable --help >/dev/null 2>&1; then
  printf 'openclaw plugins enable is unavailable on this host\n' >&2
  exit 1
fi

if ! openclaw plugins install --help >/dev/null 2>&1; then
  printf 'openclaw plugins install is unavailable on this host\n' >&2
  exit 1
fi

if ! pnpm exec tsc --version >/dev/null 2>&1; then
  printf 'TypeScript compiler is unavailable; run pnpm install first\n' >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/webhook.ts" ]]; then
  printf 'expected webhook entry missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/webhook.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/channel.ts" ]]; then
  printf 'expected channel entry missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/channel.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/config.ts" ]]; then
  printf 'expected config entry missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/config.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/runtime.ts" ]]; then
  printf 'expected runtime entry missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/runtime.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/inbound-runtime.ts" ]]; then
  printf 'expected inbound runtime entry missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/inbound-runtime.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/outbound.ts" ]]; then
  printf 'expected outbound entry missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/outbound.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/types.ts" ]]; then
  printf 'expected types entry missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/types.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/client.ts" ]]; then
  printf 'expected client entry missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/client.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/inbound.ts" ]]; then
  printf 'expected inbound entry missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/inbound.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/webhook.test.ts" ]]; then
  printf 'expected webhook test missing: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/webhook.test.ts" >&2
  exit 1
fi

if [[ ! -d "${REPO_ROOT}/test/helpers" ]]; then
  printf 'expected test helpers directory missing: %s\n' "${REPO_ROOT}/test/helpers" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/test/helpers/mock-incoming-request.ts" ]]; then
  printf 'expected mock incoming request helper missing: %s\n' "${REPO_ROOT}/test/helpers/mock-incoming-request.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/src/plugin-sdk/core.ts" ]]; then
  printf 'expected plugin SDK core missing: %s\n' "${REPO_ROOT}/src/plugin-sdk/core.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/src/plugin-sdk/webhook-ingress.ts" ]]; then
  printf 'expected webhook ingress SDK missing: %s\n' "${REPO_ROOT}/src/plugin-sdk/webhook-ingress.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/pnpm-lock.yaml" ]]; then
  printf 'pnpm-lock.yaml not found under %s\n' "${REPO_ROOT}" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/install-load.sh" ]]; then
  printf 'expected install script missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/install-load.sh" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/build.sh" ]]; then
  printf 'expected build script missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/build.sh" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/package.json" ]]; then
  printf 'expected package.json missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/package.json" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/openclaw.plugin.json" ]]; then
  printf 'expected manifest missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/openclaw.plugin.json" >&2
  exit 1
fi

if [[ ! -d "${REPO_ROOT}/extensions/xiaoli-chat/src" ]]; then
  printf 'expected src missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/index.ts" ]]; then
  printf 'expected index missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/index.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/tsconfig.build.json" ]]; then
  printf 'expected build tsconfig missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/tsconfig.build.json" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/tsconfig.json" ]]; then
  printf 'expected typecheck tsconfig missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/tsconfig.json" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/webhook.ts" ]]; then
  printf 'expected webhook entry missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/webhook.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/channel.ts" ]]; then
  printf 'expected channel entry missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/channel.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/config.ts" ]]; then
  printf 'expected config entry missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/config.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/runtime.ts" ]]; then
  printf 'expected runtime entry missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/runtime.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/inbound-runtime.ts" ]]; then
  printf 'expected inbound runtime entry missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/inbound-runtime.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/outbound.ts" ]]; then
  printf 'expected outbound entry missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/outbound.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/types.ts" ]]; then
  printf 'expected types entry missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/types.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/client.ts" ]]; then
  printf 'expected client entry missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/client.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/inbound.ts" ]]; then
  printf 'expected inbound entry missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/inbound.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/extensions/xiaoli-chat/src/webhook.test.ts" ]]; then
  printf 'expected webhook test missing after validation: %s\n' "${REPO_ROOT}/extensions/xiaoli-chat/src/webhook.test.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/test/helpers/mock-incoming-request.ts" ]]; then
  printf 'expected request helper missing after validation: %s\n' "${REPO_ROOT}/test/helpers/mock-incoming-request.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/src/plugin-sdk/core.ts" ]]; then
  printf 'expected plugin SDK core missing after validation: %s\n' "${REPO_ROOT}/src/plugin-sdk/core.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/src/plugin-sdk/webhook-ingress.ts" ]]; then
  printf 'expected webhook ingress missing after validation: %s\n' "${REPO_ROOT}/src/plugin-sdk/webhook-ingress.ts" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/pnpm-lock.yaml" ]]; then
  printf 'expected pnpm-lock.yaml missing after validation: %s\n' "${REPO_ROOT}/pnpm-lock.yaml" >&2
  exit 1
fi

if [[ ! -d "${REPO_ROOT}/node_modules" ]]; then
  printf 'expected node_modules missing after validation: %s\n' "${REPO_ROOT}/node_modules" >&2
  exit 1
fi

if ! openclaw plugins inspect "${PLUGIN_ID}" >/dev/null 2>&1; then
  printf 'plugin %s is not yet inspectable; install will proceed and create it\n' "${PLUGIN_ID}"
fi

if [[ ! -d "${PLUGIN_DIR}" ]]; then
  printf 'plugin directory disappeared during validation: %s\n' "${PLUGIN_DIR}" >&2
  exit 1
fi

if [[ ! -d "${REPO_ROOT}" ]]; then
  printf 'repo root disappeared during validation: %s\n' "${REPO_ROOT}" >&2
  exit 1
fi

if [[ ! -f "${PLUGIN_DIR}/install-load.sh" ]]; then
  printf 'install script disappeared during validation: %s\n' "${PLUGIN_DIR}/install-load.sh" >&2
  exit 1
fi

if [[ ! -f "${PLUGIN_DIR}/build.sh" ]]; then
  printf 'build script disappeared during validation: %s\n' "${PLUGIN_DIR}/build.sh" >&2
  exit 1
fi

if [[ ! -f "${PLUGIN_DIR}/package.json" ]]; then
  printf 'package.json disappeared during validation: %s\n' "${PLUGIN_DIR}/package.json" >&2
  exit 1
fi

if [[ ! -f "${PLUGIN_DIR}/openclaw.plugin.json" ]]; then
  printf 'manifest disappeared during validation: %s\n' "${PLUGIN_DIR}/openclaw.plugin.json" >&2
  exit 1
fi

if [[ ! -d "${PLUGIN_DIR}/src" ]]; then
  printf 'src disappeared during validation: %s\n' "${PLUGIN_DIR}/src" >&2
  exit 1
fi

if [[ ! -f "${PLUGIN_DIR}/index.ts" ]]; then
  printf 'index disappeared during validation: %s\n' "${PLUGIN_DIR}/index.ts" >&2
  exit 1
fi

if [[ ! -f "${PLUGIN_DIR}/tsconfig.build.json" ]]; then
  printf 'build tsconfig disappeared during validation: %s\n' "${PLUGIN_DIR}/tsconfig.build.json" >&2
  exit 1
fi

if [[ ! -f "${PLUGIN_DIR}/tsconfig.json" ]]; then
  printf 'typecheck tsconfig disappeared during validation: %s\n' "${PLUGIN_DIR}/tsconfig.json" >&2
  exit 1
fi

if [[ ! -d "/home/xuhui/.openclaw" ]]; then
  printf 'OpenClaw config directory disappeared during validation: /home/xuhui/.openclaw\n' >&2
  exit 1
fi

if [[ ! -f "/home/xuhui/.openclaw/openclaw.json" ]]; then
  printf 'OpenClaw config file disappeared during validation: /home/xuhui/.openclaw/openclaw.json\n' >&2
  exit 1
fi

printf 'Preflight checks passed.\n'
cd "${REPO_ROOT}"

printf '[1/4] Building %s...\n' "${PLUGIN_ID}"
"${PLUGIN_DIR}/build.sh"

printf '[2/4] Installing %s from local path...\n' "${PLUGIN_ID}"
openclaw plugins install -l "${PLUGIN_DIR}"

printf '[3/4] Enabling %s...\n' "${PLUGIN_ID}"
openclaw plugins enable "${PLUGIN_ID}"

printf '[4/4] Restarting gateway...\n'
openclaw gateway restart

printf '\nDone. Verify with:\n'
printf 'openclaw plugins list\n'
printf 'openclaw plugins inspect %s\n' "${PLUGIN_ID}"
