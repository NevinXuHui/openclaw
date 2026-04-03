---
summary: "密钥管理：SecretRef 契约、运行时快照行为和安全单向清理"
read_when:
  - 为提供商凭据和 `auth-profiles.json` 引用配置 SecretRefs
  - 在生产环境中安全地操作密钥重载、审计、配置和应用
  - 了解启动快速失败、非活动表面过滤和最后已知良好行为
title: "密钥管理"
x-i18n:
  sourceCommit: "latest"
  sourceFile: "gateway/secrets.md"
---

# 密钥管理

OpenClaw 支持增量式 SecretRefs，因此支持的凭据无需以明文形式存储在配置中。

明文仍然有效。SecretRefs 是每个凭据的可选功能。

## 目标和运行时模型

密钥被解析为内存中的运行时快照。

- 解析在激活期间是急切的，而不是在请求路径上延迟的。
- 当有效活动的 SecretRef 无法解析时，启动会快速失败。
- 重载使用原子交换：完全成功，或保留最后已知良好的快照。
- SecretRef 策略违规（例如 OAuth 模式的 auth profiles 与 SecretRef 输入组合）会在运行时交换之前使激活失败。
- 运行时请求仅从活动的内存快照中读取。
- 在第一次成功的配置激活/加载之后，运行时代码路径会持续读取该活动的内存快照，直到成功的重载将其交换。
- 出站传递路径也从该活动快照中读取（例如 Discord 回复/线程传递和 Telegram 操作发送）；它们不会在每次发送时重新解析 SecretRefs。

这使密钥提供商的中断远离热请求路径。

## 活动表面过滤

SecretRefs 仅在有效活动的表面上进行验证。

- 已启用的表面：未解析的引用会阻止启动/重载。
- 非活动表面：未解析的引用不会阻止启动/重载。
- 非活动引用会发出带有代码 `SECRETS_REF_IGNORED_INACTIVE_SURFACE` 的非致命诊断信息。

非活动表面的示例：

- 已禁用的 channel/account 条目。
- 没有已启用 account 继承的顶级 channel 凭据。
- 已禁用的工具/功能表面。
- 未被 `tools.web.search.provider` 选择的 Web 搜索提供商特定密钥。
  在 auto 模式下（未设置提供商），密钥会按优先级顺序进行咨询，用于提供商自动检测，直到一个解析成功。
  选择后，未选择的提供商密钥将被视为非活动，直到被选择。
- Sandbox SSH 认证材料（`agents.defaults.sandbox.ssh.identityData`、
  `certificateData`、`knownHostsData`，以及每个 agent 的覆盖）仅在
  默认 agent 或已启用 agent 的有效 sandbox 后端为 `ssh` 时才处于活动状态。
- `gateway.remote.token` / `gateway.remote.password` SecretRefs 在以下任一情况为真时处于活动状态：
  - `gateway.mode=remote`
  - 配置了 `gateway.remote.url`
  - `gateway.tailscale.mode` 为 `serve` 或 `funnel`
  - 在没有这些远程表面的 local 模式下：
    - 当 token 认证可以获胜且未配置 env/auth token 时，`gateway.remote.token` 处于活动状态。
    - 仅当 password 认证可以获胜且未配置 env/auth password 时，`gateway.remote.password` 才处于活动状态。
- 当设置了 `OPENCLAW_GATEWAY_TOKEN` 时，`gateway.auth.token` SecretRef 对于启动认证解析是非活动的，因为 env token 输入在该运行时中获胜。

## Gateway 认证表面诊断

当在 `gateway.auth.token`、`gateway.auth.password`、
`gateway.remote.token` 或 `gateway.remote.password` 上配置 SecretRef 时，gateway 启动/重载会明确记录
表面状态：

- `active`：SecretRef 是有效认证表面的一部分，必须解析。
- `inactive`：SecretRef 被忽略，因为另一个认证表面获胜，或者
  因为远程认证被禁用/未激活。

这些条目使用 `SECRETS_GATEWAY_AUTH_SURFACE` 记录，并包含活动表面策略使用的原因，因此您可以看到为什么凭据被视为活动或非活动。

## Onboarding 引用预检

当 onboarding 在交互模式下运行并且您选择 SecretRef 存储时，OpenClaw 会在保存之前运行预检验证：

- Env 引用：验证 env var 名称并确认在设置期间可见非空值。
- Provider 引用（`file` 或 `exec`）：验证提供商选择，解析 `id`，并检查解析的值类型。
- 快速启动重用路径：当 `gateway.auth.token` 已经是 SecretRef 时，onboarding 会在探测/仪表板引导之前解析它（对于 `env`、`file` 和 `exec` 引用），使用相同的快速失败门控。

如果验证失败，onboarding 会显示错误并让您重试。

## SecretRef 契约

在所有地方使用一个对象形状：

```json5
{ source: "env" | "file" | "exec", provider: "default", id: "..." }
```

### `source: "env"`

```json5
{ source: "env", provider: "default", id: "OPENAI_API_KEY" }
```

验证：

- `provider` 必须匹配 `^[a-z][a-z0-9_-]{0,63}$`
- `id` 必须匹配 `^[A-Z][A-Z0-9_]{0,127}$`

### `source: "file"`

```json5
{ source: "file", provider: "filemain", id: "/providers/openai/apiKey" }
```

验证：

- `provider` 必须匹配 `^[a-z][a-z0-9_-]{0,63}$`
- `id` 必须是绝对 JSON 指针（`/...`）
- 段中的 RFC6901 转义：`~` => `~0`，`/` => `~1`

### `source: "exec"`

```json5
{ source: "exec", provider: "vault", id: "providers/openai/apiKey" }
```

验证：

- `provider` 必须匹配 `^[a-z][a-z0-9_-]{0,63}$`
- `id` 必须匹配 `^[A-Za-z0-9][A-Za-z0-9._:/-]{0,255}$`
- `id` 不得包含 `.` 或 `..` 作为斜杠分隔的路径段（例如 `a/../b` 被拒绝）

## Provider 配置

在 `secrets.providers` 下定义提供商：

```json5
{
  secrets: {
    providers: {
      default: { source: "env" },
      filemain: {
        source: "file",
        path: "~/.openclaw/secrets.json",
        mode: "json", // 或 "singleValue"
      },
      vault: {
        source: "exec",
        command: "/usr/local/bin/openclaw-vault-resolver",
        args: ["--profile", "prod"],
        passEnv: ["PATH", "VAULT_ADDR"],
        jsonOnly: true,
      },
    },
    defaults: {
      env: "default",
      file: "filemain",
      exec: "vault",
    },
    resolution: {
      maxProviderConcurrency: 4,
      maxRefsPerProvider: 512,
      maxBatchBytes: 262144,
    },
  },
}
```

### Env provider

- 通过 `allowlist` 可选的允许列表。
- 缺失/空的 env 值会导致解析失败。

### File provider

- 从 `path` 读取本地文件。
- `mode: "json"` 期望 JSON 对象负载并将 `id` 解析为指针。
- `mode: "singleValue"` 期望引用 id `"value"` 并返回文件内容。
- 路径必须通过所有权/权限检查。
- Windows 失败关闭注意事项：如果路径的 ACL 验证不可用，解析会失败。仅对于受信任的路径，在该提供商上设置 `allowInsecurePath: true` 以绕过路径安全检查。

### Exec provider

- 运行配置的绝对二进制路径，无 shell。
- 默认情况下，`command` 必须指向常规文件（而不是符号链接）。
- 设置 `allowSymlinkCommand: true` 以允许符号链接命令路径（例如 Homebrew shims）。OpenClaw 验证解析的目标路径。
- 将 `allowSymlinkCommand` 与 `trustedDirs` 配对用于包管理器路径（例如 `["/opt/homebrew"]`）。
- 支持超时、无输出超时、输出字节限制、env 允许列表和受信任目录。
- Windows 失败关闭注意事项：如果命令路径的 ACL 验证不可用，解析会失败。仅对于受信任的路径，在该提供商上设置 `allowInsecurePath: true` 以绕过路径安全检查。

请求负载（stdin）：

```json
{ "protocolVersion": 1, "provider": "vault", "ids": ["providers/openai/apiKey"] }
```

响应负载（stdout）：

```jsonc
{ "protocolVersion": 1, "values": { "providers/openai/apiKey": "<openai-api-key>" } } // pragma: allowlist secret
```

可选的每个 id 错误：

```json
{
  "protocolVersion": 1,
  "values": {},
  "errors": { "providers/openai/apiKey": { "message": "not found" } }
}
```

## Exec 集成示例

### 1Password CLI

```json5
{
  secrets: {
    providers: {
      onepassword_openai: {
        source: "exec",
        command: "/opt/homebrew/bin/op",
        allowSymlinkCommand: true, // Homebrew 符号链接二进制文件所需
        trustedDirs: ["/opt/homebrew"],
        args: ["read", "op://Personal/OpenClaw QA API Key/password"],
        passEnv: ["HOME"],
        jsonOnly: false,
      },
    },
  },
  models: {
    providers: {
      openai: {
        baseUrl: "https://api.openai.com/v1",
        models: [{ id: "gpt-5", name: "gpt-5" }],
        apiKey: { source: "exec", provider: "onepassword_openai", id: "value" },
      },
    },
  },
}
```

### HashiCorp Vault CLI

```json5
{
  secrets: {
    providers: {
      vault_openai: {
        source: "exec",
        command: "/opt/homebrew/bin/vault",
        allowSymlinkCommand: true, // Homebrew 符号链接二进制文件所需
        trustedDirs: ["/opt/homebrew"],
        args: ["kv", "get", "-field=OPENAI_API_KEY", "secret/openclaw"],
        passEnv: ["VAULT_ADDR", "VAULT_TOKEN"],
        jsonOnly: false,
      },
    },
  },
  models: {
    providers: {
      openai: {
        baseUrl: "https://api.openai.com/v1",
        models: [{ id: "gpt-5", name: "gpt-5" }],
        apiKey: { source: "exec", provider: "vault_openai", id: "value" },
      },
    },
  },
}
```

### `sops`

```json5
{
  secrets: {
    providers: {
      sops_openai: {
        source: "exec",
        command: "/opt/homebrew/bin/sops",
        allowSymlinkCommand: true, // Homebrew 符号链接二进制文件所需
        trustedDirs: ["/opt/homebrew"],
        args: ["-d", "--extract", '["providers"]["openai"]["apiKey"]', "/path/to/secrets.enc.json"],
        passEnv: ["SOPS_AGE_KEY_FILE"],
        jsonOnly: false,
      },
    },
  },
  models: {
    providers: {
      openai: {
        baseUrl: "https://api.openai.com/v1",
        models: [{ id: "gpt-5", name: "gpt-5" }],
        apiKey: { source: "exec", provider: "sops_openai", id: "value" },
      },
    },
  },
}
```

## MCP server 环境变量

通过 `plugins.entries.acpx.config.mcpServers` 配置的 MCP server env vars 支持 SecretInput。这使 API 密钥和 tokens 远离明文配置：

```json5
{
  plugins: {
    entries: {
      acpx: {
        enabled: true,
        config: {
          mcpServers: {
            github: {
              command: "npx",
              args: ["-y", "@modelcontextprotocol/server-github"],
              env: {
                GITHUB_PERSONAL_ACCESS_TOKEN: {
                  source: "env",
                  provider: "default",
                  id: "MCP_GITHUB_PAT",
                },
              },
            },
          },
        },
      },
    },
  },
}
```

明文字符串值仍然有效。在 MCP server 进程生成之前，在 gateway 激活期间解析 env-template 引用（如 `${MCP_SERVER_API_KEY}`）和 SecretRef 对象。与其他 SecretRef 表面一样，仅当 `acpx` 插件有效活动时，未解析的引用才会阻止激活。

## Sandbox SSH 认证材料

核心 `ssh` sandbox 后端也支持 SSH 认证材料的 SecretRefs：

```json5
{
  agents: {
    defaults: {
      sandbox: {
        mode: "all",
        backend: "ssh",
        ssh: {
          target: "user@gateway-host:22",
          identityData: { source: "env", provider: "default", id: "SSH_IDENTITY" },
          certificateData: { source: "env", provider: "default", id: "SSH_CERTIFICATE" },
          knownHostsData: { source: "env", provider: "default", id: "SSH_KNOWN_HOSTS" },
        },
      },
    },
  },
}
```

运行时行为：

- OpenClaw 在 sandbox 激活期间解析这些引用，而不是在每次 SSH 调用期间延迟解析。
- 解析的值被写入具有限制性权限的临时文件，并在生成的 SSH 配置中使用。
- 如果有效的 sandbox 后端不是 `ssh`，这些引用保持非活动状态，不会阻止启动。

## 支持的凭据表面

规范的支持和不支持的凭据列在：

- [SecretRef Credential Surface](/reference/secretref-credential-surface)

运行时铸造或轮换凭据和 OAuth 刷新材料被有意排除在只读 SecretRef 解析之外。

## 必需的行为和优先级

- 没有引用的字段：不变。
- 有引用的字段：在激活期间在活动表面上是必需的。
- 如果明文和引用都存在，引用在支持的优先级路径上优先。
- 编辑哨兵 `__OPENCLAW_REDACTED__` 保留用于内部配置编辑/恢复，并作为字面提交的配置数据被拒绝。

警告和审计信号：

- `SECRETS_REF_OVERRIDES_PLAINTEXT`（运行时警告）
- `REF_SHADOWED`（当 `auth-profiles.json` 凭据优先于 `openclaw.json` 引用时的审计发现）

Google Chat 兼容性行为：

- `serviceAccountRef` 优先于明文 `serviceAccount`。
- 当设置了同级引用时，明文值被忽略。

## 激活触发器

密钥激活运行于：

- 启动（预检加最终激活）
- 配置重载热应用路径
- 配置重载重启检查路径
- 通过 `secrets.reload` 手动重载
- Gateway 配置写入 RPC 预检（`config.set` / `config.apply` / `config.patch`），用于在持久化编辑之前检查提交的配置负载中活动表面 SecretRef 的可解析性

激活契约：

- 成功原子交换快照。
- 启动失败中止 gateway 启动。
- 运行时重载失败保留最后已知良好的快照。
- 写入 RPC 预检失败拒绝提交的配置，并保持磁盘配置和活动运行时快照不变。
- 向出站辅助/工具调用提供显式的每次调用 channel token 不会触发 SecretRef 激活；激活点仍然是启动、重载和显式 `secrets.reload`。

## 降级和恢复信号

当健康状态后重载时激活失败时，OpenClaw 进入降级密钥状态。

一次性系统事件和日志代码：

- `SECRETS_RELOADER_DEGRADED`
- `SECRETS_RELOADER_RECOVERED`

行为：

- 降级：运行时保留最后已知良好的快照。
- 恢复：在下一次成功激活后发出一次。
- 已经降级时的重复失败会记录警告，但不会发送垃圾事件。
- 启动快速失败不会发出降级事件，因为运行时从未变为活动状态。

## 命令路径解析

命令路径可以通过 gateway 快照 RPC 选择支持的 SecretRef 解析。

有两种广泛的行为：

- 严格命令路径（例如 `openclaw memory` 远程内存路径和 `openclaw qr --remote`）从活动快照中读取，并在所需的 SecretRef 不可用时快速失败。
- 只读命令路径（例如 `openclaw status`、`openclaw status --all`、`openclaw channels status`、`openclaw channels resolve`、`openclaw security audit` 和只读 doctor/config 修复流程）也优先使用活动快照，但在该命令路径中目标 SecretRef 不可用时会降级而不是中止。

只读行为：

- 当 gateway 运行时，这些命令首先从活动快照中读取。
- 如果 gateway 解析不完整或 gateway 不可用，它们会尝试针对特定命令表面的目标本地回退。
- 如果目标 SecretRef 仍然不可用，命令会继续使用降级的只读输出和明确的诊断信息，例如"已配置但在此命令路径中不可用"。
- 此降级行为仅限于命令本地。它不会削弱运行时启动、重载或发送/认证路径。

其他注意事项：

- 后端密钥轮换后的快照刷新由 `openclaw secrets reload` 处理。
- 这些命令路径使用的 Gateway RPC 方法：`secrets.resolve`。

## 审计和配置工作流

默认操作员流程：

```bash
openclaw secrets audit --check
openclaw secrets configure
openclaw secrets audit --check
```

### `secrets audit`

发现包括：

- 静态明文值（`openclaw.json`、`auth-profiles.json`、`.env` 和生成的 `agents/*/agent/models.json`）
- 生成的 `models.json` 条目中的明文敏感提供商标头残留
- 未解析的引用
- 优先级遮蔽（`auth-profiles.json` 优先于 `openclaw.json` 引用）
- 遗留残留（`auth.json`、OAuth 提醒）

Exec 注意事项：

- 默认情况下，audit 跳过 exec SecretRef 可解析性检查以避免命令副作用。
- 使用 `openclaw secrets audit --allow-exec` 在审计期间执行 exec 提供商。

标头残留注意事项：

- 敏感提供商标头检测基于名称启发式（常见的认证/凭据标头名称和片段，例如 `authorization`、`x-api-key`、`token`、`secret`、`password` 和 `credential`）。

### `secrets configure`

交互式辅助工具：

- 首先配置 `secrets.providers`（`env`/`file`/`exec`，添加/编辑/删除）
- 让您在 `openclaw.json` 中选择支持的密钥承载字段，以及一个 agent 范围的 `auth-profiles.json`
- 可以直接在目标选择器中创建新的 `auth-profiles.json` 映射
- 捕获 SecretRef 详细信息（`source`、`provider`、`id`）
- 运行预检解析
- 可以立即应用

Exec 注意事项：

- 除非设置了 `--allow-exec`，否则预检会跳过 exec SecretRef 检查。
- 如果您直接从 `configure --apply` 应用，并且计划包含 exec 引用/提供商，请为应用步骤也保持 `--allow-exec` 设置。

有用的模式：

- `openclaw secrets configure --providers-only`
- `openclaw secrets configure --skip-provider-setup`
- `openclaw secrets configure --agent <id>`

`configure` 应用默认值：

- 从 `auth-profiles.json` 中清理目标提供商的匹配静态凭据
- 从 `auth.json` 中清理遗留静态 `api_key` 条目
- 从 `<config-dir>/.env` 中清理匹配的已知密钥行

### `secrets apply`

应用保存的计划：

```bash
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json --allow-exec
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json --dry-run
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json --dry-run --allow-exec
```

Exec 注意事项：

- 除非设置了 `--allow-exec`，否则 dry-run 会跳过 exec 检查。
- 除非设置了 `--allow-exec`，否则写入模式会拒绝包含 exec SecretRefs/提供商的计划。

有关严格目标/路径契约详细信息和确切拒绝规则，请参阅：

- [Secrets Apply Plan Contract](/gateway/secrets-plan-contract)

## 单向安全策略

OpenClaw 有意不写入包含历史明文密钥值的回滚备份。

安全模型：

- 预检必须在写入模式之前成功
- 运行时激活在提交之前进行验证
- apply 使用原子文件替换更新文件，并在失败时尽力恢复

## 遗留认证兼容性注意事项

对于静态凭据，运行时不再依赖于明文遗留认证存储。

- 运行时凭据源是解析的内存快照。
- 发现时会清理遗留静态 `api_key` 条目。
- OAuth 相关的兼容性行为保持独立。

## Web UI 注意事项

某些 SecretInput 联合在原始编辑器模式下比在表单模式下更容易配置。

## 相关文档

- CLI 命令：[secrets](/cli/secrets)
- 计划契约详细信息：[Secrets Apply Plan Contract](/gateway/secrets-plan-contract)
- 凭据表面：[SecretRef Credential Surface](/reference/secretref-credential-surface)
- 认证设置：[Authentication](/gateway/authentication)
- 安全态势：[Security](/gateway/security)
- 环境优先级：[Environment Variables](/help/environment)
