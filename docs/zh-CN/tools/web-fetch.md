---
summary: "web_fetch 工具 -- HTTP 获取与可读内容提取"
read_when:
  - 你想抓取某个 URL 并提取可读内容
  - 你需要配置 web_fetch 或它的 Firecrawl 回退
  - 你想了解 web_fetch 的限制和缓存
title: "Web Fetch"
sidebarTitle: "Web Fetch"
---

# Web Fetch

`web_fetch` 工具会执行普通 HTTP GET，并提取可读内容
（HTML 转 markdown 或 text）。它**不会**执行 JavaScript。

对于 JS 较重的网站或需要登录保护的页面，请改用
[Web Browser](/tools/browser)。

## 快速开始

`web_fetch` **默认启用** —— 无需额外配置。agent 可以立即调用：

```javascript
await web_fetch({ url: "https://example.com/article" });
```

## 工具参数

| 参数          | 类型     | 说明                                    |
| ------------- | -------- | --------------------------------------- |
| `url`         | `string` | 要抓取的 URL（必填，仅支持 http/https） |
| `extractMode` | `string` | `"markdown"`（默认）或 `"text"`         |
| `maxChars`    | `number` | 将输出截断到该字符数                    |

## 工作原理

<Steps>
  <Step title="抓取">
    发送带有类 Chrome User-Agent 和 `Accept-Language` 请求头的 HTTP GET。
    会拦截私有 / 内部主机名，并重新检查跳转目标。
  </Step>
  <Step title="提取">
    对 HTML 响应运行 Readability（主内容提取）。
  </Step>
  <Step title="回退（可选）">
    如果 Readability 失败且已配置 Firecrawl，则通过 Firecrawl API 以反机器人模式重试。
  </Step>
  <Step title="缓存">
    结果会缓存 15 分钟（可配置），以减少对同一 URL 的重复抓取。
  </Step>
</Steps>

## 配置

```json5
{
  tools: {
    web: {
      fetch: {
        enabled: true, // default: true
        maxChars: 50000, // max output chars
        maxCharsCap: 50000, // hard cap for maxChars param
        maxResponseBytes: 2000000, // max download size before truncation
        timeoutSeconds: 30,
        cacheTtlMinutes: 15,
        maxRedirects: 3,
        readability: true, // use Readability extraction
        userAgent: "Mozilla/5.0 ...", // override User-Agent
      },
    },
  },
}
```

## Firecrawl 回退

如果 Readability 提取失败，`web_fetch` 可以回退到
[Firecrawl](/tools/firecrawl)，以获得反机器人能力和更好的提取效果：

```json5
{
  tools: {
    web: {
      fetch: {
        firecrawl: {
          enabled: true,
          apiKey: "fc-...", // optional if FIRECRAWL_API_KEY is set
          baseUrl: "https://api.firecrawl.dev",
          onlyMainContent: true,
          maxAgeMs: 86400000, // cache duration (1 day)
          timeoutSeconds: 60,
        },
      },
    },
  },
}
```

`tools.web.fetch.firecrawl.apiKey` 支持 SecretRef 对象。

<Note>
  如果启用了 Firecrawl，且其 SecretRef 无法解析，同时又没有
  `FIRECRAWL_API_KEY` 环境变量回退，Gateway 网关启动会立即失败。
</Note>

## 限制与安全性

- `maxChars` 会被限制在 `tools.web.fetch.maxCharsCap` 以内
- 响应体在解析前会受 `maxResponseBytes` 限制；超大响应会被截断并附带警告
- 私有 / 内部主机名会被拦截
- 跳转会被检查，并受 `maxRedirects` 限制
- `web_fetch` 采用尽力而为策略 —— 某些站点仍需要使用 [Web Browser](/tools/browser)

## 工具 profile

如果你使用工具 profile 或 allowlist，请加入 `web_fetch` 或 `group:web`：

```json5
{
  tools: {
    allow: ["web_fetch"],
    // or: allow: ["group:web"]  (includes both web_fetch and web_search)
  },
}
```

## 相关内容

- [Web Search](/tools/web) -- 使用多个提供商搜索网页
- [Web Browser](/tools/browser) -- 用于 JS 密集型站点的完整浏览器自动化
- [Firecrawl](/tools/firecrawl) -- Firecrawl 搜索与抓取工具
