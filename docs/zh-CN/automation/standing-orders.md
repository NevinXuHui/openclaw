---
summary: "定义自治智能体程序的永久操作授权"
read_when:
  - 你正在设置无需逐项提示即可运行的自治智能体工作流
  - 你正在定义智能体可以独立执行什么、哪些需要人工批准
  - 你正在为多程序智能体建立清晰的边界与升级规则
title: "常驻指令"
---

# 常驻指令

常驻指令会为你的智能体授予已定义程序的**永久操作授权**。你不必每次都给出单独的任务指令，而是定义具有明确范围、触发条件和升级规则的程序，由智能体在这些边界内自主执行。

这相当于：你不再需要每周五都对助手说“发送周报”，而是授予一项常驻授权：“周报由你负责。每周五汇总、发送，只有在发现异常时才升级给我。”

## 为什么要使用常驻指令？

**没有常驻指令时：**

- 每项任务都需要你提示智能体
- 智能体会在请求之间空闲等待
- 例行工作容易被遗忘或延迟
- 你会成为瓶颈

**有了常驻指令后：**

- 智能体会在定义好的边界内自主执行
- 例行工作会按计划完成，无需额外提示
- 只有异常和审批才需要你介入
- 智能体会高效利用空闲时间

## 它们如何工作

常驻指令定义在你的[智能体工作空间](/concepts/agent-workspace)文件中。推荐做法是直接写入 `AGENTS.md`（它会在每次会话中自动注入），这样智能体始终能获取这些上下文。对于较大的配置，你也可以把它们放进单独的文件，如 `standing-orders.md`，再从 `AGENTS.md` 中引用。

每个程序应明确说明：

1. **范围** —— 智能体被授权做什么
2. **触发条件** —— 何时执行（计划、事件或条件）
3. **审批门** —— 哪些操作必须先获得人工签字
4. **升级规则** —— 何时停止并寻求帮助

智能体会在每次会话中通过工作空间引导文件加载这些指令（自动注入文件的完整列表见[智能体工作空间](/concepts/agent-workspace)），并结合[定时任务](/automation/cron-jobs)执行这些规则，以实现基于时间的触发。

<Tip>
将常驻指令放在 `AGENTS.md` 中，可以确保它们在每次会话里都被加载。工作空间引导会自动注入 `AGENTS.md`、`SOUL.md`、`TOOLS.md`、`IDENTITY.md`、`USER.md`、`HEARTBEAT.md`、`BOOTSTRAP.md` 和 `MEMORY.md`，但不会自动注入子目录中的任意文件。
</Tip>

## 常驻指令的结构

```markdown
## Program: Weekly Status Report

**Authority:** Compile data, generate report, deliver to stakeholders
**Trigger:** Every Friday at 4 PM (enforced via cron job)
**Approval gate:** None for standard reports. Flag anomalies for human review.
**Escalation:** If data source is unavailable or metrics look unusual (>2σ from norm)

### Execution Steps

1. Pull metrics from configured sources
2. Compare to prior week and targets
3. Generate report in Reports/weekly/YYYY-MM-DD.md
4. Deliver summary via configured channel
5. Log completion to Agent/Logs/

### What NOT to Do

- Do not send reports to external parties
- Do not modify source data
- Do not skip delivery if metrics look bad — report accurately
```

## 常驻指令 + 定时任务

常驻指令定义智能体**被授权做什么**。[定时任务](/automation/cron-jobs)定义**何时发生**。它们配合使用：

```
Standing Order: "You own the daily inbox triage"
    ↓
Cron Job (8 AM daily): "Execute inbox triage per standing orders"
    ↓
Agent: Reads standing orders → executes steps → reports results
```

定时任务提示应引用常驻指令，而不是重复其内容：

```bash
openclaw cron add \
  --name daily-inbox-triage \
  --cron "0 8 * * 1-5" \
  --tz America/New_York \
  --timeout-seconds 300 \
  --announce \
  --channel bluebubbles \
  --to "+1XXXXXXXXXX" \
  --message "Execute daily inbox triage per standing orders. Check mail for new alerts. Parse, categorize, and persist each item. Report summary to owner. Escalate unknowns."
```

## 示例

### 示例 1：内容与社交媒体（每周周期）

```markdown
## Program: Content & Social Media

**Authority:** Draft content, schedule posts, compile engagement reports
**Approval gate:** All posts require owner review for first 30 days, then standing approval
**Trigger:** Weekly cycle (Monday review → mid-week drafts → Friday brief)

### Weekly Cycle

- **Monday:** Review platform metrics and audience engagement
- **Tuesday–Thursday:** Draft social posts, create blog content
- **Friday:** Compile weekly marketing brief → deliver to owner

### Content Rules

- Voice must match the brand (see SOUL.md or brand voice guide)
- Never identify as AI in public-facing content
- Include metrics when available
- Focus on value to audience, not self-promotion
```

### 示例 2：财务运营（事件触发）

```markdown
## Program: Financial Processing

**Authority:** Process transaction data, generate reports, send summaries
**Approval gate:** None for analysis. Recommendations require owner approval.
**Trigger:** New data file detected OR scheduled monthly cycle

### When New Data Arrives

1. Detect new file in designated input directory
2. Parse and categorize all transactions
3. Compare against budget targets
4. Flag: unusual items, threshold breaches, new recurring charges
5. Generate report in designated output directory
6. Deliver summary to owner via configured channel

### Escalation Rules

- Single item > $500: immediate alert
- Category > budget by 20%: flag in report
- Unrecognizable transaction: ask owner for categorization
- Failed processing after 2 retries: report failure, do not guess
```

### 示例 3：监控与告警（持续运行）

```markdown
## Program: System Monitoring

**Authority:** Check system health, restart services, send alerts
**Approval gate:** Restart services automatically. Escalate if restart fails twice.
**Trigger:** Every heartbeat cycle

### Checks

- Service health endpoints responding
- Disk space above threshold
- Pending tasks not stale (>24 hours)
- Delivery channels operational

### Response Matrix

| Condition        | Action                   | Escalate?                |
| ---------------- | ------------------------ | ------------------------ |
| Service down     | Restart automatically    | Only if restart fails 2x |
| Disk space < 10% | Alert owner              | Yes                      |
| Stale task > 24h | Remind owner             | No                       |
| Channel offline  | Log and retry next cycle | If offline > 2 hours     |
```

## Execute-Verify-Report 模式

将常驻指令与严格的执行纪律结合起来时效果最好。常驻指令中的每项任务都应遵循以下循环：

1. **Execute** —— 实际完成工作（不要只是确认收到指令）
2. **Verify** —— 确认结果正确（文件存在、消息已发送、数据已解析）
3. **Report** —— 告诉所有者完成了什么，以及验证了什么

```markdown
### Execution Rules

- Every task follows Execute-Verify-Report. No exceptions.
- "I'll do that" is not execution. Do it, then report.
- "Done" without verification is not acceptable. Prove it.
- If execution fails: retry once with adjusted approach.
- If still fails: report failure with diagnosis. Never silently fail.
- Never retry indefinitely — 3 attempts max, then escalate.
```

这个模式可以避免智能体最常见的失败方式：口头确认任务，却没有真正完成它。

## 多程序架构

对于需要管理多个关注点的智能体，应将常驻指令组织成边界清晰的独立程序：

```markdown
# Standing Orders

## Program 1: [Domain A] (Weekly)

...

## Program 2: [Domain B] (Monthly + On-Demand)

...

## Program 3: [Domain C] (As-Needed)

...

## Escalation Rules (All Programs)

- [Common escalation criteria]
- [Approval gates that apply across programs]
```

每个程序都应具备：

- 自己的**触发节奏**（每周、每月、事件驱动、持续）
- 自己的**审批门**（有些程序比其他程序需要更强监督）
- 清晰的**边界**（智能体应知道一个程序在哪里结束、另一个程序从哪里开始）

## 最佳实践

### 应该做

- 先从窄范围授权开始，随着信任建立再逐步扩大
- 为高风险操作定义明确的审批门
- 加入“不要做什么”章节 —— 边界与权限同样重要
- 结合定时任务实现可靠的定时执行
- 每周审查智能体日志，确认常驻指令得到正确执行
- 随着需求变化更新常驻指令 —— 它们是活文档

### 避免这样做

- 第一天就授予过宽权限（“按你觉得最好的方式处理”）
- 跳过升级规则 —— 每个程序都需要“何时停下并提问”的条款
- 假设智能体会记住口头说明 —— 把所有内容都写进文件里
- 把多个关注点混在同一个程序里 —— 不同领域用不同程序
- 忘记用定时任务强制触发 —— 没有触发条件的常驻指令最终只会变成建议

## 相关内容

- [自动化概览](/automation) — 所有自动化机制一览
- [定时任务](/automation/cron-jobs) — 常驻指令的计划执行机制
- [钩子](/automation/hooks) — 智能体生命周期事件的事件驱动脚本
- [Webhook](/automation/webhook) — 入站 HTTP 事件触发器
- [智能体工作空间](/concepts/agent-workspace) — 常驻指令的存放位置，以及自动注入引导文件的完整列表（AGENTS.md、SOUL.md 等）
