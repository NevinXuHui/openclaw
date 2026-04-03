---
title: "插件设置与配置"
sidebarTitle: "设置与配置"
summary: "设置向导、setup-entry.ts、配置 schema 与 package.json metadata"
read_when:
  - 你正在为插件添加设置向导
  - 你需要理解 setup-entry.ts 与 index.ts 的区别
  - 你正在定义插件配置 schema 或 package.json 中的 openclaw metadata
---

# 插件设置与配置

本页参考说明插件打包（`package.json` metadata）、清单
（`openclaw.plugin.json`）、setup entry 和配置 schema。

<Tip>
  **想看操作指南？** 这些 how-to 指南会在上下文中讲解打包：
  [渠道插件](/plugins/sdk-channel-plugins#step-1-package-and-manifest) 和
  [提供商插件](/plugins/sdk-provider-plugins#step-1-package-and-manifest)。
</Tip>

## 包 metadata

你的 `package.json` 需要有一个 `openclaw` 字段，用来告诉插件系统你的插件提供什么：

**渠道插件：**

```json
{
  "name": "@myorg/openclaw-my-channel",
  "version": "1.0.0",
  "type": "module",
  "openclaw": {
    "extensions": ["./index.ts"],
    "setupEntry": "./setup-entry.ts",
    "channel": {
      "id": "my-channel",
      "label": "My Channel",
      "blurb": "Short description of the channel."
    }
  }
}
```

**提供商插件 / ClawHub 发布基线：**

```json openclaw-clawhub-package.json
{
  "name": "@myorg/openclaw-my-plugin",
  "version": "1.0.0",
  "type": "module",
  "openclaw": {
    "extensions": ["./index.ts"],
    "compat": {
      "pluginApi": ">=2026.3.24-beta.2",
      "minGatewayVersion": "2026.3.24-beta.2"
    },
    "build": {
      "openclawVersion": "2026.3.24-beta.2",
      "pluginSdkVersion": "2026.3.24-beta.2"
    }
  }
}
```

如果你要把插件以外部形式发布到 ClawHub，那么这些 `compat` 和 `build` 字段是必需的。规范的发布片段位于 `docs/snippets/plugin-publish/`。

### `openclaw` 字段

| 字段         | 类型       | 描述                                                                                    |
| ------------ | ---------- | --------------------------------------------------------------------------------------- |
| `extensions` | `string[]` | 入口文件（相对于包根目录）                                                              |
| `setupEntry` | `string`   | 轻量级、仅用于 setup 的入口（可选）                                                     |
| `channel`    | `object`   | 渠道 metadata：`id`、`label`、`blurb`、`selectionLabel`、`docsPath`、`order`、`aliases` |
| `providers`  | `string[]` | 该插件注册的 provider id                                                                |
| `install`    | `object`   | 安装提示：`npmSpec`、`localPath`、`defaultChoice`                                       |
| `startup`    | `object`   | 启动行为标志                                                                            |

### 延迟完整加载

渠道插件可以通过以下方式开启延迟加载：

```json
{
  "openclaw": {
    "extensions": ["./index.ts"],
    "setupEntry": "./setup-entry.ts",
    "startup": {
      "deferConfiguredChannelFullLoadUntilAfterListen": true
    }
  }
}
```

启用后，即使某个渠道已经配置完成，OpenClaw 在监听前的启动阶段也只会加载 `setupEntry`。完整入口会在 gateway 开始监听之后再加载。

<Warning>
  只有当你的 `setupEntry` 已经注册了 gateway 在开始监听前所需的一切内容时，才应该启用延迟加载（渠道注册、HTTP 路由、gateway 方法）。如果完整入口中仍包含启动时必须的能力，请保留默认行为。
</Warning>

## 插件清单

每个原生插件都必须在包根目录下提供一个 `openclaw.plugin.json`。OpenClaw 会使用它在不执行插件代码的情况下验证配置。

```json
{
  "id": "my-plugin",
  "name": "My Plugin",
  "description": "Adds My Plugin capabilities to OpenClaw",
  "configSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {
      "webhookSecret": {
        "type": "string",
        "description": "Webhook verification secret"
      }
    }
  }
}
```

对于渠道插件，还要添加 `kind` 和 `channels`：

```json
{
  "id": "my-channel",
  "kind": "channel",
  "channels": ["my-channel"],
  "configSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {}
  }
}
```

即使插件没有任何配置，也必须提供 schema。空 schema 也是合法的：

```json
{
  "id": "my-plugin",
  "configSchema": {
    "type": "object",
    "additionalProperties": false
  }
}
```

完整 schema 参考请见 [插件清单](/plugins/manifest)。

## ClawHub 发布

对于插件包，请使用包专用的 ClawHub 命令：

```bash
clawhub package publish your-org/your-plugin --dry-run
clawhub package publish your-org/your-plugin
```

旧版仅适用于 skill 的发布别名是给 skills 用的。插件包始终应使用 `clawhub package publish`。

## Setup entry

`setup-entry.ts` 文件是 `index.ts` 的轻量级替代方案。OpenClaw 在只需要 setup 接口面（新手引导、配置修复、禁用渠道检查）时会加载它。

```typescript
// setup-entry.ts
import { defineSetupPluginEntry } from "openclaw/plugin-sdk/core";
import { myChannelPlugin } from "./src/channel.js";

export default defineSetupPluginEntry(myChannelPlugin);
```

这样可以避免在设置流程中加载沉重的运行时代码（加密库、CLI 注册、后台服务）。

**OpenClaw 在以下情况会使用 `setupEntry` 而不是完整入口：**

- 渠道已禁用，但仍需要 setup / onboarding 接口面
- 渠道已启用，但尚未配置
- 启用了延迟加载（`deferConfiguredChannelFullLoadUntilAfterListen`）

**`setupEntry` 必须注册的内容：**

- 渠道插件对象（通过 `defineSetupPluginEntry`）
- 任何在 gateway 监听前就需要的 HTTP 路由
- 启动期间所需的任何 gateway 方法

**`setupEntry` 不应包含的内容：**

- CLI 注册
- 后台服务
- 沉重的运行时导入（加密库、SDK）
- 只在启动后需要的 gateway 方法

## 配置 schema

插件配置会根据清单中的 JSON Schema 进行校验。用户通过以下方式配置插件：

```json5
{
  plugins: {
    entries: {
      "my-plugin": {
        config: {
          webhookSecret: "abc123",
        },
      },
    },
  },
}
```

你的插件会在注册期间通过 `api.pluginConfig` 接收到这份配置。

对于渠道专属配置，请改用渠道配置区段：

```json5
{
  channels: {
    "my-channel": {
      token: "bot-token",
      allowFrom: ["user1", "user2"],
    },
  },
}
```

### 构建渠道配置 schema

使用 `openclaw/plugin-sdk/core` 中的 `buildChannelConfigSchema`，把 Zod schema 转换为 OpenClaw 用来校验的 `ChannelConfigSchema` 包装结构：

```typescript
import { z } from "zod";
import { buildChannelConfigSchema } from "openclaw/plugin-sdk/core";

const accountSchema = z.object({
  token: z.string().optional(),
  allowFrom: z.array(z.string()).optional(),
  accounts: z.object({}).catchall(z.any()).optional(),
  defaultAccount: z.string().optional(),
});

const configSchema = buildChannelConfigSchema(accountSchema);
```

## 设置向导

渠道插件可以为 `openclaw onboard` 提供交互式设置向导。这个向导是 `ChannelPlugin` 上的 `ChannelSetupWizard` 对象：

```typescript
import type { ChannelSetupWizard } from "openclaw/plugin-sdk/channel-setup";

const setupWizard: ChannelSetupWizard = {
  channel: "my-channel",
  status: {
    configuredLabel: "Connected",
    unconfiguredLabel: "Not configured",
    resolveConfigured: ({ cfg }) => Boolean((cfg.channels as any)?.["my-channel"]?.token),
  },
  credentials: [
    {
      inputKey: "token",
      providerHint: "my-channel",
      credentialLabel: "Bot token",
      preferredEnvVar: "MY_CHANNEL_BOT_TOKEN",
      envPrompt: "Use MY_CHANNEL_BOT_TOKEN from environment?",
      keepPrompt: "Keep current token?",
      inputPrompt: "Enter your bot token:",
      inspect: ({ cfg, accountId }) => {
        const token = (cfg.channels as any)?.["my-channel"]?.token;
        return {
          accountConfigured: Boolean(token),
          hasConfiguredValue: Boolean(token),
        };
      },
    },
  ],
};
```

`ChannelSetupWizard` 类型支持 `credentials`、`textInputs`、`dmPolicy`、`allowFrom`、`groupAccess`、`prepare`、`finalize` 等能力。完整示例可参考内置插件包（例如 Discord 插件中的 `src/channel.setup.ts`）。

对于只需要标准
`note -> prompt -> parse -> merge -> patch` 流程的私信 allowlist 提示，优先使用 `openclaw/plugin-sdk/setup` 中的共享 setup 辅助：`createPromptParsedAllowFromForAccount(...)`、`createTopLevelChannelParsedAllowFromPrompt(...)` 和 `createNestedChannelParsedAllowFromPrompt(...)`。

对于只在 label、score 和可选额外行上有所变化的渠道 setup 状态块，优先使用 `openclaw/plugin-sdk/setup` 中的 `createStandardChannelSetupStatus(...)`，而不是在每个插件里重复手写同样的 `status` 对象。

对于仅应在特定上下文出现的可选 setup 接口面，请使用 `openclaw/plugin-sdk/channel-setup` 中的 `createOptionalChannelSetupSurface`：

```typescript
import { createOptionalChannelSetupSurface } from "openclaw/plugin-sdk/channel-setup";

const setupSurface = createOptionalChannelSetupSurface({
  channel: "my-channel",
  label: "My Channel",
  npmSpec: "@myorg/openclaw-my-channel",
  docsPath: "/channels/my-channel",
});
// Returns { setupAdapter, setupWizard }
```

## 发布与安装

**外部插件：** 发布到 [ClawHub](/tools/clawhub) 或 npm，然后安装：

```bash
openclaw plugins install @myorg/openclaw-my-plugin
```

OpenClaw 会先尝试 ClawHub，再自动回退到 npm。你也可以强制指定来源：

```bash
openclaw plugins install clawhub:@myorg/openclaw-my-plugin   # ClawHub only
openclaw plugins install npm:@myorg/openclaw-my-plugin       # npm only
```

**仓库内插件：** 放在内置插件 workspace 树下，构建时会自动发现。

**用户可以浏览并安装：**

```bash
openclaw plugins search <query>
openclaw plugins install <package-name>
```

<Info>
  对于来源于 npm 的安装，`openclaw plugins install` 会执行
  `npm install --ignore-scripts`（不运行 lifecycle scripts）。请保持插件依赖树为纯 JS/TS，并避免依赖需要 `postinstall` 构建的包。
</Info>

## 相关内容

- [SDK 入口点](/plugins/sdk-entrypoints) -- `definePluginEntry` 和 `defineChannelPluginEntry`
- [插件清单](/plugins/manifest) -- 完整清单 schema 参考
- [构建插件](/plugins/building-plugins) -- 分步入门指南
