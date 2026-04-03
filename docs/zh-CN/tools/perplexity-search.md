---
summary: "Perplexity Search API 与 Sonar / OpenRouter 兼容路径，用于 web_search"
read_when:
  - 你想将 Perplexity Search 用于网页搜索
  - 你需要配置 PERPLEXITY_API_KEY 或 OPENROUTER_API_KEY
title: "Perplexity Search"
---

# Perplexity Search API

OpenClaw 支持将 Perplexity Search API 作为 `web_search` 提供商。
它会返回带有 `title`、`url` 和 `snippet` 字段的结构化结果。

为了兼容性，OpenClaw 也支持旧版的 Perplexity Sonar / OpenRouter 配置。
如果你使用 `OPENROUTER_API_KEY`、在 `plugins.entries.perplexity.config.webSearch.apiKey` 中设置 `sk-or-...` 密钥，或设置 `plugins.entries.perplexity.config.webSearch.baseUrl` / `model`，提供商就会切换到 chat-completions 路径，并返回带引用的 AI 综合答案，而不是结构化 Search API 结果。

## 获取 Perplexity API 密钥

1. 在 [perplexity.ai/settings/api](https://www.perplexity.ai/settings/api) 创建 Perplexity 账户
2. 在控制台中生成 API 密钥
3. 将其存入配置，或在 Gateway 网关环境中设置 `PERPLEXITY_API_KEY`。

## OpenRouter 兼容性

如果你已经通过 OpenRouter 使用过 Perplexity Sonar，请继续保留 `provider: "perplexity"`，并在 Gateway 网关环境中设置 `OPENROUTER_API_KEY`，或将 `sk-or-...` 密钥存入 `plugins.entries.perplexity.config.webSearch.apiKey`。

可选兼容控制项：

- `plugins.entries.perplexity.config.webSearch.baseUrl`
- `plugins.entries.perplexity.config.webSearch.model`

## 配置示例

### 原生 Perplexity Search API

```json5
{
  plugins: {
    entries: {
      perplexity: {
        config: {
          webSearch: {
            apiKey: "pplx-...",
          },
        },
      },
    },
  },
  tools: {
    web: {
      search: {
        provider: "perplexity",
      },
    },
  },
}
```

### OpenRouter / Sonar 兼容路径

```json5
{
  plugins: {
    entries: {
      perplexity: {
        config: {
          webSearch: {
            apiKey: "<openrouter-api-key>",
            baseUrl: "https://openrouter.ai/api/v1",
            model: "perplexity/sonar-pro",
          },
        },
      },
    },
  },
  tools: {
    web: {
      search: {
        provider: "perplexity",
      },
    },
  },
}
```

## 在哪里设置密钥

**通过配置：** 运行 `openclaw configure --section web`。它会将密钥写入
`~/.openclaw/openclaw.json` 中的 `plugins.entries.perplexity.config.webSearch.apiKey`。
该字段也接受 SecretRef 对象。

**通过环境变量：** 在 Gateway 网关进程环境中设置 `PERPLEXITY_API_KEY` 或 `OPENROUTER_API_KEY`。
对于 Gateway 网关安装，请将其放入 `~/.openclaw/.env`（或你的服务环境）。参见 [Env vars](/help/faq#env-vars-and-env-loading)。

如果已配置 `provider: "perplexity"`，而 Perplexity 密钥的 SecretRef 无法解析，且又没有环境变量回退，启动 / 重载会立即失败。

## 工具参数

这些参数适用于原生 Perplexity Search API 路径。

| 参数                  | 说明                                                  |
| --------------------- | ----------------------------------------------------- |
| `query`               | 搜索查询（必填）                                      |
| `count`               | 返回结果数量（1-10，默认：5）                         |
| `country`             | 2 位 ISO 国家代码（例如 `"US"`、`"DE"`）              |
| `language`            | ISO 639-1 语言代码（例如 `"en"`、`"de"`、`"fr"`）     |
| `freshness`           | 时间过滤：`day`（24 小时）、`week`、`month` 或 `year` |
| `date_after`          | 仅返回该日期之后发布的结果（YYYY-MM-DD）              |
| `date_before`         | 仅返回该日期之前发布的结果（YYYY-MM-DD）              |
| `domain_filter`       | 域名 allowlist / denylist 数组（最多 20 个）          |
| `max_tokens`          | 总内容预算（默认：25000，最大：1000000）              |
| `max_tokens_per_page` | 每页 token 上限（默认：2048）                         |

对于旧版 Sonar / OpenRouter 兼容路径，只支持 `query` 与 `freshness`。
`country`、`language`、`date_after`、`date_before`、`domain_filter`、`max_tokens` 和 `max_tokens_per_page` 等 Search API 专属过滤器会返回明确错误。

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

// Domain filtering (allowlist)
await web_search({
  query: "climate research",
  domain_filter: ["nature.com", "science.org", ".edu"],
});

// Domain filtering (denylist - prefix with -)
await web_search({
  query: "product reviews",
  domain_filter: ["-reddit.com", "-pinterest.com"],
});

// More content extraction
await web_search({
  query: "detailed AI research",
  max_tokens: 50000,
  max_tokens_per_page: 4096,
});
```

### Domain filter 规则

- 每次过滤最多 20 个域名
- 同一次请求中不能混用 allowlist 与 denylist
- denylist 条目使用 `-` 前缀（例如 `[`"-reddit.com"`]`）

## 说明

- Perplexity Search API 返回结构化网页搜索结果（`title`、`url`、`snippet`）
- 使用 OpenRouter，或显式设置 `plugins.entries.perplexity.config.webSearch.baseUrl` / `model`，会让 Perplexity 回到 Sonar chat completions 兼容路径
- 结果默认缓存 15 分钟（可通过 `cacheTtlMinutes` 配置）

## 相关内容

- [Web Search 概览](/tools/web) -- 所有提供商与自动检测
- [Perplexity Search API docs](https://docs.perplexity.ai/docs/search/quickstart) -- 官方 Perplexity 文档
- [Brave Search](/tools/brave-search) -- 带国家 / 语言过滤的结构化结果
- [Exa Search](/tools/exa-search) -- 带内容提取的神经搜索
