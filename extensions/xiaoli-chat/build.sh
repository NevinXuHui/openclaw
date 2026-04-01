#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

cd "${REPO_ROOT}"
rm -rf "extensions/xiaoli-chat/dist"
pnpm exec tsc -p "extensions/xiaoli-chat/tsconfig.build.json"
