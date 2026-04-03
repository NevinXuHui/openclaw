---
summary: "CLI reference for `openclaw mcp`（通过 MCP 暴露 OpenClaw 渠道会话，并管理已保存的 MCP 服务器定义）"
read_when:
  - 你正在将 Codex、Claude Code 或其他 MCP 客户端连接到 OpenClaw 支持的渠道
  - 你正在运行 `openclaw mcp serve`
  - 你正在管理由 OpenClaw 保存的 MCP 服务器定义
title: "mcp"
---

# mcp

`openclaw mcp` 有两个作用：

- 使用 `openclaw mcp serve` 将 OpenClaw 作为 MCP 服务器运行
- 使用 `list`、`show`、`set` 和 `unset` 管理由 OpenClaw 持有的出站 MCP 服务器定义

换句话说：

- `serve` 表示 OpenClaw 充当 MCP 服务器
- `list` / `show` / `set` / `unset` 表示 OpenClaw 充当 MCP 客户端侧的注册表，用于保存其运行时之后可能会消费的其他 MCP 服务器定义

当 OpenClaw 需要自己托管一个 coding harness 会话，并通过 ACP 路由该运行时时，请使用 [`openclaw acp`](/cli/acp)。

## OpenClaw 作为 MCP 服务器

这对应 `openclaw mcp serve` 路径。

## 何时使用 `serve`

在以下情况下使用 `openclaw mcp serve`：

- Codex、Claude Code 或其他 MCP 客户端需要直接与 OpenClaw 支持的渠道会话通信
- 你已经拥有一个本地或远程的 OpenClaw Gateway，并且其中存在已路由的会话
- 你希望使用一个 MCP 服务器统一接入 OpenClaw 的各类渠道后端，而不是为每个渠道单独运行桥接器

如果应由 OpenClaw 自己托管 coding runtime，并将智能体会话保留在 OpenClaw 内部，请改用 [`openclaw acp`](/cli/acp)。

## 工作原理

`openclaw mcp serve` 会启动一个基于 stdio 的 MCP 服务器。MCP 客户端拥有该进程。当客户端保持 stdio 会话开启时，桥接器会通过 WebSocket 连接到本地或远程 OpenClaw Gateway，并通过 MCP 暴露已路由的渠道会话。

生命周期如下：

1. MCP 客户端启动 `openclaw mcp serve`
2. 桥接器连接到 Gateway
3. 已路由的会话会变成 MCP 会话以及 transcript/history 工具
4. 当桥接器保持连接时，实时事件会在内存中排队
5. 如果启用了 Claude 渠道模式，同一会话还可以接收 Claude 专用推送通知

重要行为：

- 实时队列状态从桥接器连接时开始计算
- 更早的 transcript 历史通过 `messages_read` 读取
- Claude 推送通知只在 MCP 会话存活期间存在
- 当客户端断开连接时，桥接器会退出，实时队列也随之消失

## 选择客户端模式

同一个桥接器可以用两种方式使用：

- 通用 MCP 客户端：仅使用标准 MCP 工具。使用 `conversations_list`、`messages_read`、`events_poll`、`events_wait`、`messages_send` 和审批工具。
- Claude Code：标准 MCP 工具 + Claude 专用渠道适配器。启用 `--claude-channel-mode on`，或保留默认值 `auto`。

当前 `auto` 的行为与 `on` 相同。尚未实现客户端能力检测。

## `serve` 会暴露什么

该桥接器使用已有的 Gateway 会话路由元数据来暴露基于渠道的会话。当 OpenClaw 已经拥有带有已知路由信息的会话状态时，该会话就会显示出来，例如：

- `channel`
- recipient 或 destination 元数据
- 可选的 `accountId`
- 可选的 `threadId`

这让 MCP 客户端能够在一个地方完成：

- 列出最近的已路由会话
- 读取最近的 transcript 历史
- 等待新的入站事件
- 通过同一路由发送回复
- 查看桥接器连接期间到达的审批请求

## Usage

```bash
# Local Gateway
openclaw mcp serve

# Remote Gateway
openclaw mcp serve --url wss://gateway-host:18789 --token-file ~/.openclaw/gateway.token

# Remote Gateway with password auth
openclaw mcp serve --url wss://gateway-host:18789 --password-file ~/.openclaw/gateway.password

# Enable verbose bridge logs
openclaw mcp serve --verbose

# Disable Claude-specific push notifications
openclaw mcp serve --claude-channel-mode off
```

## Bridge tools

当前桥接器暴露以下 MCP 工具：

- `conversations_list`
- `conversation_get`
- `messages_read`
- `attachments_fetch`
- `events_poll`
- `events_wait`
- `messages_send`
- `permissions_list_open`
- `permissions_respond`

### `conversations_list`

列出最近的、以会话为基础、且在 Gateway 会话状态中已经带有路由元数据的会话。

常用过滤条件：

- `limit`
- `search`
- `channel`
- `includeDerivedTitles`
- `includeLastMessage`

### `conversation_get`

通过 `session_key` 返回单个会话。

### `messages_read`

读取某个以会话为基础的会话中的最近 transcript 消息。

### `attachments_fetch`

从某条 transcript 消息中提取非文本消息内容块。这是针对 transcript 内容的元数据视图，不是一个独立且持久的附件 blob 存储。

### `events_poll`

从某个数字游标开始，读取之后排队的实时事件。

### `events_wait`

长轮询，直到下一个匹配的排队事件到达，或超时。

当通用 MCP 客户端需要接近实时的投递能力，但不使用 Claude 专用推送协议时，请使用此工具。

### `messages_send`

通过当前会话中已记录的同一路由，将文本发送回去。

当前行为：

- 需要已有的会话路由
- 使用会话中的 channel、recipient、account id 和 thread id
- 仅支持发送文本

### `permissions_list_open`

列出桥接器自连接 Gateway 以来观察到的待处理 exec/plugin 审批请求。

### `permissions_respond`

通过以下之一来处理单个待审批的 exec/plugin 请求：

- `allow-once`
- `allow-always`
- `deny`

## 事件模型

桥接器在连接期间会维护一个内存中的事件队列。

当前事件类型：

- `message`
- `exec_approval_requested`
- `exec_approval_resolved`
- `plugin_approval_requested`
- `plugin_approval_resolved`
- `claude_permission_request`

重要限制：

- 队列仅覆盖实时事件；它从 MCP 桥接器启动时开始
- `events_poll` 和 `events_wait` 不会自行回放更早的 Gateway 历史
- 持久化积压内容应使用 `messages_read` 读取

## Claude 渠道通知

桥接器还可以暴露 Claude 专用的渠道通知。这是 OpenClaw 对应的 Claude Code 渠道适配器：标准 MCP 工具仍然可用，但实时入站消息也可以作为 Claude 专用 MCP 通知到达。

标志：

- `--claude-channel-mode off`：仅标准 MCP 工具
- `--claude-channel-mode on`：启用 Claude 渠道通知
- `--claude-channel-mode auto`：当前默认值；其桥接行为与 `on` 相同

启用 Claude 渠道模式后，服务器会声明 Claude 实验性能力，并可能发出：

- `notifications/claude/channel`
- `notifications/claude/channel/permission`

当前桥接器行为：

- 入站的 `user` transcript 消息会被转发为 `notifications/claude/channel`
- 通过 MCP 接收到的 Claude 权限请求会在内存中跟踪
- 如果后续关联会话发送了 `yes abcde` 或 `no abcde`，桥接器会将其转换为 `notifications/claude/channel/permission`
- 这些通知仅在实时会话中可用；如果 MCP 客户端断开连接，就没有推送目标了

这是一项有意面向特定客户端的能力。通用 MCP 客户端应依赖标准轮询工具。

## MCP 客户端配置

示例 stdio 客户端配置：

```json
{
  "mcpServers": {
    "openclaw": {
      "command": "openclaw",
      "args": [
        "mcp",
        "serve",
        "--url",
        "wss://gateway-host:18789",
        "--token-file",
        "/path/to/gateway.token"
      ]
    }
  }
}
```

对于大多数通用 MCP 客户端，建议先从标准工具界面开始，并忽略 Claude 模式。只有在客户端确实理解 Claude 专用通知方法时，才启用 Claude 模式。

## 选项

`openclaw mcp serve` 支持：

- `--url <url>`：Gateway WebSocket URL
- `--token <token>`：Gateway token
- `--token-file <path>`：从文件读取 token
- `--password <password>`：Gateway password
- `--password-file <path>`：从文件读取 password
- `--claude-channel-mode <auto|on|off>`：Claude 通知模式
- `-v`, `--verbose`：在 stderr 输出详细日志

如无特殊需要，请优先使用 `--token-file` 或 `--password-file`，而不是在命令行中直接写入密钥。

## 安全与信任边界

桥接器不会发明路由。它只会暴露 Gateway 已知如何路由的会话。

这意味着：

- 发送者允许列表、配对机制以及渠道级信任边界，仍然属于底层 OpenClaw 渠道配置的一部分
- `messages_send` 只能通过已保存的现有路由进行回复
- 对于当前桥接会话，审批状态仅存在于实时 / 内存中
- 桥接器认证应使用与你信任其他远程 Gateway 客户端时相同级别的 token 或 password 控制

如果某个会话没有出现在 `conversations_list` 中，通常原因并不是 MCP 配置错误，而是底层 Gateway 会话中缺少或不完整的路由元数据。

## 测试

OpenClaw 为这个桥接器提供了一个确定性的 Docker smoke：

```bash
pnpm test:docker:mcp-channels
```

这个 smoke 会：

- 启动一个已注入数据的 Gateway 容器
- 启动第二个容器，并在其中运行 `openclaw mcp serve`
- 验证会话发现、transcript 读取、附件元数据读取、实时事件队列行为以及出站发送路由
- 通过真实的 stdio MCP 桥接，验证 Claude 风格的渠道与权限通知

这是在不接入真实 Telegram、Discord 或 iMessage 账号的前提下，验证桥接器是否可用的最快方式。

更广泛的测试背景请参见 [Testing](/help/testing)。

## 故障排除

### 没有返回任何会话

通常意味着 Gateway 会话本身还不可路由。请确认底层会话已保存 channel/provider、recipient，以及可选的 account/thread 路由元数据。

### `events_poll` 或 `events_wait` 没有返回较早消息

这是预期行为。实时队列从桥接器连接时才开始计入。较早的 transcript 历史应通过 `messages_read` 读取。

### Claude 通知没有出现

请检查以下几点：

- 客户端是否保持了 stdio MCP 会话开启
- `--claude-channel-mode` 是否为 `on` 或 `auto`
- 客户端是否真正理解 Claude 专用通知方法
- 入站消息是否发生在桥接器连接之后

### 审批没有显示出来

`permissions_list_open` 只会显示桥接器连接期间观察到的审批请求。它不是一个持久化审批历史 API。

## OpenClaw 作为 MCP 客户端注册表

这对应 `openclaw mcp list`、`show`、`set` 和 `unset` 路径。

这些命令不会把 OpenClaw 暴露为 MCP 服务。它们只管理 OpenClaw 配置中 `mcp.servers` 下的 MCP 服务器定义。

这些已保存的定义面向 OpenClaw 之后启动或配置的运行时，例如内嵌 Pi 和其他运行时适配器。OpenClaw 将这些定义集中保存，这样这些运行时就不必再维护各自重复的 MCP 服务器列表。

重要行为：

- 这些命令只读写 OpenClaw 配置
- 它们不会连接目标 MCP 服务器
- 它们不会验证命令、URL 或远程传输当前是否可达
- 运行时适配器会在真正执行时决定支持哪些传输形态

## 已保存的 MCP 服务器定义

OpenClaw 还会在配置中维护一个轻量级 MCP 服务器注册表，供那些想使用 OpenClaw 管理的 MCP 定义的界面使用。

命令：

- `openclaw mcp list`
- `openclaw mcp show [name]`
- `openclaw mcp set <name> <json>`
- `openclaw mcp unset <name>`

示例：

```bash
openclaw mcp list
openclaw mcp show context7 --json
openclaw mcp set context7 '{"command":"uvx","args":["context7-mcp"]}'
openclaw mcp set docs '{"url":"https://mcp.example.com"}'
openclaw mcp unset context7
```

示例配置结构：

```json
{
  "mcp": {
    "servers": {
      "context7": {
        "command": "uvx",
        "args": ["context7-mcp"]
      },
      "docs": {
        "url": "https://mcp.example.com"
      }
    }
  }
}
```

### Stdio 传输

启动本地子进程，并通过 stdin/stdout 通信。

| Field                      | 说明                       |
| -------------------------- | -------------------------- |
| `command`                  | 要启动的可执行文件（必填） |
| `args`                     | 命令行参数数组             |
| `env`                      | 额外环境变量               |
| `cwd` / `workingDirectory` | 进程工作目录               |

### SSE / HTTP 传输

通过 HTTP Server-Sent Events 连接远程 MCP 服务器。

| Field     | 说明                                     |
| --------- | ---------------------------------------- |
| `url`     | 远程服务器的 HTTP 或 HTTPS URL（必填）   |
| `headers` | 可选的 HTTP 头键值映射（例如认证 token） |

示例：

```json
{
  "mcp": {
    "servers": {
      "remote-tools": {
        "url": "https://mcp.example.com",
        "headers": {
          "Authorization": "Bearer <token>"
        }
      }
    }
  }
}
```

日志和状态输出中会对 `url` 中的敏感值（userinfo）以及 `headers` 进行脱敏处理。

这些命令只管理已保存的配置。它们不会启动渠道桥接器、不会打开实时 MCP 客户端会话，也不会证明目标服务器当前可达。

## 当前限制

本页描述的是当前已发布版本中的桥接器行为。

当前限制：

- 会话发现依赖于现有 Gateway 会话路由元数据
- 除了 Claude 专用适配器之外，尚无通用推送协议
- 目前还不支持消息编辑或 reaction 工具
- HTTP/SSE 传输只连接单个远程服务器；尚不支持多路上游
- `permissions_list_open` 只包含桥接器连接期间观察到的审批请求
