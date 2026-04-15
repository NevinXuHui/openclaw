#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

# 解析参数
BUNDLE_MODE=false
if [[ "${1:-}" == "--bundle" ]]; then
    BUNDLE_MODE=true
fi

if [ "$BUNDLE_MODE" = true ]; then
    echo "Building xiaoli-chat plugin (BUNDLE mode)..."
else
    echo "Building xiaoli-chat plugin (NORMAL mode)..."
fi

# 清理旧的构建输出
rm -rf "${SCRIPT_DIR}/dist"
mkdir -p "${SCRIPT_DIR}/dist/src"

cd "${SCRIPT_DIR}"

# 检查 esbuild（优先使用全局，然后使用本地）
ESBUILD_CMD=""
if command -v esbuild &> /dev/null; then
    ESBUILD_CMD="esbuild"
    echo "使用全局 esbuild: $(which esbuild)"
elif command -v "${REPO_ROOT}/node_modules/.bin/esbuild" &> /dev/null; then
    ESBUILD_CMD="${REPO_ROOT}/node_modules/.bin/esbuild"
    echo "使用本地 esbuild: ${ESBUILD_CMD}"
else
    echo "Error: esbuild not found"
    echo "Please install esbuild globally: npm install -g esbuild"
    echo "Or install locally: cd ${REPO_ROOT} && pnpm install"
    exit 1
fi

# 检查 tsc（优先使用全局，然后使用本地）
TSC_CMD=""
if command -v tsc &> /dev/null; then
    TSC_CMD="tsc"
elif command -v "${REPO_ROOT}/node_modules/.bin/tsc" &> /dev/null; then
    TSC_CMD="${REPO_ROOT}/node_modules/.bin/tsc"
else
    echo "Warning: tsc not found, skipping type declarations"
fi

if [ "$BUNDLE_MODE" = true ]; then
    # ============================================
    # 打包模式：将所有代码打包成单个文件
    # ============================================
    echo "Bundling all code into a single file..."

    "$ESBUILD_CMD" index.ts \
        --bundle \
        --outfile=dist/index.js \
        --format=esm \
        --platform=node \
        --target=es2023 \
        --external:openclaw/plugin-sdk/* \
        --tsconfig=tsconfig.build.json \
        --minify=false

    if [ -n "$TSC_CMD" ]; then
        echo "Generating type declarations..."
        "$TSC_CMD" \
        -p tsconfig.build.json \
        --emitDeclarationOnly \
        --declaration \
        --declarationMap false \
        2>&1 | grep -v "is not under 'rootDir'" | grep -v "File is ECMAScript module" || true
    else
        echo "Skipping type declarations (tsc not found)"
    fi

    echo ""
    echo "✓ Bundle complete!"
    echo "  Output: ${SCRIPT_DIR}/dist/index.js (bundled)"
    echo ""
    echo "Bundle size:"
    ls -lh dist/index.js

else
    # ============================================
    # 普通模式：保持模块结构
    # ============================================
    echo "Compiling TypeScript files..."

    # 编译所有 TypeScript 文件（不打包，只转译）
    for file in index.ts src/*.ts; do
        if [ -f "$file" ] && [[ ! "$file" =~ \.test\.ts$ ]]; then
            outfile="dist/${file%.ts}.js"
            mkdir -p "$(dirname "$outfile")"
            "$ESBUILD_CMD" "$file" \
                --outfile="$outfile" \
                --format=esm \
                --platform=node \
                --target=es2023 \
                --tsconfig=tsconfig.build.json
        fi
    done

    if [ -n "$TSC_CMD" ]; then
        echo "Generating type declarations..."
        "$TSC_CMD" \
        -p tsconfig.build.json \
        --emitDeclarationOnly \
        --declaration \
        --declarationMap false \
        2>&1 | grep -v "is not under 'rootDir'" | grep -v "File is ECMAScript module" || true
    else
        echo "Skipping type declarations (tsc not found)"
    fi

    echo ""
    echo "✓ Build complete!"
    echo "  Output: ${SCRIPT_DIR}/dist/"
    echo ""
    echo "Files generated:"
    ls -lh dist/*.js dist/*.d.ts 2>/dev/null || true
    echo ""
    ls -lh dist/src/*.js 2>/dev/null | head -5 || true
fi

echo ""
echo "Usage:"
echo "  ./build.sh          # Normal build (keep module structure)"
echo "  ./build.sh --bundle # Bundle all code into single file"
