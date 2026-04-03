---
title: "Volcengine (Doubao)"
summary: "Volcano Engine 设置（Doubao 模型、通用 + 编程端点）"
read_when:
  - 您想在 OpenClaw 中使用 Volcano Engine 或 Doubao 模型
  - 您需要 Volcengine API 密钥设置
x-i18n:
  sourceCommit: "latest"
  sourceFile: "providers/volcengine.md"
---

# Volcengine (Doubao)

Volcengine provider 提供对 Doubao 模型和 Volcano Engine 上托管的第三方模型的访问，为通用和编程工作负载提供单独的端点。

- Providers：`volcengine`（通用）+ `volcengine-plan`（编程）
- 认证：`VOLCANO_ENGINE_API_KEY`
- API：OpenAI 兼容

## 快速入门

1. 设置 API 密钥：

```bash
openclaw onboard --auth-choice volcengine-api-key
```

2. 设置默认模型：

```json5
{
  agents: {
    defaults: {
      model: { primary: "volcengine-plan/ark-code-latest" },
    },
  },
}
```

## 非交互式示例

```bash
openclaw onboard --non-interactive \
  --mode local \
  --auth-choice volcengine-api-key \
  --volcengine-api-key "$VOLCANO_ENGINE_API_KEY"
```

## Providers 和端点

| Provider          | 端点                                      | 用例     |
| ----------------- | ----------------------------------------- | -------- |
| `volcengine`      | `ark.cn-beijing.volces.com/api/v3`        | 通用模型 |
| `volcengine-plan` | `ark.cn-beijing.volces.com/api/coding/v3` | 编程模型 |

两个 providers 都从单个 API 密钥配置。设置会自动注册两者。

## 可用模型

- **doubao-seed-1-8** - Doubao Seed 1.8（通用，默认）
- **doubao-seed-code-preview** - Doubao 编程模型
- **ark-code-latest** - 编程套餐默认
- **Kimi K2.5** - 通过 Volcano Engine 的 Moonshot AI
- **GLM-4.7** - 通过 Volcano Engine 的 GLM
- **DeepSeek V3.2** - 通过 Volcano Engine 的 DeepSeek

大多数模型支持文本 + 图像输入。上下文窗口范围从 128K 到 256K tokens。

## 环境注意事项

如果 Gateway 网关作为守护进程运行（launchd/systemd），请确保 `VOLCANO_ENGINE_API_KEY` 对该进程可用（例如，在 `~/.openclaw/.env` 中或通过 `env.shellEnv`）。
