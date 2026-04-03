---
summary: "Exa AI 搜索 -- 带内容提取的神经搜索与关键词搜索"
read_when:
  - 你想将 Exa 用于 web_search
  - 你需要 EXA_API_KEY
  - 你想使用神经搜索或内容提取
title: "Exa Search"
---

# Exa Search

OpenClaw 支持将 [Exa AI](https://exa.ai/) 作为 `web_search` 提供商。Exa
提供神经搜索、关键词搜索和混合搜索模式，并内置内容提取能力
（highlights、text、summaries）。

## 获取 API 密钥

<Steps>
  <Step title="创建账户">
    在 [exa.ai](https://exa.ai/) 注册，并在控制台中生成 API 密钥。
  </Step>
  <Step title="保存密钥">
    在 Gateway 网关环境中设置 `EXA_API_KEY`，或通过以下方式配置：

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
      exa: {
        config: {
          webSearch: {
            apiKey: "exa-...", // optional if EXA_API_KEY is set
          },
        },
      },
    },
  },
  tools: {
    web: {
      search: {
        provider: "exa",
      },
    },
  },
}
```

**环境变量替代方案：** 在 Gateway 网关环境中设置 `EXA_API_KEY`。
对于 Gateway 网关安装，请将其放入 `~/.openclaw/.env`。

## 工具参数

| 参数          | 说明                                                                      |
| ------------- | ------------------------------------------------------------------------- |
| `query`       | 搜索查询（必填）                                                          |
| `count`       | 返回结果数量（1-100）                                                     |
| `type`        | 搜索模式：`auto`、`neural`、`fast`、`deep`、`deep-reasoning` 或 `instant` |
| `freshness`   | 时间过滤：`day`、`week`、`month` 或 `year`                                |
| `date_after`  | 返回该日期之后的结果（YYYY-MM-DD）                                        |
| `date_before` | 返回该日期之前的结果（YYYY-MM-DD）                                        |
| `contents`    | 内容提取选项（见下文）                                                    |

### 内容提取

Exa 可以在搜索结果中一并返回提取出的内容。传入 `contents`
对象即可启用：

```javascript
await web_search({
  query: "transformer architecture explained",
  type: "neural",
  contents: {
    text: true, // full page text
    highlights: { numSentences: 3 }, // key sentences
    summary: true, // AI summary
  },
});
```

| Contents 选项 | 类型                                                                  | 说明         |
| ------------- | --------------------------------------------------------------------- | ------------ |
| `text`        | `boolean \| { maxCharacters }`                                        | 提取整页文本 |
| `highlights`  | `boolean \| { maxCharacters, query, numSentences, highlightsPerUrl }` | 提取关键句   |
| `summary`     | `boolean \| { query }`                                                | AI 生成摘要  |

### 搜索模式

| 模式             | 说明                         |
| ---------------- | ---------------------------- |
| `auto`           | Exa 自动选择最佳模式（默认） |
| `neural`         | 语义 / 含义驱动搜索          |
| `fast`           | 快速关键词搜索               |
| `deep`           | 更彻底的深度搜索             |
| `deep-reasoning` | 带推理能力的深度搜索         |
| `instant`        | 最快返回结果                 |

## 说明

- 如果未提供 `contents` 选项，Exa 默认使用 `{ highlights: true }`，
  因此结果会包含关键句摘录
- 当 Exa API 响应中存在 `highlightScores` 和 `summary` 字段时，结果会保留这些字段
- 结果描述的解析顺序为：highlights 优先，其次 summary，最后是全文文本 ——
  使用其中可用的一项
- `freshness` 与 `date_after` / `date_before` 不能同时使用 ——
  请只选一种时间过滤模式
- 单次查询最多可返回 100 条结果（受 Exa 搜索类型限制）
- 结果默认缓存 15 分钟（可通过 `cacheTtlMinutes` 配置）
- Exa 是官方 API 集成，返回结构化 JSON 响应

## 相关内容

- [Web Search 概览](/tools/web) -- 所有提供商与自动检测
- [Brave Search](/tools/brave-search) -- 带国家 / 语言过滤的结构化结果
- [Perplexity Search](/tools/perplexity-search) -- 带域名过滤的结构化结果
