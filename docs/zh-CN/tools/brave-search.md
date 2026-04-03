---
summary: "用于 web_search 的 Brave Search API 设置"
read_when:
  - 你想将 Brave Search 用作 web_search
  - 你需要 BRAVE_API_KEY 或套餐详情
title: "Brave Search"
---

# Brave Search API

OpenClaw 支持将 Brave Search API 作为 `web_search` 提供商。

## 获取 API 密钥

1. 在 [https://brave.com/search/api/](https://brave.com/search/api/) 创建 Brave Search API 账户
2. 在控制台中选择 **Search** 套餐并生成 API 密钥。
3. 将密钥存入配置，或在 Gateway 网关环境中设置 `BRAVE_API_KEY`。

## 配置示例

```json5
{
  plugins: {
    entries: {
      brave: {
        config: {
          webSearch: {
            apiKey: "BRAVE_API_KEY_HERE",
          },
        },
      },
    },
  },
  tools: {
    web: {
      search: {
        provider: "brave",
        maxResults: 5,
        timeoutSeconds: 30,
      },
    },
  },
}
```

Brave 专属搜索设置现在位于 `plugins.entries.brave.config.webSearch.*` 下。
旧的 `tools.web.search.apiKey` 仍会通过兼容层加载，但它已不再是规范配置路径。

## 工具参数

| 参数          | 说明                                                         |
| ------------- | ------------------------------------------------------------ |
| `query`       | 搜索查询（必填）                                             |
| `count`       | 返回结果数量（1-10，默认：5）                                |
| `country`     | 2 位 ISO 国家代码（例如 `"US"`、`"DE"`）                     |
| `language`    | 搜索结果的 ISO 639-1 语言代码（例如 `"en"`、`"de"`、`"fr"`） |
| `ui_lang`     | UI 元素的 ISO 语言代码                                       |
| `freshness`   | 时间过滤：`day`（24 小时）、`week`、`month` 或 `year`        |
| `date_after`  | 仅返回该日期之后发布的结果（YYYY-MM-DD）                     |
| `date_before` | 仅返回该日期之前发布的结果（YYYY-MM-DD）                     |

**示例：**

```javascript
// Country and language-specific search
await web_search({
  query: "renewable energy",
  country: "DE",
  language: "de",
});

// Recent results (past week)
await web_search({
  query: "AI news",
  freshness: "week",
});

// Date range search
await web_search({
  query: "AI developments",
  date_after: "2024-01-01",
  date_before: "2024-06-30",
});
```

## 说明

- OpenClaw 使用 Brave 的 **Search** 套餐。如果你使用旧版订阅（例如最初每月 2,000 次查询的 Free 套餐），它仍然有效，但不包含较新的功能，例如 LLM Context 或更高的速率限制。
- 每个 Brave 套餐都包含**每月 5 美元免费额度**（可续期）。Search 套餐的价格是每 1,000 次请求 5 美元，因此该额度可覆盖每月 1,000 次查询。请在 Brave 控制台中设置使用上限，以避免意外费用。当前套餐信息请参见 [Brave API portal](https://brave.com/search/api/)。
- Search 套餐包含 LLM Context 端点和 AI 推理权限。若要存储结果以训练或微调模型，则需要具备显式存储权限的套餐。详见 Brave 的 [Terms of Service](https://api-dashboard.search.brave.com/terms-of-service)。
- 结果默认缓存 15 分钟（可通过 `cacheTtlMinutes` 配置）。

## 相关内容

- [Web Search 概览](/tools/web) -- 所有提供商与自动检测
- [Perplexity Search](/tools/perplexity-search) -- 带域名过滤的结构化结果
- [Exa Search](/tools/exa-search) -- 带内容提取的神经搜索
