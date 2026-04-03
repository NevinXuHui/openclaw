---
summary: "DeepSeek 设置（鉴权 + 模型选择）"
read_when:
  - 你想在 OpenClaw 中使用 DeepSeek
  - 你需要 API key 环境变量或 CLI 鉴权选项
---

# DeepSeek

[DeepSeek](https://www.deepseek.com) 通过 OpenAI 兼容 API 提供强大的 AI 模型。

- Provider: `deepseek`
- Auth: `DEEPSEEK_API_KEY`
- API: OpenAI-compatible

## 快速开始

设置 API key（推荐：为 Gateway 持久保存）：

```bash
openclaw onboard --auth-choice deepseek-api-key
```

这会提示你输入 API key，并将 `deepseek/deepseek-chat` 设置为默认模型。

## 非交互示例

```bash
openclaw onboard --non-interactive \
  --mode local \
  --auth-choice deepseek-api-key \
  --deepseek-api-key "$DEEPSEEK_API_KEY" \
  --skip-health \
  --accept-risk
```

## 环境说明

如果 Gateway 作为守护进程运行（launchd/systemd），请确保 `DEEPSEEK_API_KEY` 对该进程可用（例如写入 `~/.openclaw/.env`，或通过 `env.shellEnv` 提供）。

## 可用模型

| Model ID            | 名称                     | 类型      | 上下文 |
| ------------------- | ------------------------ | --------- | ------ |
| `deepseek-chat`     | DeepSeek Chat (V3.2)     | General   | 128K   |
| `deepseek-reasoner` | DeepSeek Reasoner (V3.2) | Reasoning | 128K   |

- **deepseek-chat** 对应非思考模式下的 DeepSeek-V3.2。
- **deepseek-reasoner** 对应思考模式下的 DeepSeek-V3.2，带 chain-of-thought reasoning。

你可以在 [platform.deepseek.com](https://platform.deepseek.com/api_keys) 获取 API key。
