---
summary: "使用 Google Search grounding 的 Gemini 网页搜索"
read_when:
  - 你想将 Gemini 用于 web_search
  - 你需要 GEMINI_API_KEY
  - 你想使用 Google Search grounding
title: "Gemini Search"
---

# Gemini Search

OpenClaw 支持使用内置
[Google Search grounding](https://ai.google.dev/gemini-api/docs/grounding) 的 Gemini 模型，
它会基于实时 Google Search 结果返回带引用的 AI 综合答案。

## 获取 API 密钥

<Steps>
  <Step title="创建密钥">
    前往 [Google AI Studio](https://aistudio.google.com/apikey) 创建 API 密钥。
  </Step>
  <Step title="保存密钥">
    在 Gateway 网关环境中设置 `GEMINI_API_KEY`，或通过以下方式配置：

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
      google: {
        config: {
          webSearch: {
            apiKey: "AIza...", // optional if GEMINI_API_KEY is set
            model: "gemini-2.5-flash", // default
          },
        },
      },
    },
  },
  tools: {
    web: {
      search: {
        provider: "gemini",
      },
    },
  },
}
```

**环境变量替代方案：** 在 Gateway 网关环境中设置 `GEMINI_API_KEY`。
对于 Gateway 网关安装，请将其放入 `~/.openclaw/.env`。

## 工作原理

与返回链接和摘要列表的传统搜索提供商不同，
Gemini 使用 Google Search grounding 生成带内联引用的 AI 综合答案。
结果同时包含综合答案和来源 URL。

- 来自 Gemini grounding 的引用 URL 会自动从 Google 跳转链接解析为直链。
- 跳转解析会先经过 SSRF 防护路径（HEAD + 跳转检查 +
  http/https 校验），再返回最终引用 URL。
- 跳转解析使用严格的 SSRF 默认策略，因此跳转到私有 / 内部目标时会被拦截。

## 支持的参数

Gemini 搜索支持标准的 `query` 和 `count` 参数。
不支持 `country`、`language`、`freshness` 和
`domain_filter` 等提供商专属过滤器。

## 模型选择

默认模型为 `gemini-2.5-flash`（速度快且成本较低）。任何支持 grounding 的
Gemini 模型都可通过
`plugins.entries.google.config.webSearch.model` 使用。

## 相关内容

- [Web Search 概览](/tools/web) -- 所有提供商与自动检测
- [Brave Search](/tools/brave-search) -- 带摘要的结构化结果
- [Perplexity Search](/tools/perplexity-search) -- 结构化结果 + 内容提取
