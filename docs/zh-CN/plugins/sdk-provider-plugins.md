---
title: "构建提供商插件"
sidebarTitle: "提供商插件"
summary: "构建 OpenClaw 模型提供商插件的分步指南"
read_when:
  - 你正在构建新的模型提供商插件
  - 你想为 OpenClaw 添加 OpenAI 兼容代理或自定义 LLM
  - 你需要理解提供商鉴权、目录和运行时 hooks
---

# 构建提供商插件

本指南将带你构建一个为 OpenClaw 添加模型提供商（LLM）的提供商插件。完成后，你将拥有一个带模型目录、API key 鉴权和动态模型解析能力的提供商。

<Info>
  如果你还没有构建过任何 OpenClaw 插件，请先阅读
  [入门指南](/plugins/building-plugins)，了解基础包结构和清单设置。
</Info>

## 演练

<Steps>
  <a id="step-1-package-and-manifest"></a>
  <Step title="包与清单">
    <CodeGroup>
    ```json package.json
    {
      "name": "@myorg/openclaw-acme-ai",
      "version": "1.0.0",
      "type": "module",
      "openclaw": {
        "extensions": ["./index.ts"],
        "providers": ["acme-ai"],
        "compat": {
          "pluginApi": ">=2026.3.24-beta.2",
          "minGatewayVersion": "2026.3.24-beta.2"
        },
        "build": {
          "openclawVersion": "2026.3.24-beta.2",
          "pluginSdkVersion": "2026.3.24-beta.2"
        }
      }
    }
    ```

    ```json openclaw.plugin.json
    {
      "id": "acme-ai",
      "name": "Acme AI",
      "description": "Acme AI model provider",
      "providers": ["acme-ai"],
      "providerAuthEnvVars": {
        "acme-ai": ["ACME_AI_API_KEY"]
      },
      "providerAuthChoices": [
        {
          "provider": "acme-ai",
          "method": "api-key",
          "choiceId": "acme-ai-api-key",
          "choiceLabel": "Acme AI API key",
          "groupId": "acme-ai",
          "groupLabel": "Acme AI",
          "cliFlag": "--acme-ai-api-key",
          "cliOption": "--acme-ai-api-key <key>",
          "cliDescription": "Acme AI API key"
        }
      ],
      "configSchema": {
        "type": "object",
        "additionalProperties": false
      }
    }
    ```
    </CodeGroup>

    清单中声明 `providerAuthEnvVars`，这样 OpenClaw 就能在不加载插件运行时的情况下检测凭证。如果你要在 ClawHub 上发布这个提供商，则 `package.json` 中的这些 `openclaw.compat` 和 `openclaw.build` 字段是必需的。

  </Step>

  <Step title="注册提供商">
    一个最小可用的提供商需要 `id`、`label`、`auth` 和 `catalog`：

    ```typescript index.ts
    import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";
    import { createProviderApiKeyAuthMethod } from "openclaw/plugin-sdk/provider-auth";

    export default definePluginEntry({
      id: "acme-ai",
      name: "Acme AI",
      description: "Acme AI model provider",
      register(api) {
        api.registerProvider({
          id: "acme-ai",
          label: "Acme AI",
          docsPath: "/providers/acme-ai",
          envVars: ["ACME_AI_API_KEY"],

          auth: [
            createProviderApiKeyAuthMethod({
              providerId: "acme-ai",
              methodId: "api-key",
              label: "Acme AI API key",
              hint: "API key from your Acme AI dashboard",
              optionKey: "acmeAiApiKey",
              flagName: "--acme-ai-api-key",
              envVar: "ACME_AI_API_KEY",
              promptMessage: "Enter your Acme AI API key",
              defaultModel: "acme-ai/acme-large",
            }),
          ],

          catalog: {
            order: "simple",
            run: async (ctx) => {
              const apiKey =
                ctx.resolveProviderApiKey("acme-ai").apiKey;
              if (!apiKey) return null;
              return {
                provider: {
                  baseUrl: "https://api.acme-ai.com/v1",
                  apiKey,
                  api: "openai-completions",
                  models: [
                    {
                      id: "acme-large",
                      name: "Acme Large",
                      reasoning: true,
                      input: ["text", "image"],
                      cost: { input: 3, output: 15, cacheRead: 0.3, cacheWrite: 3.75 },
                      contextWindow: 200000,
                      maxTokens: 32768,
                    },
                    {
                      id: "acme-small",
                      name: "Acme Small",
                      reasoning: false,
                      input: ["text"],
                      cost: { input: 1, output: 5, cacheRead: 0.1, cacheWrite: 1.25 },
                      contextWindow: 128000,
                      maxTokens: 8192,
                    },
                  ],
                },
              };
            },
          },
        });
      },
    });
    ```

    到这里，你已经拥有一个可工作的提供商。用户现在可以执行
    `openclaw onboard --acme-ai-api-key <key>`，并选择
    `acme-ai/acme-large` 作为模型。

    对于只注册一个文本提供商、使用 API key 鉴权并且只拥有一个基于 catalog 的运行时的内置提供商，优先使用更窄的 `defineSingleProviderPluginEntry(...)` 辅助：

    ```typescript
    import { defineSingleProviderPluginEntry } from "openclaw/plugin-sdk/provider-entry";

    export default defineSingleProviderPluginEntry({
      id: "acme-ai",
      name: "Acme AI",
      description: "Acme AI model provider",
      provider: {
        label: "Acme AI",
        docsPath: "/providers/acme-ai",
        auth: [
          {
            methodId: "api-key",
            label: "Acme AI API key",
            hint: "API key from your Acme AI dashboard",
            optionKey: "acmeAiApiKey",
            flagName: "--acme-ai-api-key",
            envVar: "ACME_AI_API_KEY",
            promptMessage: "Enter your Acme AI API key",
            defaultModel: "acme-ai/acme-large",
          },
        ],
        catalog: {
          buildProvider: () => ({
            api: "openai-completions",
            baseUrl: "https://api.acme-ai.com/v1",
            models: [{ id: "acme-large", name: "Acme Large" }],
          }),
        },
      },
    });
    ```

    如果你的鉴权流程还需要在新手引导期间 patch `models.providers.*`、别名以及智能体默认模型，请使用 `openclaw/plugin-sdk/provider-onboard` 中的 preset 辅助。更窄的辅助包括 `createDefaultModelPresetAppliers(...)`、`createDefaultModelsPresetAppliers(...)` 和 `createModelCatalogPresetAppliers(...)`。

  </Step>

  <Step title="添加动态模型解析">
    如果你的提供商接受任意模型 id（例如某个代理或路由器），请添加 `resolveDynamicModel`：

    ```typescript
    api.registerProvider({
      // ... id, label, auth, catalog from above

      resolveDynamicModel: (ctx) => ({
        id: ctx.modelId,
        name: ctx.modelId,
        provider: "acme-ai",
        api: "openai-completions",
        baseUrl: "https://api.acme-ai.com/v1",
        reasoning: false,
        input: ["text"],
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: 128000,
        maxTokens: 8192,
      }),
    });
    ```

    如果解析过程需要发起网络请求，请使用 `prepareDynamicModel` 做异步预热 —— 完成后会再次执行 `resolveDynamicModel`。

  </Step>

  <Step title="按需添加运行时 hooks">
    大多数提供商只需要 `catalog` + `resolveDynamicModel`。仅在提供商确实需要时再逐步添加其他 hook。

    <Tabs>
      <Tab title="令牌交换">
        对于每次推理调用前都需要令牌交换的提供商：

        ```typescript
        prepareRuntimeAuth: async (ctx) => {
          const exchanged = await exchangeToken(ctx.apiKey);
          return {
            apiKey: exchanged.token,
            baseUrl: exchanged.baseUrl,
            expiresAt: exchanged.expiresAt,
          };
        },
        ```
      </Tab>
      <Tab title="自定义请求头">
        对于需要自定义请求头或请求体修改的提供商：

        ```typescript
        // wrapStreamFn returns a StreamFn derived from ctx.streamFn
        wrapStreamFn: (ctx) => {
          if (!ctx.streamFn) return undefined;
          const inner = ctx.streamFn;
          return async (params) => {
            params.headers = {
              ...params.headers,
              "X-Acme-Version": "2",
            };
            return inner(params);
          };
        },
        ```
      </Tab>
      <Tab title="用量与计费">
        对于暴露用量/计费数据的提供商：

        ```typescript
        resolveUsageAuth: async (ctx) => {
          const auth = await ctx.resolveOAuthToken();
          return auth ? { token: auth.token } : null;
        },
        fetchUsageSnapshot: async (ctx) => {
          return await fetchAcmeUsage(ctx.token, ctx.timeoutMs);
        },
        ```
      </Tab>
    </Tabs>

    <Accordion title="全部可用的 provider hooks">
      OpenClaw 会按以下顺序调用这些 hooks。大多数提供商只会用到 2-3 个：

      | # | Hook | 何时使用 |
      | --- | --- | --- |
      | 1 | `catalog` | 模型目录或 base URL 默认值 |
      | 2 | `resolveDynamicModel` | 接受任意上游模型 id |
      | 3 | `prepareDynamicModel` | 解析前异步拉取元数据 |
      | 4 | `normalizeResolvedModel` | 在 runner 之前做传输重写 |
      | 5 | `capabilities` | transcript/tooling 元数据（数据，不可调用） |
      | 6 | `prepareExtraParams` | 默认请求参数 |
      | 7 | `wrapStreamFn` | 自定义请求头/请求体包装 |
      | 8 | `formatApiKey` | 自定义运行时令牌形状 |
      | 9 | `refreshOAuth` | 自定义 OAuth 刷新 |
      | 10 | `buildAuthDoctorHint` | 鉴权修复提示 |
      | 11 | `isCacheTtlEligible` | Prompt cache TTL 门控 |
      | 12 | `buildMissingAuthMessage` | 自定义缺失鉴权提示 |
      | 13 | `suppressBuiltInModel` | 隐藏过时的上游条目 |
      | 14 | `augmentModelCatalog` | 合成前向兼容条目 |
      | 15 | `isBinaryThinking` | 二元 thinking 开/关 |
      | 16 | `supportsXHighThinking` | 是否支持 `xhigh` reasoning |
      | 17 | `resolveDefaultThinkingLevel` | 默认 `/think` 策略 |
      | 18 | `isModernModelRef` | live/smoke 模型匹配 |
      | 19 | `prepareRuntimeAuth` | 推理前的令牌交换 |
      | 20 | `resolveUsageAuth` | 自定义用量凭证解析 |
      | 21 | `fetchUsageSnapshot` | 自定义用量端点 |
      | 22 | `onModelSelected` | 选中模型后的回调（例如遥测） |

      详细说明和真实示例见
      [内部机制：提供商运行时 hooks](/plugins/architecture#provider-runtime-hooks)。
    </Accordion>

  </Step>

  <Step title="添加额外能力（可选）">
    <a id="step-5-add-extra-capabilities"></a>
    一个提供商插件可以在文本推理之外，同时注册语音、媒体理解、图像生成和 Web 搜索能力：

    ```typescript
    register(api) {
      api.registerProvider({ id: "acme-ai", /* ... */ });

      api.registerSpeechProvider({
        id: "acme-ai",
        label: "Acme Speech",
        isConfigured: ({ config }) => Boolean(config.messages?.tts),
        synthesize: async (req) => ({
          audioBuffer: Buffer.from(/* PCM data */),
          outputFormat: "mp3",
          fileExtension: ".mp3",
          voiceCompatible: false,
        }),
      });

      api.registerMediaUnderstandingProvider({
        id: "acme-ai",
        capabilities: ["image", "audio"],
        describeImage: async (req) => ({ text: "A photo of..." }),
        transcribeAudio: async (req) => ({ text: "Transcript..." }),
      });

      api.registerImageGenerationProvider({
        id: "acme-ai",
        label: "Acme Images",
        generate: async (req) => ({ /* image result */ }),
      });
    }
    ```

    OpenClaw 会把这类插件归类为 **hybrid-capability** 插件。这也是公司级插件的推荐模式（每个 vendor 一个插件）。见 [内部机制：能力归属](/plugins/architecture#capability-ownership-model)。

  </Step>

  <Step title="测试">
    <a id="step-6-test"></a>
    ```typescript src/provider.test.ts
    import { describe, it, expect } from "vitest";
    // Export your provider config object from index.ts or a dedicated file
    import { acmeProvider } from "./provider.js";

    describe("acme-ai provider", () => {
      it("resolves dynamic models", () => {
        const model = acmeProvider.resolveDynamicModel!({
          modelId: "acme-beta-v3",
        } as any);
        expect(model.id).toBe("acme-beta-v3");
        expect(model.provider).toBe("acme-ai");
      });

      it("returns catalog when key is available", async () => {
        const result = await acmeProvider.catalog!.run({
          resolveProviderApiKey: () => ({ apiKey: "test-key" }),
        } as any);
        expect(result?.provider?.models).toHaveLength(2);
      });

      it("returns null catalog when no key", async () => {
        const result = await acmeProvider.catalog!.run({
          resolveProviderApiKey: () => ({ apiKey: undefined }),
        } as any);
        expect(result).toBeNull();
      });
    });
    ```

  </Step>
</Steps>

## 发布到 ClawHub

提供商插件的发布方式与其他外部代码插件相同：

```bash
clawhub package publish your-org/your-plugin --dry-run
clawhub package publish your-org/your-plugin
```

不要在这里使用旧版的仅适用于 skills 的发布别名；插件包应使用 `clawhub package publish`。

## 文件结构

```
<bundled-plugin-root>/acme-ai/
├── package.json              # openclaw.providers metadata
├── openclaw.plugin.json      # Manifest with providerAuthEnvVars
├── index.ts                  # definePluginEntry + registerProvider
└── src/
    ├── provider.test.ts      # Tests
    └── usage.ts              # Usage endpoint (optional)
```

## Catalog 顺序参考

`catalog.order` 用于控制你的 catalog 相对于内置提供商的合并时机：

| 顺序      | 何时执行       | 适用场景                     |
| --------- | -------------- | ---------------------------- |
| `simple`  | 第一阶段       | 纯 API-key 提供商            |
| `profile` | `simple` 之后  | 依赖 auth profile 的提供商   |
| `paired`  | `profile` 之后 | 合成多个相关条目             |
| `late`    | 最后           | 覆盖现有提供商（冲突时胜出） |

## 下一步

- [渠道插件](/plugins/sdk-channel-plugins) — 如果你的插件还提供一个渠道
- [SDK 运行时](/plugins/sdk-runtime) — `api.runtime` 辅助（TTS、搜索、子智能体）
- [SDK 概览](/plugins/sdk-overview) — 完整子路径导入参考
- [插件内部机制](/plugins/architecture#provider-runtime-hooks) — hook 细节与内置示例
