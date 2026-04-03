---
title: "插件 SDK 概览"
sidebarTitle: "SDK 概览"
summary: "导入映射、注册 API 参考与 SDK 架构"
read_when:
  - 你需要知道应该从哪个 SDK 子路径导入
  - 你想查阅 OpenClawPluginApi 上所有注册方法的参考
  - 你正在查找某个具体的 SDK 导出
---

# 插件 SDK 概览

插件 SDK 是插件与核心之间的类型化契约。本页是关于**导入什么**以及**你可以注册什么**的参考说明。

<Tip>
  **想看操作指南？**
  - 第一个插件？从 [入门指南](/plugins/building-plugins) 开始
  - 渠道插件？见 [渠道插件](/plugins/sdk-channel-plugins)
  - 提供商插件？见 [提供商插件](/plugins/sdk-provider-plugins)
</Tip>

## 导入约定

始终从具体子路径导入：

```typescript
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";
import { defineChannelPluginEntry } from "openclaw/plugin-sdk/core";
```

每个子路径都是一个小型、自包含模块。这样可以保持启动快速，并避免循环依赖问题。

## 子路径参考

下面按用途分组列出最常用的子路径。完整的 100+ 子路径清单位于 `scripts/lib/plugin-sdk-entrypoints.json`。

### 插件入口

| 子路径                    | 关键导出                                                                                                                               |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `plugin-sdk/plugin-entry` | `definePluginEntry`                                                                                                                    |
| `plugin-sdk/core`         | `defineChannelPluginEntry`, `createChatChannelPlugin`, `createChannelPluginBase`, `defineSetupPluginEntry`, `buildChannelConfigSchema` |

<AccordionGroup>
  <Accordion title="渠道子路径">
    | 子路径 | 关键导出 |
    | --- | --- |
    | `plugin-sdk/channel-setup` | `createOptionalChannelSetupSurface` |
    | `plugin-sdk/channel-pairing` | `createChannelPairingController` |
    | `plugin-sdk/channel-reply-pipeline` | `createChannelReplyPipeline` |
    | `plugin-sdk/channel-config-helpers` | `createHybridChannelConfigAdapter` |
    | `plugin-sdk/channel-config-schema` | 渠道配置 schema 类型 |
    | `plugin-sdk/channel-policy` | `resolveChannelGroupRequireMention` |
    | `plugin-sdk/channel-lifecycle` | `createAccountStatusSink` |
    | `plugin-sdk/channel-inbound` | 防抖、提及匹配、封装辅助 |
    | `plugin-sdk/channel-send-result` | 回复结果类型 |
    | `plugin-sdk/channel-actions` | `createMessageToolButtonsSchema`, `createMessageToolCardSchema` |
    | `plugin-sdk/channel-targets` | 目标解析/匹配辅助 |
    | `plugin-sdk/channel-contract` | 渠道契约类型 |
    | `plugin-sdk/channel-feedback` | 反馈/反应连接 |
  </Accordion>

  <Accordion title="提供商子路径">
    | 子路径 | 关键导出 |
    | --- | --- |
    | `plugin-sdk/cli-backend` | CLI 后端默认值与 watchdog 常量 |
    | `plugin-sdk/provider-auth` | `createProviderApiKeyAuthMethod`, `ensureApiKeyFromOptionEnvOrPrompt`, `upsertAuthProfile` |
    | `plugin-sdk/provider-model-shared` | `normalizeModelCompat` |
    | `plugin-sdk/provider-catalog-shared` | `findCatalogTemplate`, `buildSingleProviderApiKeyCatalog` |
    | `plugin-sdk/provider-usage` | `fetchClaudeUsage` 等 |
    | `plugin-sdk/provider-stream` | 流包装类型 |
    | `plugin-sdk/provider-onboard` | 新手引导配置 patch 辅助 |
    | `plugin-sdk/global-singleton` | 进程内 singleton/map/cache 辅助 |
  </Accordion>

  <Accordion title="鉴权与安全子路径">
    | 子路径 | 关键导出 |
    | --- | --- |
    | `plugin-sdk/command-auth` | `resolveControlCommandGate` |
    | `plugin-sdk/allow-from` | `formatAllowFromLowercase` |
    | `plugin-sdk/secret-input` | Secret 输入解析辅助 |
    | `plugin-sdk/webhook-ingress` | Webhook 请求/目标辅助 |
    | `plugin-sdk/webhook-request-guards` | 请求体大小/超时辅助 |
  </Accordion>

  <Accordion title="运行时与存储子路径">
    | 子路径 | 关键导出 |
    | --- | --- |
    | `plugin-sdk/runtime-store` | `createPluginRuntimeStore` |
    | `plugin-sdk/config-runtime` | 配置加载/写入辅助 |
    | `plugin-sdk/approval-runtime` | exec 与插件审批辅助 |
    | `plugin-sdk/infra-runtime` | 系统事件/heartbeat 辅助 |
    | `plugin-sdk/collection-runtime` | 小型有界缓存辅助 |
    | `plugin-sdk/diagnostic-runtime` | 诊断标志与事件辅助 |
    | `plugin-sdk/error-runtime` | 错误图与格式化辅助 |
    | `plugin-sdk/fetch-runtime` | 包装后的 fetch、proxy 和 pinned lookup 辅助 |
    | `plugin-sdk/host-runtime` | 主机名与 SCP 主机归一化辅助 |
    | `plugin-sdk/retry-runtime` | 重试配置与重试执行辅助 |
    | `plugin-sdk/agent-runtime` | 智能体目录/身份/workspace 辅助 |
    | `plugin-sdk/directory-runtime` | 基于配置的目录查询/去重 |
    | `plugin-sdk/keyed-async-queue` | `KeyedAsyncQueue` |
  </Accordion>

  <Accordion title="能力与测试子路径">
    | 子路径 | 关键导出 |
    | --- | --- |
    | `plugin-sdk/image-generation` | 图像生成提供商类型 |
    | `plugin-sdk/media-understanding` | 媒体理解提供商类型 |
    | `plugin-sdk/speech` | 语音提供商类型 |
    | `plugin-sdk/testing` | `installCommonResolveTargetErrorCases`, `shouldAckReaction` |
  </Accordion>
</AccordionGroup>

## 注册 API

`register(api)` 回调会接收一个 `OpenClawPluginApi` 对象，包含以下方法：

### 能力注册

| 方法                                          | 它注册什么            |
| --------------------------------------------- | --------------------- |
| `api.registerProvider(...)`                   | 文本推理（LLM）       |
| `api.registerCliBackend(...)`                 | 本地 CLI 推理后端     |
| `api.registerChannel(...)`                    | 消息渠道              |
| `api.registerSpeechProvider(...)`             | 文本转语音 / STT 合成 |
| `api.registerMediaUnderstandingProvider(...)` | 图像/音频/视频分析    |
| `api.registerImageGenerationProvider(...)`    | 图像生成              |
| `api.registerWebSearchProvider(...)`          | Web 搜索              |

### 工具与命令

| 方法                            | 它注册什么                                  |
| ------------------------------- | ------------------------------------------- |
| `api.registerTool(tool, opts?)` | 智能体工具（必选，或 `{ optional: true }`） |
| `api.registerCommand(def)`      | 自定义命令（绕过 LLM）                      |

### 基础设施

| 方法                                           | 它注册什么        |
| ---------------------------------------------- | ----------------- |
| `api.registerHook(events, handler, opts?)`     | 事件 hook         |
| `api.registerHttpRoute(params)`                | Gateway HTTP 端点 |
| `api.registerGatewayMethod(name, handler)`     | Gateway RPC 方法  |
| `api.registerCli(registrar, opts?)`            | CLI 子命令        |
| `api.registerService(service)`                 | 后台服务          |
| `api.registerInteractiveHandler(registration)` | 交互式处理器      |

### CLI 注册 metadata

`api.registerCli(registrar, opts?)` 支持两类顶层 metadata：

- `commands`：由 registrar 拥有的显式命令根
- `descriptors`：用于根 CLI 帮助、路由和懒加载插件 CLI 注册的解析期命令 descriptor

如果你希望某个插件命令在正常根 CLI 路径中保持懒加载，请提供 `descriptors`，并确保它们覆盖该 registrar 暴露的所有顶级命令根。

```typescript
api.registerCli(
  async ({ program }) => {
    const { registerMatrixCli } = await import("./src/cli.js");
    registerMatrixCli({ program });
  },
  {
    descriptors: [
      {
        name: "matrix",
        description: "Manage Matrix accounts, verification, devices, and profile state",
        hasSubcommands: true,
      },
    ],
  },
);
```

仅在你不需要懒加载根 CLI 注册时才单独使用 `commands`。这种急切兼容路径仍然受支持，但不会安装基于 descriptor 的占位符来支持解析期懒加载。

### CLI 后端注册

`api.registerCliBackend(...)` 允许插件为本地 AI CLI 后端（如 `claude-cli` 或 `codex-cli`）提供默认配置。

- 后端 `id` 会成为模型引用中的提供商前缀，例如 `claude-cli/opus`。
- 后端 `config` 与 `agents.defaults.cliBackends.<id>` 的配置形状相同。
- 用户配置仍然优先。OpenClaw 会先把 `agents.defaults.cliBackends.<id>` 合并到插件默认值之上，再运行 CLI。
- 当后端在合并后仍需要兼容性重写（例如规范化旧 flag 形状）时，请使用 `normalizeConfig`。

### 独占插槽

| 方法                                       | 它注册什么                   |
| ------------------------------------------ | ---------------------------- |
| `api.registerContextEngine(id, factory)`   | 上下文引擎（一次仅激活一个） |
| `api.registerMemoryPromptSection(builder)` | memory 提示词区段构建器      |
| `api.registerMemoryFlushPlan(resolver)`    | memory flush plan 解析器     |
| `api.registerMemoryRuntime(runtime)`       | memory 运行时适配器          |

### Memory embedding 适配器

| 方法                                           | 它注册什么                             |
| ---------------------------------------------- | -------------------------------------- |
| `api.registerMemoryEmbeddingProvider(adapter)` | 当前激活插件的 memory embedding 适配器 |

- `registerMemoryPromptSection`、`registerMemoryFlushPlan` 和 `registerMemoryRuntime` 仅能用于 memory 插件。
- `registerMemoryEmbeddingProvider` 允许当前激活的 memory 插件注册一个或多个 embedding 适配器 id（例如 `openai`、`gemini` 或插件自定义 id）。
- 用户配置（例如 `agents.defaults.memorySearch.provider` 和 `agents.defaults.memorySearch.fallback`）会针对这些已注册的适配器 id 进行解析。

### 事件与生命周期

| 方法                                         | 它的作用            |
| -------------------------------------------- | ------------------- |
| `api.on(hookName, handler, opts?)`           | 类型化生命周期 hook |
| `api.onConversationBindingResolved(handler)` | 会话绑定解析回调    |

### Hook 决策语义

- `before_tool_call`：返回 `{ block: true }` 是终止性决策。一旦任意 handler 设置它，就会跳过更低优先级 handler。
- `before_tool_call`：返回 `{ block: false }` 会被视为“未做决定”（等同于省略 `block`），而不是覆盖。
- `before_install`：返回 `{ block: true }` 是终止性决策。一旦任意 handler 设置它，就会跳过更低优先级 handler。
- `before_install`：返回 `{ block: false }` 会被视为“未做决定”（等同于省略 `block`），而不是覆盖。
- `message_sending`：返回 `{ cancel: true }` 是终止性决策。一旦任意 handler 设置它，就会跳过更低优先级 handler。
- `message_sending`：返回 `{ cancel: false }` 会被视为“未做决定”（等同于省略 `cancel`），而不是覆盖。

### API 对象字段

| 字段                     | 类型                      | 描述                                                            |
| ------------------------ | ------------------------- | --------------------------------------------------------------- |
| `api.id`                 | `string`                  | 插件 id                                                         |
| `api.name`               | `string`                  | 显示名称                                                        |
| `api.version`            | `string?`                 | 插件版本（可选）                                                |
| `api.description`        | `string?`                 | 插件描述（可选）                                                |
| `api.source`             | `string`                  | 插件源码路径                                                    |
| `api.rootDir`            | `string?`                 | 插件根目录（可选）                                              |
| `api.config`             | `OpenClawConfig`          | 当前配置快照                                                    |
| `api.pluginConfig`       | `Record<string, unknown>` | 来自 `plugins.entries.<id>.config` 的插件专属配置               |
| `api.runtime`            | `PluginRuntime`           | [运行时辅助](/plugins/sdk-runtime)                              |
| `api.logger`             | `PluginLogger`            | 作用域化 logger（`debug`、`info`、`warn`、`error`）             |
| `api.registrationMode`   | `PluginRegistrationMode`  | `"full"`、`"setup-only"`、`"setup-runtime"` 或 `"cli-metadata"` |
| `api.resolvePath(input)` | `(string) => string`      | 按插件根目录解析路径                                            |

## 内部模块约定

在插件内部，请使用本地 barrel 文件进行内部导入：

```
my-plugin/
  api.ts            # Public exports for external consumers
  runtime-api.ts    # Internal-only runtime exports
  index.ts          # Plugin entry point
  setup-entry.ts    # Lightweight setup-only entry (optional)
```

<Warning>
  在生产代码中，永远不要通过 `openclaw/plugin-sdk/<your-plugin>` 导入你自己的插件。
  内部导入请改走 `./api.ts` 或 `./runtime-api.ts`。SDK 路径只应作为外部契约存在。
</Warning>

<Warning>
  扩展生产代码同样应避免导入 `openclaw/plugin-sdk/<other-plugin>`。
  如果某个辅助函数确实需要共享，请将它提升到中立的 SDK 子路径，例如 `openclaw/plugin-sdk/speech`、`.../provider-model-shared`，或其他按能力划分的接口面，而不是让两个插件直接耦合。
</Warning>

## 相关内容

- [入口点](/plugins/sdk-entrypoints) — `definePluginEntry` 和 `defineChannelPluginEntry` 选项
- [运行时辅助](/plugins/sdk-runtime) — 完整 `api.runtime` 命名空间参考
- [设置与配置](/plugins/sdk-setup) — 打包、清单、配置 schema
- [测试](/plugins/sdk-testing) — 测试工具与 lint 规则
- [SDK 迁移](/plugins/sdk-migration) — 从废弃接口面迁移
- [插件内部机制](/plugins/architecture) — 深入架构与能力模型
