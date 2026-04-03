---
summary: "Tavily 搜索与提取工具"
read_when:
  - 你想使用 Tavily 驱动的网页搜索
  - 你需要 Tavily API 密钥
  - 你想将 Tavily 作为 web_search 提供商
  - 你想从 URL 提取内容
title: "Tavily"
---

# Tavily

OpenClaw 可以通过两种方式使用 **Tavily**：

- 作为 `web_search` 提供商
- 作为显式插件工具：`tavily_search` 和 `tavily_extract`

Tavily 是一个为 AI 应用设计的搜索 API，返回面向 LLM 消费优化的结构化结果。它支持可配置的搜索深度、主题过滤、域名过滤、AI 生成答案摘要，以及从 URL 提取内容（包括 JavaScript 渲染页面）。

## 获取 API 密钥

1. 在 [tavily.com](https://tavily.com/) 创建 Tavily 账户。
2. 在控制台中生成 API 密钥。
3. 将其存入配置，或在 Gateway 网关环境中设置 `TAVILY_API_KEY`。

## 配置 Tavily 搜索

```json5
{
  plugins: {
    entries: {
      tavily: {
        enabled: true,
        config: {
          webSearch: {
            apiKey: "tvly-...", // optional if TAVILY_API_KEY is set
            baseUrl: "https://api.tavily.com",
          },
        },
      },
    },
  },
  tools: {
    web: {
      search: {
        provider: "tavily",
      },
    },
  },
}
```

说明：

- 在新手引导中选择 Tavily，或运行 `openclaw configure --section web` 选择 Tavily 时，会自动启用捆绑的 Tavily 插件。
- Tavily 配置应存放在 `plugins.entries.tavily.config.webSearch.*` 下。
- 使用 Tavily 的 `web_search` 支持 `query` 和 `count`（最多 20 条结果）。
- 如果你需要 `search_depth`、`topic`、`include_answer` 或域名过滤等 Tavily 专属控制项，请使用 `tavily_search`。

## Tavily 插件工具

### `tavily_search`

当你需要 Tavily 专属搜索控制，而不是通用 `web_search` 时，请使用它。

| 参数              | 说明                                                     |
| ----------------- | -------------------------------------------------------- |
| `query`           | 搜索查询字符串（保持在 400 字符以内）                    |
| `search_depth`    | `basic`（默认，平衡）或 `advanced`（相关性最高，但更慢） |
| `topic`           | `general`（默认）、`news`（实时更新）或 `finance`        |
| `max_results`     | 返回结果数量，1-20（默认：5）                            |
| `include_answer`  | 是否包含 AI 生成的答案摘要（默认：false）                |
| `time_range`      | 按新鲜度过滤：`day`、`week`、`month` 或 `year`           |
| `include_domains` | 用于限制结果来源的域名数组                               |
| `exclude_domains` | 用于排除结果来源的域名数组                               |

**搜索深度：**

| 深度       | 速度 | 相关性 | 适用场景                     |
| ---------- | ---- | ------ | ---------------------------- |
| `basic`    | 更快 | 高     | 通用查询（默认）             |
| `advanced` | 更慢 | 最高   | 高精度、具体事实、研究型查询 |

### `tavily_extract`

当你需要从一个或多个 URL 中提取干净内容时，请使用它。它可以处理 JavaScript 渲染页面，并支持基于查询的分块重排，以便有针对性地提取内容。

| 参数                | 说明                                                       |
| ------------------- | ---------------------------------------------------------- |
| `urls`              | 待提取的 URL 数组（每次请求 1-20 个）                      |
| `query`             | 按与该查询的相关性对提取出的内容块重新排序                 |
| `extract_depth`     | `basic`（默认，较快）或 `advanced`（适用于 JS 较重的页面） |
| `chunks_per_source` | 每个 URL 返回的内容块数量，1-5（需要 `query`）             |
| `include_images`    | 是否在结果中包含图片 URL（默认：false）                    |

**提取深度：**

| 深度       | 何时使用                      |
| ---------- | ----------------------------- |
| `basic`    | 简单页面 —— 先从这里开始      |
| `advanced` | JS 渲染的 SPA、动态内容、表格 |

提示：

- 每次请求最多 20 个 URL。更大的列表请拆分成多次调用。
- 使用 `query` + `chunks_per_source` 可以只获取相关内容，而不是整页全文。
- 先尝试 `basic`；如果内容缺失或不完整，再切换到 `advanced`。

## 选择正确的工具

| 需求                         | 工具             |
| ---------------------------- | ---------------- |
| 快速网页搜索，不需要特殊选项 | `web_search`     |
| 带深度、主题和 AI 答案的搜索 | `tavily_search`  |
| 从特定 URL 提取内容          | `tavily_extract` |

## 相关内容

- [Web Search 概览](/tools/web) -- 所有提供商与自动检测
- [Firecrawl](/tools/firecrawl) -- 带内容提取的搜索 + 抓取
- [Exa Search](/tools/exa-search) -- 带内容提取的神经搜索
