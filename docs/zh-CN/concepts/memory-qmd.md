---
title: "QMD 记忆引擎"
summary: "本地优先的搜索 sidecar，支持 BM25、向量、重排序和查询扩展"
read_when:
  - 你想将 QMD 设置为记忆后端
  - 你想要重排序或额外索引路径等高级记忆功能
---

# QMD 记忆引擎

[QMD](https://github.com/tobi/qmd) 是一个本地优先的搜索 sidecar，可与 OpenClaw 一起运行。它在单个二进制中结合了 BM25、向量搜索和重排序，并且可以索引工作空间记忆文件之外的内容。

## 相比内置引擎增加了什么

- **重排序和查询扩展**，提高召回效果。
- **索引额外目录** —— 项目文档、团队笔记、磁盘上的任意内容。
- **索引会话转录** —— 回忆更早之前的对话。
- **完全本地** —— 通过 Bun + node-llama-cpp 运行，并自动下载 GGUF 模型。
- **自动回退** —— 如果 QMD 不可用，OpenClaw 会无缝回退到内置引擎。

## 快速开始

### 前置条件

- 安装 QMD：`bun install -g @tobilu/qmd`
- 允许扩展的 SQLite 构建版本（macOS 上可使用 `brew install sqlite`）。
- QMD 必须出现在 Gateway 网关的 `PATH` 中。
- macOS 和 Linux 可开箱即用。Windows 最适合通过 WSL2 使用。

### 启用

```json5
{
  memory: {
    backend: "qmd",
  },
}
```

OpenClaw 会在 `~/.openclaw/agents/<agentId>/qmd/` 下创建独立的 QMD 主目录，并自动管理 sidecar 生命周期 —— collection、更新和嵌入运行都会由它处理。

## sidecar 的工作方式

- OpenClaw 会根据你的工作空间记忆文件以及配置的 `memory.qmd.paths` 创建 collection，然后在启动时和周期性地（默认每 5 分钟）运行 `qmd update` + `qmd embed`。
- 启动时的刷新会在后台运行，因此不会阻塞聊天启动。
- 搜索使用已配置的 `searchMode`（默认：`search`；也支持 `vsearch` 和 `query`）。如果某种模式失败，OpenClaw 会重试 `qmd query`。
- 如果 QMD 完全失败，OpenClaw 会回退到内置 SQLite 引擎。

<Info>
首次搜索可能会比较慢 —— QMD 会在第一次运行 `qmd query` 时自动下载用于重排序和查询扩展的 GGUF 模型（约 2 GB）。
</Info>

## 索引额外路径

将 QMD 指向附加目录，使其也可以被搜索：

```json5
{
  memory: {
    backend: "qmd",
    qmd: {
      paths: [{ name: "docs", path: "~/notes", pattern: "**/*.md" }],
    },
  },
}
```

额外路径中的片段会在搜索结果中显示为 `qmd/<collection>/<relative-path>`。`memory_get` 能识别这个前缀，并从正确的 collection 根目录读取内容。

## 索引会话转录

启用会话索引，以便回忆更早的对话：

```json5
{
  memory: {
    backend: "qmd",
    qmd: {
      sessions: { enabled: true },
    },
  },
}
```

转录内容会以已清理的 User/Assistant 回合形式导出到专用的 QMD collection 中，路径为 `~/.openclaw/agents/<id>/qmd/sessions/`。

## 搜索范围

默认情况下，QMD 搜索结果只会在私信会话中显示（不会在群组或渠道中显示）。可以通过配置 `memory.qmd.scope` 来修改：

```json5
{
  memory: {
    qmd: {
      scope: {
        default: "deny",
        rules: [{ action: "allow", match: { chatType: "direct" } }],
      },
    },
  },
}
```

当 scope 拒绝一次搜索时，OpenClaw 会记录一条警告日志，并带上推导出的 channel 和 chat type，方便排查空结果问题。

## 引用

当 `memory.citations` 为 `auto` 或 `on` 时，搜索片段会包含 `Source: <path#line>` 页脚。将 `memory.citations = "off"` 可省略页脚，但内部仍会把路径传给智能体。

## 何时使用

在以下情况下请选择 QMD：

- 你需要通过重排序获得更高质量的结果。
- 你需要搜索工作空间之外的项目文档或笔记。
- 你需要回忆过去的会话对话。
- 你需要完全本地、无需 API key 的搜索。

对于更简单的设置，[内置引擎](/concepts/memory-builtin) 已经能很好工作，而且不需要额外依赖。

## 故障排除

**找不到 QMD？** 确保该二进制在 Gateway 网关的 `PATH` 中。如果 OpenClaw 作为服务运行，请创建一个符号链接：
`sudo ln -s ~/.bun/bin/qmd /usr/local/bin/qmd`。

**首次搜索很慢？** QMD 会在第一次使用时下载 GGUF 模型。使用与 OpenClaw 相同的 XDG 目录先运行一次 `qmd query "test"` 进行预热。

**搜索超时？** 增大 `memory.qmd.limits.timeoutMs`（默认：4000ms）。较慢的硬件可以设置为 `120000`。

**群聊里结果为空？** 检查 `memory.qmd.scope` —— 默认只允许私信会话。

**工作空间可见的临时仓库导致 `ENAMETOOLONG` 或索引损坏？**
QMD 的遍历目前遵循底层 QMD 扫描器行为，而不是 OpenClaw 内置的符号链接规则。请将临时 monorepo checkout 放在诸如 `.tmp/` 之类的隐藏目录中，或者放在已索引的 QMD 根目录之外，直到 QMD 提供防循环遍历或显式排除控制。

## 配置

要了解完整的配置面（`memory.qmd.*`）、搜索模式、更新间隔、scope 规则及所有其他选项，请参阅[记忆配置参考](/reference/memory-config)。
