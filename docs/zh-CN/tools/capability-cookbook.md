---
summary: "向 OpenClaw 插件系统添加新共享能力的贡献者指南"
read_when:
  - 你正在添加新的核心能力和插件注册面
  - 你需要判断代码应放在 core、厂商插件还是功能插件中
  - 你正在为渠道或工具接入新的运行时 helper
title: "添加能力（贡献者指南）"
sidebarTitle: "添加能力"
---

# 添加能力

<Info>
  这是一份面向 OpenClaw core 开发者的**贡献者指南**。如果你正在
  构建外部插件，请改看 [Building Plugins](/plugins/building-plugins)。
</Info>

当 OpenClaw 需要引入新领域能力时使用它，例如图像生成、视频
生成，或未来某个由厂商支持的新功能领域。

规则是：

- plugin = 所有权边界
- capability = 共享的 core 契约

这意味着你不应一开始就把某个厂商直接接进某个渠道或工具。
应先定义 capability。

## 何时创建 capability

当以下条件全部成立时，请创建新的 capability：

1. 合理地说，可能会有多个厂商来实现它
2. 渠道、工具或功能插件应能在不关心厂商的前提下消费它
3. core 需要拥有回退、策略、配置或交付行为

如果这项工作只涉及单个厂商，且共享契约还不存在，请停下来，
先定义契约。

## 标准顺序

1. 定义强类型的 core 契约。
2. 为该契约添加插件注册面。
3. 添加共享的运行时 helper。
4. 接入一个真实的厂商插件作为证明。
5. 让功能 / 渠道消费者迁移到运行时 helper。
6. 添加契约测试。
7. 编写面向运维者的配置文档和所有权模型说明。

## 各部分分别放在哪里

Core：

- request / response 类型
- provider 注册表与解析逻辑
- fallback 行为
- 配置 schema 与标签 / help
- runtime helper surface

厂商插件：

- 厂商 API 调用
- 厂商认证处理
- 厂商专属请求归一化
- capability 实现的注册

功能 / 渠道插件：

- 调用 `api.runtime.*` 或对应的 `plugin-sdk/*-runtime` helper
- 永远不要直接调用某个厂商实现

## 文件检查清单

对于一个新的 capability，通常会涉及这些位置：

- `src/<capability>/types.ts`
- `src/<capability>/...registry/runtime.ts`
- `src/plugins/types.ts`
- `src/plugins/registry.ts`
- `src/plugins/captured-registration.ts`
- `src/plugins/contracts/registry.ts`
- `src/plugins/runtime/types-core.ts`
- `src/plugins/runtime/index.ts`
- `src/plugin-sdk/<capability>.ts`
- `src/plugin-sdk/<capability>-runtime.ts`
- 一个或多个捆绑插件包
- config / docs / tests

## 示例：图像生成

图像生成遵循标准形态：

1. core 定义 `ImageGenerationProvider`
2. core 暴露 `registerImageGenerationProvider(...)`
3. core 暴露 `runtime.imageGeneration.generate(...)`
4. `openai` 与 `google` 插件注册由厂商支持的实现
5. 未来其他厂商可以注册同一个契约，而无需更改渠道 / 工具

该配置键与视觉分析路由是分开的：

- `agents.defaults.imageModel` = 分析图像
- `agents.defaults.imageGenerationModel` = 生成图像

请保持两者分离，以便 fallback 与策略保持明确。

## 评审检查清单

在发布新 capability 之前，请确认：

- 没有任何渠道 / 工具直接导入厂商代码
- runtime helper 是共享路径
- 至少有一个契约测试断言了捆绑所有权
- 配置文档明确写出了新的 model / config key
- 插件文档解释了所有权边界

如果某个 PR 跳过 capability 层，直接把厂商行为硬编码进渠道 / 工具，
请退回并先定义契约。
