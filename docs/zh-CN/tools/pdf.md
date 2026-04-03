---
title: "PDF 工具"
summary: "使用原生提供商支持和提取回退分析一个或多个 PDF 文档"
read_when:
  - 你想从 agent 分析 PDF
  - 你需要精确了解 pdf 工具参数和限制
  - 你正在调试原生 PDF 模式与提取回退模式
---

# PDF 工具

`pdf` 用于分析一个或多个 PDF 文档并返回文本。

快速行为说明：

- 对 Anthropic 和 Google 模型提供商使用原生提供商模式。
- 对其他提供商使用提取回退模式（先提取文本，不足时再提取页面图像）。
- 支持单个输入（`pdf`）或多个输入（`pdfs`），每次调用最多 10 个 PDF。

## 可用性

只有当 OpenClaw 能为 agent 解析出支持 PDF 的模型配置时，才会注册该工具：

1. `agents.defaults.pdfModel`
2. 回退到 `agents.defaults.imageModel`
3. 再回退到基于可用认证的尽力默认提供商

如果无法解析出可用模型，则不会暴露 `pdf` 工具。

## 输入参考

- `pdf`（`string`）：单个 PDF 路径或 URL
- `pdfs`（`string[]`）：多个 PDF 路径或 URL，总数最多 10 个
- `prompt`（`string`）：分析提示词，默认值为 `Analyze this PDF document.`
- `pages`（`string`）：页码过滤，例如 `1-5` 或 `1,3,7-9`
- `model`（`string`）：可选模型覆盖（`provider/model`）
- `maxBytesMb`（`number`）：每个 PDF 的大小上限（MB）

输入说明：

- `pdf` 与 `pdfs` 会在加载前合并并去重。
- 如果未提供 PDF 输入，工具会报错。
- `pages` 会按 1 基页码解析、去重、排序，并限制在配置的最大页数内。
- `maxBytesMb` 默认取 `agents.defaults.pdfMaxBytesMb`，否则为 `10`。

## 支持的 PDF 引用方式

- 本地文件路径（包括 `~` 展开）
- `file://` URL
- `http://` 与 `https://` URL

引用说明：

- 其他 URI 协议（例如 `ftp://`）会被拒绝，并返回 `unsupported_pdf_reference`。
- 在沙箱模式下，远程 `http(s)` URL 会被拒绝。
- 开启仅工作区文件策略后，位于允许根目录之外的本地文件路径会被拒绝。

## 执行模式

### 原生提供商模式

当提供商为 `anthropic` 与 `google` 时，使用原生模式。
该工具会直接把原始 PDF 字节发送到提供商 API。

原生模式限制：

- 不支持 `pages`。如果设置该参数，工具会返回错误。

### 提取回退模式

对于非原生提供商，使用回退模式。

流程：

1. 从选定页面提取文本（最多 `agents.defaults.pdfMaxPages` 页，默认 `20`）。
2. 如果提取文本长度少于 `200` 个字符，则把选定页面渲染为 PNG 图像并一并包含。
3. 将提取内容和提示词发送到所选模型。

回退模式细节：

- 页面图像提取使用 `4,000,000` 的像素预算。
- 如果目标模型不支持图像输入，且又无法提取文本，工具会报错。
- 提取回退依赖 `pdfjs-dist`（图像渲染还需要 `@napi-rs/canvas`）。

## 配置

```json5
{
  agents: {
    defaults: {
      pdfModel: {
        primary: "anthropic/claude-opus-4-6",
        fallbacks: ["openai/gpt-5-mini"],
      },
      pdfMaxBytesMb: 10,
      pdfMaxPages: 20,
    },
  },
}
```

完整字段说明请参见 [Configuration Reference](/gateway/configuration-reference)。

## 输出细节

工具会在 `content[0].text` 中返回文本，并在 `details` 中返回结构化元数据。

常见 `details` 字段：

- `model`：解析后的模型引用（`provider/model`）
- `native`：原生提供商模式时为 `true`，回退模式时为 `false`
- `attempts`：回退过程中先失败后成功的尝试记录

路径字段：

- 单个 PDF 输入：`details.pdf`
- 多个 PDF 输入：`details.pdfs[]`，每项包含 `pdf`
- 沙箱路径重写元数据（如适用）：`rewrittenFrom`

## 错误行为

- 缺少 PDF 输入：抛出 `pdf required: provide a path or URL to a PDF document`
- PDF 数量过多：在 `details.error = "too_many_pdfs"` 中返回结构化错误
- 不支持的引用协议：返回 `details.error = "unsupported_pdf_reference"`
- 原生模式下使用 `pages`：抛出清晰错误 `pages is not supported with native PDF providers`

## 示例

单个 PDF：

```json
{
  "pdf": "/tmp/report.pdf",
  "prompt": "Summarize this report in 5 bullets"
}
```

多个 PDF：

```json
{
  "pdfs": ["/tmp/q1.pdf", "/tmp/q2.pdf"],
  "prompt": "Compare risks and timeline changes across both documents"
}
```

带页码过滤的回退模型：

```json
{
  "pdf": "https://example.com/report.pdf",
  "pages": "1-3,7",
  "model": "openai/gpt-5-mini",
  "prompt": "Extract only customer-impacting incidents"
}
```

## 相关内容

- [Tools Overview](/tools) — 所有可用 agent 工具
- [Configuration Reference](/gateway/configuration-reference#agent-defaults) — pdfMaxBytesMb 与 pdfMaxPages 配置
