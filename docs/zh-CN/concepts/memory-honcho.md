---
title: "Honcho 记忆"
summary: "通过 Honcho 插件提供 AI 原生的跨会话记忆"
read_when:
  - 你想要可跨会话和跨渠道工作的持久记忆
  - 你想要 AI 驱动的回忆能力和用户建模
---

# Honcho 记忆

[Honcho](https://honcho.dev) 为 OpenClaw 增加了 AI 原生记忆。它会将对话持久化到专用服务中，并随着时间推移构建用户和智能体模型，为你的智能体提供超出工作空间 Markdown 文件范围的跨会话上下文。

## 它提供什么

- **跨会话记忆** —— 每轮对话后都会持久化，因此上下文可以跨会话重置、压缩和渠道切换继续保留。
- **用户建模** —— Honcho 会为每个用户维护资料（偏好、事实、沟通风格），并为智能体维护资料（个性、学到的行为）。
- **语义搜索** —— 可以搜索过去对话中提炼出的观察结果，而不只是当前会话。
- **多智能体感知** —— 父智能体会自动跟踪新启动的子智能体，并将父智能体作为观察者加入子会话。

## 可用工具

Honcho 会注册一组工具，供智能体在对话期间使用：

**数据检索（快速，无需 LLM 调用）：**

| Tool                        | 作用                                   |
| --------------------------- | -------------------------------------- |
| `honcho_context`            | 获取跨会话的完整用户表示               |
| `honcho_search_conclusions` | 对已存储结论进行语义搜索               |
| `honcho_search_messages`    | 跨会话查找消息（可按发送者、日期过滤） |
| `honcho_session`            | 获取当前会话历史和摘要                 |

**问答（LLM 驱动）：**

| Tool         | 作用                                                                                |
| ------------ | ----------------------------------------------------------------------------------- |
| `honcho_ask` | 向 Honcho 询问关于用户的问题。`depth='quick'` 用于查事实，`'thorough'` 用于综合分析 |

## 快速开始

安装插件并运行设置：

```bash
openclaw plugins install @honcho-ai/openclaw-honcho
openclaw honcho setup
openclaw gateway --force
```

设置命令会提示你输入 API 凭据、写入配置，并可选择迁移现有的工作空间记忆文件。

<Info>
Honcho 可以完全本地运行（自托管），也可以使用托管 API `api.honcho.dev`。自托管方案不需要任何外部依赖。
</Info>

## 配置

设置位于 `plugins.entries["openclaw-honcho"].config` 下：

```json5
{
  plugins: {
    entries: {
      "openclaw-honcho": {
        config: {
          apiKey: "your-api-key", // omit for self-hosted
          workspaceId: "openclaw", // memory isolation
          baseUrl: "https://api.honcho.dev",
        },
      },
    },
  },
}
```

对于自托管实例，将 `baseUrl` 指向你的本地服务器（例如 `http://localhost:8000`），并省略 API key。

## 迁移现有记忆

如果你已经有工作空间记忆文件（`USER.md`、`MEMORY.md`、`IDENTITY.md`、`memory/`、`canvas/`），`openclaw honcho setup` 会检测它们并提示是否迁移。

<Info>
迁移是非破坏性的 —— 文件会上传到 Honcho。原始文件绝不会被删除或移动。
</Info>

## 工作原理

每次 AI 回合结束后，对话都会被持久化到 Honcho。用户消息和智能体消息都会被观察，从而让 Honcho 能持续构建和完善其模型。

在对话过程中，Honcho 工具会在 `before_prompt_build` 阶段查询服务，并在模型看到提示词前注入相关上下文。这可以确保回合边界准确，并且召回内容更相关。

## Honcho 与内置记忆的区别

|              | 内置 / QMD               | Honcho                 |
| ------------ | ------------------------ | ---------------------- |
| **存储**     | 工作空间 Markdown 文件   | 专用服务（本地或托管） |
| **跨会话**   | 通过记忆文件实现         | 自动，内置支持         |
| **用户建模** | 手动（写入 `MEMORY.md`） | 自动生成资料           |
| **搜索**     | 向量 + 关键词（混合）    | 基于观察结果的语义搜索 |
| **多智能体** | 不跟踪                   | 具备父子智能体感知     |
| **依赖**     | 无（内置）或 QMD 二进制  | 需要安装插件           |

Honcho 和内置记忆系统可以一起使用。配置了 QMD 后，会额外提供工具，用于搜索本地 Markdown 文件，同时结合 Honcho 的跨会话记忆能力。

## CLI 命令

```bash
openclaw honcho setup                        # Configure API key and migrate files
openclaw honcho status                       # Check connection status
openclaw honcho ask <question>               # Query Honcho about the user
openclaw honcho search <query> [-k N] [-d D] # Semantic search over memory
```

## 延伸阅读

- [插件源码](https://github.com/plastic-labs/openclaw-honcho)
- [Honcho 文档](https://docs.honcho.dev)
- [Honcho OpenClaw 集成指南](https://docs.honcho.dev/v3/guides/integrations/openclaw)
- [记忆](/concepts/memory) —— OpenClaw 记忆概览
- [上下文引擎](/concepts/context-engine) —— 插件上下文引擎的工作方式
