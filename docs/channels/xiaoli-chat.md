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

- 不支持 media
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
  -> dispatchInboundDirectDmWithRuntime(...)
  -> OpenClaw 标准 reply pipeline
  -> sendText(...)
  -> 外部平台回复 API
```

相关代码：

- `extensions/xiaoli-chat/index.ts:12`
- `extensions/xiaoli-chat/src/webhook.ts:95`
- `extensions/xiaoli-chat/src/inbound.ts:11`
- `extensions/xiaoli-chat/src/inbound-runtime.ts:44`

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
- config adapter
- setup adapter

当前声明的能力：

- `chatTypes: ["direct", "group", "thread"]`
- `media: false`
- `reactions: false`
- `threads: true`
- `edit: false`
- `unsend: false`
- `reply: true`
- `effects: false`
- `nativeCommands: false`
- `blockStreaming: false`

这里的关键原则是：

**能力声明必须反映真实接线情况，而不是平台理论上可能支持什么。**

比如当前代码并没有做 media、reaction、edit，那就不要提前宣称支持。

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

文件：`extensions/xiaoli-chat/src/inbound-runtime.ts:26`

这是整个插件里最关键的 OpenClaw 接缝之一。

### 8.1 它做了什么

`handleXiaoliInboundMessage(...)` 当前的流程：

1. 如果不是私聊消息，先忽略
2. 从 runtime 里加载配置
3. 解析默认账号
4. 调用 `dispatchInboundDirectDmWithRuntime(...)`
5. 提供 `deliver(...)` 回调，把 AI 回复再发回平台

### 8.2 为什么这是核心接入点

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

### 8.3 当前限制

在 `extensions/xiaoli-chat/src/inbound-runtime.ts:33`：

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
pnpm test -- "extensions/xiaoli-chat/src/webhook.test.ts"
```

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

## 相关文档

- [Building Plugins](/plugins/building-plugins)
- [Building Channel Plugins](/plugins/sdk-channel-plugins)
- [Channel Routing](/channels/channel-routing)
- [Pairing](/channels/pairing)
- [Groups](/channels/groups)
