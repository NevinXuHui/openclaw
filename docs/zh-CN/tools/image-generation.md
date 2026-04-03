---
summary: "使用已配置的提供商（OpenAI、Google Gemini、fal、MiniMax）生成和编辑图像"
read_when:
  - 通过 agent 生成图像
  - 配置图像生成提供商和模型
  - 理解 image_generate 工具参数
title: "Image Generation"
---

# Image Generation

`image_generate` 工具让 agent 可以使用你已配置的提供商来创建和编辑图像。生成的图像会自动作为媒体附件出现在 agent 的回复中。

<Note>
  该工具仅在至少有一个图像生成提供商可用时才会出现。如果你没有看到 agent 工具列表中的 `image_generate`，请配置 `agents.defaults.imageGenerationModel` 或设置提供商 API 密钥。
</Note>

## 快速开始

1. 为至少一个提供商设置 API 密钥（例如 `OPENAI_API_KEY` 或 `GEMINI_API_KEY`）。
2. 可选地设置你的首选模型：

```json5
{
  agents: {
    defaults: {
      imageGenerationModel: "openai/gpt-image-1",
    },
  },
}
```

3. 向 agent 提问：_"Generate an image of a friendly lobster mascot."_

agent 会自动调用 `image_generate`。无需显式加入工具 allow-list —— 当有可用提供商时，它默认启用。

## 支持的提供商

| 提供商  | 默认模型                         | 编辑支持       | API 密钥                             |
| ------- | -------------------------------- | -------------- | ------------------------------------ |
| OpenAI  | `gpt-image-1`                    | 否             | `OPENAI_API_KEY`                     |
| Google  | `gemini-3.1-flash-image-preview` | 是             | `GEMINI_API_KEY` 或 `GOOGLE_API_KEY` |
| fal     | `fal-ai/flux/dev`                | 是             | `FAL_KEY`                            |
| MiniMax | `image-01`                       | 是（主体参考） | `MINIMAX_API_KEY`                    |

在运行时使用 `action: "list"` 来查看可用的提供商和模型：

```
/tool image_generate action=list
```

## 工具参数

| 参数          | 类型     | 说明                                                                            |
| ------------- | -------- | ------------------------------------------------------------------------------- |
| `prompt`      | string   | 图像生成提示词（`action: "generate"` 时必填）                                   |
| `action`      | string   | `"generate"`（默认）或 `"list"`（查看提供商）                                   |
| `model`       | string   | 提供商 / 模型覆盖，例如 `openai/gpt-image-1`                                    |
| `image`       | string   | 编辑模式下的单张参考图路径或 URL                                                |
| `images`      | string[] | 编辑模式下的多张参考图（最多 5 张）                                             |
| `size`        | string   | 尺寸提示：`1024x1024`、`1536x1024`、`1024x1536`、`1024x1792`、`1792x1024`       |
| `aspectRatio` | string   | 宽高比：`1:1`、`2:3`、`3:2`、`3:4`、`4:3`、`4:5`、`5:4`、`9:16`、`16:9`、`21:9` |
| `resolution`  | string   | 分辨率提示：`1K`、`2K` 或 `4K`                                                  |
| `count`       | number   | 生成图像数量（1–4）                                                             |
| `filename`    | string   | 输出文件名提示                                                                  |

并非所有提供商都支持所有参数。工具会传递各提供商支持的参数，并忽略其余部分。

## 配置

### 模型选择

```json5
{
  agents: {
    defaults: {
      // String form: primary model only
      imageGenerationModel: "google/gemini-3-pro-image-preview",

      // Object form: primary + ordered fallbacks
      imageGenerationModel: {
        primary: "openai/gpt-image-1",
        fallbacks: ["google/gemini-3.1-flash-image-preview", "fal/fal-ai/flux/dev"],
      },
    },
  },
}
```

### 提供商选择顺序

当生成图像时，OpenClaw 会按以下顺序尝试提供商：

1. 工具调用中的 **`model` 参数**（如果 agent 指定了）
2. 配置中的 **`imageGenerationModel.primary`**
3. 按顺序尝试 **`imageGenerationModel.fallbacks`**
4. **自动检测** —— 查询所有已注册提供商的默认值，优先顺序为：已配置的主提供商，然后 OpenAI，然后 Google，再然后是其他提供商

如果某个提供商失败（认证错误、速率限制等），系统会自动尝试下一个候选项。如果全部失败，错误中会包含每次尝试的详细信息。

### 图像编辑

Google、fal 和 MiniMax 支持编辑参考图像。传入参考图路径或 URL：

```
"Generate a watercolor version of this photo" + image: "/path/to/photo.jpg"
```

Google 通过 `images` 参数最多支持 5 张参考图。fal 和 MiniMax 支持 1 张。

## 提供商能力

| 能力                   | OpenAI          | Google            | fal             | MiniMax                |
| ---------------------- | --------------- | ----------------- | --------------- | ---------------------- |
| 生成                   | 是（最多 4 张） | 是（最多 4 张）   | 是（最多 4 张） | 是（最多 9 张）        |
| 编辑 / 参考图          | 否              | 是（最多 5 张图） | 是（1 张图）    | 是（1 张图，主体参考） |
| 尺寸控制               | 是              | 是                | 是              | 否                     |
| 宽高比                 | 否              | 是                | 是（仅生成）    | 是                     |
| 分辨率（1K / 2K / 4K） | 否              | 是                | 是              | 否                     |

## 相关内容

- [Tools Overview](/tools) — 所有可用 agent 工具
- [Configuration Reference](/gateway/configuration-reference#agent-defaults) — `imageGenerationModel` 配置
- [Models](/concepts/models) — 模型配置与故障转移
