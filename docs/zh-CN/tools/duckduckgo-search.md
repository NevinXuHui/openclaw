---
summary: "DuckDuckGo 网页搜索 -- 免密钥回退提供商（实验性，基于 HTML）"
read_when:
  - 你想要无需 API 密钥的网页搜索提供商
  - 你想将 DuckDuckGo 用于 web_search
  - 你需要零配置搜索回退
title: "DuckDuckGo Search"
---

# DuckDuckGo Search

OpenClaw 支持将 DuckDuckGo 作为**免密钥**的 `web_search` 提供商。无需 API
密钥或账户。

<Warning>
  DuckDuckGo 是一个**实验性的非官方**集成，它从 DuckDuckGo 的非 JavaScript
  搜索页面抓取结果，而不是使用官方 API。遇到机器人挑战页面或 HTML 结构变更时，
  可能会偶尔失效。
</Warning>

## 设置

无需 API 密钥 —— 只需将 DuckDuckGo 设为提供商：

<Steps>
  <Step title="配置">
    ```bash
    openclaw configure --section web
    # Select "duckduckgo" as the provider
    ```
  </Step>
</Steps>

## 配置

```json5
{
  tools: {
    web: {
      search: {
        provider: "duckduckgo",
      },
    },
  },
}
```

用于地区和 SafeSearch 的可选插件级设置：

```json5
{
  plugins: {
    entries: {
      duckduckgo: {
        config: {
          webSearch: {
            region: "us-en", // DuckDuckGo region code
            safeSearch: "moderate", // "strict", "moderate", or "off"
          },
        },
      },
    },
  },
}
```

## 工具参数

| 参数         | 说明                                                  |
| ------------ | ----------------------------------------------------- |
| `query`      | 搜索查询（必填）                                      |
| `count`      | 返回结果数量（1-10，默认：5）                         |
| `region`     | DuckDuckGo 地区代码（例如 `us-en`、`uk-en`、`de-de`） |
| `safeSearch` | SafeSearch 级别：`strict`、`moderate`（默认）或 `off` |

`region` 和 `safeSearch` 也可以在插件配置中设置（见上文）——
工具参数会在单次查询中覆盖配置值。

## 说明

- **无需 API 密钥** —— 开箱即用，零配置
- **实验性** —— 从 DuckDuckGo 的非 JavaScript HTML 搜索页收集结果，
  并非官方 API 或 SDK
- **存在机器人挑战风险** —— DuckDuckGo 在高频或自动化使用场景下可能会返回 CAPTCHA
  或直接拦截请求
- **HTML 解析** —— 结果依赖页面结构，而页面结构可能在没有通知的情况下变更
- **自动检测顺序** —— DuckDuckGo 在自动检测中最后检查（顺序 100），因此只要有带 API
  密钥的提供商可用，它们会优先于 DuckDuckGo
- **SafeSearch 在未配置时默认是 `moderate`**

<Tip>
  对于生产场景，建议考虑使用 [Brave Search](/tools/brave-search)
  （提供免费层）或其他基于 API 的提供商。
</Tip>

## 相关内容

- [Web Search 概览](/tools/web) -- 所有提供商与自动检测
- [Brave Search](/tools/brave-search) -- 带免费层的结构化结果
- [Exa Search](/tools/exa-search) -- 带内容提取的神经搜索
