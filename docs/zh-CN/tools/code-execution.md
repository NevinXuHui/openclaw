---
summary: "code_execution -- 使用 xAI 进行沙箱化远程 Python 分析"
read_when:
  - 你想启用或配置 code_execution
  - 你想进行远程分析而不使用本地 shell 访问
  - 你想把 x_search 或 web_search 与远程 Python 分析结合使用
title: "Code Execution"
---

# Code Execution

`code_execution` 会在 xAI 的 Responses API 上执行沙箱化的远程 Python 分析。
它不同于本地的 [`exec`](/tools/exec)：

- `exec` 在你的机器或节点上运行 shell 命令
- `code_execution` 在 xAI 的远程沙箱中运行 Python

请在以下场景中使用 `code_execution`：

- 计算
- 制表
- 快速统计
- 图表式分析
- 分析由 `x_search` 或 `web_search` 返回的数据

当你需要本地文件、shell、仓库或已配对设备时，**不要**使用它。
这种场景请改用 [`exec`](/tools/exec)。

## 设置

你需要一个 xAI API 密钥。以下任一方式均可：

- `XAI_API_KEY`
- `plugins.entries.xai.config.webSearch.apiKey`

示例：

```json5
{
  plugins: {
    entries: {
      xai: {
        config: {
          webSearch: {
            apiKey: "xai-...",
          },
          codeExecution: {
            enabled: true,
            model: "grok-4-1-fast",
            maxTurns: 2,
            timeoutSeconds: 30,
          },
        },
      },
    },
  },
}
```

## 如何使用

请自然提问，并明确说明分析意图：

```text
Use code_execution to calculate the 7-day moving average for these numbers: ...
```

```text
Use x_search to find posts mentioning OpenClaw this week, then use code_execution to count them by day.
```

```text
Use web_search to gather the latest AI benchmark numbers, then use code_execution to compare percent changes.
```

该工具在内部只接收一个 `task` 参数，因此 agent 应将完整的分析请求与任何内联数据一次性发送到同一个提示中。

## 限制

- 这是远程 xAI 执行，不是本地进程执行。
- 它应被视为临时分析环境，而不是持久化 notebook。
- 不要假设它能访问本地文件或你的工作区。
- 如果需要最新的 X 数据，请先使用 [`x_search`](/tools/web#x_search)。

## 另请参见

- [Web 工具](/tools/web)
- [Exec](/tools/exec)
- [xAI](/providers/xai)
