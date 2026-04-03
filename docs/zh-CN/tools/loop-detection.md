---
title: "Tool-loop 检测"
summary: "如何启用和调优用于检测重复工具调用循环的护栏"
read_when:
  - 用户报告 agent 卡在重复工具调用中
  - 你需要调优重复调用保护
  - 你正在编辑 agent 工具 / 运行时策略
---

# Tool-loop 检测

OpenClaw 可以防止 agent 陷入重复的工具调用模式。
该护栏**默认关闭**。

仅在确实需要的地方启用它，因为在严格设置下，它可能会拦截合法的重复调用。

## 为什么需要它

- 检测没有进展的重复序列。
- 检测高频、无结果的循环（同一工具、同样输入、重复报错）。
- 针对已知轮询工具，检测特定的重复调用模式。

## 配置块

全局默认值：

```json5
{
  tools: {
    loopDetection: {
      enabled: false,
      historySize: 30,
      warningThreshold: 10,
      criticalThreshold: 20,
      globalCircuitBreakerThreshold: 30,
      detectors: {
        genericRepeat: true,
        knownPollNoProgress: true,
        pingPong: true,
      },
    },
  },
}
```

按 agent 覆盖（可选）：

```json5
{
  agents: {
    list: [
      {
        id: "safe-runner",
        tools: {
          loopDetection: {
            enabled: true,
            warningThreshold: 8,
            criticalThreshold: 16,
          },
        },
      },
    ],
  },
}
```

### 字段行为

- `enabled`：总开关。`false` 表示完全不执行循环检测。
- `historySize`：用于分析的近期工具调用历史数量。
- `warningThreshold`：在模式被归类为仅警告前的阈值。
- `criticalThreshold`：阻止重复循环模式的阈值。
- `globalCircuitBreakerThreshold`：全局无进展熔断阈值。
- `detectors.genericRepeat`：检测同一工具 + 同一参数的重复模式。
- `detectors.knownPollNoProgress`：检测无状态变化的已知轮询模式。
- `detectors.pingPong`：检测交替往返的 ping-pong 模式。

## 推荐设置

- 从 `enabled: true` 且其余默认值不变开始。
- 保持阈值顺序为 `warningThreshold < criticalThreshold < globalCircuitBreakerThreshold`。
- 如果出现误报：
  - 提高 `warningThreshold` 和 / 或 `criticalThreshold`
  - （可选）提高 `globalCircuitBreakerThreshold`
  - 仅关闭导致问题的 detector
  - 减小 `historySize`，降低历史上下文的严格度

## 日志与预期行为

当检测到循环时，OpenClaw 会报告一个 loop 事件，并根据严重程度阻止或抑制下一轮工具循环。
这样可以在保留正常工具访问的同时，保护用户免于失控的 token 消耗和卡死。

- 优先使用警告和临时抑制。
- 只有在重复证据持续累积时才升级。

## 说明

- `tools.loopDetection` 会与 agent 级覆盖合并。
- 按 agent 的配置会完整覆盖或扩展全局值。
- 如果没有任何配置，护栏保持关闭。
