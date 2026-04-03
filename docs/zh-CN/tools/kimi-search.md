---
summary: "通过 Moonshot web search 使用 Kimi 网页搜索"
read_when:
  - 你想将 Kimi 用于 web_search
  - 你需要 KIMI_API_KEY 或 MOONSHOT_API_KEY
title: "Kimi Search"
---

# Kimi Search

OpenClaw 支持将 Kimi 作为 `web_search` 提供商，使用 Moonshot web search
生成带引用的 AI 综合答案。

## 获取 API 密钥

<Steps>
  <Step title="创建密钥">
    从 [Moonshot AI](https://platform.moonshot.cn/) 获取 API 密钥。
  </Step>
  <Step title="保存密钥">
    在 Gateway 网关环境中设置 `KIMI_API_KEY` 或 `MOONSHOT_API_KEY`，或
    通过以下方式配置：

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
      moonshot: {
        config: {
          webSearch: {
            apiKey: "sk-...", // optional if KIMI_API_KEY or MOONSHOT_API_KEY is set
          },
        },
      },
    },
  },
  tools: {
    web: {
      search: {
        provider: "kimi",
      },
    },
  },
}
```

**环境变量替代方案：** 在 Gateway 网关环境中设置 `KIMI_API_KEY` 或 `MOONSHOT_API_KEY`。对于 Gateway 网关安装，请将其放入 `~/.openclaw/.env`。

## 工作原理

Kimi 使用 Moonshot web search 生成带内联引用的综合答案，
类似于 Gemini 与 Grok 的 grounding 响应方式。

## 支持的参数

Kimi 搜索支持标准的 `query` 和 `count` 参数。
目前不支持提供商专属过滤器。

## 相关内容

- [Web Search 概览](/tools/web) -- 所有提供商与自动检测
- [Gemini Search](/tools/gemini-search) -- 通过 Google grounding 提供 AI 综合答案
- [Grok Search](/tools/grok-search) -- 通过 xAI grounding 提供 AI 综合答案
