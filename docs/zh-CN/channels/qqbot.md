---
summary: "QQ Bot 设置、配置与使用方式"
read_when:
  - 你想把 OpenClaw 连接到 QQ
  - 你需要设置 QQ Bot 凭证
  - 你想启用 QQ Bot 群聊或私聊支持
title: QQ Bot
---

# QQ Bot

QQ Bot 通过官方 QQ Bot API（WebSocket gateway）连接到 OpenClaw。该插件支持 C2C 私聊、群组 @ 消息和频道消息，并支持丰富媒体（图片、语音、视频、文件）。

状态：内置渠道插件。支持私信、群聊、频道和媒体。不支持 reactions 和 threads。

## 随 OpenClaw 捆绑提供

当前的 OpenClaw 安装已内置 QQ Bot。正常设置时，你无需再执行额外的 `openclaw plugins install`。

## 设置

1. 前往 [QQ 开放平台](https://q.qq.com/)，用手机 QQ 扫码完成注册 / 登录。
2. 点击 **Create Bot** 创建一个新的 QQ 机器人。
3. 在机器人的设置页面中找到 **AppID** 和 **AppSecret** 并复制它们。

> AppSecret 不会以明文形式再次显示 —— 如果你离开页面前没有保存，就必须重新生成一个新的。

4. 添加该渠道：

```bash
openclaw channels add --channel qqbot --token "AppID:AppSecret"
```

5. 重启 Gateway 网关。

交互式设置路径：

```bash
openclaw channels add
openclaw configure --section channels
```

## 配置

最小配置：

```json5
{
  channels: {
    qqbot: {
      enabled: true,
      appId: "YOUR_APP_ID",
      clientSecret: "YOUR_APP_SECRET",
    },
  },
}
```

默认账号环境变量：

- `QQBOT_APP_ID`
- `QQBOT_CLIENT_SECRET`

文件形式的 AppSecret：

```json5
{
  channels: {
    qqbot: {
      enabled: true,
      appId: "YOUR_APP_ID",
      clientSecretFile: "/path/to/qqbot-secret.txt",
    },
  },
}
```

说明：

- 环境变量回退仅适用于默认 QQ Bot 账号。
- `openclaw channels add --channel qqbot --token-file ...` 只会提供 AppSecret；AppID 仍必须已存在于配置中或 `QQBOT_APP_ID` 中。
- `clientSecret` 除了明文字符串，也支持 SecretRef 输入。

### 多账号设置

在单个 OpenClaw 实例中运行多个 QQ 机器人：

```json5
{
  channels: {
    qqbot: {
      enabled: true,
      appId: "111111111",
      clientSecret: "secret-of-bot-1",
      accounts: {
        bot2: {
          enabled: true,
          appId: "222222222",
          clientSecret: "secret-of-bot-2",
        },
      },
    },
  },
}
```

每个账号都会启动自己的 WebSocket 连接，并维护独立的 token 缓存（按 `appId` 隔离）。

通过 CLI 添加第二个机器人：

```bash
openclaw channels add --channel qqbot --account bot2 --token "222222222:secret-of-bot-2"
```

### 语音（STT / TTS）

STT 和 TTS 支持两级配置与优先级回退：

| Setting | Plugin-specific      | Framework fallback            |
| ------- | -------------------- | ----------------------------- |
| STT     | `channels.qqbot.stt` | `tools.media.audio.models[0]` |
| TTS     | `channels.qqbot.tts` | `messages.tts`                |

```json5
{
  channels: {
    qqbot: {
      stt: {
        provider: "your-provider",
        model: "your-stt-model",
      },
      tts: {
        provider: "your-provider",
        model: "your-tts-model",
        voice: "your-voice",
      },
    },
  },
}
```

将任一项设置为 `enabled: false` 即可禁用。

出站音频上传 / 转码行为也可以通过 `channels.qqbot.audioFormatPolicy` 调整：

- `sttDirectFormats`
- `uploadDirectFormats`
- `transcodeEnabled`

## 目标格式

| Format                     | 说明        |
| -------------------------- | ----------- |
| `qqbot:c2c:OPENID`         | 私聊（C2C） |
| `qqbot:group:GROUP_OPENID` | 群聊        |
| `qqbot:channel:CHANNEL_ID` | 频道        |

> 每个机器人都有自己的一组用户 OpenID。由 Bot A 收到的 OpenID **不能** 用于通过 Bot B 发送消息。

## Slash 命令

在进入 AI 队列之前就会被拦截的内置命令：

| Command        | 说明                            |
| -------------- | ------------------------------- |
| `/bot-ping`    | 延迟测试                        |
| `/bot-version` | 显示 OpenClaw 框架版本          |
| `/bot-help`    | 列出所有命令                    |
| `/bot-upgrade` | 显示 QQBot 升级指南链接         |
| `/bot-logs`    | 将最近的 gateway 日志导出为文件 |

在任意命令后追加 `?` 可查看用法帮助（例如 `/bot-upgrade ?`）。

## 故障排除

- **机器人回复 “gone to Mars”**：凭证未配置，或 Gateway 网关尚未启动。
- **没有收到入站消息**：请确认 `appId` 和 `clientSecret` 正确，且机器人已在 QQ 开放平台启用。
- **使用 `--token-file` 设置后仍显示未配置**：`--token-file` 只设置 AppSecret。你仍然需要在配置或 `QQBOT_APP_ID` 中提供 `appId`。
- **主动发送的消息未送达**：如果用户近期没有交互，QQ 可能会拦截机器人主动发起的消息。
- **语音未被转写**：请确认已配置 STT，且提供商可访问。
