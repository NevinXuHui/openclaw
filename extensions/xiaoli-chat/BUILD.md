# Xiaoli Chat 插件构建说明

## 为什么不能独立编译？

OpenClaw 插件依赖 `openclaw/plugin-sdk/*` 模块，这些模块位于根项目的 `src/plugin-sdk/` 目录中。TypeScript 编译器需要访问这些源文件进行类型检查和模块解析。

尝试独立编译会遇到以下问题：
- ❌ 无法解析 `openclaw/plugin-sdk/core` 等模块
- ❌ 设置 `rootDir` 会导致编译整个仓库
- ❌ 使用 `paths` 映射仍然会包含其他插件的代码

## 推荐的构建方式

### 方式一：从根项目构建（推荐）

```bash
cd /mine/Code/ai-tools/openclaw
pnpm build
```

这会编译整个项目，包括 xiaoli-chat 插件。

### 方式二：使用 build.sh 脚本

```bash
cd extensions/xiaoli-chat
./build.sh
```

这个脚本会显示当前编译状态和推荐的构建方式。

### 方式三：使用 package.json 脚本

```bash
cd extensions/xiaoli-chat
pnpm build
```

这会调用 `build.sh` 脚本。

## 编译输出

编译成功后，输出位于：
```
extensions/xiaoli-chat/dist/
├── index.js
├── index.d.ts
└── src/
    ├── channel.js
    ├── webhook.js
    ├── inbound.js
    ├── outbound.js
    ├── client.js
    ├── config.js
    ├── runtime.js
    └── types.js
```

## 类型检查

如果只想进行类型检查而不编译：

```bash
cd extensions/xiaoli-chat
pnpm typecheck
```

这使用 `tsconfig.json` 进行类型检查，不会生成输出文件。

## 其他 OpenClaw 插件

所有 OpenClaw 插件都遵循相同的模式：
- 没有独立的构建脚本
- 通过根项目的构建系统编译
- 在 `package.json` 中定义 `openclaw.build` 元数据

参考其他插件：
- `extensions/discord/`
- `extensions/telegram/`
- `extensions/slack/`
