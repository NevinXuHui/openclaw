# OpenClaw 项目架构分析文档

> 本文档面向初学者，即使不熟悉 TypeScript 也能理解项目结构

## 📋 项目概览

**OpenClaw** 是一个开源的个人 AI 助手网关系统，主要功能包括：

- 🤖 **多平台消息集成**：支持 WhatsApp、Telegram、Discord、Slack、Signal、iMessage 等 20+ 个聊天平台
- 🧠 **多模型支持**：兼容 OpenAI、Anthropic Claude、Google Gemini 等主流 AI 模型
- 🎙️ **语音交互**：支持 macOS/iOS/Android 平台的语音输入输出
- 🎨 **可视化 Canvas**：提供实时渲染的交互界面
- 🔌 **插件化架构**：支持第三方扩展开发

**核心价值**：作为中间层，将用户在各种聊天平台的消息转发给 AI 模型，并将 AI 回复返回原平台。

---

## 🏗️ 整体架构

### 架构图

```
┌─────────────────────────────────────────────────────────┐
│                    用户交互层                              │
│  Telegram │ Discord │ Slack │ WhatsApp │ Signal │ ...   │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                  Channel Adapters                        │
│         (各平台消息格式统一化处理)                          │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                  Gateway Router                          │
│         (消息路由、会话管理、权限控制)                       │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                  Agent Manager                           │
│    (AI 模型调用、认证管理、负载均衡、故障转移)                │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                   AI 模型层                               │
│   OpenAI │ Claude │ Gemini │ 本地模型 │ ...             │
└─────────────────────────────────────────────────────────┘
```

---

## 🔌 RPC 模式详解

### 什么是 RPC 模式？

OpenClaw 使用 **WebSocket-based RPC (Remote Procedure Call)** 架构，而不是传统的 REST API。这意味着：

- **持久连接**：客户端与网关建立长连接，无需每次请求都重新连接
- **双向通信**：服务器可以主动推送事件给客户端（如实时消息、状态更新）
- **低延迟**：适合实时聊天场景，减少连接开销

### RPC 通信流程

```
┌──────────────┐                    ┌──────────────┐
│   CLI 客户端  │                    │  Gateway 网关 │
│              │                    │              │
│              │  1. WebSocket 连接  │              │
│              ├───────────────────>│              │
│              │                    │              │
│              │  2. connect.challenge│             │
│              │<───────────────────┤              │
│              │     (nonce)        │              │
│              │                    │              │
│              │  3. connect 请求    │              │
│              ├───────────────────>│              │
│              │  (auth + device)   │              │
│              │                    │              │
│              │  4. hello-ok 响应   │              │
│              │<───────────────────┤              │
│              │  (features + token)│              │
│              │                    │              │
│              │  5. RPC 方法调用    │              │
│              ├───────────────────>│              │
│              │  {method, params}  │              │
│              │                    │              │
│              │  6. 响应/事件推送   │              │
│              │<───────────────────┤              │
│              │  {payload/event}   │              │
└──────────────┘                    └──────────────┘
```

### 协议帧类型

OpenClaw 定义了三种核心帧类型（在 `src/gateway/protocol/schema/frames.ts` 中）：

#### 1. 请求帧 (RequestFrame)

客户端发送给服务器的 RPC 调用：

```typescript
{
  type: "req",           // 帧类型标识
  id: "uuid-string",     // 请求唯一 ID
  method: "agent",       // 方法名（如 agent, chat.send, channels.status）
  params: {              // 方法参数（可选）
    message: "你好",
    sessionKey: "main"
  }
}
```

#### 2. 响应帧 (ResponseFrame)

服务器返回的执行结果：

```typescript
{
  type: "res",           // 帧类型标识
  id: "uuid-string",     // 对应请求的 ID
  ok: true,              // 是否成功
  payload: {             // 返回数据（成功时）
    result: "..."
  },
  error: {               // 错误信息（失败时）
    code: "UNAUTHORIZED",
    message: "认证失败",
    details: {...}
  }
}
```

#### 3. 事件帧 (EventFrame)

服务器主动推送的事件通知：

```typescript
{
  type: "event",         // 帧类型标识
  event: "agent.reply",  // 事件名称
  seq: 123,              // 序列号（用于检测丢包）
  payload: {             // 事件数据
    text: "AI 回复内容",
    done: true
  }
}
```

### 核心 RPC 方法

OpenClaw 网关提供了丰富的 RPC 方法（在 `src/gateway/server-methods.ts` 中注册）：

| 方法名 | 功能 | 参数示例 |
|--------|------|----------|
| `connect` | 建立连接并认证 | `{auth, device, role, scopes}` |
| `health` | 健康检查 | `{}` |
| `agent` | 发送消息给 AI | `{message, sessionKey}` |
| `chat.send` | 发送聊天消息 | `{channel, target, text}` |
| `channels.status` | 查询频道状态 | `{probe: true}` |
| `config.get` | 获取配置 | `{key: "gateway.bind"}` |
| `config.set` | 设置配置 | `{key, value}` |
| `cron.list` | 列出定时任务 | `{}` |
| `models.list` | 列出可用模型 | `{}` |
| `tools.catalog` | 获取工具目录 | `{}` |

### 认证机制

OpenClaw 支持多种认证方式：

#### 1. 设备认证（Device Identity）

```typescript
// 客户端生成 RSA 密钥对
const deviceIdentity = {
  deviceId: "device-uuid",
  publicKey: "base64-encoded-public-key",
  privateKeyPem: "-----BEGIN PRIVATE KEY-----..."
};

// 签名认证负载
const payload = {
  deviceId,
  clientId: "gateway-client",
  role: "operator",
  scopes: ["operator.admin"],
  signedAtMs: Date.now(),
  nonce: "server-challenge-nonce"
};
const signature = sign(privateKey, payload);

// 发送 connect 请求
{
  method: "connect",
  params: {
    device: {
      id: deviceId,
      publicKey,
      signature,
      signedAt,
      nonce
    }
  }
}
```

#### 2. Token 认证

```typescript
{
  method: "connect",
  params: {
    auth: {
      token: "shared-gateway-token",      // 共享令牌
      deviceToken: "device-specific-token", // 设备令牌
      password: "gateway-password"        // 密码
    }
  }
}
```

#### 3. Bootstrap Token

用于首次配对的临时令牌：

```typescript
{
  method: "connect",
  params: {
    auth: {
      bootstrapToken: "one-time-pairing-token"
    }
  }
}
```

### 权限控制

网关方法按角色和作用域进行权限控制：

```typescript
// 方法注册时定义权限
registerMethod({
  name: "config.set",
  role: "operator",              // 需要 operator 角色
  scopes: ["operator.admin"],    // 需要 admin 作用域
  rateLimit: {
    maxPerMinute: 10             // 速率限制
  },
  handler: async (params) => {
    // 实现逻辑
  }
});
```

### 实时事件推送

网关可以主动推送事件给客户端：

```typescript
// 服务器端推送事件
gateway.broadcast({
  type: "event",
  event: "agent.reply",
  seq: nextSeq++,
  payload: {
    text: "AI 正在思考...",
    done: false
  }
});

// 客户端监听事件
client.onEvent = (evt) => {
  if (evt.event === "agent.reply") {
    console.log(evt.payload.text);
  }
};
```

### CLI 如何使用 RPC

CLI 通过 `src/cli/gateway-rpc.ts` 封装 RPC 调用：

```typescript
// 1. 创建网关客户端
const client = new GatewayClient({
  url: "ws://127.0.0.1:18789",
  token: config.gateway.token,
  deviceIdentity: loadOrCreateDeviceIdentity()
});

// 2. 启动连接
client.start();

// 3. 等待连接成功
await new Promise((resolve) => {
  client.onHelloOk = resolve;
});

// 4. 调用 RPC 方法
const result = await client.request("agent", {
  message: "你好",
  sessionKey: "main"
});

// 5. 监听事件
client.onEvent = (evt) => {
  if (evt.event === "agent.reply") {
    process.stdout.write(evt.payload.text);
  }
};
```

### 协议版本管理

OpenClaw 使用协议版本号确保兼容性：

```typescript
// 当前协议版本
export const PROTOCOL_VERSION = 3;

// 连接时协商版本
{
  method: "connect",
  params: {
    minProtocol: 3,  // 客户端支持的最低版本
    maxProtocol: 3   // 客户端支持的最高版本
  }
}

// 服务器返回协商结果
{
  type: "hello-ok",
  protocol: 3,       // 实际使用的版本
  features: {
    methods: ["agent", "chat.send", ...],
    events: ["agent.reply", "tick", ...]
  }
}
```

### 心跳与重连

网关通过心跳机制保持连接活跃：

```typescript
// 服务器定期发送 tick 事件
{
  type: "event",
  event: "tick",
  payload: {
    ts: Date.now()
  }
}

// 客户端检测心跳超时
if (Date.now() - lastTick > tickIntervalMs * 2) {
  // 关闭连接并重连
  ws.close(4000, "tick timeout");
}

// 自动重连（指数退避）
backoffMs = Math.min(backoffMs * 2, 30_000);
setTimeout(() => client.start(), backoffMs);
```

### 安全特性

#### 1. TLS 指纹验证

```typescript
// 客户端验证服务器证书指纹
const client = new GatewayClient({
  url: "wss://gateway.example.com",
  tlsFingerprint: "SHA256:AA:BB:CC:..."
});

// 连接时验证
const actualFingerprint = socket.getPeerCertificate().fingerprint256;
if (actualFingerprint !== expectedFingerprint) {
  throw new Error("TLS fingerprint mismatch");
}
```

#### 2. 明文连接保护

```typescript
// 禁止非回环地址使用 ws://
if (!isSecureWebSocketUrl(url)) {
  throw new Error(
    "SECURITY ERROR: Cannot connect over plaintext ws://. " +
    "Use wss:// or SSH tunnel."
  );
}
```

#### 3. 速率限制

```typescript
// 方法级速率限制
const rateLimiter = new RateLimiter({
  maxPerMinute: 10,
  maxPerHour: 100
});

if (!rateLimiter.allow(clientId, method)) {
  throw new Error("RATE_LIMITED");
}
```

---

## 📂 目录结构详解

### 核心模块

```
openclaw/
├── src/
│   ├── gateway/              # 🚦 网关核心
│   │   ├── protocol/         # 通信协议定义
│   │   └── server.ts         # 网关服务器主逻辑
│   │
│   ├── channels/             # 📱 聊天平台适配器
│   │   ├── telegram/         # Telegram 集成
│   │   ├── discord/          # Discord 集成
│   │   ├── slack/            # Slack 集成
│   │   └── ...               # 其他平台
│   │
│   ├── agents/               # 🤖 AI 代理管理
│   │   ├── auth-profiles.ts  # 认证配置管理
│   │   ├── api-key-rotation.ts # API 密钥轮换
│   │   └── acp-spawn.ts      # 代理进程生成
│   │
│   ├── plugins/              # 🔌 插件系统
│   │   ├── registry.ts       # 插件注册表
│   │   ├── loader.ts         # 插件加载器
│   │   └── contracts/        # 插件契约定义
│   │
│   ├── plugin-sdk/           # 🛠️ 插件开发 SDK
│   │   ├── core.ts           # 核心 API
│   │   ├── channel-setup.ts  # 频道插件接口
│   │   └── provider-setup.ts # 模型提供商接口
│   │
│   ├── cli/                  # 💻 命令行工具
│   ├── commands/             # 📝 CLI 命令实现
│   ├── config/               # ⚙️ 配置管理
│   ├── infra/                # 🏢 基础设施
│   ├── media/                # 🎬 媒体处理
│   ├── tts/                  # 🔊 文字转语音
│   ├── web-search/           # 🔍 网络搜索
│   ├── security/             # 🔒 安全模块
│   └── utils/                # 🧰 工具函数
│
├── docs/                     # 📚 文档
├── scripts/                  # 🔧 构建脚本
├── package.json              # 📦 项目配置
└── tsconfig.json             # 🔷 TypeScript 配置
```

---

## 🔄 消息处理流程

### 完整流程示例

假设用户在 Telegram 上发送消息 "今天天气怎么样？"

```
第 1 步：消息接收
┌─────────────────────────────────────┐
│ 用户在 Telegram 发送消息              │
│ "今天天气怎么样？"                     │
└──────────────┬──────────────────────┘
               │
第 2 步：平台适配
┌──────────────▼──────────────────────┐
│ Telegram Channel Adapter             │
│ - 解析 Telegram API 消息格式          │
│ - 提取文本、用户 ID、会话 ID           │
│ - 转换为统一的内部消息格式             │
└──────────────┬──────────────────────┘
               │
第 3 步：网关路由
┌──────────────▼──────────────────────┐
│ Gateway Router                       │
│ - 识别用户身份                        │
│ - 检查权限和配额                      │
│ - 选择目标 AI 模型                    │
│ - 加载会话历史                        │
└──────────────┬──────────────────────┘
               │
第 4 步：AI 调用
┌──────────────▼──────────────────────┐
│ Agent Manager                        │
│ - 选择可用的 API 密钥                 │
│ - 构建 AI 请求 payload               │
│ - 调用 OpenAI/Claude API             │
│ - 处理流式响应                        │
└──────────────┬──────────────────────┘
               │
第 5 步：响应处理
┌──────────────▼──────────────────────┐
│ AI 模型返回结果                       │
│ "今天北京晴天，气温 15-25°C"           │
└──────────────┬──────────────────────┘
               │
第 6 步：返回用户
┌──────────────▼──────────────────────┐
│ Telegram Channel Adapter             │
│ - 将 AI 回复转换为 Telegram 格式      │
│ - 通过 Telegram API 发送              │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│ 用户在 Telegram 收到回复              │
└─────────────────────────────────────┘
```

---

## 🎯 核心模块详解

### 1. Gateway（网关）

**位置**：`src/gateway/`

**职责**：
- 消息路由和分发
- 会话状态管理
- 权限验证和访问控制
- 负载均衡

**关键文件**：
- `server.ts` - 网关服务器主逻辑
- `protocol/schema.ts` - 通信协议定义

---

### 2. Channels（频道适配器）

**位置**：`src/channels/`

**职责**：
- 对接各个聊天平台的 API
- 统一消息格式
- 处理平台特定功能（表情、附件等）

**支持的平台**：
- Telegram、Discord、Slack、WhatsApp、Signal、iMessage、Matrix 等 20+ 个平台

---

### 3. Agents（AI 代理）

**位置**：`src/agents/`

**职责**：
- 管理 AI 模型连接
- API 密钥轮换和故障转移
- 请求/响应处理
- 流式输出管理

---

### 4. Plugins（插件系统）

**位置**：`src/plugins/` + `src/plugin-sdk/`

**设计理念**：
- 核心功能最小化
- 通过插件扩展功能
- 类似 VS Code 的扩展机制

**插件类型**：
1. **Channel Plugins** - 新增聊天平台支持
2. **Provider Plugins** - 新增 AI 模型提供商
3. **Tool Plugins** - 新增工具能力（搜索、计算等）

---

## 🛠️ 技术栈

### 核心技术

| 技术 | 版本 | 用途 |
|------|------|------|
| **TypeScript** | 5.x | 主要编程语言 |
| **Node.js** | 22.16+ | 运行时环境 |
| **pnpm** | 9.x | 包管理器 |
| **Vitest** | 最新 | 测试框架 |
| **Zod** | 3.x | 数据验证 |

---

## 🚀 快速上手

### 安装步骤

#### 1. 全局安装 OpenClaw
```bash
npm install -g openclaw@latest
# 或使用 pnpm
pnpm add -g openclaw@latest
```

#### 2. 运行初始化向导
```bash
openclaw onboard --install-daemon
```

向导会引导你完成：
- ✅ 选择 AI 提供商（OpenAI/Claude/Gemini）
- ✅ 输入 API 密钥
- ✅ 选择要连接的聊天平台
- ✅ 配置网关端口
- ✅ 安装系统守护进程

#### 3. 启动网关
```bash
openclaw gateway --port 18789 --verbose
```

#### 4. 测试连接
```bash
# 直接与 AI 对话
openclaw agent --message "你好，介绍一下自己" --thinking high

# 发送消息到 Telegram
openclaw message send --to +1234567890 --message "测试消息"
```

---

### 从源码运行（开发者）

```bash
# 1. 克隆仓库
git clone https://github.com/openclaw/openclaw.git
cd openclaw

# 2. 安装依赖
pnpm install

# 3. 构建 UI
pnpm ui:build

# 4. 构建项目
pnpm build

# 5. 运行初始化
pnpm openclaw onboard --install-daemon

# 6. 开发模式（自动重载）
pnpm gateway:watch
```

---

## 🔧 配置文件

### 配置文件位置

```
~/.openclaw/
├── config.json           # 主配置文件
├── credentials/          # API 密钥存储
│   ├── openai.json
│   ├── anthropic.json
│   └── ...
├── sessions/             # 会话历史
└── plugins/              # 已安装插件
```

### 配置示例

```json
{
  "gateway": {
    "port": 18789,
    "mode": "local"
  },
  "models": {
    "default": "openai/gpt-4",
    "fallback": ["anthropic/claude-3-sonnet"]
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "YOUR_BOT_TOKEN"
    },
    "discord": {
      "enabled": true,
      "token": "YOUR_BOT_TOKEN"
    }
  }
}
```

---

## 🧪 测试

### 运行测试

```bash
# 运行所有测试
pnpm test

# 运行特定测试
pnpm test -- src/gateway/server.test.ts

# 生成覆盖率报告
pnpm test:coverage
```

---

## 🐛 故障排查

### 常见问题

#### 1. 网关无法启动
```bash
# 检查端口占用
lsof -i :18789

# 查看日志
tail -f ~/.openclaw/logs/gateway.log

# 运行诊断
openclaw doctor
```

#### 2. AI 响应超时
```bash
# 检查网络连接
curl https://api.openai.com/v1/models

# 切换到备用模型
openclaw config set models.default "anthropic/claude-3-sonnet"
```

#### 3. 消息发送失败
```bash
# 检查频道状态
openclaw channels status --probe

# 重新认证
openclaw channels auth telegram
```

---

## 📚 学习路径

### 初学者路径

1. **第 1 周**：安装并运行，熟悉基本命令
2. **第 2 周**：阅读 `docs/` 目录文档
3. **第 3 周**：查看 `src/cli/` 和 `src/commands/` 代码
4. **第 4 周**：理解 Gateway 和 Channel 的工作原理

### 进阶路径

1. **第 1 个月**：开发简单插件
2. **第 2 个月**：贡献代码到主仓库
3. **第 3 个月**：深入理解 Agent 管理和负载均衡
4. **第 4 个月**：参与架构设计讨论

---

## 📖 参考资源

### 官方资源

- 🌐 [官方网站](https://openclaw.ai)
- 📚 [完整文档](https://docs.openclaw.ai)
- 💬 [Discord 社区](https://discord.gg/clawd)
- 🐙 [GitHub 仓库](https://github.com/openclaw/openclaw)

### 相关文档

- [快速开始指南](https://docs.openclaw.ai/start/getting-started)
- [插件开发教程](https://docs.openclaw.ai/plugins/building-plugins)
- [API 参考](https://docs.openclaw.ai/reference/api)
- [常见问题](https://docs.openclaw.ai/help/faq)

---

## 🔧 Tool Plugins 深度解析

### 什么是 Tool Plugins？

Tool Plugins（工具插件）是 OpenClaw 扩展 AI 能力的核心机制。通过工具插件，AI 可以：
- 🔍 **搜索网络**：获取实时信息
- 🖼️ **生成图片**：调用 DALL-E、Midjourney 等
- 📄 **处理文档**：读取 PDF、生成报告
- 🔊 **语音合成**：文字转语音
- ⏰ **定时任务**：设置提醒和自动化
- 💬 **发送消息**：跨平台消息推送
- 🎨 **Canvas 渲染**：实时可视化界面

---

### 工具系统架构

```
┌─────────────────────────────────────────────────────┐
│                   AI 模型层                          │
│         (Claude, GPT-4, Gemini)                     │
└──────────────────┬──────────────────────────────────┘
                   │ 决定调用哪个工具
┌──────────────────▼──────────────────────────────────┐
│              Tool Registry (工具注册表)               │
│  - 核心工具 (Core Tools)                             │
│  - 插件工具 (Plugin Tools)                           │
└──────────────────┬──────────────────────────────────┘
                   │ 路由到具体工具
┌──────────────────▼──────────────────────────────────┐
│              Tool Execution (工具执行)                │
│  - 参数验证                                          │
│  - 权限检查                                          │
│  - 执行逻辑                                          │
│  - 结果返回                                          │
└──────────────────┬──────────────────────────────────┘
                   │ 返回结果
┌──────────────────▼──────────────────────────────────┐
│              AI 模型层                                │
│         (处理结果并生成回复)                          │
└─────────────────────────────────────────────────────┘
```

---

### 核心工具列表

OpenClaw 内置了丰富的核心工具：

#### 1. 🌐 Web Tools（网络工具）

**Web Search（网络搜索）**
- **位置**：`src/agents/tools/web-search.ts`
- **功能**：搜索互联网获取实时信息
- **支持的搜索引擎**：
  - Google Search
  - Bing Search
  - DuckDuckGo
  - Brave Search
  - 自定义搜索提供商（通过插件）

**参数示例**：
```typescript
{
  name: "web_search",
  parameters: {
    query: "OpenAI GPT-4 最新功能",
    max_results: 10,
    search_depth: "basic" // 或 "advanced"
  }
}
```

**Web Fetch（网页抓取）**
- **位置**：`src/agents/tools/web-fetch.ts`
- **功能**：抓取网页内容并提取可读文本
- **特性**：
  - 自动提取主要内容
  - 过滤广告和导航
  - 支持 JavaScript 渲染
  - Markdown 格式输出

**参数示例**：
```typescript
{
  name: "web_fetch",
  parameters: {
    url: "https://example.com/article",
    extract_readable: true,
    timeout: 30000
  }
}
```

---

#### 2. 🖼️ Image Tools（图像工具）

**Image Generate（图像生成）**
- **位置**：`src/agents/tools/image-generate-tool.ts`
- **功能**：使用 AI 生成图像
- **支持的提供商**：
  - OpenAI DALL-E 3
  - Google Imagen
  - Stability AI
  - Midjourney（通过插件）

**参数示例**：
```typescript
{
  name: "image_generate",
  parameters: {
    prompt: "一只戴着墨镜的猫在海滩上",
    model: "openai/dall-e-3",
    size: "1024x1024",
    quality: "hd",
    style: "vivid"
  }
}
```

**Image Tool（图像处理）**
- **位置**：`src/agents/tools/image-tool.ts`
- **功能**：读取、分析、编辑图像
- **支持操作**：
  - 读取本地图片
  - 图片格式转换
  - 缩放和裁剪
  - 元数据提取

---

#### 3. 📄 PDF Tool（PDF 工具）

**位置**：`src/agents/tools/pdf-tool.ts`

**功能**：
- 读取 PDF 内容
- 提取文本和图片
- PDF 转 Markdown
- 生成 PDF 文档

**参数示例**：
```typescript
{
  name: "pdf_tool",
  parameters: {
    action: "read",
    file_path: "/path/to/document.pdf",
    extract_images: true,
    page_range: "1-10"
  }
}
```

---

#### 4. 🔊 TTS Tool（文字转语音）

**位置**：`src/agents/tools/tts-tool.ts`

**功能**：
- 文字转语音
- 支持多种语言和声音
- 可调节语速和音调

**支持的提供商**：
- OpenAI TTS
- Google Cloud TTS
- Azure TTS
- ElevenLabs

**参数示例**：
```typescript
{
  name: "tts",
  parameters: {
    text: "你好，这是一段测试语音",
    voice: "alloy",
    model: "tts-1-hd",
    speed: 1.0
  }
}
```

---

#### 5. ⏰ Cron Tool（定时任务）

**位置**：`src/agents/tools/cron-tool.ts`

**功能**：
- 创建定时任务
- 管理提醒
- 自动化工作流

**参数示例**：
```typescript
{
  name: "cron",
  parameters: {
    action: "add",
    schedule: {
      kind: "cron",
      expression: "0 9 * * *" // 每天早上9点
    },
    payload: {
      kind: "agentTurn",
      message: "早安！今天的日程安排是什么？"
    }
  }
}
```

---

#### 6. 💬 Message Tool（消息工具）

**位置**：`src/agents/tools/message-tool.ts`

**功能**：
- 发送消息到各个平台
- 支持文本、图片、文件
- 跨平台消息转发

**参数示例**：
```typescript
{
  name: "message",
  parameters: {
    to: "telegram:user:123456",
    text: "这是一条测试消息",
    attachments: ["/path/to/image.jpg"]
  }
}
```

---

#### 7. 🎨 Canvas Tool（画布工具）

**位置**：`src/agents/tools/canvas-tool.ts`

**功能**：
- 实时渲染可视化界面
- 支持 HTML/CSS/JavaScript
- 交互式组件

**参数示例**：
```typescript
{
  name: "canvas",
  parameters: {
    action: "render",
    content: "<div>Hello Canvas!</div>",
    style: "body { background: #f0f0f0; }"
  }
}
```

---

#### 8. 🔗 Gateway Tool（网关工具）

**位置**：`src/agents/tools/gateway-tool.ts`

**功能**：
- 调用网关 API
- 管理会话
- 控制路由

---

#### 9. 🤖 Sessions Tools（会话工具）

**位置**：`src/agents/tools/sessions-*.ts`

**包含的工具**：
- `sessions_list` - 列出所有会话
- `sessions_send` - 向会话发送消息
- `sessions_spawn` - 创建新会话
- `sessions_history` - 查看会话历史
- `sessions_yield` - 暂停会话

---

### 工具接口定义

所有工具都遵循统一的接口：

```typescript
// 工具类型定义
type AnyAgentTool = {
  // 工具名称（唯一标识）
  name: string;

  // 工具标签（显示名称）
  label?: string;

  // 工具描述（AI 用于理解工具用途）
  description: string;

  // 参数模式（JSON Schema）
  parameters: TSchema;

  // 执行函数
  execute: (toolCallId: string, args: any) => Promise<AgentToolResult>;

  // 是否仅限所有者使用
  ownerOnly?: boolean;

  // 显示摘要
  displaySummary?: string;
};
```

---

### 如何开发自定义工具插件

#### 步骤 1：创建工具文件

在插件目录创建工具文件：

```typescript
// my-plugin/src/tools/calculator-tool.ts
import { Type } from "@sinclair/typebox";
import type { AnyAgentTool } from "openclaw/plugin-sdk";

export function createCalculatorTool(): AnyAgentTool {
  return {
    name: "calculator",
    label: "Calculator",
    description: "执行数学计算",

    // 定义参数模式
    parameters: Type.Object({
      expression: Type.String({
        description: "数学表达式，例如：2 + 2 * 3"
      }),
      precision: Type.Optional(Type.Number({
        description: "小数精度，默认为 2"
      }))
    }),

    // 实现执行逻辑
    execute: async (toolCallId, args) => {
      try {
        const { expression, precision = 2 } = args;

        // 安全的数学表达式求值
        const result = evaluateMathExpression(expression);
        const rounded = Number(result.toFixed(precision));

        return {
          type: "text",
          text: `计算结果：${expression} = ${rounded}`
        };
      } catch (error) {
        return {
          type: "text",
          text: `计算错误：${error.message}`
        };
      }
    }
  };
}

// 安全的数学表达式求值函数
function evaluateMathExpression(expr: string): number {
  // 只允许数字和基本运算符
  if (!/^[\d+\-*/().\s]+$/.test(expr)) {
    throw new Error("表达式包含非法字符");
  }

  // 使用 Function 构造器安全求值
  return new Function(`return ${expr}`)();
}
```

---

#### 步骤 2：注册工具到插件

```typescript
// my-plugin/src/index.ts
import type { OpenClawPlugin } from "openclaw/plugin-sdk";
import { createCalculatorTool } from "./tools/calculator-tool.js";

export default {
  id: "my-calculator-plugin",
  name: "Calculator Plugin",
  version: "1.0.0",

  // 注册工具
  tools: (context) => {
    return [
      createCalculatorTool()
    ];
  }
} satisfies OpenClawPlugin;
```

---

#### 步骤 3：配置插件清单

```json
// my-plugin/openclaw.plugin.json
{
  "id": "my-calculator-plugin",
  "name": "Calculator Plugin",
  "version": "1.0.0",
  "description": "提供数学计算功能",
  "author": "Your Name",
  "main": "dist/index.js",
  "openclaw": {
    "minVersion": "2026.1.0"
  }
}
```

---

#### 步骤 4：安装和启用插件

```bash
# 安装插件
openclaw plugin install ./my-plugin

# 启用插件
openclaw plugin enable my-calculator-plugin

# 验证工具已注册
openclaw tools list
```

---

### 高级工具特性

#### 1. 工具权限控制

```typescript
export function createAdminTool(): AnyAgentTool {
  return {
    name: "admin_action",
    description: "执行管理员操作",

    // 仅限所有者使用
    ownerOnly: true,

    parameters: Type.Object({
      action: Type.String()
    }),

    execute: async (toolCallId, args, context) => {
      // 检查权限
      if (!context.senderIsOwner) {
        throw new ToolAuthorizationError("此工具仅限所有者使用");
      }

      // 执行管理操作
      // ...
    }
  };
}
```

---

#### 2. 工具参数验证

```typescript
import { ToolInputError } from "openclaw/plugin-sdk";

export function createWeatherTool(): AnyAgentTool {
  return {
    name: "weather",
    description: "查询天气信息",

    parameters: Type.Object({
      city: Type.String({ description: "城市名称" }),
      unit: Type.Optional(Type.String({
        description: "温度单位：celsius 或 fahrenheit"
      }))
    }),

    execute: async (toolCallId, args) => {
      const { city, unit = "celsius" } = args;

      // 参数验证
      if (!city || city.trim().length === 0) {
        throw new ToolInputError("城市名称不能为空");
      }

      if (unit !== "celsius" && unit !== "fahrenheit") {
        throw new ToolInputError("温度单位必须是 celsius 或 fahrenheit");
      }

      // 查询天气
      const weather = await fetchWeather(city, unit);

      return {
        type: "text",
        text: `${city}的天气：${weather.description}，温度：${weather.temp}°${unit === "celsius" ? "C" : "F"}`
      };
    }
  };
}
```

---

#### 3. 工具结果类型

工具可以返回多种类型的结果：

```typescript
// 文本结果
return {
  type: "text",
  text: "这是文本结果"
};

// 图片结果
return {
  type: "image",
  source: {
    type: "url",
    url: "https://example.com/image.jpg"
  }
};

// 文件结果
return {
  type: "document",
  source: {
    type: "base64",
    media_type: "application/pdf",
    data: base64Data
  }
};

// JSON 结果
return {
  type: "text",
  text: JSON.stringify({
    status: "success",
    data: { ... }
  }, null, 2)
};
```

---

#### 4. 异步工具执行

```typescript
export function createLongRunningTool(): AnyAgentTool {
  return {
    name: "long_task",
    description: "执行长时间运行的任务",

    parameters: Type.Object({
      task_id: Type.String()
    }),

    execute: async (toolCallId, args) => {
      const { task_id } = args;

      // 启动异步任务
      const taskPromise = startLongRunningTask(task_id);

      // 返回任务状态
      return {
        type: "text",
        text: `任务 ${task_id} 已启动，正在后台执行...`
      };
    }
  };
}
```

---

### 工具调试技巧

#### 1. 启用工具日志

```bash
# 设置环境变量
export DEBUG=openclaw:tools:*

# 启动网关（详细模式）
openclaw gateway --verbose
```

#### 2. 查看可用工具

OpenClaw 没有独立的 `tools list` 命令，但可以通过以下方式查看工具：

**方法 1：通过 Agent 命令查看**
```bash
# 运行 agent 并让 AI 列出可用工具
openclaw agent --message "列出你可以使用的所有工具" --local
```

**方法 2：查看配置文件**
```bash
# 查看工具配置
openclaw config get tools

# 查看插件配置
openclaw config get plugins
```

**方法 3：查看插件列表**
```bash
# 列出已安装的插件（插件可能提供工具）
openclaw plugin list
```

#### 3. 测试工具

```bash
# 通过 agent 命令测试工具
openclaw agent --message "使用 web_search 工具搜索 OpenAI" --local

# 测试图片生成工具
openclaw agent --message "生成一张猫的图片" --local
```

#### 4. 查看工具执行日志

```bash
# 启动网关并查看实时日志
openclaw gateway --verbose --ws-log full

# 在另一个终端查看日志
openclaw logs
```

---

### 工具最佳实践

#### ✅ 推荐做法

1. **清晰的描述**：工具描述要详细，让 AI 能准确理解用途
2. **参数验证**：始终验证输入参数，提供友好的错误信息
3. **错误处理**：捕获所有可能的异常，避免工具崩溃
4. **幂等性**：相同输入应产生相同输出
5. **性能优化**：避免阻塞操作，使用异步处理
6. **安全检查**：验证权限，防止未授权访问

#### ❌ 避免做法

1. **过于复杂**：一个工具只做一件事
2. **缺少文档**：参数和返回值要有清晰说明
3. **硬编码**：使用配置而非硬编码值
4. **忽略错误**：不要吞掉异常
5. **阻塞操作**：避免长时间同步操作
6. **不安全的代码**：防止代码注入和路径遍历

---

### 工具生态系统

OpenClaw 支持通过插件扩展工具生态：

```
核心工具 (Core Tools)
├── Web Search
├── Web Fetch
├── Image Generate
├── PDF Tool
├── TTS Tool
└── ...

插件工具 (Plugin Tools)
├── Calculator Plugin
├── Weather Plugin
├── Database Plugin
├── API Integration Plugin
└── Custom Tools
```

---

### 实战案例：天气查询工具

完整的天气查询工具实现：

```typescript
// weather-plugin/src/tools/weather-tool.ts
import { Type } from "@sinclair/typebox";
import type { AnyAgentTool } from "openclaw/plugin-sdk";
import { ToolInputError } from "openclaw/plugin-sdk";

interface WeatherData {
  city: string;
  temperature: number;
  description: string;
  humidity: number;
  wind_speed: number;
}

export function createWeatherTool(config?: {
  apiKey?: string;
}): AnyAgentTool {
  return {
    name: "weather",
    label: "Weather Query",
    description: "查询指定城市的实时天气信息，包括温度、湿度、风速等",

    parameters: Type.Object({
      city: Type.String({
        description: "城市名称，例如：北京、上海、New York"
      }),
      unit: Type.Optional(Type.String({
        description: "温度单位：celsius（摄氏度）或 fahrenheit（华氏度），默认为 celsius",
        enum: ["celsius", "fahrenheit"]
      })),
      language: Type.Optional(Type.String({
        description: "返回语言：zh（中文）或 en（英文），默认为 zh",
        enum: ["zh", "en"]
      }))
    }),

    execute: async (toolCallId, args) => {
      try {
        // 参数提取和验证
        const city = args.city?.trim();
        const unit = args.unit || "celsius";
        const language = args.language || "zh";

        if (!city) {
          throw new ToolInputError("城市名称不能为空");
        }

        // 调用天气 API
        const weather = await fetchWeatherData(city, unit, config?.apiKey);

        // 格式化结果
        const tempUnit = unit === "celsius" ? "°C" : "°F";
        const result = language === "zh"
          ? formatWeatherZh(weather, tempUnit)
          : formatWeatherEn(weather, tempUnit);

        return {
          type: "text",
          text: result
        };

      } catch (error) {
        if (error instanceof ToolInputError) {
          throw error;
        }

        return {
          type: "text",
          text: `查询天气失败：${error.message}`
        };
      }
    }
  };
}

async function fetchWeatherData(
  city: string,
  unit: string,
  apiKey?: string
): Promise<WeatherData> {
  // 实际实现中调用天气 API
  const response = await fetch(
    `https://api.weatherapi.com/v1/current.json?key=${apiKey}&q=${city}&lang=zh`
  );

  if (!response.ok) {
    throw new Error(`天气 API 返回错误：${response.status}`);
  }

  const data = await response.json();

  return {
    city: data.location.name,
    temperature: unit === "celsius" ? data.current.temp_c : data.current.temp_f,
    description: data.current.condition.text,
    humidity: data.current.humidity,
    wind_speed: data.current.wind_kph
  };
}

function formatWeatherZh(weather: WeatherData, unit: string): string {
  return `
📍 城市：${weather.city}
🌡️ 温度：${weather.temperature}${unit}
☁️ 天气：${weather.description}
💧 湿度：${weather.humidity}%
💨 风速：${weather.wind_speed} km/h
  `.trim();
}

function formatWeatherEn(weather: WeatherData, unit: string): string {
  return `
📍 City: ${weather.city}
🌡️ Temperature: ${weather.temperature}${unit}
☁️ Condition: ${weather.description}
💧 Humidity: ${weather.humidity}%
💨 Wind Speed: ${weather.wind_speed} km/h
  `.trim();
}
```

使用示例：

```bash
# AI 调用工具
User: 北京今天天气怎么样？

AI: 让我查询一下北京的天气...
[调用 weather 工具]

Result:
📍 城市：北京
🌡️ 温度：15°C
☁️ 天气：晴
💧 湿度：45%
💨 风速：12 km/h
```

---

## 📝 附录

### 术语表

| 术语 | 解释 |
|------|------|
| **Gateway** | 网关，消息路由的核心组件 |
| **Channel** | 频道，指各个聊天平台 |
| **Agent** | 代理，负责与 AI 模型交互 |
| **Plugin** | 插件，扩展功能的模块 |
| **Session** | 会话，用户与 AI 的对话历史 |
| **Tool** | 工具，AI 可调用的功能模块 |
| **Tool Registry** | 工具注册表，管理所有可用工具 |
| **Tool Execution** | 工具执行，运行工具并返回结果 |

---

**文档版本**：v1.1
**最后更新**：2026-04-03

---

> 💡 **提示**：本文档持续更新中，欢迎贡献改进建议！
