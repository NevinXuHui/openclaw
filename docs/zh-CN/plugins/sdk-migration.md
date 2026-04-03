---
title: "插件 SDK 迁移"
sidebarTitle: "迁移到 SDK"
summary: "从旧版向后兼容层迁移到现代插件 SDK"
read_when:
  - 你看到了 OPENCLAW_PLUGIN_SDK_COMPAT_DEPRECATED 警告
  - 你看到了 OPENCLAW_EXTENSION_API_DEPRECATED 警告
  - 你正在把插件升级到现代插件架构
  - 你维护外部 OpenClaw 插件
---

# 插件 SDK 迁移

OpenClaw 已从宽泛的向后兼容层迁移到现代插件架构，改为使用聚焦且有文档的导入路径。如果你的插件是在新架构出现之前构建的，本指南可以帮助你完成迁移。

## 有什么变化

旧版插件系统提供了两个开放度很高的接口面，允许插件从单一入口导入几乎任何所需内容：

- **`openclaw/plugin-sdk/compat`** — 一个会重新导出大量辅助函数的单一导入入口。它最初是为了在构建新插件架构期间，保持旧版基于 hook 的插件继续可用。
- **`openclaw/extension-api`** — 一个桥接层，让插件能直接访问宿主侧辅助函数，例如嵌入式智能体运行器。

这两个接口面现在都已经**废弃**。它们在运行时仍可工作，但新插件不得再使用它们，现有插件也应在下一个 major 版本移除它们之前完成迁移。

<Warning>
  这个向后兼容层将在未来的 major 版本中移除。仍然从这些接口面导入的插件届时将会失效。
</Warning>

## 为什么会有这次变更

旧方式带来了几个问题：

- **启动慢** — 导入一个辅助函数就会加载几十个无关模块
- **循环依赖** — 宽泛的重导出很容易制造导入环
- **API 接口面不清晰** — 无法判断哪些导出是稳定接口，哪些只是内部实现

现代插件 SDK 修复了这些问题：每个导入路径（`openclaw/plugin-sdk/\<subpath\>`）都是一个小型、自包含模块，具备清晰用途和文档化契约。

## 如何迁移

<Steps>
  <Step title="查找废弃导入">
    搜索你的插件中是否使用了这两个已废弃的接口面：

    ```bash
    grep -r "plugin-sdk/compat" my-plugin/
    grep -r "openclaw/extension-api" my-plugin/
    ```

  </Step>

  <Step title="替换为聚焦导入">
    旧接口面的每个导出都映射到一个特定的现代导入路径：

    ```typescript
    // Before (deprecated backwards-compatibility layer)
    import {
      createChannelReplyPipeline,
      createPluginRuntimeStore,
      resolveControlCommandGate,
    } from "openclaw/plugin-sdk/compat";

    // After (modern focused imports)
    import { createChannelReplyPipeline } from "openclaw/plugin-sdk/channel-reply-pipeline";
    import { createPluginRuntimeStore } from "openclaw/plugin-sdk/runtime-store";
    import { resolveControlCommandGate } from "openclaw/plugin-sdk/command-auth";
    ```

    对于宿主侧辅助函数，请改为使用注入的插件运行时，而不是直接导入：

    ```typescript
    // Before (deprecated extension-api bridge)
    import { runEmbeddedPiAgent } from "openclaw/extension-api";
    const result = await runEmbeddedPiAgent({ sessionId, prompt });

    // After (injected runtime)
    const result = await api.runtime.agent.runEmbeddedPiAgent({ sessionId, prompt });
    ```

    其他旧版桥接辅助函数也遵循同样模式：

    | 旧导入 | 现代等价项 |
    | --- | --- |
    | `resolveAgentDir` | `api.runtime.agent.resolveAgentDir` |
    | `resolveAgentWorkspaceDir` | `api.runtime.agent.resolveAgentWorkspaceDir` |
    | `resolveAgentIdentity` | `api.runtime.agent.resolveAgentIdentity` |
    | `resolveThinkingDefault` | `api.runtime.agent.resolveThinkingDefault` |
    | `resolveAgentTimeoutMs` | `api.runtime.agent.resolveAgentTimeoutMs` |
    | `ensureAgentWorkspace` | `api.runtime.agent.ensureAgentWorkspace` |
    | session store helpers | `api.runtime.agent.session.*` |

  </Step>

  <Step title="构建并测试">
    ```bash
    pnpm build
    pnpm test -- my-plugin/
    ```
  </Step>
</Steps>

## 导入路径参考

<Accordion title="完整导入路径表">
  | 导入路径 | 用途 | 关键导出 |
  | --- | --- | --- |
  | `plugin-sdk/plugin-entry` | 规范的插件入口辅助 | `definePluginEntry` |
  | `plugin-sdk/core` | 渠道入口定义、渠道 builder、基础类型 | `defineChannelPluginEntry`, `createChatChannelPlugin` |
  | `plugin-sdk/channel-setup` | 设置向导适配器 | `createOptionalChannelSetupSurface` |
  | `plugin-sdk/channel-pairing` | 私信配对原语 | `createChannelPairingController` |
  | `plugin-sdk/channel-reply-pipeline` | 回复前缀与输入中状态连接 | `createChannelReplyPipeline` |
  | `plugin-sdk/channel-config-helpers` | 配置适配器工厂 | `createHybridChannelConfigAdapter` |
  | `plugin-sdk/channel-config-schema` | 配置 schema builder | 渠道配置 schema 类型 |
  | `plugin-sdk/channel-policy` | 群组/私信策略解析 | `resolveChannelGroupRequireMention` |
  | `plugin-sdk/channel-lifecycle` | 账户状态追踪 | `createAccountStatusSink` |
  | `plugin-sdk/channel-runtime` | 运行时连接辅助 | 渠道运行时工具 |
  | `plugin-sdk/channel-send-result` | 发送结果类型 | 回复结果类型 |
  | `plugin-sdk/runtime-store` | 持久化插件存储 | `createPluginRuntimeStore` |
  | `plugin-sdk/approval-runtime` | 审批提示辅助 | exec/plugin 审批载荷与回复辅助 |
  | `plugin-sdk/collection-runtime` | 有界缓存辅助 | `pruneMapToMaxSize` |
  | `plugin-sdk/diagnostic-runtime` | 诊断门控辅助 | `isDiagnosticFlagEnabled`, `isDiagnosticsEnabled` |
  | `plugin-sdk/error-runtime` | 错误格式化辅助 | `formatUncaughtError`、错误图辅助 |
  | `plugin-sdk/fetch-runtime` | 包装后的 fetch/proxy 辅助 | `resolveFetch`、proxy 辅助 |
  | `plugin-sdk/host-runtime` | 主机归一化辅助 | `normalizeHostname`, `normalizeScpRemoteHost` |
  | `plugin-sdk/retry-runtime` | 重试辅助 | `RetryConfig`, `retryAsync`, policy runner |
  | `plugin-sdk/allow-from` | allowlist 格式化 | `formatAllowFromLowercase` |
  | `plugin-sdk/allowlist-resolution` | allowlist 输入映射 | `mapAllowlistResolutionInputs` |
  | `plugin-sdk/command-auth` | 命令门控 | `resolveControlCommandGate` |
  | `plugin-sdk/secret-input` | Secret 输入解析 | Secret 输入辅助 |
  | `plugin-sdk/webhook-ingress` | Webhook 请求辅助 | Webhook 目标工具 |
  | `plugin-sdk/webhook-request-guards` | Webhook 请求体保护辅助 | 请求体读取/限制辅助 |
  | `plugin-sdk/reply-payload` | 消息回复类型 | 回复载荷类型 |
  | `plugin-sdk/provider-onboard` | 提供商新手引导 patch | 新手引导配置辅助 |
  | `plugin-sdk/keyed-async-queue` | 有序异步队列 | `KeyedAsyncQueue` |
  | `plugin-sdk/testing` | 测试工具 | 测试辅助与 mock |
</Accordion>

使用与你工作最匹配的最窄导入路径。如果你找不到某个导出，请查看 `src/plugin-sdk/` 下的源码，或到 Discord 提问。

## 移除时间线

| 时间                  | 会发生什么                                   |
| --------------------- | -------------------------------------------- |
| **现在**              | 废弃接口面会发出运行时警告                   |
| **下一个 major 版本** | 废弃接口面会被移除；仍在使用它们的插件将失败 |

所有核心插件都已完成迁移。外部插件应在下一个 major 版本之前完成迁移。

## 临时抑制警告

在你进行迁移期间，可以设置以下环境变量：

```bash
OPENCLAW_SUPPRESS_PLUGIN_SDK_COMPAT_WARNING=1 openclaw gateway run
OPENCLAW_SUPPRESS_EXTENSION_API_WARNING=1 openclaw gateway run
```

这只是临时逃生通道，不是永久方案。

## 相关内容

- [入门指南](/plugins/building-plugins) — 构建你的第一个插件
- [SDK 概览](/plugins/sdk-overview) — 完整子路径导入参考
- [渠道插件](/plugins/sdk-channel-plugins) — 构建渠道插件
- [提供商插件](/plugins/sdk-provider-plugins) — 构建提供商插件
- [插件内部机制](/plugins/architecture) — 架构深度解析
- [插件清单](/plugins/manifest) — 清单 schema 参考
