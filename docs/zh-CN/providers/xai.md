---
summary: "在 OpenClaw 中使用 xAI Grok 模型"
read_when:
  - 您想在 OpenClaw 中使用 Grok 模型
  - 您正在配置 xAI 认证或模型 id
title: "xAI"
x-i18n:
  sourceCommit: "latest"
  sourceFile: "providers/xai.md"
---

# xAI

OpenClaw 附带用于 Grok 模型的捆绑 `xai` provider 插件。

## 设置

1. 在 xAI 控制台中创建 API 密钥。
2. 设置 `XAI_API_KEY`，或运行：

```bash
openclaw onboard --auth-choice xai-api-key
```

3. 选择一个模型，例如：

```json5
{
  agents: { defaults: { model: { primary: "xai/grok-4" } } },
}
```

OpenClaw 现在使用 xAI Responses API 作为捆绑的 xAI 传输。相同的 `XAI_API_KEY` 还可以支持 Grok 支持的 `web_search`、一流的 `x_search` 和远程 `code_execution`。
如果您在 `plugins.entries.xai.config.webSearch.apiKey` 下存储 xAI 密钥，捆绑的 xAI 模型 provider 现在也会重用该密钥作为回退。
`code_execution` 调优位于 `plugins.entries.xai.config.codeExecution` 下。

## 当前捆绑模型目录

OpenClaw 现在开箱即用地包含这些 xAI 模型系列：

- `grok-4`、`grok-4-0709`
- `grok-4-fast-reasoning`、`grok-4-fast-non-reasoning`
- `grok-4-1-fast-reasoning`、`grok-4-1-fast-non-reasoning`
- `grok-4.20-reasoning`、`grok-4.20-non-reasoning`
- `grok-code-fast-1`

当它们遵循相同的 API 形状时，插件还会前向解析较新的 `grok-4*` 和 `grok-code-fast*` id。

## 网络搜索

捆绑的 `grok` 网络搜索 provider 也使用 `XAI_API_KEY`：

```bash
openclaw config set tools.web.search.provider grok
```

## 已知限制

- 今天的认证仅限 API 密钥。OpenClaw 中还没有 xAI OAuth/设备代码流程。
- `grok-4.20-multi-agent-experimental-beta-0304` 在正常的 xAI provider 路径上不受支持，因为它需要与标准 OpenClaw xAI 传输不同的上游 API 表面。

## 注意事项

- OpenClaw 在共享运行器路径上自动应用 xAI 特定的工具架构和工具调用兼容性修复。
- `web_search`、`x_search` 和 `code_execution` 作为 OpenClaw 工具公开。OpenClaw 在每个工具请求内启用它需要的特定 xAI 内置功能，而不是将所有原生工具附加到每个聊天回合。
- `x_search` 和 `code_execution` 由捆绑的 xAI 插件拥有，而不是硬编码到核心模型运行时中。
- `code_execution` 是远程 xAI 沙箱执行，而不是本地 [`exec`](/tools/exec)。
- 有关更广泛的 provider 概述，请参阅 [Model providers](/providers/index)。
