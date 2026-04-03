---
title: "插件入口点"
sidebarTitle: "入口点"
summary: "definePluginEntry、defineChannelPluginEntry 和 defineSetupPluginEntry 的参考说明"
read_when:
  - 你需要 definePluginEntry 或 defineChannelPluginEntry 的精确类型签名
  - 你想理解注册模式（full / setup / CLI metadata）
  - 你要查阅入口点选项
---

# 插件入口点

每个插件都会导出一个默认入口对象。SDK 提供了三个辅助函数来创建它们。

<Tip>
  **想看操作指南？** 请查看 [渠道插件](/plugins/sdk-channel-plugins)
  或 [提供商插件](/plugins/sdk-provider-plugins) 的分步教程。
</Tip>

## `definePluginEntry`

**导入：** `openclaw/plugin-sdk/plugin-entry`

用于提供商插件、工具插件、hook 插件，以及任何**不是**消息渠道的插件。

```typescript
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

export default definePluginEntry({
  id: "my-plugin",
  name: "My Plugin",
  description: "Short summary",
  register(api) {
    api.registerProvider({
      /* ... */
    });
    api.registerTool({
      /* ... */
    });
  },
});
```

| 字段           | 类型                                                             | 必填 | 默认值        |
| -------------- | ---------------------------------------------------------------- | ---- | ------------- |
| `id`           | `string`                                                         | 是   | —             |
| `name`         | `string`                                                         | 是   | —             |
| `description`  | `string`                                                         | 是   | —             |
| `kind`         | `string`                                                         | 否   | —             |
| `configSchema` | `OpenClawPluginConfigSchema \| () => OpenClawPluginConfigSchema` | 否   | 空对象 schema |
| `register`     | `(api: OpenClawPluginApi) => void`                               | 是   | —             |

- `id` 必须与你的 `openclaw.plugin.json` 清单一致。
- `kind` 用于独占插槽：`"memory"` 或 `"context-engine"`。
- `configSchema` 可以写成函数，以实现惰性求值。

## `defineChannelPluginEntry`

**导入：** `openclaw/plugin-sdk/core`

它是在 `definePluginEntry` 之上封装的渠道专用连接层。会自动调用
`api.registerChannel({ plugin })`，暴露可选的根帮助 CLI metadata 接缝，并根据注册模式决定是否执行 `registerFull`。

```typescript
import { defineChannelPluginEntry } from "openclaw/plugin-sdk/core";

export default defineChannelPluginEntry({
  id: "my-channel",
  name: "My Channel",
  description: "Short summary",
  plugin: myChannelPlugin,
  setRuntime: setMyRuntime,
  registerCliMetadata(api) {
    api.registerCli(/* ... */);
  },
  registerFull(api) {
    api.registerGatewayMethod(/* ... */);
  },
});
```

| 字段                  | 类型                                                             | 必填 | 默认值        |
| --------------------- | ---------------------------------------------------------------- | ---- | ------------- |
| `id`                  | `string`                                                         | 是   | —             |
| `name`                | `string`                                                         | 是   | —             |
| `description`         | `string`                                                         | 是   | —             |
| `plugin`              | `ChannelPlugin`                                                  | 是   | —             |
| `configSchema`        | `OpenClawPluginConfigSchema \| () => OpenClawPluginConfigSchema` | 否   | 空对象 schema |
| `setRuntime`          | `(runtime: PluginRuntime) => void`                               | 否   | —             |
| `registerCliMetadata` | `(api: OpenClawPluginApi) => void`                               | 否   | —             |
| `registerFull`        | `(api: OpenClawPluginApi) => void`                               | 否   | —             |

- `setRuntime` 会在注册期间调用，这样你就能保存运行时引用（通常结合 `createPluginRuntimeStore` 使用）。在 CLI metadata 捕获期间不会调用它。
- `registerCliMetadata` 会在 `api.registrationMode === "cli-metadata"` 和 `api.registrationMode === "full"` 两种情况下运行。
  它是放置由渠道拥有的 CLI descriptor 的规范位置，这样根帮助仍然不会激活插件，而正常的 CLI 命令注册也仍然能与完整插件加载兼容。
- `registerFull` 仅在 `api.registrationMode === "full"` 时运行。在仅 setup 加载期间会被跳过。
- 对于插件自有的根 CLI 命令，如果你希望它保持懒加载且不从根 CLI 解析树中消失，优先使用 `api.registerCli(..., { descriptors: [...] })`。
  对于渠道插件，应优先在 `registerCliMetadata(...)` 中注册这些 descriptor，并让 `registerFull(...)` 专注于仅运行时工作。

## `defineSetupPluginEntry`

**导入：** `openclaw/plugin-sdk/core`

用于轻量级 `setup-entry.ts` 文件。它只返回 `{ plugin }`，不包含运行时或 CLI 连接。

```typescript
import { defineSetupPluginEntry } from "openclaw/plugin-sdk/core";

export default defineSetupPluginEntry(myChannelPlugin);
```

当渠道被禁用、未配置，或启用了延迟加载时，OpenClaw 会加载它而不是完整入口。关于它何时重要，见 [设置与配置](/plugins/sdk-setup#setup-entry)。

## 注册模式

`api.registrationMode` 会告诉你的插件当前是如何被加载的：

| 模式              | 何时发生                   | 应注册什么        |
| ----------------- | -------------------------- | ----------------- |
| `"full"`          | 正常的 Gateway 启动        | 所有内容          |
| `"setup-only"`    | 渠道被禁用/未配置          | 仅渠道注册        |
| `"setup-runtime"` | 设置流程中且运行时可用     | 渠道 + 轻量运行时 |
| `"cli-metadata"`  | 根帮助 / CLI metadata 捕获 | 仅 CLI descriptor |

`defineChannelPluginEntry` 会自动处理这部分拆分。如果你对渠道直接使用 `definePluginEntry`，就需要自己检查模式：

```typescript
register(api) {
  if (api.registrationMode === "cli-metadata" || api.registrationMode === "full") {
    api.registerCli(/* ... */);
    if (api.registrationMode === "cli-metadata") return;
  }

  api.registerChannel({ plugin: myPlugin });
  if (api.registrationMode !== "full") return;

  // Heavy runtime-only registrations
  api.registerService(/* ... */);
}
```

对于 CLI registrar，尤其要注意：

- 当 registrar 拥有一个或多个根命令，并且你希望 OpenClaw 在首次调用时再懒加载真实 CLI 模块时，请使用 `descriptors`
- 确保这些 descriptor 覆盖 registrar 暴露的每个顶级命令根
- 仅在急切兼容路径下使用 `commands`

## 插件形态

OpenClaw 会根据插件的注册行为对已加载插件进行分类：

| 形态                  | 描述                                   |
| --------------------- | -------------------------------------- |
| **plain-capability**  | 单一能力类型（例如仅 provider）        |
| **hybrid-capability** | 多种能力类型（例如 provider + speech） |
| **hook-only**         | 只有 hook，没有能力                    |
| **non-capability**    | 有工具/命令/服务，但没有能力           |

使用 `openclaw plugins inspect <id>` 可以查看某个插件的形态。

## 相关内容

- [SDK 概览](/plugins/sdk-overview) — 注册 API 与子路径参考
- [运行时辅助](/plugins/sdk-runtime) — `api.runtime` 与 `createPluginRuntimeStore`
- [设置与配置](/plugins/sdk-setup) — 清单、setup entry、延迟加载
- [渠道插件](/plugins/sdk-channel-plugins) — 构建 `ChannelPlugin` 对象
- [提供商插件](/plugins/sdk-provider-plugins) — 提供商注册与 hooks
