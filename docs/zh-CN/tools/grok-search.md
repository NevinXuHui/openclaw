---
summary: "通过 xAI 的网页 grounding 响应进行 Grok 网页搜索"
read_when:
  - 你想将 Grok 用于 web_search
  - 你需要用于网页搜索的 XAI_API_KEY
title: "Grok Search"
---

# Grok Search

OpenClaw 支持将 Grok 作为 `web_search` 提供商，使用 xAI 的网页 grounding
响应生成基于实时搜索结果、带引用的 AI 综合答案。

同一个 `XAI_API_KEY` 也可用于内置的 `x_search` 工具，以搜索 X
（原 Twitter）帖子。如果你将该密钥保存在
`plugins.entries.xai.config.webSearch.apiKey` 下，OpenClaw 现在也会将其复用为
捆绑 xAI 模型提供商的回退密钥。

对于转发数、回复数、书签数或浏览量等帖子级 X 指标，
请优先使用带精确帖子 URL 或状态 ID 的 `x_search`，而不是泛搜索查询。

## 新手引导与配置

如果你在以下流程中选择 **Grok**：

- `openclaw onboard`
- `openclaw configure --section web`

OpenClaw 可以显示单独的后续步骤，以便使用同一个
`XAI_API_KEY` 启用 `x_search`。该后续步骤：

- 仅在你为 `web_search` 选择 Grok 后出现
- 不是单独的顶级 web-search 提供商选项
- 可以在同一流程中可选设置 `x_search` 模型

如果你跳过它，也可以稍后在配置中启用或修改 `x_search`。

## 获取 API 密钥

<Steps>
  <Step title="创建密钥">
    从 [xAI](https://console.x.ai/) 获取 API 密钥。
  </Step>
  <Step title="保存密钥">
    在 Gateway 网关环境中设置 `XAI_API_KEY`，或通过以下方式配置：

    ```bash
    openclaw configure --section web
    ```

  </Step>
</Steps>

## 配置

```json5
{
  plugins: {
    entries: {
      xai: {
        config: {
          webSearch: {
            apiKey: "xai-...", // optional if XAI_API_KEY is set
          },
        },
      },
    },
  },
  tools: {
    web: {
      search: {
        provider: "grok",
      },
    },
  },
}
```

**环境变量替代方案：** 在 Gateway 网关环境中设置 `XAI_API_KEY`。
对于 Gateway 网关安装，请将其放入 `~/.openclaw/.env`。

## 工作原理

Grok 使用 xAI 的网页 grounding 响应生成带内联引用的综合答案，
类似于 Gemini 的 Google Search grounding 方式。

## 支持的参数

Grok 搜索支持标准的 `query` 和 `count` 参数。
目前不支持提供商专属过滤器。

## 相关内容

- [Web Search 概览](/tools/web) -- 所有提供商与自动检测
- [Web Search 中的 x_search](/tools/web#x_search) -- 通过 xAI 提供的一等公民 X 搜索
- [Gemini Search](/tools/gemini-search) -- 通过 Google grounding 提供 AI 综合答案
