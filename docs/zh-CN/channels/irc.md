---
title: IRC
summary: "IRC 插件设置、访问控制与故障排除"
read_when:
  - 你想把 OpenClaw 连接到 IRC 频道或私信
  - 你正在配置 IRC 允许列表、群组策略或提及门控
---

# IRC

如果你想让 OpenClaw 运行在经典 IRC 频道（`#room`）和私信中，请使用 IRC。
IRC 以扩展插件形式提供，但配置位于主配置文件的 `channels.irc` 下。

## 快速开始

1. 在 `~/.openclaw/openclaw.json` 中启用 IRC 配置。
2. 至少设置以下内容：

```json5
{
  channels: {
    irc: {
      enabled: true,
      host: "irc.libera.chat",
      port: 6697,
      tls: true,
      nick: "openclaw-bot",
      channels: ["#openclaw"],
    },
  },
}
```

3. 启动或重启 gateway：

```bash
openclaw gateway run
```

## 安全默认值

- `channels.irc.dmPolicy` 默认值为 `"pairing"`。
- `channels.irc.groupPolicy` 默认值为 `"allowlist"`。
- 当 `groupPolicy="allowlist"` 时，设置 `channels.irc.groups` 以定义允许的频道。
- 除非你明确接受明文传输，否则应使用 TLS（`channels.irc.tls=true`）。

## 访问控制

IRC 频道存在两个独立的“门”：

1. **频道访问**（`groupPolicy` + `groups`）：机器人是否接受来自某个频道的消息。
2. **发送者访问**（`groupAllowFrom` / 每频道 `groups["#channel"].allowFrom`）：该频道中谁可以触发机器人。

配置键：

- 私信允许列表（私信发送者访问）：`channels.irc.allowFrom`
- 群组发送者允许列表（频道发送者访问）：`channels.irc.groupAllowFrom`
- 每频道控制（频道 + 发送者 + 提及规则）：`channels.irc.groups["#channel"]`
- `channels.irc.groupPolicy="open"` 允许未配置的频道（**默认仍要求提及**）

允许列表条目应使用稳定的发送者身份（`nick!user@host`）。
裸昵称匹配是可变的，只有在 `channels.irc.dangerouslyAllowNameMatching: true` 时才会启用。

### 常见陷阱：`allowFrom` 用于私信，不用于频道

如果你看到如下日志：

- `irc: drop group sender alice!ident@host (policy=allowlist)`

……这意味着该发送者**没有被允许**发送群组/频道消息。解决方式是：

- 设置 `channels.irc.groupAllowFrom`（对所有频道全局生效），或
- 设置每频道发送者允许列表：`channels.irc.groups["#channel"].allowFrom`

示例（允许 `#tuirc-dev` 中的任何人都能和机器人交互）：

```json5
{
  channels: {
    irc: {
      groupPolicy: "allowlist",
      groups: {
        "#tuirc-dev": { allowFrom: ["*"] },
      },
    },
  },
}
```

## 回复触发（提及）

即使某个频道已被允许（通过 `groupPolicy` + `groups`），且发送者也被允许，OpenClaw 在群组上下文中默认仍然**要求提及**。

这意味着，除非消息中包含能匹配机器人的提及模式，否则你可能会看到诸如 `drop channel … (missing-mention)` 的日志。

如果你希望机器人在 IRC 频道中**无需提及也能回复**，请为该频道关闭提及门控：

```json5
{
  channels: {
    irc: {
      groupPolicy: "allowlist",
      groups: {
        "#tuirc-dev": {
          requireMention: false,
          allowFrom: ["*"],
        },
      },
    },
  },
}
```

或者，如果你想允许**所有** IRC 频道（不使用每频道允许列表），同时也允许无需提及即可回复：

```json5
{
  channels: {
    irc: {
      groupPolicy: "open",
      groups: {
        "*": { requireMention: false, allowFrom: ["*"] },
      },
    },
  },
}
```

## 安全说明（公开频道推荐）

如果你在公开频道中使用 `allowFrom: ["*"]`，任何人都可以向机器人发出提示。
为了降低风险，应为该频道限制可用工具。

### 为频道中的所有人使用相同工具策略

```json5
{
  channels: {
    irc: {
      groups: {
        "#tuirc-dev": {
          allowFrom: ["*"],
          tools: {
            deny: ["group:runtime", "group:fs", "gateway", "nodes", "cron", "browser"],
          },
        },
      },
    },
  },
}
```

### 按发送者区分工具权限（所有者拥有更多权限）

使用 `toolsBySender` 可以对 `"*"` 应用更严格策略，并对你的昵称放宽限制：

```json5
{
  channels: {
    irc: {
      groups: {
        "#tuirc-dev": {
          allowFrom: ["*"],
          toolsBySender: {
            "*": {
              deny: ["group:runtime", "group:fs", "gateway", "nodes", "cron", "browser"],
            },
            "id:eigen": {
              deny: ["gateway", "nodes", "cron"],
            },
          },
        },
      },
    },
  },
}
```

说明：

- `toolsBySender` 的键应对 IRC 发送者身份使用 `id:` 前缀：
  `id:eigen` 或 `id:eigen!~eigen@174.127.248.171`，后者匹配更强。
- 旧版无前缀键仍然可用，并只会按 `id:` 方式匹配。
- 第一个匹配到的发送者策略优先生效；`"*"` 是通配回退。

关于群组访问与提及门控及其相互关系的更多内容，请参见：[/channels/groups](/channels/groups)。

## NickServ

如需在连接后向 NickServ 认证：

```json5
{
  channels: {
    irc: {
      nickserv: {
        enabled: true,
        service: "NickServ",
        password: "your-nickserv-password",
      },
    },
  },
}
```

可选：连接后执行一次性注册：

```json5
{
  channels: {
    irc: {
      nickserv: {
        register: true,
        registerEmail: "bot@example.com",
      },
    },
  },
}
```

在昵称完成注册后，请关闭 `register`，以避免重复尝试 REGISTER。

## 环境变量

默认账号支持：

- `IRC_HOST`
- `IRC_PORT`
- `IRC_TLS`
- `IRC_NICK`
- `IRC_USERNAME`
- `IRC_REALNAME`
- `IRC_PASSWORD`
- `IRC_CHANNELS`（逗号分隔）
- `IRC_NICKSERV_PASSWORD`
- `IRC_NICKSERV_REGISTER_EMAIL`

## 故障排除

- 如果机器人已连接但始终不在频道中回复，请同时检查 `channels.irc.groups` 和提及门控是否正在丢弃消息（`missing-mention`）。如果你希望它无需 ping 也能回复，请为该频道设置 `requireMention:false`。
- 如果登录失败，请检查昵称是否可用，以及服务器密码是否正确。
- 如果在自定义网络上 TLS 失败，请检查 host/port 与证书配置。

## 相关内容

- [聊天渠道概览](/channels) — 所有支持的渠道
- [配对](/channels/pairing) — 私信认证与配对流程
- [群组](/channels/groups) — 群聊行为与提及门控
- [渠道路由](/channels/channel-routing) — 消息的会话路由
- [安全](/gateway/security) — 访问模型与加固
