---
summary: "用于后台任务和分离式运行的 ClawFlow 工作流编排"
read_when:
  - 你希望由一个 flow 管理一个或多个分离式任务
  - 你希望按整体查看或取消一个后台作业
  - 你希望理解 flow 与任务及后台工作的关系
title: "ClawFlow"
---

# ClawFlow

ClawFlow 是位于[后台任务](/automation/tasks)之上的 flow 层。任务仍然负责跟踪分离式工作。ClawFlow 则会把这些任务运行归并成单个作业，保留父级所有者上下文，并提供 flow 级控制界面。

当工作不止一次分离式运行时，请使用 ClawFlow。一个 flow 当然也可以只包含一个任务，但它同样可以用简单的线性顺序协调多个任务。

## 简要概述

- 任务是执行记录。
- ClawFlow 是位于任务之上的作业级封装。
- 一个 flow 会为整个作业保留统一的所有者/会话上下文。
- 使用 `openclaw flows list`、`openclaw flows show` 和 `openclaw flows cancel` 来检查或管理 flow。

## 快速开始

```bash
openclaw flows list
openclaw flows show <flow-id-or-owner-session>
openclaw flows cancel <flow-id-or-owner-session>
```

## 它与任务的关系

后台任务仍然承担底层工作：

- ACP 运行
- 子智能体运行
- 定时任务执行
- 由 CLI 发起的运行

ClawFlow 位于这份账本之上：

- 它会将相关的任务运行放到同一个 flow id 下
- 它会将 flow 状态与单个任务状态分开跟踪
- 它让阻塞型或多步骤工作能在一个地方更容易检查

对于一次单独的分离式运行，flow 可以只是单任务 flow。对于更结构化的工作，ClawFlow 可以将多个任务运行归入同一个作业。

## 运行时基座

ClawFlow 是运行时基座，不是一种工作流语言。

它负责：

- flow id
- 所有者会话与返回上下文
- 等待状态
- 小型持久化输出
- 完成、失败、取消与阻塞状态

它**不**负责分支逻辑或业务逻辑。这些应放在位于其上的编写层中：

- Lobster
- acpx
- 普通 TypeScript 辅助函数
- 内置 skills

在实际使用中，编写层只需面向一个很小的运行时接口：

- `createFlow(...)`
- `runTaskInFlow(...)`
- `setFlowWaiting(...)`
- `setFlowOutput(...)`
- `appendFlowOutput(...)`
- `emitFlowUpdate(...)`
- `resumeFlow(...)`
- `finishFlow(...)`
- `failFlow(...)`

这样就能在核心中保留 flow 所有权和返回线程行为，而不会强制上层只能使用某一种 DSL。

## 编写模式

推荐的结构是线性的：

1. 为整个作业创建一个 flow。
2. 在该 flow 下运行一个分离式任务。
3. 等待子任务或外部事件。
4. 在调用方中恢复该 flow。
5. 启动下一个子任务，或者结束 flow。

ClawFlow 会持久化恢复这个作业所需的最小状态：当前步骤、正在等待的任务，以及用于步骤间传递的小型输出包。

## CLI 界面

flow CLI 被有意保持得很小：

- `openclaw flows list` 显示活跃和最近的 flow
- `openclaw flows show <lookup>` 显示单个 flow 及其关联任务
- `openclaw flows cancel <lookup>` 取消该 flow 及其所有活跃子任务

`flows show` 还会显示当前等待目标和已存储的输出键，这通常足以回答“这个作业现在在等什么？”，无需再逐个翻看子任务。

查找标识既可以是 flow id，也可以是 owner session key。

## 相关内容

- [后台任务](/automation/tasks) — 分离式工作账本
- [CLI：flows](/cli/flows) — flow 检查与控制命令
- [定时任务](/automation/cron-jobs) — 可能会创建任务的计划任务
