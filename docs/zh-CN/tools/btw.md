---
summary: "使用 /btw 提出临时的旁支问题"
read_when:
  - 你想针对当前会话提出一个快速的旁支问题
  - 你正在实现或调试各客户端中的 BTW 行为
title: "BTW 旁支问题"
---

# BTW 旁支问题

`/btw` 让你可以针对**当前会话**提出一个快速的旁支问题，而不会把这个问题写入普通会话历史。

它参考了 Claude Code 的 `/btw` 行为，但适配到了 OpenClaw 的 Gateway 网关与多渠道架构中。

## 它会做什么

当你发送：

```text
/btw what changed?
```

OpenClaw 会：

1. 快照当前会话上下文，
2. 发起一次单独的**无工具**模型调用，
3. 只回答这个旁支问题，
4. 不影响主运行，
5. **不会**把 BTW 问题或回答写入会话历史，
6. 将回答作为**实时侧边结果**发出，而不是普通 assistant 消息。

需要记住的核心模型是：

- 共享同一个会话上下文
- 但这是一次独立的一次性旁支查询
- 不调用工具
- 不污染未来上下文
- 不写入转录持久化

## 它不会做什么

`/btw` **不会**：

- 创建新的持久会话，
- 继续尚未完成的主任务，
- 运行工具或 agent 工具循环，
- 将 BTW 问题 / 回答写入 transcript 历史，
- 出现在 `chat.history` 中，
- 在重载后继续存在。

它被有意设计为**临时的（ephemeral）**。

## 上下文如何工作

BTW 将当前会话仅作为**背景上下文**使用。

如果主运行当前仍在进行中，OpenClaw 会对当前消息状态进行快照，并将正在进行的主提示词作为背景上下文一并包含，同时明确告知模型：

- 只回答旁支问题，
- 不要恢复或完成未完成的主任务，
- 不要发出工具调用或伪工具调用。

这样既让 BTW 与主运行隔离，又能让它理解当前会话在做什么。

## 传递模型

BTW **不会**以普通 assistant transcript 消息的形式投递。

在 Gateway 网关协议层：

- 普通 assistant 聊天使用 `chat` 事件
- BTW 使用 `chat.side_result` 事件

这种分离是有意为之。如果 BTW 复用普通 `chat` 事件路径，客户端就会把它当作常规会话历史。

因为 BTW 使用单独的实时事件，且不会从 `chat.history` 回放，所以在重载后它会消失。

## 表面行为

### TUI

在 TUI 中，BTW 会以内联方式显示在当前会话视图中，但它仍然是临时的：

- 与普通 assistant 回复在视觉上有明显区别
- 可通过 `Enter` 或 `Esc` 关闭
- 重载后不会回放

### 外部渠道

在 Telegram、WhatsApp 和 Discord 等渠道上，BTW 会以明确标记的一次性回复形式发送，因为这些表面没有本地临时覆盖层的概念。

这条回答仍会被视为 side result，而不是正常的会话历史。

### Control UI / web

Gateway 网关已经会正确地将 BTW 发为 `chat.side_result`，且 BTW 不会出现在 `chat.history` 中，因此 Web 端的持久化契约已经是正确的。

当前的 Control UI 仍需要专门的 `chat.side_result` 消费逻辑，才能在浏览器中实时渲染 BTW。在这一客户端能力落地之前，BTW 已经是一个完整的 Gateway 网关层功能，TUI 和外部渠道都可正常使用，但浏览器 UX 还未完整支持。

## 何时使用 BTW

当你想要以下能力时，请使用 `/btw`：

- 对当前工作做一个快速澄清，
- 在长时间运行仍在进行时获得一个事实性旁支回答，
- 得到一个不应成为未来会话上下文一部分的临时答案。

示例：

```text
/btw what file are we editing?
/btw what does this error mean?
/btw summarize the current task in one sentence
/btw what is 17 * 19?
```

## 何时不要使用 BTW

如果你希望回答成为该会话未来工作上下文的一部分，就不要使用 `/btw`。

在这种情况下，请直接在主会话中正常提问，而不是使用 BTW。

## 相关内容

- [Slash commands](/tools/slash-commands)
- [Thinking Levels](/tools/thinking)
- [Session](/concepts/session)
