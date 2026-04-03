---
title: "内置记忆引擎"
summary: "默认基于 SQLite 的记忆后端，支持关键词、向量与混合搜索"
read_when:
  - 你想了解默认的记忆后端
  - 你想配置 embedding 提供商或混合搜索
---

# 内置记忆引擎

内置引擎是默认的记忆后端。它会将你的记忆索引存储在按智能体划分的 SQLite 数据库中，无需额外依赖即可开始使用。

## 它提供什么

- **关键词搜索**：通过 FTS5 全文索引（BM25 评分）。
- **向量搜索**：通过任意受支持提供商生成 embeddings。
- **混合搜索**：结合前两者，以获得更好的结果。
- **CJK 支持**：通过 trigram 分词支持中文、日文和韩文。
- **sqlite-vec 加速**：在数据库内执行向量查询（可选）。

## 快速开始

如果你拥有 OpenAI、Gemini、Voyage 或 Mistral 的 API 密钥，内置引擎会自动检测并启用向量搜索。无需额外配置。

如果你想显式指定提供商：

```json5
{
  agents: {
    defaults: {
      memorySearch: {
        provider: "openai",
      },
    },
  },
}
```

如果没有 embedding 提供商，则只能使用关键词搜索。

## 支持的 embedding 提供商

| Provider | ID        | 自动检测   | 说明                           |
| -------- | --------- | ---------- | ------------------------------ |
| OpenAI   | `openai`  | 是         | 默认：`text-embedding-3-small` |
| Gemini   | `gemini`  | 是         | 支持多模态（图像 + 音频）      |
| Voyage   | `voyage`  | 是         |                                |
| Mistral  | `mistral` | 是         |                                |
| Ollama   | `ollama`  | 否         | 本地运行，需显式设置           |
| Local    | `local`   | 是（优先） | GGUF 模型，约需下载 0.6 GB     |

自动检测会按上表顺序选择第一个可解析 API 密钥的提供商。若需覆盖，请设置 `memorySearch.provider`。

## 索引如何工作

OpenClaw 会把 `MEMORY.md` 和 `memory/*.md` 切分为若干块（约 400 个 token，80 个 token 重叠），并将其存储到按智能体划分的 SQLite 数据库中。

- **索引位置：** `~/.openclaw/memory/<agentId>.sqlite`
- **文件监视：** 记忆文件发生变更后，会触发一次带去抖的重新索引（1.5 秒）。
- **自动重建索引：** 当 embedding 提供商、模型或分块配置发生变化时，会自动重建整个索引。
- **按需重建：** `openclaw memory index --force`

<Info>
你也可以通过 `memorySearch.extraPaths` 索引工作空间外部的 Markdown 文件。详见[记忆配置参考](/reference/memory-config#additional-memory-paths)。
</Info>

## 何时使用

对于大多数用户，内置引擎都是合适的选择：

- 开箱即用，无需额外依赖。
- 关键词搜索和向量搜索都表现良好。
- 支持所有 embedding 提供商。
- 混合搜索能够结合两种检索方式的优势。

如果你需要 reranking、query expansion，或希望索引工作空间之外的目录，请考虑切换到 [QMD](/concepts/memory-qmd)。

如果你想要跨会话记忆和自动用户建模，请考虑 [Honcho](/concepts/memory-honcho)。

## 故障排除

**记忆搜索被禁用了？** 请检查 `openclaw memory status`。如果未检测到提供商，请显式设置一个，或添加 API 密钥。

**结果陈旧？** 请运行 `openclaw memory index --force` 进行重建。极少数情况下，监视器可能会漏掉文件变更。

**sqlite-vec 无法加载？** OpenClaw 会自动回退为进程内的余弦相似度计算。请查看日志中的具体加载错误。

## 配置

关于 embedding 提供商设置、混合搜索调优（权重、MMR、时间衰减）、批量索引、多模态记忆、sqlite-vec、额外路径以及其他所有配置项，请参见[记忆配置参考](/reference/memory-config)。
