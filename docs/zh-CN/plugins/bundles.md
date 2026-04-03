---
summary: "安装和使用 Codex、Claude 和 Cursor bundles 作为 OpenClaw 插件"
read_when:
  - 您想安装 Codex、Claude 或 Cursor 兼容的 bundle
  - 您需要了解 OpenClaw 如何将 bundle 内容映射到原生功能
  - 您正在调试 bundle 检测或缺失的功能
title: "插件 Bundles"
x-i18n:
  sourceCommit: "latest"
  sourceFile: "plugins/bundles.md"
---

# 插件 Bundles

OpenClaw 可以从三个外部生态系统安装插件：**Codex**、**Claude** 和 **Cursor**。这些被称为 **bundles** — 内容和元数据包，OpenClaw 将其映射到原生功能，如 skills、钩子和 MCP 工具。

<Info>
  Bundles **不**等同于原生 OpenClaw 插件。原生插件在进程内运行，可以注册任何功能。Bundles 是具有选择性功能映射和更窄信任边界的内容包。
</Info>

## 为什么存在 bundles

许多有用的插件以 Codex、Claude 或 Cursor 格式发布。OpenClaw 不要求作者将它们重写为原生 OpenClaw 插件，而是检测这些格式并将其支持的内容映射到原生功能集。这意味着您可以安装 Claude 命令包或 Codex skill bundle 并立即使用它。

## 安装 bundle

<Steps>
  <Step title="从目录、存档或市场安装">
    ```bash
    # 本地目录
    openclaw plugins install ./my-bundle

    # 存档
    openclaw plugins install ./my-bundle.tgz

    # Claude 市场
    openclaw plugins marketplace list <marketplace-name>
    openclaw plugins install <plugin-name>@<marketplace-name>
    ```

  </Step>

  <Step title="验证检测">
    ```bash
    openclaw plugins list
    openclaw plugins inspect <id>
    ```

    Bundles 显示为 `Format: bundle`，子类型为 `codex`、`claude` 或 `cursor`。

  </Step>

  <Step title="重启并使用">
    ```bash
    openclaw gateway restart
    ```

    映射的功能（skills、钩子、MCP 工具）在下一个会话中可用。

  </Step>
</Steps>

## OpenClaw 从 bundles 映射的内容

并非每个 bundle 功能今天都在 OpenClaw 中运行。以下是有效的内容和已检测但尚未连接的内容。

### 现在支持

| 功能       | 如何映射                                                                 | 适用于         |
| ---------- | ------------------------------------------------------------------------ | -------------- |
| Skill 内容 | Bundle skill 根作为普通 OpenClaw skills 加载                             | 所有格式       |
| 命令       | `commands/` 和 `.cursor/commands/` 被视为 skill 根                       | Claude、Cursor |
| 钩子包     | OpenClaw 风格的 `HOOK.md` + `handler.ts` 布局                            | Codex          |
| MCP 工具   | Bundle MCP 配置合并到嵌入式 Pi 设置中；支持的 stdio 和 HTTP 服务器已加载 | 所有格式       |
| 设置       | Claude `settings.json` 作为嵌入式 Pi 默认值导入                          | Claude         |

#### Skill 内容

- bundle skill 根作为普通 OpenClaw skill 根加载
- Claude `commands` 根被视为额外的 skill 根
- Cursor `.cursor/commands` 根被视为额外的 skill 根

这意味着 Claude markdown 命令文件通过普通的 OpenClaw skill 加载器工作。Cursor 命令 markdown 通过相同的路径工作。

#### 钩子包

- bundle 钩子根**仅**在使用普通 OpenClaw 钩子包布局时工作。今天这主要是 Codex 兼容的情况：
  - `HOOK.md`
  - `handler.ts` 或 `handler.js`

#### Pi 的 MCP

- 启用的 bundles 可以贡献 MCP 服务器配置
- OpenClaw 将 bundle MCP 配置合并到有效的嵌入式 Pi 设置中作为 `mcpServers`
- OpenClaw 通过启动 stdio 服务器或连接到 HTTP 服务器，在嵌入式 Pi 智能体回合期间公开支持的 bundle MCP 工具
- 项目本地 Pi 设置在 bundle 默认值之后仍然适用，因此工作区设置可以在需要时覆盖 bundle MCP 条目

##### 传输

MCP 服务器可以使用 stdio 或 HTTP 传输：

**Stdio** 启动子进程：

```json
{
  "mcp": {
    "servers": {
      "my-server": {
        "command": "node",
        "args": ["server.js"],
        "env": { "PORT": "3000" }
      }
    }
  }
}
```

**HTTP** 默认通过 `sse` 连接到正在运行的 MCP 服务器，或在请求时使用 `streamable-http`：

```json
{
  "mcp": {
    "servers": {
      "my-server": {
        "url": "http://localhost:3100/mcp",
        "transport": "streamable-http",
        "headers": {
          "Authorization": "Bearer ${MY_SECRET_TOKEN}"
        },
        "connectionTimeoutMs": 30000
      }
    }
  }
}
```

- `transport` 可以设置为 `"streamable-http"` 或 `"sse"`；省略时，OpenClaw 使用 `sse`
- 仅允许 `http:` 和 `https:` URL 方案
- `headers` 值支持 `${ENV_VAR}` 插值
- 同时具有 `command` 和 `url` 的服务器条目会被拒绝
- URL 凭据（userinfo 和查询参数）从工具描述和日志中编辑
- `connectionTimeoutMs` 覆盖 stdio 和 HTTP 传输的默认 30 秒连接超时

##### 工具命名

OpenClaw 以 `serverName__toolName` 形式使用 provider 安全名称注册 bundle MCP 工具。例如，键为 `"vigil-harbor"` 的服务器公开 `memory_search` 工具，注册为 `vigil-harbor__memory_search`。

- `A-Za-z0-9_-` 之外的字符替换为 `-`
- 服务器前缀限制为 30 个字符
- 完整工具名称限制为 64 个字符
- 空服务器名称回退到 `mcp`
- 冲突的清理名称使用数字后缀消歧

#### 嵌入式 Pi 设置

- 当 bundle 启用时，Claude `settings.json` 作为默认嵌入式 Pi 设置导入
- OpenClaw 在应用之前清理 shell 覆盖键

清理的键：

- `shellPath`
- `shellCommandPrefix`

### 已检测但未执行

这些在诊断中被识别和显示，但 OpenClaw 不运行它们：

- Claude `agents`、`hooks.json` 自动化、`lspServers`、`outputStyles`
- Cursor `.cursor/agents`、`.cursor/hooks.json`、`.cursor/rules`
- Codex 内联/应用元数据，超出功能报告

## Bundle 格式

<AccordionGroup>
  <Accordion title="Codex bundles">
    标记：`.codex-plugin/plugin.json`

    可选内容：`skills/`、`hooks/`、`.mcp.json`、`.app.json`

    当 Codex bundles 使用 skill 根和 OpenClaw 风格的钩子包目录（`HOOK.md` + `handler.ts`）时，最适合 OpenClaw。

  </Accordion>

  <Accordion title="Claude bundles">
    两种检测模式：

    - **基于清单：** `.claude-plugin/plugin.json`
    - **无清单：** 默认 Claude 布局（`skills/`、`commands/`、`agents/`、`hooks/`、`.mcp.json`、`settings.json`）

    Claude 特定行为：

    - `commands/` 被视为 skill 内容
    - `settings.json` 导入到嵌入式 Pi 设置中（shell 覆盖键被清理）
    - `.mcp.json` 向嵌入式 Pi 公开支持的 stdio 工具
    - `hooks/hooks.json` 被检测但不执行
    - 清单中的自定义组件路径是附加的（它们扩展默认值，而不是替换它们）

  </Accordion>

  <Accordion title="Cursor bundles">
    标记：`.cursor-plugin/plugin.json`

    可选内容：`skills/`、`.cursor/commands/`、`.cursor/agents/`、`.cursor/rules/`、`.cursor/hooks.json`、`.mcp.json`

    - `.cursor/commands/` 被视为 skill 内容
    - `.cursor/rules/`、`.cursor/agents/` 和 `.cursor/hooks.json` 仅检测

  </Accordion>
</AccordionGroup>

## 检测优先级

OpenClaw 首先检查原生插件格式：

1. `openclaw.plugin.json` 或带有 `openclaw.extensions` 的有效 `package.json` — 视为**原生插件**
2. Bundle 标记（`.codex-plugin/`、`.claude-plugin/` 或默认 Claude/Cursor 布局）— 视为 **bundle**

如果目录同时包含两者，OpenClaw 使用原生路径。这可以防止双格式包被部分安装为 bundles。

## 安全性

Bundles 的信任边界比原生插件更窄：

- OpenClaw **不**在进程内加载任意 bundle 运行时模块
- Skills 和钩子包路径必须保持在插件根内（边界检查）
- 设置文件使用相同的边界检查读取
- 支持的 stdio MCP 服务器可以作为子进程启动

这使得 bundles 默认更安全，但您仍应将第三方 bundles 视为它们确实公开的功能的受信任内容。

## 故障排除

<AccordionGroup>
  <Accordion title="Bundle 被检测到但功能不运行">
    运行 `openclaw plugins inspect <id>`。如果功能被列出但标记为未连接，那是产品限制 — 不是损坏的安装。
  </Accordion>

  <Accordion title="Claude 命令文件未出现">
    确保 bundle 已启用，并且 markdown 文件位于检测到的 `commands/` 或 `skills/` 根内。
  </Accordion>

  <Accordion title="Claude 设置不适用">
    仅支持来自 `settings.json` 的嵌入式 Pi 设置。OpenClaw 不将 bundle 设置视为原始配置补丁。
  </Accordion>

  <Accordion title="Claude 钩子不执行">
    `hooks/hooks.json` 仅检测。如果您需要可运行的钩子，请使用 OpenClaw 钩子包布局或发布原生插件。
  </Accordion>
</AccordionGroup>

## 相关

- [Install and Configure Plugins](/tools/plugin)
- [Building Plugins](/plugins/building-plugins) — 创建原生插件
- [Plugin Manifest](/plugins/manifest) — 原生清单架构
