# Xiaoli Chat 插件构建指南

## 前置要求

- Node.js >= 22
- esbuild（全局或本地安装）
- TypeScript 编译器（可选，用于生成类型声明）

## 多架构支持

构建脚本已更新，支持以下架构：
- ✅ x86-64 (AMD64)
- ✅ ARM64 (aarch64)

构建脚本会自动：
1. 优先使用全局安装的 esbuild（支持多架构）
2. 如果全局不存在，回退到本地 node_modules 中的 esbuild
3. 如果 tsc 不可用，跳过类型声明生成（不影响插件运行）

## 快速开始

### 方式 1：使用全局工具（推荐，支持多架构）

```bash
# 安装全局工具
npm install -g esbuild typescript

# 编译插件
cd extensions/xiaoli-chat
./build.sh
```

### 方式 2：使用本地依赖

```bash
# 在仓库根目录安装依赖
cd /mine/Code/ai-tools/openclaw
pnpm install

# 编译插件
cd extensions/xiaoli-chat
./build.sh
```

## 构建模式

### 普通模式（默认）

保持模块结构，每个 TypeScript 文件编译成对应的 JavaScript 文件：

```bash
./build.sh
```

**输出结构**：
```
dist/
├── index.js
├── index.d.ts
└── src/
    ├── channel.js
    ├── client.js
    ├── config.js
    ├── inbound.js
    ├── inbound-runtime.js
    ├── outbound.js
    ├── runtime.js
    ├── types.js
    └── webhook.js
```

### 打包模式

将所有代码打包成单个文件：

```bash
./build.sh --bundle
```

**输出结构**：
```
dist/
├── index.js      # 所有代码打包在一起
└── index.d.ts
```

## 构建输出

编译后的文件位于 `dist/` 目录：

- `dist/index.js` - 插件入口点
- `dist/index.d.ts` - TypeScript 类型声明（如果 tsc 可用）
- `dist/src/*.js` - 各个模块（普通模式）

## 架构检测

构建脚本会自动检测并使用合适的工具：

```bash
# 示例输出（ARM64）
Building xiaoli-chat plugin (NORMAL mode)...
使用全局 esbuild: /root/bin/esbuild
Compiling TypeScript files...
✓ Build complete!
```

```bash
# 示例输出（x86-64，使用本地）
Building xiaoli-chat plugin (NORMAL mode)...
使用本地 esbuild: /mine/Code/ai-tools/openclaw/node_modules/.bin/esbuild
Compiling TypeScript files...
✓ Build complete!
```

## 故障排查

### esbuild 未找到

**方式 1：全局安装（推荐）**
```bash
npm install -g esbuild
```

**方式 2：本地安装**
```bash
cd /mine/Code/ai-tools/openclaw
pnpm install
```

### 架构不匹配错误

如果遇到 "cannot execute binary file: Exec format error"：

```bash
# 卸载并重新安装 esbuild（会自动下载正确架构）
npm uninstall -g esbuild
npm install -g esbuild

# 或在项目中重新安装
cd /mine/Code/ai-tools/openclaw
rm -rf node_modules
pnpm install
```

### TypeScript 编译警告

如果看到 "Warning: tsc not found, skipping type declarations"：

```bash
# 安装 TypeScript（可选）
npm install -g typescript

# 类型声明不是必需的，插件仍可正常运行
```

### TypeScript 编译错误

```bash
# 检查 TypeScript 版本
tsc --version

# 重新安装依赖
cd /mine/Code/ai-tools/openclaw
rm -rf node_modules
pnpm install
```

## 开发工作流

1. 修改源代码
2. 运行 `./build.sh` 重新编译
3. 运行 `openclaw gateway restart` 重启 gateway
4. 测试更改

## 持续集成

在 CI 环境中，建议使用全局工具以避免架构问题：

```bash
# CI 脚本示例
npm install -g esbuild typescript
cd extensions/xiaoli-chat
./build.sh
```

## 相关文档

- [INSTALL.md](./INSTALL.md) - 安装指南
- [TESTING.md](./TESTING.md) - 测试指南
