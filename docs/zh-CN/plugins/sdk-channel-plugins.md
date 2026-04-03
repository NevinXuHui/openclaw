---
title: "构建渠道插件"
sidebarTitle: "渠道插件"
summary: "构建 OpenClaw 消息渠道插件的分步指南"
read_when:
  - 你正在构建新的消息渠道插件
  - 你想将 OpenClaw 连接到某个消息平台
  - 你需要理解 ChannelPlugin 适配器接口
---

# 构建渠道插件

本指南将带你构建一个把 OpenClaw 连接到消息平台的渠道插件。完成后，你将拥有一个具备私信安全、配对、回复线程和出站消息能力的可用渠道。

<Info>
  如果你还没有构建过任何 OpenClaw 插件，请先阅读
  [入门指南](/plugins/building-plugins)，了解基础包结构和清单设置。
</Info>

## 渠道插件的工作方式

渠道插件不需要自带 send/edit/react 工具。OpenClaw 在核心中保留了一个共享的 `message` 工具。你的插件负责：

- **配置** — 账户解析与设置向导
- **安全** — 私信策略和 allowlist
- **配对** — 私信审批流程
- **会话语法** — 提供商特定的会话 id 如何映射到基础 chat、thread id 和父级回退
- **出站** — 向平台发送文本、媒体和投票
- **线程** — 回复如何挂接到线程中

核心负责共享 `message` 工具、提示词连接、外层会话键形状、通用 `:thread:` 记账以及分发。

如果你的平台会在 conversation id 中存储额外作用域，请在插件内通过 `messaging.resolveSessionConversation(...)` 处理这部分解析。这是把 `rawId` 映射为基础 conversation id、可选 thread id、显式 `baseConversationId` 以及任意 `parentConversationCandidates` 的规范 hook。返回 `parentConversationCandidates` 时，请按“最窄父级 → 最宽/基础会话”的顺序排列。

如果某个内置插件需要在渠道注册表启动前完成同样的解析，也可以额外暴露顶层 `session-key-api.ts` 文件，并导出同名的 `resolveSessionConversation(...)`。只有在运行时插件注册表尚不可用时，核心才会使用这个适合引导期的接口。

当插件只需要在通用/raw id 之上补充父级回退时，`messaging.resolveParentConversationCandidates(...)` 仍然可作为旧版兼容回退。如果两个 hook 都存在，核心会优先使用 `resolveSessionConversation(...).parentConversationCandidates`，只有当前者未返回这些值时，才会回退到 `resolveParentConversationCandidates(...)`。

## 审批与渠道能力

大多数渠道插件都不需要编写专门的审批代码。

- 核心负责同聊天中的 `/approve`、共享审批按钮载荷以及通用回退投递。
- 只有当审批鉴权与普通聊天鉴权不同时，才使用 `auth.authorizeActorAction` 或 `auth.getActionAvailabilityState`。
- 当渠道需要定制载荷生命周期行为时，可使用 `outbound.shouldSuppressLocalPayloadPrompt` 或 `outbound.beforeDeliverPayload`，例如隐藏重复的本地审批提示，或在发送前展示输入中状态。
- 只有在需要原生审批路由或抑制回退时才使用 `approvals.delivery`。
- 只有当某个渠道确实需要自定义审批载荷，而不能使用共享渲染器时，才使用 `approvals.render`。
- 如果某个渠道能从现有配置中推断出稳定、类似 owner 的私信身份，请使用 `openclaw/plugin-sdk/approval-runtime` 中的 `createResolvedApproverActionAuthAdapter` 来限制同聊天内的 `/approve`，而不要向核心添加审批专用逻辑。

对于 Slack、Matrix、Microsoft Teams 及类似聊天渠道，默认路径通常已经足够：核心处理审批，而插件只需暴露常规的出站与鉴权能力。

## 演练

<Steps>
  <a id="step-1-package-and-manifest"></a>
  <Step title="包与清单">
    创建标准插件文件。`package.json` 中的 `channel` 字段会让它成为渠道插件：

    <CodeGroup>
    ```json package.json
    {
      "name": "@myorg/openclaw-acme-chat",
      "version": "1.0.0",
      "type": "module",
      "openclaw": {
        "extensions": ["./index.ts"],
        "setupEntry": "./setup-entry.ts",
        "channel": {
          "id": "acme-chat",
          "label": "Acme Chat",
          "blurb": "Connect OpenClaw to Acme Chat."
        }
      }
    }
    ```

    ```json openclaw.plugin.json
    {
      "id": "acme-chat",
      "kind": "channel",
      "channels": ["acme-chat"],
      "name": "Acme Chat",
      "description": "Acme Chat channel plugin",
      "configSchema": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "acme-chat": {
            "type": "object",
            "properties": {
              "token": { "type": "string" },
              "allowFrom": {
                "type": "array",
                "items": { "type": "string" }
              }
            }
          }
        }
      }
    }
    ```
    </CodeGroup>

  </Step>

  <Step title="构建渠道插件对象">
    `ChannelPlugin` 接口包含很多可选的适配器接口。先从最小集合开始——`id` 和 `setup`——再按需增加适配器。

    创建 `src/channel.ts`：

    ```typescript src/channel.ts
    import {
      createChatChannelPlugin,
      createChannelPluginBase,
    } from "openclaw/plugin-sdk/core";
    import type { OpenClawConfig } from "openclaw/plugin-sdk/core";
    import { acmeChatApi } from "./client.js"; // your platform API client

    type ResolvedAccount = {
      accountId: string | null;
      token: string;
      allowFrom: string[];
      dmPolicy: string | undefined;
    };

    function resolveAccount(
      cfg: OpenClawConfig,
      accountId?: string | null,
    ): ResolvedAccount {
      const section = (cfg.channels as Record<string, any>)?.["acme-chat"];
      const token = section?.token;
      if (!token) throw new Error("acme-chat: token is required");
      return {
        accountId: accountId ?? null,
        token,
        allowFrom: section?.allowFrom ?? [],
        dmPolicy: section?.dmSecurity,
      };
    }

    export const acmeChatPlugin = createChatChannelPlugin<ResolvedAccount>({
      base: createChannelPluginBase({
        id: "acme-chat",
        setup: {
          resolveAccount,
          inspectAccount(cfg, accountId) {
            const section =
              (cfg.channels as Record<string, any>)?.["acme-chat"];
            return {
              enabled: Boolean(section?.token),
              configured: Boolean(section?.token),
              tokenStatus: section?.token ? "available" : "missing",
            };
          },
        },
      }),

      // DM security: who can message the bot
      security: {
        dm: {
          channelKey: "acme-chat",
          resolvePolicy: (account) => account.dmPolicy,
          resolveAllowFrom: (account) => account.allowFrom,
          defaultPolicy: "allowlist",
        },
      },

      // Pairing: approval flow for new DM contacts
      pairing: {
        text: {
          idLabel: "Acme Chat username",
          message: "Send this code to verify your identity:",
          notify: async ({ target, code }) => {
            await acmeChatApi.sendDm(target, `Pairing code: ${code}`);
          },
        },
      },

      // Threading: how replies are delivered
      threading: { topLevelReplyToMode: "reply" },

      // Outbound: send messages to the platform
      outbound: {
        attachedResults: {
          sendText: async (params) => {
            const result = await acmeChatApi.sendMessage(
              params.to,
              params.text,
            );
            return { messageId: result.id };
          },
        },
        base: {
          sendMedia: async (params) => {
            await acmeChatApi.sendFile(params.to, params.filePath);
          },
        },
      },
    });
    ```

    <Accordion title="createChatChannelPlugin 为你完成什么">
      你不需要手写底层适配器接口，只要传入声明式选项，builder 就会把它们组合起来：

      | 选项 | 它会连接什么 |
      | --- | --- |
      | `security.dm` | 基于配置字段的作用域化私信安全解析器 |
      | `pairing.text` | 带验证码交换的文本型私信配对流程 |
      | `threading` | reply-to 模式解析器（固定、按账户作用域或自定义） |
      | `outbound.attachedResults` | 返回结果元数据（消息 id）的发送函数 |

      如果你需要完全控制，也可以直接传入原始适配器对象，而不是这些声明式选项。
    </Accordion>

  </Step>

  <Step title="连接入口点">
    创建 `index.ts`：

    ```typescript index.ts
    import { defineChannelPluginEntry } from "openclaw/plugin-sdk/core";
    import { acmeChatPlugin } from "./src/channel.js";

    export default defineChannelPluginEntry({
      id: "acme-chat",
      name: "Acme Chat",
      description: "Acme Chat channel plugin",
      plugin: acmeChatPlugin,
      registerCliMetadata(api) {
        api.registerCli(
          ({ program }) => {
            program
              .command("acme-chat")
              .description("Acme Chat management");
          },
          {
            descriptors: [
              {
                name: "acme-chat",
                description: "Acme Chat management",
                hasSubcommands: false,
              },
            ],
          },
        );
      },
      registerFull(api) {
        api.registerGatewayMethod(/* ... */);
      },
    });
    ```

    把由渠道拥有的 CLI descriptor 放在 `registerCliMetadata(...)` 中，这样 OpenClaw 就能在不激活完整渠道运行时的前提下，在根帮助里展示它们；而正常的完整加载仍然会拾取同样的 descriptor 来完成真实命令注册。把 `registerFull(...)` 留给仅运行时需要的工作。
    `defineChannelPluginEntry` 会自动处理不同注册模式的拆分。完整选项见
    [入口点](/plugins/sdk-entrypoints#definechannelpluginentry)。

  </Step>

  <Step title="添加 setup entry">
    创建 `setup-entry.ts`，用于在新手引导期间进行轻量加载：

    ```typescript setup-entry.ts
    import { defineSetupPluginEntry } from "openclaw/plugin-sdk/core";
    import { acmeChatPlugin } from "./src/channel.js";

    export default defineSetupPluginEntry(acmeChatPlugin);
    ```

    当渠道被禁用或尚未配置时，OpenClaw 会加载这个入口，而不是完整入口。这样可以在设置流程中避免拉入沉重的运行时代码。详见 [设置与配置](/plugins/sdk-setup#setup-entry)。

  </Step>

  <Step title="处理入站消息">
    你的插件需要从平台接收消息并转发给 OpenClaw。典型模式是一个 webhook，它会验证请求并通过你渠道的入站处理器进行分发：

    ```typescript
    registerFull(api) {
      api.registerHttpRoute({
        path: "/acme-chat/webhook",
        auth: "plugin", // plugin-managed auth (verify signatures yourself)
        handler: async (req, res) => {
          const event = parseWebhookPayload(req);

          // Your inbound handler dispatches the message to OpenClaw.
          // The exact wiring depends on your platform SDK —
          // see a real example in the bundled Microsoft Teams or Google Chat plugin package.
          await handleAcmeChatInbound(api, event);

          res.statusCode = 200;
          res.end("ok");
          return true;
        },
      });
    }
    ```

    <Note>
      入站消息处理是渠道特定的。每个渠道插件都拥有自己的入站流水线。请查看内置渠道插件（例如 Microsoft Teams 或 Google Chat 插件包）来参考真实模式。
    </Note>

  </Step>

<a id="step-6-test"></a>
<Step title="测试">
编写与代码同目录放置的测试文件 `src/channel.test.ts`：

    ```typescript src/channel.test.ts
    import { describe, it, expect } from "vitest";
    import { acmeChatPlugin } from "./channel.js";

    describe("acme-chat plugin", () => {
      it("resolves account from config", () => {
        const cfg = {
          channels: {
            "acme-chat": { token: "test-token", allowFrom: ["user1"] },
          },
        } as any;
        const account = acmeChatPlugin.setup!.resolveAccount(cfg, undefined);
        expect(account.token).toBe("test-token");
      });

      it("inspects account without materializing secrets", () => {
        const cfg = {
          channels: { "acme-chat": { token: "test-token" } },
        } as any;
        const result = acmeChatPlugin.setup!.inspectAccount!(cfg, undefined);
        expect(result.configured).toBe(true);
        expect(result.tokenStatus).toBe("available");
      });

      it("reports missing config", () => {
        const cfg = { channels: {} } as any;
        const result = acmeChatPlugin.setup!.inspectAccount!(cfg, undefined);
        expect(result.configured).toBe(false);
      });
    });
    ```

    ```bash
    pnpm test -- <bundled-plugin-root>/acme-chat/
    ```

    共享测试辅助见 [测试](/plugins/sdk-testing)。

  </Step>
</Steps>

## 文件结构

```
<bundled-plugin-root>/acme-chat/
├── package.json              # openclaw.channel metadata
├── openclaw.plugin.json      # Manifest with config schema
├── index.ts                  # defineChannelPluginEntry
├── setup-entry.ts            # defineSetupPluginEntry
├── api.ts                    # Public exports (optional)
├── runtime-api.ts            # Internal runtime exports (optional)
└── src/
    ├── channel.ts            # ChannelPlugin via createChatChannelPlugin
    ├── channel.test.ts       # Tests
    ├── client.ts             # Platform API client
    └── runtime.ts            # Runtime store (if needed)
```

## 高级主题

<CardGroup cols={2}>
  <Card title="线程选项" icon="git-branch" href="/plugins/sdk-entrypoints#registration-mode">
    固定、按账户作用域或自定义的回复模式
  </Card>
  <Card title="消息工具集成" icon="puzzle" href="/plugins/architecture#channel-plugins-and-the-shared-message-tool">
    describeMessageTool 与动作发现
  </Card>
  <Card title="目标解析" icon="crosshair" href="/plugins/architecture#channel-target-resolution">
    inferTargetChatType、looksLikeId、resolveTarget
  </Card>
  <Card title="运行时辅助" icon="settings" href="/plugins/sdk-runtime">
    通过 api.runtime 使用 TTS、STT、媒体与子智能体
  </Card>
</CardGroup>

## 下一步

- [提供商插件](/plugins/sdk-provider-plugins) — 如果你的插件还提供模型
- [SDK 概览](/plugins/sdk-overview) — 完整子路径导入参考
- [SDK 测试](/plugins/sdk-testing) — 测试工具与契约测试
- [插件清单](/plugins/manifest) — 完整清单 schema
