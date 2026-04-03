---
title: "Perplexity (Provider)"
summary: "Perplexity 网络搜索 provider 设置（API 密钥、搜索模式、过滤）"
read_when:
  - 您想将 Perplexity 配置为网络搜索 provider
  - 您需要 Perplexity API 密钥或 OpenRouter 代理设置
x-i18n:
  sourceCommit: "latest"
  sourceFile: "providers/perplexity-provider.md"
---

# Perplexity (网络搜索 Provider)

Perplexity 插件通过 Perplexity Search API 或通过 OpenRouter 的 Perplexity Sonar 提供网络搜索功能。

<Note>
本页面涵盖 Perplexity **provider** 设置。有关 Perplexity **工具**（智能体如何使用它），请参阅 [Perplexity tool](/tools/perplexity-search)。
</Note>

- 类型：网络搜索 provider（不是模型 provider）
- 认证：`PERPLEXITY_API_KEY`（直接）或 `OPENROUTER_API_KEY`（通过 OpenRouter）
- 配置路径：`plugins.entries.perplexity.config.webSearch.apiKey`

## 快速入门

1. 设置 API 密钥：

```bash
openclaw configure --section web
```

或直接设置：

```bash
openclaw config set plugins.entries.perplexity.config.webSearch.apiKey "pplx-xxxxxxxxxxxx"
```

2. 配置后，智能体将自动使用 Perplexity 进行网络搜索。

## 搜索模式

插件根据 API 密钥前缀自动选择传输：

| 密钥前缀 | 传输                       | 功能                           |
| -------- | -------------------------- | ------------------------------ |
| `pplx-`  | 原生 Perplexity Search API | 结构化结果、域/语言/日期过滤器 |
| `sk-or-` | OpenRouter (Sonar)         | AI 合成的答案与引用            |

## 原生 API 过滤

使用原生 Perplexity API（`pplx-` 密钥）时，搜索支持：

- **国家**：2 字母国家代码
- **语言**：ISO 639-1 语言代码
- **日期范围**：day、week、month、year
- **域过滤器**：允许列表/拒绝列表（最多 20 个域）
- **内容预算**：`max_tokens`、`max_tokens_per_page`

## 环境注意事项

如果 Gateway 网关作为守护进程运行（launchd/systemd），请确保 `PERPLEXITY_API_KEY` 对该进程可用（例如，在 `~/.openclaw/.env` 中或通过 `env.shellEnv`）。
