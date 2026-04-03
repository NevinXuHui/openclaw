---
summary: "CLI reference for `openclaw flows`（列出、检查、取消）"
read_when:
  - 你想检查或取消一个 flow
  - 你想了解后台任务如何汇总为更高层级的作业
title: "flows"
---

# `openclaw flows`

检查并管理 [ClawFlow](/automation/clawflow) 作业。

```bash
openclaw flows list
openclaw flows show <lookup>
openclaw flows cancel <lookup>
```

## 命令

### `flows list`

列出已跟踪的 flow 及其任务数量。

```bash
openclaw flows list
openclaw flows list --status blocked
openclaw flows list --json
```

### `flows show`

按 flow id 或 owner session key 显示单个 flow。

```bash
openclaw flows show <lookup>
openclaw flows show <lookup> --json
```

输出包含 flow 状态、当前步骤、等待目标、阻塞摘要（如存在）、已存储的输出键以及关联任务。

### `flows cancel`

取消一个 flow 及其所有活跃子任务。

```bash
openclaw flows cancel <lookup>
```

## 相关内容

- [ClawFlow](/automation/clawflow) — 位于任务之上的作业级编排
- [后台任务](/automation/tasks) — 分离式工作账本
- [CLI reference](/cli/index) — 完整命令树
