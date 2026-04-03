---
summary: "社区维护的 OpenClaw 插件：浏览、安装并提交你自己的插件"
read_when:
  - 你想查找第三方 OpenClaw 插件
  - 你想发布或列出自己的插件
title: "社区插件"
---

# 社区插件

社区插件是第三方软件包，可为 OpenClaw 扩展新的渠道、工具、提供商或其他能力。它们由社区构建和维护，发布在 [ClawHub](/tools/clawhub) 或 npm 上，并且可以通过一条命令安装。

```bash
openclaw plugins install <package-name>
```

OpenClaw 会先检查 ClawHub，并自动回退到 npm。

## 已收录的插件

### Codex App Server Bridge

面向 Codex App Server 对话的独立 OpenClaw 桥接。可将聊天绑定到 Codex 线程，通过纯文本与之对话，并使用聊天原生命令控制恢复、规划、审查、模型选择、压缩等。

- **npm:** `openclaw-codex-app-server`
- **repo:** [github.com/pwrdrvr/openclaw-codex-app-server](https://github.com/pwrdrvr/openclaw-codex-app-server)

```bash
openclaw plugins install openclaw-codex-app-server
```

### DingTalk

使用 Stream 模式的企业机器人集成。支持通过任意 DingTalk 客户端收发文本、图片和文件消息。

- **npm:** `@largezhou/ddingtalk`
- **repo:** [github.com/largezhou/openclaw-dingtalk](https://github.com/largezhou/openclaw-dingtalk)

```bash
openclaw plugins install @largezhou/ddingtalk
```

### Lossless Claw (LCM)

面向 OpenClaw 的 Lossless Context Management 插件。基于 DAG 的会话摘要与增量压缩，在降低 token 用量的同时保留完整上下文保真度。

- **npm:** `@martian-engineering/lossless-claw`
- **repo:** [github.com/Martian-Engineering/lossless-claw](https://github.com/Martian-Engineering/lossless-claw)

```bash
openclaw plugins install @martian-engineering/lossless-claw
```

### Opik

官方插件，可将智能体追踪导出到 Opik。用于监控智能体行为、成本、tokens、错误等。

- **npm:** `@opik/opik-openclaw`
- **repo:** [github.com/comet-ml/opik-openclaw](https://github.com/comet-ml/opik-openclaw)

```bash
openclaw plugins install @opik/opik-openclaw
```

### QQbot

通过 QQ Bot API 将 OpenClaw 连接到 QQ。支持私聊、群提及、频道消息，以及语音、图片、视频和文件等富媒体。

- **npm:** `@sliverp/qqbot`
- **repo:** [github.com/sliverp/qqbot](https://github.com/sliverp/qqbot)

```bash
openclaw plugins install @sliverp/qqbot
```

### wecom

OpenClaw 企业微信渠道插件。
基于企业微信 AI Bot WebSocket 长连接，支持私聊与群聊、流式回复和主动消息发送。

- **npm:** `@wecom/wecom-openclaw-plugin`
- **repo:** [github.com/WecomTeam/wecom-openclaw-plugin](https://github.com/WecomTeam/wecom-openclaw-plugin)

```bash
openclaw plugins install @wecom/wecom-openclaw-plugin
```

## 提交你的插件

我们欢迎有用、文档完善且可安全运行的社区插件。

<Steps>
  <Step title="发布到 ClawHub 或 npm">
    你的插件必须能够通过 `openclaw plugins install \<package-name\>` 安装。
    请发布到 [ClawHub](/tools/clawhub)（推荐）或 npm。
    完整指南见 [构建插件](/plugins/building-plugins)。

  </Step>

  <Step title="托管到 GitHub">
    源代码必须位于公开仓库中，并包含设置文档和 issue 跟踪器。

  </Step>

  <Step title="发起 PR">
    将你的插件添加到本页面，并提供：

    - 插件名称
    - npm 包名
    - GitHub 仓库 URL
    - 一行描述
    - 安装命令

  </Step>
</Steps>

## 质量门槛

| 要求                  | 原因                                           |
| --------------------- | ---------------------------------------------- |
| 发布到 ClawHub 或 npm | 用户需要 `openclaw plugins install` 能正常工作 |
| 公开的 GitHub 仓库    | 便于审查源码、跟踪 issue，并保持透明           |
| 设置与使用文档        | 用户需要知道如何配置                           |
| 持续维护              | 近期有更新或能及时响应 issue                   |

低投入封装、归属不清或无人维护的软件包可能会被拒绝。

## 相关内容

- [安装并配置插件](/tools/plugin) — 如何安装任意插件
- [构建插件](/plugins/building-plugins) — 创建你自己的插件
- [插件清单](/plugins/manifest) — 清单 schema
