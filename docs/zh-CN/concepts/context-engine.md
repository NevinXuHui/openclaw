---
summary: "上下文引擎：可插拔的上下文组装、压缩与子智能体生命周期"
read_when:
  - 你想了解 OpenClaw 如何组装模型上下文
  - 你正在切换 legacy 引擎与插件引擎
  - 你正在构建一个上下文引擎插件
title: "上下文引擎"
---

# 上下文引擎

**上下文引擎** 用于控制 OpenClaw 如何为每次运行构建模型上下文。
它决定包含哪些消息、如何总结较早的历史，以及如何在子智能体边界之间管理上下文。

OpenClaw 内置了一个 `legacy` 引擎。插件可以注册替代引擎，用来替换当前激活的上下文引擎生命周期。

## 快速开始

检查当前激活的是哪个引擎：

```bash
openclaw doctor
# or inspect config directly:
cat ~/.openclaw/openclaw.json | jq '.plugins.slots.contextEngine'
```

### 安装上下文引擎插件

上下文引擎插件与其他 OpenClaw 插件的安装方式相同。先安装，再在 slot 中选择要使用的引擎：

```bash
# Install from npm
openclaw plugins install @martian-engineering/lossless-claw

# Or install from a local path (for development)
openclaw plugins install -l ./my-context-engine
```

然后在配置中启用该插件，并将其选为当前激活的引擎：

```json5
// openclaw.json
{
  plugins: {
    slots: {
      contextEngine: "lossless-claw", // must match the plugin's registered engine id
    },
    entries: {
      "lossless-claw": {
        enabled: true,
        // Plugin-specific config goes here (see the plugin's docs)
      },
    },
  },
}
```

安装并配置完成后，重启 gateway。

如果要切回内置引擎，将 `contextEngine` 设为 `"legacy"` 即可（或者直接删除该键 —— `"legacy"` 是默认值）。

## 工作原理

每次 OpenClaw 运行模型提示时，上下文引擎都会参与以下四个生命周期阶段：

1. **Ingest** —— 当新消息被加入会话时调用。引擎可以将消息存储或索引到自己的数据存储中。
2. **Assemble** —— 每次模型运行前调用。引擎返回一组有序消息（以及可选的 `systemPromptAddition`），这些内容需适配当前 token 预算。
3. **Compact** —— 当上下文窗口已满，或用户执行 `/compact` 时调用。引擎会总结较早历史，以释放空间。
4. **After turn** —— 一次运行完成后调用。引擎可以持久化状态、触发后台压缩或更新索引。

### 子智能体生命周期（可选）

OpenClaw 当前只会调用一个子智能体生命周期钩子：

- **onSubagentEnded** —— 当子智能体会话完成或被清扫时执行清理。

`prepareSubagentSpawn` 已包含在接口中，供未来使用，但当前运行时尚未调用它。

### 系统提示附加内容

`assemble` 方法可以返回一个 `systemPromptAddition` 字符串。OpenClaw 会将其添加到本次运行的系统提示前部。这样，引擎就能注入动态召回指导、检索说明或具备上下文感知的提示，而无需依赖静态工作空间文件。

## legacy 引擎

内置的 `legacy` 引擎会保留 OpenClaw 的原始行为：

- **Ingest**：空操作（消息持久化由会话管理器直接处理）。
- **Assemble**：透传（运行时中的既有 sanitize → validate → limit 流水线负责组装上下文）。
- **Compact**：委托给内置摘要式压缩逻辑，它会为较早消息生成单个摘要，并保留最近消息。
- **After turn**：空操作。

legacy 引擎不会注册工具，也不会提供 `systemPromptAddition`。

当未设置 `plugins.slots.contextEngine`（或设置为 `"legacy"`）时，会自动使用该引擎。

## 插件引擎

插件可以通过插件 API 注册一个上下文引擎：

```ts
export default function register(api) {
  api.registerContextEngine("my-engine", () => ({
    info: {
      id: "my-engine",
      name: "My Context Engine",
      ownsCompaction: true,
    },

    async ingest({ sessionId, message, isHeartbeat }) {
      // Store the message in your data store
      return { ingested: true };
    },

    async assemble({ sessionId, messages, tokenBudget }) {
      // Return messages that fit the budget
      return {
        messages: buildContext(messages, tokenBudget),
        estimatedTokens: countTokens(messages),
        systemPromptAddition: "Use lcm_grep to search history...",
      };
    },

    async compact({ sessionId, force }) {
      // Summarize older context
      return { ok: true, compacted: true };
    },
  }));
}
```

然后在配置中启用：

```json5
{
  plugins: {
    slots: {
      contextEngine: "my-engine",
    },
    entries: {
      "my-engine": {
        enabled: true,
      },
    },
  },
}
```

### `ContextEngine` 接口

必需成员：

| Member             | 类型     | 用途                                          |
| ------------------ | -------- | --------------------------------------------- |
| `info`             | Property | 引擎 id、名称、版本，以及是否自行负责压缩     |
| `ingest(params)`   | Method   | 存储单条消息                                  |
| `assemble(params)` | Method   | 为模型运行构建上下文（返回 `AssembleResult`） |
| `compact(params)`  | Method   | 汇总 / 缩减上下文                             |

`assemble` 返回一个 `AssembleResult`，包含：

- `messages` —— 要发送给模型的有序消息。
- `estimatedTokens`（必填，`number`）—— 引擎对组装后上下文总 token 数的估计。OpenClaw 会用它来判断压缩阈值，并用于诊断报告。
- `systemPromptAddition`（可选，`string`）—— 会被加到系统提示前面。

可选成员：

| Member                         | 类型   | 用途                                                                                 |
| ------------------------------ | ------ | ------------------------------------------------------------------------------------ |
| `bootstrap(params)`            | Method | 为会话初始化引擎状态。在引擎首次看到某个会话时调用（例如导入历史记录）。             |
| `ingestBatch(params)`          | Method | 以批量方式摄取一个完整轮次。会在某次运行完成后调用，并一次性传入该轮次中的所有消息。 |
| `afterTurn(params)`            | Method | 运行结束后的生命周期工作（持久化状态、触发后台压缩）。                               |
| `prepareSubagentSpawn(params)` | Method | 为子会话准备共享状态。                                                               |
| `onSubagentEnded(params)`      | Method | 在子智能体结束后执行清理。                                                           |
| `dispose()`                    | Method | 释放资源。会在 gateway 关闭或插件重载时调用 —— 不是按会话调用。                      |

### `ownsCompaction`

`ownsCompaction` 用于控制 Pi 内置的运行中自动压缩是否在本次运行中保持启用：

- `true` —— 引擎自行负责压缩行为。OpenClaw 会为该次运行禁用 Pi 的内置自动压缩，而引擎自己的 `compact()` 实现需要负责 `/compact`、上下文溢出恢复压缩，以及它希望在 `afterTurn()` 中执行的任何主动压缩。
- `false` 或未设置 —— Pi 的内置自动压缩在提示执行期间仍然可能运行，但活动引擎的 `compact()` 方法仍会在 `/compact` 和上下文溢出恢复时被调用。

`ownsCompaction: false` **并不表示** OpenClaw 会自动回退到 legacy 引擎的压缩路径。

这意味着插件存在两种有效模式：

- **Owning 模式** —— 实现你自己的压缩算法，并设置 `ownsCompaction: true`。
- **Delegating 模式** —— 设置 `ownsCompaction: false`，并在 `compact()` 中调用 `openclaw/plugin-sdk/core` 提供的 `delegateCompactionToRuntime(...)`，从而使用 OpenClaw 内置的压缩行为。

对于一个处于激活状态且不自行负责压缩的引擎而言，空操作 `compact()` 是不安全的，因为它会让该引擎 slot 下正常的 `/compact` 与上下文溢出恢复路径失效。

## 配置参考

```json5
{
  plugins: {
    slots: {
      // Select the active context engine. Default: "legacy".
      // Set to a plugin id to use a plugin engine.
      contextEngine: "legacy",
    },
  },
}
```

该 slot 在运行时是排他的 —— 对于某一次运行或压缩操作，只会解析出一个已注册的上下文引擎。其他已启用的 `kind: "context-engine"` 插件仍然可以加载并执行它们的注册代码；`plugins.slots.contextEngine` 只决定当 OpenClaw 需要上下文引擎时，最终解析哪个已注册的引擎 id。

## 与压缩和记忆的关系

- **压缩** 是上下文引擎的一项职责。legacy 引擎会委托给 OpenClaw 内置的摘要逻辑。插件引擎则可以实现任意压缩策略（DAG 摘要、向量检索等）。
- **记忆插件**（`plugins.slots.memory`）与上下文引擎是独立的。记忆插件提供搜索 / 检索；上下文引擎决定模型最终看到什么。两者可以配合使用 —— 例如某个上下文引擎可以在组装阶段使用记忆插件返回的数据。
- **会话裁剪**（修剪内存中的旧工具结果）无论活动上下文引擎是谁，都会继续执行。

## 提示

- 使用 `openclaw doctor` 验证你的引擎是否正确加载。
- 如果你切换了引擎，现有会话会继续保留各自当前的历史；新引擎只会接管后续运行。
- 引擎错误会被记录并显示在诊断中。如果插件引擎注册失败，或所选引擎 id 无法解析，OpenClaw **不会** 自动回退；在你修复插件或将 `plugins.slots.contextEngine` 切回 `"legacy"` 之前，运行都会失败。
- 开发时，可使用 `openclaw plugins install -l ./my-engine` 直接链接本地插件目录，而无需复制。

另见：[压缩](/concepts/compaction)、[上下文](/concepts/context)、[插件](/tools/plugin)、[插件清单](/plugins/manifest)。

## 相关内容

- [上下文](/concepts/context) — 智能体轮次的上下文是如何构建的
- [插件架构](/plugins/architecture) — 如何注册上下文引擎插件
- [压缩](/concepts/compaction) — 如何总结长对话
