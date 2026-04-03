---
title: "构建插件"
sidebarTitle: "入门指南"
summary: "在几分钟内创建您的第一个 OpenClaw 插件"
read_when:
  - 您想创建一个新的 OpenClaw 插件
  - 您需要插件开发的快速入门指南
  - 您正在向 OpenClaw 添加新的 channel、provider、工具或其他功能
x-i18n:
  sourceCommit: "latest"
  sourceFile: "plugins/building-plugins.md"
---

# 构建插件

插件通过新功能扩展 OpenClaw：channels、模型 providers、语音、图像生成、网络搜索、智能体工具或任何组合。

您不需要将插件添加到 OpenClaw 仓库。发布到 [ClawHub](/tools/clawhub) 或 npm，用户使用 `openclaw plugins install <package-name>` 安装。OpenClaw 首先尝试 ClawHub，然后自动回退到 npm。

## 先决条件

- Node >= 22 和包管理器（npm 或 pnpm）
- 熟悉 TypeScript（ESM）
- 对于仓库内插件：克隆仓库并完成 `pnpm install`

## 什么类型的插件？

<CardGroup cols={3}>
  <Card title="Channel 插件" icon="messages-square" href="/plugins/sdk-channel-plugins">
    将 OpenClaw 连接到消息平台（Discord、IRC 等）
  </Card>
  <Card title="Provider 插件" icon="cpu" href="/plugins/sdk-provider-plugins">
    添加模型 provider（LLM、代理或自定义端点）
  </Card>
  <Card title="工具 / 钩子插件" icon="wrench">
    注册智能体工具、事件钩子或服务 — 继续阅读下文
  </Card>
</CardGroup>

## 快速入门：工具插件

本演练创建一个注册智能体工具的最小插件。Channel 和 provider 插件有上面链接的专用指南。

<Steps>
  <Step title="创建包和清单">
    <CodeGroup>
    ```json package.json
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

    ```json openclaw.plugin.json
    {
      "id": "my-plugin",
      "name": "My Plugin",
      "description": "Adds a custom tool to OpenClaw",
      "configSchema": {
        "type": "object",
        "additionalProperties": false
      }
    }
    ```
    </CodeGroup>

    每个插件都需要一个清单，即使没有配置。完整架构请参阅 [Manifest](/plugins/manifest)。规范的 ClawHub 发布片段位于 `docs/snippets/plugin-publish/`。

  </Step>

  <Step title="编写入口点">

    ```typescript
    // index.ts
    import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";
    import { Type } from "@sinclair/typebox";

    export default definePluginEntry({
      id: "my-plugin",
      name: "My Plugin",
      description: "Adds a custom tool to OpenClaw",
      register(api) {
        api.registerTool({
          name: "my_tool",
          description: "Do a thing",
          parameters: Type.Object({ input: Type.String() }),
          async execute(_id, params) {
            return { content: [{ type: "text", text: `Got: ${params.input}` }] };
          },
        });
      },
    });
    ```

    `definePluginEntry` 用于非 channel 插件。对于 channels，使用 `defineChannelPluginEntry` — 请参阅 [Channel Plugins](/plugins/sdk-channel-plugins)。有关完整的入口点选项，请参阅 [Entry Points](/plugins/sdk-entrypoints)。

  </Step>

  <Step title="测试和发布">

    **外部插件：** 使用 ClawHub 验证和发布，然后安装：

    ```bash
    clawhub package publish your-org/your-plugin --dry-run
    clawhub package publish your-org/your-plugin
    openclaw plugins install clawhub:@myorg/openclaw-my-plugin
    ```

    OpenClaw 还会在 npm 之前检查 ClawHub 以获取裸包规范，如 `@myorg/openclaw-my-plugin`。

    **仓库内插件：** 放置在捆绑插件工作区树下 — 自动发现。

    ```bash
    pnpm test -- <bundled-plugin-root>/my-plugin/
    ```

  </Step>
</Steps>

## 插件功能

单个插件可以通过 `api` 对象注册任意数量的功能：

| 功能            | 注册方法                                      | 详细指南                                                                        |
| --------------- | --------------------------------------------- | ------------------------------------------------------------------------------- |
| 文本推理（LLM） | `api.registerProvider(...)`                   | [Provider Plugins](/plugins/sdk-provider-plugins)                               |
| CLI 推理后端    | `api.registerCliBackend(...)`                 | [CLI Backends](/gateway/cli-backends)                                           |
| Channel / 消息  | `api.registerChannel(...)`                    | [Channel Plugins](/plugins/sdk-channel-plugins)                                 |
| 语音（TTS/STT） | `api.registerSpeechProvider(...)`             | [Provider Plugins](/plugins/sdk-provider-plugins#step-5-add-extra-capabilities) |
| 媒体理解        | `api.registerMediaUnderstandingProvider(...)` | [Provider Plugins](/plugins/sdk-provider-plugins#step-5-add-extra-capabilities) |
| 图像生成        | `api.registerImageGenerationProvider(...)`    | [Provider Plugins](/plugins/sdk-provider-plugins#step-5-add-extra-capabilities) |
| 网络搜索        | `api.registerWebSearchProvider(...)`          | [Provider Plugins](/plugins/sdk-provider-plugins#step-5-add-extra-capabilities) |
| 智能体工具      | `api.registerTool(...)`                       | 下文                                                                            |
| 自定义命令      | `api.registerCommand(...)`                    | [Entry Points](/plugins/sdk-entrypoints)                                        |
| 事件钩子        | `api.registerHook(...)`                       | [Entry Points](/plugins/sdk-entrypoints)                                        |
| HTTP 路由       | `api.registerHttpRoute(...)`                  | [Internals](/plugins/architecture#gateway-http-routes)                          |
| CLI 子命令      | `api.registerCli(...)`                        | [Entry Points](/plugins/sdk-entrypoints)                                        |

有关完整的注册 API，请参阅 [SDK Overview](/plugins/sdk-overview#registration-api)。

需要记住的钩子守卫语义：

- `before_tool_call`：`{ block: true }` 是终止的，并停止较低优先级的处理程序。
- `before_tool_call`：`{ block: false }` 被视为无决定。
- `before_tool_call`：`{ requireApproval: true }` 暂停智能体执行，并通过执行批准覆盖层、Telegram 按钮、Discord 交互或任何 channel 上的 `/approve` 命令提示用户批准。
- `before_install`：`{ block: true }` 是终止的，并停止较低优先级的处理程序。
- `before_install`：`{ block: false }` 被视为无决定。
- `message_sending`：`{ cancel: true }` 是终止的，并停止较低优先级的处理程序。
- `message_sending`：`{ cancel: false }` 被视为无决定。

`/approve` 命令处理执行和插件批准，并具有自动回退。插件批准转发可以通过配置中的 `approvals.plugin` 独立配置。

有关详细信息，请参阅 [SDK Overview hook decision semantics](/plugins/sdk-overview#hook-decision-semantics)。

## 注册智能体工具

工具是 LLM 可以调用的类型化函数。它们可以是必需的（始终可用）或可选的（用户选择加入）：

```typescript
register(api) {
  // 必需工具 — 始终可用
  api.registerTool({
    name: "my_tool",
    description: "Do a thing",
    parameters: Type.Object({ input: Type.String() }),
    async execute(_id, params) {
      return { content: [{ type: "text", text: params.input }] };
    },
  });

  // 可选工具 — 用户必须添加到允许列表
  api.registerTool(
    {
      name: "workflow_tool",
      description: "Run a workflow",
      parameters: Type.Object({ pipeline: Type.String() }),
      async execute(_id, params) {
        return { content: [{ type: "text", text: params.pipeline }] };
      },
    },
    { optional: true },
  );
}
```

用户在配置中启用可选工具：

```json5
{
  tools: { allow: ["workflow_tool"] },
}
```

- 工具名称不得与核心工具冲突（冲突会被跳过）
- 对具有副作用或额外二进制要求的工具使用 `optional: true`
- 用户可以通过将插件 id 添加到 `tools.allow` 来启用插件中的所有工具

## 导入约定

始终从聚焦的 `openclaw/plugin-sdk/<subpath>` 路径导入：

```typescript
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";
import { createPluginRuntimeStore } from "openclaw/plugin-sdk/runtime-store";

// 错误：单体根（已弃用，将被删除）
import { ... } from "openclaw/plugin-sdk";
```

有关完整的子路径参考，请参阅 [SDK Overview](/plugins/sdk-overview)。

在您的插件中，使用本地桶文件（`api.ts`、`runtime-api.ts`）进行内部导入 — 永远不要通过其 SDK 路径导入您自己的插件。

## 提交前检查清单

<Check>**package.json** 具有正确的 `openclaw` 元数据</Check>
<Check>**openclaw.plugin.json** 清单存在且有效</Check>
<Check>入口点使用 `defineChannelPluginEntry` 或 `definePluginEntry`</Check>
<Check>所有导入使用聚焦的 `plugin-sdk/<subpath>` 路径</Check>
<Check>内部导入使用本地模块，而不是 SDK 自导入</Check>
<Check>测试通过（`pnpm test -- <bundled-plugin-root>/my-plugin/`）</Check>
<Check>`pnpm check` 通过（仓库内插件）</Check>

## Beta 版本测试

1. 在 [openclaw/openclaw](https://github.com/openclaw/openclaw/releases) 上关注 GitHub 发布标签，并通过 `Watch` > `Releases` 订阅。Beta 标签看起来像 `v2026.3.N-beta.1`。您还可以为官方 OpenClaw X 账户 [@openclaw](https://x.com/openclaw) 打开发布公告通知。
2. 一旦出现 beta 标签，立即针对它测试您的插件。稳定版之前的窗口通常只有几个小时。
3. 测试后在 `plugin-forum` Discord 频道中您的插件线程中发布 `all good` 或出现的问题。如果您还没有线程，请创建一个。
4. 如果出现问题，打开或更新标题为 `Beta blocker: <plugin-name> - <summary>` 的 issue，并应用 `beta-blocker` 标签。将 issue 链接放在您的线程中。
5. 打开一个标题为 `fix(<plugin-id>): beta blocker - <summary>` 的 PR 到 `main`，并在 PR 和您的 Discord 线程中链接该 issue。贡献者无法标记 PR，因此标题是维护者和自动化的 PR 端信号。带有 PR 的阻止程序会被合并；没有 PR 的阻止程序可能仍然会发布。维护者在 beta 测试期间会关注这些线程。
6. 沉默意味着绿色。如果您错过了窗口，您的修复可能会在下一个周期中落地。

## 下一步

<CardGroup cols={2}>
  <Card title="Channel Plugins" icon="messages-square" href="/plugins/sdk-channel-plugins">
    构建消息 channel 插件
  </Card>
  <Card title="Provider Plugins" icon="cpu" href="/plugins/sdk-provider-plugins">
    构建模型 provider 插件
  </Card>
  <Card title="SDK Overview" icon="book-open" href="/plugins/sdk-overview">
    导入映射和注册 API 参考
  </Card>
  <Card title="Runtime Helpers" icon="settings" href="/plugins/sdk-runtime">
    通过 api.runtime 使用 TTS、搜索、子智能体
  </Card>
  <Card title="Testing" icon="test-tubes" href="/plugins/sdk-testing">
    测试实用程序和模式
  </Card>
  <Card title="Plugin Manifest" icon="file-json" href="/plugins/manifest">
    完整清单架构参考
  </Card>
</CardGroup>

## 相关

- [Plugin Architecture](/plugins/architecture) — 内部架构深入探讨
- [SDK Overview](/plugins/sdk-overview) — Plugin SDK 参考
- [Manifest](/plugins/manifest) — 插件清单格式
- [Channel Plugins](/plugins/sdk-channel-plugins) — 构建 channel 插件
- [Provider Plugins](/plugins/sdk-provider-plugins) — 构建 provider 插件
