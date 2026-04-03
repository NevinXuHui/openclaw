---
summary: "SearXNG 网页搜索 -- 自托管、免密钥的元搜索提供商"
read_when:
  - 你想要自托管的网页搜索提供商
  - 你想将 SearXNG 用于 web_search
  - 你需要注重隐私或适合 air-gapped 环境的搜索选项
title: "SearXNG Search"
---

# SearXNG Search

OpenClaw 支持将 [SearXNG](https://docs.searxng.org/) 作为**自托管、免密钥**的 `web_search` 提供商。SearXNG 是一个开源元搜索引擎，可聚合来自 Google、Bing、DuckDuckGo 等来源的结果。

优势：

- **免费且无限制** —— 无需 API 密钥或商业订阅
- **隐私 / air-gap** —— 查询不会离开你的网络
- **任何地方都可用** —— 不受商业搜索 API 的地域限制

## 设置

<Steps>
  <Step title="运行一个 SearXNG 实例">
    ```bash
    docker run -d -p 8888:8080 searxng/searxng
    ```

    也可以使用你已有访问权限的任意 SearXNG 部署。生产环境部署请参见
    [SearXNG documentation](https://docs.searxng.org/)。

  </Step>
  <Step title="配置">
    ```bash
    openclaw configure --section web
    # Select "searxng" as the provider
    ```

    或设置环境变量，让自动检测发现它：

    ```bash
    export SEARXNG_BASE_URL="http://localhost:8888"
    ```

  </Step>
</Steps>

## 配置

```json5
{
  tools: {
    web: {
      search: {
        provider: "searxng",
      },
    },
  },
}
```

SearXNG 实例的插件级设置：

```json5
{
  plugins: {
    entries: {
      searxng: {
        config: {
          webSearch: {
            baseUrl: "http://localhost:8888",
            categories: "general,news", // optional
            language: "en", // optional
          },
        },
      },
    },
  },
}
```

`baseUrl` 字段也接受 SecretRef 对象。

## 环境变量

可将 `SEARXNG_BASE_URL` 作为配置替代方式：

```bash
export SEARXNG_BASE_URL="http://localhost:8888"
```

当设置了 `SEARXNG_BASE_URL` 且未显式配置提供商时，自动检测会自动选择 SearXNG（优先级最低 —— 任何带 API 密钥的提供商都会优先命中）。

## 插件配置参考

| 字段         | 说明                                                |
| ------------ | --------------------------------------------------- |
| `baseUrl`    | SearXNG 实例的基础 URL（必填）                      |
| `categories` | 逗号分隔的分类，例如 `general`、`news` 或 `science` |
| `language`   | 结果语言代码，例如 `en`、`de` 或 `fr`               |

## 说明

- **JSON API** —— 使用 SearXNG 原生 `format=json` 端点，而不是 HTML 抓取
- **无需 API 密钥** —— 对任何 SearXNG 实例都能开箱即用
- **自动检测顺序** —— SearXNG 在自动检测中最后检查（顺序 200），因此任何带 API 密钥的提供商都会优先于 SearXNG，DuckDuckGo（顺序 100）也会优先于它
- **自托管** —— 由你掌控实例、查询和上游搜索引擎
- **未配置时 `categories` 默认为 `general`**

<Tip>
  为了让 SearXNG JSON API 正常工作，请确认你的 SearXNG 实例已在其 `settings.yml` 的 `search.formats` 中启用 `json` 格式。
</Tip>

## 相关内容

- [Web Search 概览](/tools/web) -- 所有提供商与自动检测
- [DuckDuckGo Search](/tools/duckduckgo-search) -- 另一个免密钥回退选项
- [Brave Search](/tools/brave-search) -- 带免费层的结构化结果
