---
title: "提示词缓存"
summary: "提示词缓存旋钮、合并顺序、provider 行为和调优模式"
read_when:
  - 您想通过缓存保留降低提示词 token 成本
  - 您需要在多智能体设置中实现每个智能体的缓存行为
  - 您正在一起调优心跳和缓存 TTL 修剪
x-i18n:
  sourceCommit: "latest"
  sourceFile: "reference/prompt-caching.md"
---

# 提示词缓存

提示词缓存意味着模型 provider 可以跨回合重用未更改的提示词前缀（通常是系统/开发者指令和其他稳定上下文），而不是每次都重新处理它们。第一个匹配的请求写入缓存 tokens（`cacheWrite`），后续匹配的请求可以读取它们（`cacheRead`）。

为什么这很重要：更低的 token 成本、更快的响应和长期运行会话的更可预测的性能。没有缓存，重复的提示词在每次回合都支付完整的提示词成本，即使大部分输入没有改变。

本页面涵盖影响提示词重用和 token 成本的所有缓存相关旋钮。

有关 Anthropic 定价详细信息，请参阅：
[https://docs.anthropic.com/docs/build-with-claude/prompt-caching](https://docs.anthropic.com/docs/build-with-claude/prompt-caching)

## 主要旋钮

### `cacheRetention`（全局默认、模型和每个智能体）

将缓存保留设置为所有模型的全局默认值：

```yaml
agents:
  defaults:
    params:
      cacheRetention: "long" # none | short | long
```

按模型覆盖：

```yaml
agents:
  defaults:
    models:
      "anthropic/claude-opus-4-6":
        params:
          cacheRetention: "short" # none | short | long
```

每个智能体覆盖：

```yaml
agents:
  list:
    - id: "alerts"
      params:
        cacheRetention: "none"
```

配置合并顺序：

1. `agents.defaults.params`（全局默认 — 适用于所有模型）
2. `agents.defaults.models["provider/model"].params`（每个模型覆盖）
3. `agents.list[].params`（匹配智能体 id；按键覆盖）

### 旧版 `cacheControlTtl`

旧版值仍然被接受并映射：

- `5m` -> `short`
- `1h` -> `long`

对于新配置，优先使用 `cacheRetention`。

### `contextPruning.mode: "cache-ttl"`

在缓存 TTL 窗口后修剪旧的工具结果上下文，以便空闲后请求不会重新缓存过大的历史记录。

```yaml
agents:
  defaults:
    contextPruning:
      mode: "cache-ttl"
      ttl: "1h"
```

有关完整行为，请参阅 [Session Pruning](/concepts/session-pruning)。

### 心跳保持温暖

心跳可以保持缓存窗口温暖，并减少空闲间隙后的重复缓存写入。

```yaml
agents:
  defaults:
    heartbeat:
      every: "55m"
```

在 `agents.list[].heartbeat` 支持每个智能体的心跳。

## Provider 行为

### Anthropic（直接 API）

- 支持 `cacheRetention`。
- 使用 Anthropic API 密钥认证配置文件时，当未设置时，OpenClaw 为 Anthropic 模型引用设置 `cacheRetention: "short"`。

### Amazon Bedrock

- Anthropic Claude 模型引用（`amazon-bedrock/*anthropic.claude*`）支持显式 `cacheRetention` 传递。
- 非 Anthropic Bedrock 模型在运行时被强制为 `cacheRetention: "none"`。

### OpenRouter Anthropic 模型

对于 `openrouter/anthropic/*` 模型引用，OpenClaw 在系统/开发者提示词块上注入 Anthropic `cache_control`，以改善提示词缓存重用。

### 其他 providers

如果 provider 不支持此缓存模式，`cacheRetention` 无效。

## 调优模式

### 混合流量（推荐默认）

在您的主智能体上保持长期基线，在突发通知智能体上禁用缓存：

```yaml
agents:
  defaults:
    model:
      primary: "anthropic/claude-opus-4-6"
    models:
      "anthropic/claude-opus-4-6":
        params:
          cacheRetention: "long"
  list:
    - id: "research"
      default: true
      heartbeat:
        every: "55m"
    - id: "alerts"
      params:
        cacheRetention: "none"
```

### 成本优先基线

- 设置基线 `cacheRetention: "short"`。
- 启用 `contextPruning.mode: "cache-ttl"`。
- 仅对从温暖缓存中受益的智能体保持心跳低于您的 TTL。

## 缓存诊断

OpenClaw 为嵌入式智能体运行公开专用的缓存跟踪诊断。

### `diagnostics.cacheTrace` 配置

```yaml
diagnostics:
  cacheTrace:
    enabled: true
    filePath: "~/.openclaw/logs/cache-trace.jsonl" # 可选
    includeMessages: false # 默认 true
    includePrompt: false # 默认 true
    includeSystem: false # 默认 true
```

默认值：

- `filePath`：`$OPENCLAW_STATE_DIR/logs/cache-trace.jsonl`
- `includeMessages`：`true`
- `includePrompt`：`true`
- `includeSystem`：`true`

### 环境变量切换（一次性调试）

- `OPENCLAW_CACHE_TRACE=1` 启用缓存跟踪。
- `OPENCLAW_CACHE_TRACE_FILE=/path/to/cache-trace.jsonl` 覆盖输出路径。
- `OPENCLAW_CACHE_TRACE_MESSAGES=0|1` 切换完整消息有效负载捕获。
- `OPENCLAW_CACHE_TRACE_PROMPT=0|1` 切换提示词文本捕获。
- `OPENCLAW_CACHE_TRACE_SYSTEM=0|1` 切换系统提示词捕获。

### 要检查的内容

- 缓存跟踪事件是 JSONL，包括分阶段快照，如 `session:loaded`、`prompt:before`、`stream:context` 和 `session:after`。
- 每回合缓存 token 影响通过 `cacheRead` 和 `cacheWrite` 在正常使用表面中可见（例如 `/usage full` 和会话使用摘要）。

## 快速故障排除

- 大多数回合的高 `cacheWrite`：检查易变的系统提示词输入，并验证模型/provider 支持您的缓存设置。
- `cacheRetention` 无效：确认模型键匹配 `agents.defaults.models["provider/model"]`。
- 带有缓存设置的 Bedrock Nova/Mistral 请求：预期运行时强制为 `none`。

相关文档：

- [Anthropic](/providers/anthropic)
- [Token Use and Costs](/reference/token-use)
- [Session Pruning](/concepts/session-pruning)
- [Gateway Configuration Reference](/gateway/configuration-reference)
