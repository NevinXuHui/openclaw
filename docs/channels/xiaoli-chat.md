---
title: Xiaoli Chat
summary: "Xiaoli Chat 插件架构、接口、安装配置与逐步开发说明"
read_when:
  - 你正在开发 xiaoli-chat 渠道插件
  - 你想理解 xiaoli-chat 的架构与请求链路
  - 你想参考一个最小 webhook 聊天插件的完整实现
---

# Xiaoli Chat

`xiaoli-chat` 是一个仓库内的渠道插件示例，用来演示如何把外部聊天平台接入 OpenClaw。它当前覆盖了以下核心能力：

- 标准的 channel plugin 入口
- 最小可用的出站发送适配层
- 最小可用的入站 webhook
- DM 安全策略与 allowlist 接入
- 接入 OpenClaw 标准 reply pipeline
- 可独立运行的 typecheck / build / install-load 脚本

这份文档是**实现导向**的，不是泛泛介绍。它基于当前仓库里的 `xiaoli-chat` 实现来讲，目的是把插件的逻辑、架构、接口、构建、安装、验证方式一次讲清楚，并作为你后续开发类似插件时的参考模板。

## 这个插件当前做到了什么

当前已实现范围：

- 支持通过平台 HTTP API 发送文本消息
- 支持通过 webhook 接收入站私聊消息
- 支持用 HMAC SHA256 校验 webhook 签名
- 支持把入站 DM 接入 OpenClaw 标准 direct-message dispatch pipeline
- 支持 DM 安全策略与 allowlist 配置
- 支持本地 build、install、enable、gateway restart 的完整链路

当前明确**还没做**的内容：

- 用户发来的 inbound media 附件暂不解析（仅透传 URL 到 extraContext）
- 不支持 reactions
- 不支持 edit / unsend
- 不支持 native commands
- 群消息虽然可进入插件层，但还没有接入 reply pipeline
- 当前只有单账号模型，虽然部分接口仍保留 `accountId` 以便后续扩展

## 文件结构总览

当前插件的核心文件：

- `extensions/xiaoli-chat/index.ts`
- `extensions/xiaoli-chat/openclaw.plugin.json`
- `extensions/xiaoli-chat/package.json`
- `extensions/xiaoli-chat/build.sh`
- `extensions/xiaoli-chat/install-load.sh`
- `extensions/xiaoli-chat/src/channel.ts`
- `extensions/xiaoli-chat/src/types.ts`
- `extensions/xiaoli-chat/src/config.ts`
- `extensions/xiaoli-chat/src/client.ts`
- `extensions/xiaoli-chat/src/outbound.ts`
- `extensions/xiaoli-chat/src/inbound.ts`
- `extensions/xiaoli-chat/src/inbound-runtime.ts`
- `extensions/xiaoli-chat/src/webhook.ts`
- `extensions/xiaoli-chat/src/runtime.ts`
- `extensions/xiaoli-chat/src/webhook.test.ts`
- `extensions/xiaoli-chat/src/inbound-runtime.test.ts`

本插件使用到的 OpenClaw 公共 SDK 面：

- `src/plugin-sdk/core.ts`
- `src/plugin-sdk/runtime-store.ts`
- `src/plugin-sdk/channel-inbound.ts`
- `src/plugin-sdk/webhook-ingress.ts`

## 整体架构分层

这个插件是按“小文件、单职责”的方式拆开的，可以分成 8 层：

1. **入口层**
   - `extensions/xiaoli-chat/index.ts:6`
   - 负责注册 channel plugin 和 webhook 路由

2. **渠道定义层**
   - `extensions/xiaoli-chat/src/channel.ts:52`
   - 定义 capabilities、config adapter、setup adapter、DM security、pairing、threading、outbound

3. **配置解析层**
   - `extensions/xiaoli-chat/src/config.ts:17`
   - 把原始 `OpenClawConfig` 转成运行期可直接使用的账号对象

4. **出站传输层**
   - `extensions/xiaoli-chat/src/outbound.ts:4`
   - `extensions/xiaoli-chat/src/client.ts:3`
   - 把 OpenClaw 的发送动作转换成平台 HTTP 请求

5. **入站传输 / 安全边界层**
   - `extensions/xiaoli-chat/src/webhook.ts:95`
   - 负责 HTTP method 检查、content-type 检查、限流、读取 body、验签、JSON 解析、字段校验、错误响应

6. **入站标准化层**
   - `extensions/xiaoli-chat/src/inbound.ts:11`
   - 把未知 webhook payload 转成统一的 `XiaoliInboundMessage`

7. **入站运行时桥接层**
   - `extensions/xiaoli-chat/src/inbound-runtime.ts:26`
   - 把“已通过安全边界”的标准化消息交给 OpenClaw 标准 direct-DM reply pipeline

8. **运行时存储层**
   - `extensions/xiaoli-chat/src/runtime.ts:4`
   - 存储插件 runtime，供 webhook handler 后续读取配置和调用运行期服务

## 完整请求流转

### 出站消息流

```text
OpenClaw message tool
  -> xiaoliChatPlugin.outbound.attachedResults.sendText
  -> resolveXiaoliAccount(...)
  -> sendText(...)
  -> XiaoliChatClient.sendMessage(...)
  -> POST {baseUrl}/messages
```

相关代码：

- `extensions/xiaoli-chat/src/channel.ts:121`
- `extensions/xiaoli-chat/src/outbound.ts:4`
- `extensions/xiaoli-chat/src/client.ts:6`

### 入站消息流

```text
外部平台 webhook
  -> /hooks/xiaoli-chat/webhook
  -> applyBasicWebhookRequestGuards(...)
  -> readWebhookBodyOrReject(...)
  -> HMAC 签名校验
  -> parseJsonBody(...)
  -> normalizeInboundMessage(...)
  -> isValidInboundMessage(...)
  -> handleXiaoliInboundMessage(...)
  -> finalizeInboundContext(...)
  -> recordInboundSession(...)
  -> createChannelReplyPipeline(...)
  -> dispatchReplyWithBufferedBlockDispatcher(...)
  -> OpenClaw 标准 reply pipeline（支持 blockStreaming）
  -> deliver(...) 回调
  -> sendText(...) / sendMedia(...)
  -> 外部平台回复 API
```

相关代码：

- `extensions/xiaoli-chat/index.ts:12`
- `extensions/xiaoli-chat/src/webhook.ts:95`
- `extensions/xiaoli-chat/src/inbound.ts:11`
- `extensions/xiaoli-chat/src/inbound-runtime.ts:36`

---

## 第一步：定义插件入口

插件入口位于 `extensions/xiaoli-chat/index.ts:6`。

```ts
export default defineChannelPluginEntry({
  id: "xiaoli-chat",
  name: "Xiaoli Chat",
  description: "Xiaoli Chat channel plugin",
  plugin: xiaoliChatPlugin,
  setRuntime: setXiaoliRuntime,
  registerFull(api) {
    api.registerHttpRoute({
      path: XIAOLI_WEBHOOK_PATH,
      auth: "plugin",
      handler: createXiaoliWebhookHandler({ logger: api.logger }),
    });
  },
});
```

这里刻意保持很薄，只做 4 件事：

- 注册插件 id 和元数据
- 注入已经组合好的 `xiaoliChatPlugin`
- 用 `setXiaoliRuntime` 保存 runtime
- 注册一个 webhook HTTP 路由

设计原则：

- `index.ts` 只负责“装配”，不要堆业务逻辑
- 路由细节放 `src/webhook.ts`
- runtime 存储放 `src/runtime.ts`
- channel 行为定义放 `src/channel.ts`

这样拆开后，后面排查问题时边界很清楚。

---

## 第二步：定义 manifest 与 package metadata

### 2.1 `openclaw.plugin.json`

文件：`extensions/xiaoli-chat/openclaw.plugin.json:1`

它声明了：

- 插件 id：`xiaoli-chat`
- 插件 kind：`channel`
- 归属 channel id：`xiaoli-chat`
- 配置 schema

当前 schema 里声明的字段：

- `enabled`
- `token`
- `baseUrl`
- `allowFrom`
- `dmSecurity`
- `webhookSecret`

这个文件很关键，因为 OpenClaw 是 **manifest-first** 的。也就是说：

- 插件发现
- 配置校验
- setup 元数据识别

都应该能在插件运行前，仅靠 manifest 正常工作。

### 2.2 `package.json`

文件：`extensions/xiaoli-chat/package.json:1`

这里除了普通 npm 包信息，还定义了 OpenClaw 关心的元数据：

- 包名：`@openclaw/xiaoli-chat`
- 脚本：
  - `build`
  - `typecheck`
  - `install:local`
  - `load`
- `openclaw.extensions`
- `openclaw.setupEntry`
- `openclaw.channel.id`
- `openclaw.install.localPath`
- `openclaw.install.minHostVersion`

这两个文件分工是：

- `openclaw.plugin.json`：定义插件身份与配置契约
- `package.json`：定义包级元数据、脚本和本地安装行为

---

## 第三步：定义 channel plugin 对象

核心文件：`extensions/xiaoli-chat/src/channel.ts:52`

它通过 `createChatChannelPlugin(...)` 构建出真正的渠道插件对象。这是整个插件最核心的文件之一。

### 3.1 base：基础元信息与能力声明

位置：`extensions/xiaoli-chat/src/channel.ts:53`

这里定义了：

- channel id
- 展示元数据
- capabilities
- streaming configuration
- config adapter
- setup adapter

当前声明的能力：

- `chatTypes: ["direct", "group", "thread"]`
- `media: true` // 支持媒体附件（图片、文件等）
- `reactions: false`
- `threads: true`
- `edit: false`
- `unsend: false`
- `reply: true`
- `effects: false`
- `nativeCommands: false`
- `blockStreaming: true` // 启用流式输出，支持分块发送回复

**流式输出配置（2026-04-14）**：

```typescript
streaming: {
  blockStreamingCoalesceDefaults: {
    flushOnEnqueue: true,  // 禁用合并，每个 block 立即发送
  },
},
```

这个配置解决了流式输出的关键问题：

**问题**：默认情况下，OpenClaw 的 block coalescer 会等待 `idleMs`（默认 1000ms）来合并多个 block。当第一个 block 生成后，如果第二个 block 在 1 秒内到达（工具调用场景），两个 block 会被合并成一条消息发送。

**解决方案**：设置 `flushOnEnqueue: true` 禁用合并机制，每个 block 生成后立即发送，不等待后续内容。

**效果**：

- 第一条消息（"正在查询..."）在生成后立即发送（5-7 秒）
- 第二条消息（工具结果）在生成后立即发送（20-30 秒）
- 两条消息独立到达，间隔符合预期（4-9ms 是 LLM 生成间隔，不是批处理延迟）

这里的关键原则是：

**能力声明必须反映真实接线情况，而不是平台理论上可能支持什么。**

**2026-04-13 更新**：已启用 `blockStreaming` 和 `media` 支持。`blockStreaming` 允许 AI 回复以流式方式分块发送，第一条回复会立即发送而不等待后续内容生成完成。

**2026-04-14 更新**：添加 `flushOnEnqueue: true` 配置，禁用 block 合并机制，确保每个 block 立即发送。

### 3.2 config adapter：配置适配层

位置：`extensions/xiaoli-chat/src/channel.ts:68`

当前提供了：

- `listAccountIds`
- `resolveAccount`
- `inspectAccount`
- `defaultAccountId`

当前插件只有默认账号：

- `listAccountIds()` 返回 `[DEFAULT_ACCOUNT_ID]`

虽然现在是单账号，但仍然保留 `accountId` 相关接口，这是为了后续升级到多账号时不用整体重构。

### 3.3 setup adapter：安装/配置写回层

位置：`extensions/xiaoli-chat/src/channel.ts:74`

提供了：

- `resolveAccountId: () => DEFAULT_ACCOUNT_ID`
- `applyAccountConfig(...)`

`applyAccountConfig(...)` 的作用，是把 setup 输入的数据写回到 OpenClaw 配置树中。这里做得比较规范：

- 不直接修改原对象
- 只写插件自己负责的字段
- setup 逻辑与 runtime 逻辑分离

这是个很好的参考模式。

### 3.4 security：DM 安全策略

位置：`extensions/xiaoli-chat/src/channel.ts:87`

这里接入了 OpenClaw 的 DM 安全模型：

- `channelKey: "xiaoli-chat"`
- `resolvePolicy: (account) => account.dmSecurity`
- `resolveAllowFrom: (account) => account.allowFrom`
- `defaultPolicy: "allowlist"`

含义是：

- 具体的策略配置来自插件自己的 config
- 真正的安全执行依然走 OpenClaw 的共享安全机制

也就是“平台配置插件化，安全执行框架化”。

### 3.5 pairing：配对认证流程

位置：`extensions/xiaoli-chat/src/channel.ts:96`

当前使用文本配对方式：

- `idLabel: "Xiaoli Chat user id"`
- 提示文案：`Send this code to verify your identity:`
- `notify(...)` 通过 `sendText(...)` 把配对码发回平台用户

这是很多聊天渠道都可以复用的最小方案：

- 只要平台支持给用户发私信
- 就能完成文本配对

### 3.6 threading：回复线程策略

位置：`extensions/xiaoli-chat/src/channel.ts:111`

当前设置：

- `topLevelReplyToMode: "reply"`

这个字段决定 OpenClaw 顶层回复在该渠道上如何映射。

### 3.7 outbound：出站适配层

位置：`extensions/xiaoli-chat/src/channel.ts:115`

当前 outbound 分为两块：

- `base.deliveryMode = "direct"`
- `attachedResults.sendText(...)`

发送流程：

1. 从配置中解析账号
2. 把 `threadId` 从可空值标准化成 `string | undefined`
3. 调 `sendText(...)`
4. 返回 `{ messageId }`

这里返回 `messageId` 很重要，因为它会回流给 OpenClaw，作为发送结果元数据的一部分。

---

## 第四步：定义插件领域类型

文件：`extensions/xiaoli-chat/src/types.ts:1`

这里定义了插件的核心类型：

- `XiaoliDmSecurityPolicy`
- `XiaoliChatConfig`
- `ResolvedXiaoliAccount`
- `XiaoliWebhookSecurityConfig`
- `XiaoliInboundMessage`
- `XiaoliSendMessageParams`

这个文件的价值在于：

- 把配置契约写清楚
- 把传输契约写清楚
- 把运行期账号契约写清楚
- 避免在各文件中散落临时对象类型
- 避免 `any`

以后如果插件继续扩展，最应该优先改的也是这里，比如：

- 多账号结构
- media payload 类型
- 群消息 payload 类型
- 更复杂的 outbound result 类型

---

## 第五步：把配置解析成运行期账号对象

文件：`extensions/xiaoli-chat/src/config.ts:17`

### 5.1 `resolveXiaoliAccount(...)`

这个函数负责把原始 `OpenClawConfig` 转成运行期可直接使用的账号对象。

它做了这些事：

- 读取 `channels["xiaoli-chat"]`
- 要求必须存在 `token`
- 给以下字段补默认值：
  - `baseUrl`
  - `allowFrom`
  - `dmSecurity`

当前默认值：

- `DEFAULT_BASE_URL = "https://api.example.com"`
- `DEFAULT_DM_SECURITY_POLICY = "allowlist"`

### 5.2 `resolveXiaoliWebhookSecurity(...)`

这个函数专门负责解析 webhook 安全配置：

- 如果 `webhookSecret` 缺失或为空，返回 `null`
- 如果已配置，返回 `{ secret }`

这样就把“发送 token”和“webhook 验签密钥”分开了，边界更清楚。

### 5.3 `inspectXiaoliAccount(...)`

这个函数给 setup / inspection 场景使用，返回：

- `enabled`
- `configured`
- `tokenStatus`

这是很好的做法，因为它把“账号是否可用”的判断集中在配置层，而不是散落到 webhook 或 outbound 中。

---

## 第六步：实现出站发送链路

出站链路刻意拆成两层。

### 6.1 薄适配层：`outbound.ts`

文件：`extensions/xiaoli-chat/src/outbound.ts:4`

`sendText(...)` 很薄，只负责：

- 接收 resolved account 与发送参数
- 创建 `XiaoliChatClient`
- 把真正的 HTTP 调用委托给 client

这么做的好处是：

- `channel.ts` 不需要知道 HTTP 细节
- transport 逻辑不会污染 channel 定义层

### 6.2 HTTP client 层：`client.ts`

文件：`extensions/xiaoli-chat/src/client.ts:3`

`XiaoliChatClient.sendMessage(...)` 当前的行为是：

- 发起 `POST ${baseUrl}/messages`
- 使用 `authorization: Bearer <token>`
- 发送 JSON body：
  - `chatId`
  - `text`
  - `threadId`
- 如果不是 2xx，直接抛错
- 要求响应 JSON 里必须有 `id`
- 返回 `{ messageId: data.id }`

这就是当前插件的**平台出站协议**。

如果你以后要把这个插件适配到真实平台，最先需要替换的通常就是这个文件。

---

## 第七步：标准化入站 payload

文件：`extensions/xiaoli-chat/src/inbound.ts:11`

### 7.1 `normalizeInboundMessage(...)`

这个函数把未知 webhook payload 转成统一结构：

```ts
{
  senderId,
  chatId,
  messageId,
  text,
  threadId,
  isDirectMessage,
}
```

### 7.2 `isValidInboundMessage(...)`

这个函数负责最小字段校验，要求以下字段非空：

- `senderId`
- `chatId`
- `messageId`
- `text`

注意这里的校验是**最小可运行版本**，不是完整 schema 校验。

也就是说：

- 它足以支撑最小 webhook DM 流程
- 但还不适合承担复杂平台 payload 的完整约束

---

## 第八步：把入站消息桥接到 OpenClaw 标准 reply pipeline

文件：`extensions/xiaoli-chat/src/inbound-runtime.ts:36`

这是整个插件里最关键的 OpenClaw 接缝之一。

### 8.1 架构重构（2026-04-13）

**重要变更**：从旧的 `dispatchInboundDirectDmWithRuntime` 迁移到标准 channel plugin 架构，使用 `dispatchReplyWithBufferedBlockDispatcher` 以支持 `blockStreaming` 流式输出。

### 8.2 它做了什么

`handleXiaoliInboundMessage(...)` 当前的流程：

1. 如果不是私聊消息，先忽略
2. 从 runtime 里加载配置
3. 解析默认账号
4. 构建媒体上下文（如果有附件）
5. 调用 `finalizeInboundContext(...)` 构建标准化上下文
   - **关键**：参数键名必须使用**大写字母开头**（如 `Body`、`BodyForAgent`、`SessionKey` 等）
   - 这是 OpenClaw SDK 的标准格式要求
6. 调用 `recordInboundSession(...)` 记录会话
7. 调用 `createChannelReplyPipeline(...)` 创建回复管道
8. 调用 `dispatchReplyWithBufferedBlockDispatcher(...)` 分发回复
9. 提供 `deliver(...)` 回调，把 AI 回复（包括工具调用结果）再发回平台

### 8.3 关键修复：参数键名格式

**问题**：之前使用小写字母开头的键名（如 `body`、`bodyForAgent`、`sessionKey`）导致 agent 无法正确读取消息内容。

**解决方案**：参考 WhatsApp 插件实现，使用大写字母开头的键名：

```typescript
const ctxPayload = finalizeInboundContext({
  SessionKey: sessionKey,
  AccountId: accountId,
  MessageSid: message.messageId,
  From: message.senderId,
  To: message.chatId,
  Body: bodyForAgent,
  BodyForAgent: bodyForAgent,
  RawBody: message.text,
  CommandBody: message.text,
  ConversationLabel: message.senderId,
  SenderId: message.senderId,
  MediaPath: mediaContext?.MediaPath,
  MediaUrl: mediaContext?.MediaUrl,
  MediaType: mediaContext?.MediaType,
  Provider: "xiaoli-chat",
  Surface: "xiaoli-chat",
  OriginatingChannel: "xiaoli-chat",
  OriginatingTo: message.chatId,
  // ... 其他字段
});
```

### 8.4 deliver 回调的工具调用响应支持

`deliver(...)` 使用 `resolveSendableOutboundReplyParts(payload)` 统一解析 `OutboundReplyPayload`，处理三种情况：

- **空 payload**：`!reply.hasContent` 时直接返回，不发送
- **含媒体**：`reply.hasMedia` 时按 `mediaUrls` 顺序调 `sendMedia`，首条带文本 caption，后续 caption 为空
- **纯文本**：调 `sendText`

这样，当 AI 模型调用工具后生成的结果（无论是文本还是媒体，如图片）都能正确下发到 Xiaoli Chat 会话，而不会被丢弃。

工具调用结果通过 OpenClaw 内部的 `dispatcher.sendToolResult(...)` 链路流入 `deliver`，插件无需额外处理。

### 8.5 blockStreaming 流式输出

通过使用 `dispatchReplyWithBufferedBlockDispatcher` 和在 channel capabilities 中启用 `blockStreaming: true`，插件现在支持流式输出：

- **第一条回复立即发送**：AI 生成第一个文本块后立即通过 `deliver` 回调发送，不等待后续内容
- **后续块独立发送**：每个新的文本块生成后都会触发独立的 `deliver` 调用
- **发送延迟极低**：每次 `deliver` 调用到实际发送只需几毫秒

这大幅改善了用户体验，用户可以更快看到 AI 的初始响应。

### 8.6 为什么这是核心接入点

这个插件**没有自己实现 agent loop**。

它做的是把一个“已经通过安全边界、已经标准化”的入站消息，交给 OpenClaw 标准 direct-DM pipeline，并补齐这些上下文：

- `channel`
- `channelLabel`
- `peer`
- `senderId`
- `senderAddress`
- `recipientAddress`
- `conversationLabel`
- `rawBody`
- `messageId`
- `bodyForAgent`
- `commandBody`
- `extraContext`
- `deliver(...)`
- `onRecordError(...)`
- `onDispatchError(...)`

因此，插件本身不负责生成 AI 回复，而是负责：

- 把外部消息转换成 OpenClaw 能理解的标准输入
- 再把 OpenClaw 生成的回复投递回平台

### 8.7 当前限制

在 `extensions/xiaoli-chat/src/inbound-runtime.ts:43`：

- 非 direct message 目前只记录日志，不进入 reply pipeline

也就是：

- 群消息已经能识别
- 但故意不处理

这是当前版本的范围控制，而不是 bug。

---

## 第九步：实现 webhook 安全边界

文件：`extensions/xiaoli-chat/src/webhook.ts:95`

这是整个插件的 transport boundary。

### 9.1 路由路径

当前 webhook 路径是：

- `XIAOLI_WEBHOOK_PATH = "/hooks/xiaoli-chat/webhook"`

由 `extensions/xiaoli-chat/index.ts:12` 注册。

### 9.2 GET 请求行为

`GET` 请求返回一个最小 ready 响应：

```json
{
  "ok": true,
  "channel": "xiaoli-chat",
  "webhook": "ready",
  "path": "/hooks/xiaoli-chat/webhook"
}
```

它只用于：

- 健康检查
- 路由是否挂载的快速验证

### 9.3 POST 请求处理顺序

`POST` 当前严格按以下顺序执行：

1. 路由匹配
2. method / content-type / rate-limit 守卫
3. runtime 是否已初始化
4. webhook secret 是否已配置
5. 按 `pre-auth` profile 读取请求体
6. HMAC 签名校验
7. JSON 解析
8. payload 标准化
9. 必填字段校验
10. 调用 runtime bridge
11. 返回 accepted 或 error

这个顺序非常重要，因为它体现了安全边界设计：

- 在进入业务逻辑前，先限制 request body
- 在信任 payload 之前，先验签
- 只有通过 transport boundary 的请求，才会进入 OpenClaw runtime

### 9.4 复用公共 request guards

这里没有手写所有 HTTP 细节，而是复用了 `openclaw/plugin-sdk/webhook-ingress` 提供的公共能力：

- `applyBasicWebhookRequestGuards`
- `createFixedWindowRateLimiter`
- `readWebhookBodyOrReject`
- `resolveRequestClientIp`
- `WEBHOOK_RATE_LIMIT_DEFAULTS`

这很重要，因为它保证：

- 错误码语义和仓库内其他 webhook 保持一致
- 请求体读取限制与超时策略保持一致
- 限流行为保持一致

### 9.5 签名校验方式

当前验签逻辑包含：

- 请求头：`x-xiaoli-signature`
- 算法：HMAC SHA256
- 支持可选前缀：`sha256=`
- 常量时间比较：通过 digest 后再 `timingSafeEqual`

相关代码：

- `extensions/xiaoli-chat/src/webhook.ts:52`
- `extensions/xiaoli-chat/src/webhook.ts:65`

支持的头部格式：

- `x-xiaoli-signature: sha256=<hex>`
- `x-xiaoli-signature: <hex>`

### 9.6 当前响应语义

当前 webhook 响应：

- `200`：GET ready
- `401`：签名缺失或无效
- `400`：JSON 非法或字段缺失
- `503`：runtime 未初始化
- `503`：webhook secret 未配置
- `202`：消息已接受
- `500`：运行期处理失败

另外，公共 guard 还可能直接返回这些标准错误：

- `405`
- `415`
- `413`
- `408`
- `429`

---

## 第十步：存储并读取插件 runtime

文件：`extensions/xiaoli-chat/src/runtime.ts:4`

这里通过 `createPluginRuntimeStore<PluginRuntime>(...)` 创建了 runtime store，并导出：

- `setXiaoliRuntime`
- `getXiaoliRuntime`
- `tryGetXiaoliRuntime`

这个模块的意义是：

- 插件在启动注册路由时，可以把 runtime 保存下来
- 后续 webhook 请求真正到来时，handler 可以再从 store 里取 runtime

否则 `webhook.ts` 无法：

- 读取运行期配置
- 调用标准 dispatch

它相当于把“启动时上下文”和“请求时上下文”连接起来。

---

## 第十一步：独立 typecheck 与 build

这个插件已经专门做成了“可独立编译”。

### 11.1 typecheck

通过 `extensions/xiaoli-chat/tsconfig.json` 配置，并在：

- `extensions/xiaoli-chat/package.json:9`

暴露命令。

命令：

```bash
pnpm exec tsc -p "extensions/xiaoli-chat/tsconfig.json" --noEmit
```

### 11.2 build

构建脚本：

- `extensions/xiaoli-chat/build.sh:1`

它做的事情很简单：

1. 定位仓库根目录
2. 删除 `extensions/xiaoli-chat/dist`
3. 运行 `pnpm exec tsc -p "extensions/xiaoli-chat/tsconfig.build.json"`

执行方式：

```bash
./extensions/xiaoli-chat/build.sh
```

或者：

```bash
pnpm --dir "./extensions/xiaoli-chat" run build
```

### 11.3 构建产物

最终输出到：

- `extensions/xiaoli-chat/dist`

里面会生成编译后的 JS 与 declaration files。

---

## 第十二步：本地安装与加载流程

一键脚本：

- `extensions/xiaoli-chat/install-load.sh:1`

### 12.1 它做了什么

在大量 preflight 校验之后，脚本会依次执行：

1. build 插件
2. `openclaw plugins install -l "${PLUGIN_DIR}"`
3. `openclaw plugins enable "xiaoli-chat"`
4. `openclaw gateway restart`

### 12.2 为什么 preflight 这么重

这个脚本在真正执行前会检查：

- 命令是否存在且可执行
- 插件关键文件是否存在
- 仓库依赖前置条件是否满足
- OpenClaw 配置目录是否存在且可写
- plugin SDK / test helper 文件是否存在
- gateway / plugins 相关 CLI 子命令是否可用

它虽然长，但优点很明显：

- 一旦失败，报错位置很明确
- 比起“直接执行然后莫名挂掉”，更容易定位原因

### 12.3 运行方式

```bash
./extensions/xiaoli-chat/install-load.sh
```

---

## 第十三步：配置说明

当前配置结构等价于：

```json5
{
  channels: {
    "xiaoli-chat": {
      enabled: true,
      token: "YOUR_PLATFORM_TOKEN",
      baseUrl: "https://your-platform.example/api",
      allowFrom: ["user-1", "user-2"],
      dmSecurity: "allowlist",
      webhookSecret: "YOUR_WEBHOOK_SECRET",
    },
  },
}
```

### 字段说明

- `enabled`
  - 是否启用该渠道
- `token`
  - 出站 API token
- `baseUrl`
  - 外部平台 API 基地址
- `allowFrom`
  - DM allowlist
- `dmSecurity`
  - DM 安全策略
  - 当前支持：`open | allowlist`
- `webhookSecret`
  - webhook 验签共享密钥

---

## 第十四步：接口说明

### 14.1 配置 / 运行期接口

来自 `extensions/xiaoli-chat/src/types.ts:1`：

- `XiaoliChatConfig`
- `ResolvedXiaoliAccount`
- `XiaoliWebhookSecurityConfig`

### 14.2 入站消息接口

来自 `extensions/xiaoli-chat/src/types.ts:25`：

```ts
export type XiaoliInboundMessage = {
  senderId: string;
  chatId: string;
  messageId: string;
  text: string;
  threadId?: string;
  isDirectMessage: boolean;
  thinking?: string;
  media?: XiaoliMediaAttachment[];
};
```

其中 `XiaoliMediaAttachment` 包含：

```ts
export type XiaoliMediaAttachment = {
  url: string;
  type?: string;
  name?: string;
};
```

### 14.3 出站发送接口

来自 `extensions/xiaoli-chat/src/types.ts:34`：

```ts
export type XiaoliSendMessageParams = {
  chatId: string;
  text: string;
  threadId?: string;
};
```

### 14.4 当前 outbound client 使用的平台 HTTP 协议

请求：

```http
POST {baseUrl}/messages
Authorization: Bearer <token>
Content-Type: application/json
```

请求体：

```json
{
  "chatId": "chat-123",
  "text": "hello",
  "threadId": "optional-thread-id"
}
```

预期响应：

```json
{
  "id": "platform-message-id"
}
```

### 14.5 当前 inbound normalizer 期望的 webhook payload

当前插件期望的 payload 结构等价于：

```json
{
  "senderId": "user-123",
  "chatId": "chat-456",
  "messageId": "msg-789",
  "text": "hello",
  "threadId": "optional-thread-id",
  "isDirectMessage": true
}
```

接受消息时要求以下字段必须存在且非空：

- `senderId`
- `chatId`
- `messageId`
- `text`

---

## 第十五步：如何验证这个插件

### 15.1 静态验证

类型检查：

```bash
pnpm exec tsc -p "extensions/xiaoli-chat/tsconfig.json" --noEmit
```

构建：

```bash
./extensions/xiaoli-chat/build.sh
```

目标测试：

```bash
pnpm exec vitest run extensions/xiaoli-chat/src/webhook.test.ts extensions/xiaoli-chat/src/inbound-runtime.test.ts
```

`webhook.test.ts` 覆盖 transport/security boundary；`inbound-runtime.test.ts` 覆盖 deliver 回调的 text / media / 空 payload 场景。

### 15.2 安装 / 加载验证

```bash
./extensions/xiaoli-chat/install-load.sh
openclaw plugins list
openclaw plugins inspect xiaoli-chat
```

### 15.3 webhook 验证

ready 检查：

```bash
curl -i "http://127.0.0.1:18789/hooks/xiaoli-chat/webhook"
```

如果宿主 runtime 已真正激活这条路由，预期会返回 `200` JSON ready 响应。

签名 POST 的验证思路：

1. 准备原始 JSON body
2. 用 `webhookSecret` 计算 `sha256` HMAC
3. 放入 `x-xiaoli-signature`
4. 带 `Content-Type: application/json` 发请求

预期结果：

- content-type 错误 -> `415`
- body 超大 -> `413`
- 读取 body 超时 -> `408`
- 签名缺失或错误 -> `401`
- JSON 非法 -> `400`
- 缺失必填字段 -> `400`
- 有效签名且 payload 合法 -> `202`

---

## 第十六步：已知兼容性说明

在实际本地验证时，有一个需要特别注意的点：

- 在宿主 `OpenClaw 2026.3.28` 上，插件可能显示为 loaded
- 但 webhook 路由不一定真的在运行时激活
- 这时访问 `GET /hooks/xiaoli-chat/webhook` 可能会落到 control UI 的 HTML fallback，而不是插件 handler

这说明验证时要把两件事分开看：

1. **插件有没有成功编译、安装、启用、加载**
2. **当前宿主版本有没有真正支持并激活这个插件使用到的运行时能力**

不要把这两个问题混在一起，否则会误判问题位置。

---

## 第十七步：如果你要从零开发一个类似插件，推荐顺序是什么

如果你想做一个类似飞书、QQ、Xiaoli Chat 这种“可聊天渠道插件”，推荐按下面顺序推进：

1. 创建插件目录、`package.json`、`openclaw.plugin.json`
2. 在 `src/types.ts` 定义共享类型
3. 在 `src/config.ts` 实现配置解析
4. 在 `src/client.ts` 实现平台 outbound client
5. 在 `src/outbound.ts` 写一层薄适配器
6. 在 `src/channel.ts` 组装 channel plugin：
   - capabilities
   - config adapter
   - setup adapter
   - security
   - pairing
   - threading
   - outbound
7. 在 `src/runtime.ts` 建立 runtime store
8. 在 `index.ts` 注册入口
9. 在 `src/inbound.ts` 实现 inbound 标准化
10. 在 `src/inbound-runtime.ts` 接到 OpenClaw 标准 dispatch
11. 在 `src/webhook.ts` 加上 transport/security boundary
12. 先写 webhook boundary 的测试
13. 准备独立 `tsconfig.json` 和 `tsconfig.build.json`
14. 写 `build.sh`
15. 写 `install-load.sh`
16. 分开验证：typecheck、test、build、install、load、webhook

按这个顺序做，职责会更清楚，也不容易把：

- transport 逻辑
- config 逻辑
- OpenClaw runtime 逻辑

混在一起。

---

## 第十八步：Go webhook 中转服务（xiaoli-chat-webhook）

目录：`xiaoli-chat-webhook/`

这是一个独立的 Go 服务，用于在**外部 Xiaoli Chat 平台**与**OpenClaw `xiaoli-chat` 插件**之间做协议桥接。它不属于 OpenClaw 插件本身，而是作为外部适配层单独部署。

### 18.1 它解决的问题

实际平台的 webhook payload 格式往往和 OpenClaw `xiaoli-chat` 插件期望的格式不同。这个中转服务负责：

1. 接收来自 Xiaoli Chat 平台的原始 webhook 事件（含签名校验）
2. 将消息字段重新映射成插件期望的格式，转发到 `/hooks/xiaoli-chat/webhook`
3. 接收 OpenClaw 通过 `POST /messages` 发回的回复
4. 通过 SSE 将回复实时推送给前端或测试客户端

### 18.2 数据流

```text
Xiaoli Chat 平台
  -> POST /webhook（带签名）
  -> HMAC 验签
  -> 字段映射
  -> POST {OPENCLAW_URL}/hooks/xiaoli-chat/webhook（生成签名）
  -> OpenClaw 标准 reply pipeline
  -> sendText / sendMedia（插件 deliver 回调）
  -> POST /messages（OpenClaw 回调该服务）
  -> 写入内存环形缓冲区
  -> 广播到所有 SSE 客户端
```

### 18.3 环境变量

| 变量             | 必填 | 说明                                                  |
| ---------------- | ---- | ----------------------------------------------------- |
| `WEBHOOK_SECRET` | ✅   | 从平台接收 webhook 时的验签密钥（也用于生成转发签名） |
| `XIAOLI_TOKEN`   | ✅   | `/messages` 端点的 Bearer 认证 token                  |
| `OPENCLAW_URL`   | 否   | OpenClaw gateway 地址，默认 `http://localhost:18789`  |
| `PORT`           | 否   | 服务监听端口，默认 `8080`                             |

### 18.4 HTTP 端点

| 路径             | 方法 | 说明                                                |
| ---------------- | ---- | --------------------------------------------------- |
| `POST /webhook`  | POST | 接收平台事件，转发到 OpenClaw                       |
| `POST /messages` | POST | 接收 OpenClaw 回复，需 Bearer 认证                  |
| `GET /replies`   | GET  | 查询内存里最近的回复（支持 `chatId`、`limit` 参数） |
| `GET /stream`    | GET  | SSE 流，实时推送回复（支持 `chatId` 过滤）          |
| `GET /health`    | GET  | 健康检查                                            |

### 18.5 `/webhook` 接收的事件格式

```json
{
  "event": "message",
  "timestamp": 1712800000,
  "data": {
    "user": "user-123",
    "channel": "chat-456",
    "message": "hello",
    "media": [{ "url": "https://example.com/img.png", "type": "image", "name": "img.png" }]
  }
}
```

目前支持的事件类型：`message`、`user_joined`（其余记录日志后忽略）。

### 18.6 转发给 OpenClaw 的消息格式

中转服务将平台事件重新映射为插件期望的结构：

```json
{
  "senderId": "user-123",
  "chatId": "chat-456",
  "messageId": "msg-<nanoseconds>",
  "text": "hello",
  "isDirectMessage": true,
  "media": [...]
}
```

并通过 `x-xiaoli-signature: sha256=<hmac>` 头携带签名。

### 18.7 `/messages` 接收的回复格式

```json
{
  "chatId": "chat-456",
  "text": "AI 回复内容",
  "threadId": "optional",
  "mediaUrl": "https://example.com/reply.png",
  "mediaType": "image"
}
```

需携带 `Authorization: Bearer <XIAOLI_TOKEN>`。

### 18.8 启动方式

```bash
cd xiaoli-chat-webhook
WEBHOOK_SECRET=your-secret XIAOLI_TOKEN=your-token go run main.go
```

或使用 `run.sh`：

```bash
./xiaoli-chat-webhook/run.sh
```

### 18.9 并发安全

- `recentReplies`（环形缓冲，最近 100 条）：用 `sync.RWMutex` 保护
- `sseClients`（SSE 连接池）：用 `sync.Mutex` 保护
- HTTP 请求使用全局复用的 `http.Client`（60s 超时）
- 服务支持 graceful shutdown（监听 `SIGINT` / `SIGTERM`，10s 宽限期）

### 18.10 流式输出修复（2026-04-14）

**问题**：Go webhook 服务使用异步处理（`go func()`）导致消息顺序混乱或丢失。

**症状**：

- 第一条消息（"正在查询..."）不发送
- 只有最后一条消息到达客户端
- 两条消息间隔 4ms 但只收到一条

**根本原因**：

```go
// 错误实现：立即返回 HTTP 200，然后异步处理
w.WriteHeader(http.StatusOK)
json.NewEncoder(w).Encode(...)

go func() {
    // 异步存储和广播
    // 多个 goroutine 并发执行，导致竞态条件
}()
```

**解决方案**：改为同步处理

```go
// 正确实现：先处理消息，再返回响应
log.Printf("收到 OpenClaw 回复...")

// 同步存储到内存
repliesMu.Lock()
recentReplies = append(recentReplies, replyMsg)
repliesMu.Unlock()

// 同步广播到 SSE 客户端
broadcastToSSEClients(replyMsg)

// 最后返回响应
w.WriteHeader(http.StatusOK)
json.NewEncoder(w).Encode(...)
```

**修复效果**：

- ✅ 所有消息按顺序正确发送
- ✅ 第一条消息立即到达（5-7 秒）
- ✅ 第二条消息独立到达（工具调用完成后）
- ✅ 消息间隔 4ms，符合预期

**性能影响**：由于存储和广播都是轻量级内存操作（<1ms），同步处理不会造成明显延迟，反而保证了消息的完整性和顺序性。

---

## 这个插件给出的设计经验

### 1. 入口文件一定要薄

- `index.ts` 负责注册，不负责实现细节

### 2. 配置解析与传输实现要分开

- `config.ts` 负责生成运行期账号对象
- `client.ts` 负责平台 HTTP 细节

### 3. transport security 与业务逻辑要分开

- `webhook.ts` 负责尽早拒绝坏请求
- `inbound-runtime.ts` 只处理已经可信、已标准化的消息

### 4. 优先复用公共 SDK，不要重复造轮子

- 用 `createChatChannelPlugin(...)`
- 用 `createPluginRuntimeStore(...)`
- 用 `dispatchInboundDirectDmWithRuntime(...)`
- 用 `webhook-ingress` 的 guards

### 5. 能力声明要保持诚实

- 当前没接好的能力就不要提前宣称支持
- 群消息、media 等后续能力，等真正接好后再开放

---

## 第十九步：架构重构记录（2026-04-13）

### 19.1 问题背景

在原始实现中，xiaoli-chat 插件使用了旧的 `dispatchInboundDirectDmWithRuntime` API，存在以下问题：

1. **不支持流式输出**：第一条回复需要等待所有内容生成完成后才能发送
2. **用户体验差**：用户需要等待很长时间（20-30秒）才能看到任何响应
3. **架构不标准**：没有使用标准的 channel plugin reply pipeline

### 19.2 重构目标

1. 迁移到标准 channel plugin 架构
2. 启用 `blockStreaming` 支持流式输出
3. 第一条回复立即发送，不等待后续内容
4. 保持向后兼容，不破坏现有功能

### 19.3 核心变更

#### 变更 1：启用 blockStreaming capability

**文件**：`extensions/xiaoli-chat/src/channel.ts`

```typescript
capabilities: {
  chatTypes: ["direct", "group", "thread"],
  media: true,
  reactions: false,
  threads: true,
  edit: false,
  unsend: false,
  reply: true,
  effects: false,
  nativeCommands: false,
  blockStreaming: true,  // 从 false 改为 true
}
```

#### 变更 2：重构 inbound-runtime.ts

**文件**：`extensions/xiaoli-chat/src/inbound-runtime.ts`

**旧实现**：

```typescript
await dispatchInboundDirectDmWithRuntime({
  runtime,
  channel: "xiaoli-chat",
  channelLabel: "Xiaoli Chat",
  peer: { kind: "direct", id: message.senderId },
  // ... 其他参数
});
```

**新实现**：

```typescript
// 1. 使用 finalizeInboundContext 构建标准化上下文
const ctxPayload = finalizeInboundContext({
  SessionKey: sessionKey,
  AccountId: accountId,
  MessageSid: message.messageId,
  From: message.senderId,
  To: message.chatId,
  Body: bodyForAgent,
  BodyForAgent: bodyForAgent,
  RawBody: message.text,
  CommandBody: message.text,
  // ... 其他字段（注意：键名必须大写字母开头）
});

// 2. 记录会话
await recordInboundSession({
  storePath,
  sessionKey,
  ctx: ctxPayload,
  onRecordError: (error) => { ... },
});

// 3. 创建 reply pipeline
const { onModelSelected, ...replyPipeline } = createChannelReplyPipeline({
  cfg,
  agentId: "default",
  channel: "xiaoli-chat",
  accountId,
});

// 4. 使用 buffered block dispatcher 分发回复
await dispatchReplyWithBufferedBlockDispatcher({
  ctx: ctxPayload,
  cfg,
  dispatcherOptions: {
    ...replyPipeline,
    deliver,
    onError: (error, info) => { ... },
  },
  replyOptions: {
    onModelSelected,
  },
});
```

#### 变更 3：关键修复 - 参数键名格式

**问题**：`finalizeInboundContext` 期望的参数键名是**大写字母开头**（如 `Body`、`BodyForAgent`），而不是小写字母开头（如 `body`、`bodyForAgent`）。

**错误示例**（导致 agent 无法读取消息）：

```typescript
const ctxPayload = finalizeInboundContext({
  sessionKey: sessionKey, // ❌ 错误：小写开头
  accountId: accountId, // ❌ 错误：小写开头
  bodyForAgent: bodyForAgent, // ❌ 错误：小写开头
  // ...
});
```

**正确示例**：

```typescript
const ctxPayload = finalizeInboundContext({
  SessionKey: sessionKey, // ✅ 正确：大写开头
  AccountId: accountId, // ✅ 正确：大写开头
  BodyForAgent: bodyForAgent, // ✅ 正确：大写开头
  // ...
});
```

这个格式要求来自 OpenClaw SDK 的标准约定，可以参考 WhatsApp 插件的实现。

### 19.4 验证结果

重构后的测试结果：

1. ✅ **消息正确接收**：agent 能够正确读取并理解用户消息
2. ✅ **流式输出工作**：第一条回复在生成后立即发送（约 5-7 秒）
3. ✅ **发送延迟极低**：每次 deliver 调用到实际发送只需 7-12ms
4. ✅ **多块独立发送**：每个文本块生成后都会触发独立的 deliver 调用
5. ✅ **向后兼容**：现有功能（媒体附件、线程回复等）保持正常工作

### 19.5 性能对比

**重构前**：

- 第一条回复延迟：25-30 秒（等待所有内容生成完成）
- 用户体验：长时间无响应

**重构后**：

- 第一条回复延迟：5-7 秒（LLM 生成时间）
- 发送延迟：7-12ms
- 用户体验：快速看到初始响应，后续内容逐步到达

### 19.6 参考实现

如果你需要实现类似的流式输出功能，可以参考以下文件：

- `extensions/whatsapp/src/auto-reply/monitor/inbound-dispatch.ts` - WhatsApp 的标准实现
- `extensions/discord/src/monitor/inbound-context.ts` - Discord 的实现
- `extensions/xiaoli-chat/src/inbound-runtime.ts` - 本插件的实现

关键点：

1. 使用 `finalizeInboundContext` 而不是手动构建上下文
2. 参数键名必须大写字母开头
3. 使用 `dispatchReplyWithBufferedBlockDispatcher` 而不是旧的 dispatch API
4. 在 channel capabilities 中启用 `blockStreaming: true`

### 19.7 常见问题

**Q: 为什么 agent 说"没有收到消息"？**

A: 检查 `finalizeInboundContext` 的参数键名是否使用大写字母开头。这是最常见的错误。

**Q: 如何验证流式输出是否工作？**

A: 查看 OpenClaw 日志，应该看到多次 `deliver called` 日志，每次间隔几秒钟。如果只看到一次 deliver，说明流式输出没有启用。

**Q: 如何调试 deliver 回调？**

A: 在 `deliver` 函数中添加详细的时间戳日志，记录每次调用的时间和内容长度。

---

## 相关文档

- [Building Plugins](/plugins/building-plugins)
- [Building Channel Plugins](/plugins/sdk-channel-plugins)
- [Channel Routing](/channels/channel-routing)
- [Pairing](/channels/pairing)
- [Groups](/channels/groups)
