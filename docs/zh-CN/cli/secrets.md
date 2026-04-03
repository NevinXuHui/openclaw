---
summary: "CLI reference for `openclaw secrets`（reload、audit、configure、apply）"
read_when:
  - 在运行时重新解析 secret refs
  - 审计明文残留与未解析引用
  - 配置 SecretRef 并应用单向清洗改动
title: "secrets"
---

# `openclaw secrets`

使用 `openclaw secrets` 管理 SecretRef，并保持当前运行时快照处于健康状态。

命令角色：

- `reload`：gateway RPC（`secrets.reload`），重新解析 refs，并且只有在全部成功时才切换运行时快照（不会写配置）。
- `audit`：对配置 / auth / generated-model 存储以及旧版残留执行只读扫描，检查明文、未解析引用和优先级漂移（除非设置 `--allow-exec`，否则会跳过 exec refs）。
- `configure`：用于 provider 设置、目标映射和预检的交互式规划器（要求 TTY）。
- `apply`：执行已保存的计划（`--dry-run` 仅做校验；dry-run 默认跳过 exec 检查，而写入模式会拒绝包含 exec 的计划，除非设置 `--allow-exec`），然后清洗指定的明文残留。

推荐的运维流程：

```bash
openclaw secrets audit --check
openclaw secrets configure
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json --dry-run
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json
openclaw secrets audit --check
openclaw secrets reload
```

如果你的计划包含 `exec` SecretRef/provider，请在 dry-run 和正式写入两次 `apply` 中都传入 `--allow-exec`。

面向 CI / gate 的退出码说明：

- `audit --check` 在发现问题时返回 `1`。
- 未解析引用返回 `2`。

相关内容：

- Secrets 指南：[Secrets Management](/gateway/secrets)
- 凭证面：[SecretRef Credential Surface](/reference/secretref-credential-surface)
- 安全指南：[Security](/gateway/security)

## 重新加载运行时快照

重新解析 secret refs，并以原子方式切换运行时快照。

```bash
openclaw secrets reload
openclaw secrets reload --json
```

说明：

- 使用 gateway RPC 方法 `secrets.reload`。
- 如果解析失败，gateway 会保留最后一个已知可用的快照，并返回错误（不会部分激活）。
- JSON 响应中包含 `warningCount`。

## 审计

扫描 OpenClaw 状态，检查：

- 明文密钥存储
- 未解析的 refs
- 优先级漂移（`auth-profiles.json` 中的凭证覆盖了 `openclaw.json` 中的 refs）
- 生成的 `agents/*/agent/models.json` 残留（provider `apiKey` 值和敏感 provider headers）
- 旧版残留（旧 auth store 条目、OAuth 提醒等）

Header 残留说明：

- 敏感 provider header 的检测基于名称启发式规则（常见认证 / 凭证头名称与片段，例如 `authorization`、`x-api-key`、`token`、`secret`、`password` 和 `credential`）。

```bash
openclaw secrets audit
openclaw secrets audit --check
openclaw secrets audit --json
openclaw secrets audit --allow-exec
```

退出行为：

- `--check` 在发现问题时返回非零。
- 未解析引用会返回更高优先级的非零退出码。

报告结构亮点：

- `status`：`clean | findings | unresolved`
- `resolution`：`refsChecked`、`skippedExecRefs`、`resolvabilityComplete`
- `summary`：`plaintextCount`、`unresolvedRefCount`、`shadowedRefCount`、`legacyResidueCount`
- finding codes：
  - `PLAINTEXT_FOUND`
  - `REF_UNRESOLVED`
  - `REF_SHADOWED`
  - `LEGACY_RESIDUE`

## Configure（交互式助手）

以交互方式构建 provider 与 SecretRef 变更，运行预检，并可选择直接应用：

```bash
openclaw secrets configure
openclaw secrets configure --plan-out /tmp/openclaw-secrets-plan.json
openclaw secrets configure --apply --yes
openclaw secrets configure --providers-only
openclaw secrets configure --skip-provider-setup
openclaw secrets configure --agent ops
openclaw secrets configure --json
```

流程：

- 首先设置 provider（对 `secrets.providers` aliases 执行 `add/edit/remove`）。
- 然后做凭证映射（选择字段并分配 `{source, provider, id}` refs）。
- 最后执行预检，并可选择应用。

标志：

- `--providers-only`：只配置 `secrets.providers`，跳过凭证映射。
- `--skip-provider-setup`：跳过 provider 设置，并将凭证映射到已有 provider。
- `--agent <id>`：将 `auth-profiles.json` 的目标发现与写入限制到单个 agent store。
- `--allow-exec`：允许在预检 / apply 期间检查 exec SecretRefs（可能会执行 provider 命令）。

说明：

- 需要交互式 TTY。
- 不能同时使用 `--providers-only` 与 `--skip-provider-setup`。
- `configure` 会定位 `openclaw.json` 以及所选 agent 范围下 `auth-profiles.json` 中带有密钥的字段。
- `configure` 支持在 picker 流程中直接创建新的 `auth-profiles.json` 映射。
- 规范支持面参见：[SecretRef Credential Surface](/reference/secretref-credential-surface)。
- 它会在 apply 前执行预检解析。
- 如果预检 / apply 涉及 exec refs，请在这两步中都保留 `--allow-exec`。
- 生成的计划默认启用清洗选项（`scrubEnv`、`scrubAuthProfilesForProviderTargets`、`scrubLegacyAuthJson` 均启用）。
- apply 路径对被清洗掉的明文值是单向的。
- 如果未传 `--apply`，CLI 在预检后仍会提示 `Apply this plan now?`。
- 使用 `--apply`（且未传 `--yes`）时，CLI 会额外要求一次不可逆确认。

Exec provider 安全说明：

- Homebrew 安装通常会在 `/opt/homebrew/bin/*` 暴露符号链接二进制文件。
- 仅在确有需要时设置 `allowSymlinkCommand: true`，并结合 `trustedDirs` 使用（例如 `["/opt/homebrew"]`）。
- 在 Windows 上，如果无法验证某个 provider 路径的 ACL，OpenClaw 会以 fail-closed 方式失败。对于受信任路径，才应为该 provider 设置 `allowInsecurePath: true` 以绕过路径安全检查。

## 应用已保存的计划

应用或预检之前生成的计划：

```bash
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json --allow-exec
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json --dry-run
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json --dry-run --allow-exec
openclaw secrets apply --from /tmp/openclaw-secrets-plan.json --json
```

Exec 行为：

- `--dry-run` 会执行预检校验，但不写入文件。
- dry-run 默认跳过 exec SecretRef 检查。
- 写入模式会拒绝包含 exec SecretRef/provider 的计划，除非传入 `--allow-exec`。
- 在任一模式下，如需执行 provider 检查 / 执行，请通过 `--allow-exec` 显式启用。

计划契约详情（允许的目标路径、校验规则与失败语义）：

- [Secrets Apply Plan Contract](/gateway/secrets-plan-contract)

`apply` 可能会更新：

- `openclaw.json`（SecretRef 目标 + provider upsert/delete）
- `auth-profiles.json`（provider-target 清洗）
- 旧版 `auth.json` 残留
- `~/.openclaw/.env` 中那些已迁移的已知密钥键

## 为什么没有回滚备份

`secrets apply` 有意不会写入包含旧明文值的回滚备份。

它的安全性来自严格预检 + 近似原子的 apply，以及在失败时尽力恢复内存状态。

## 示例

```bash
openclaw secrets audit --check
openclaw secrets configure
openclaw secrets audit --check
```

如果 `audit --check` 仍然报告明文问题，请更新报告中剩余的目标路径，然后重新运行审计。
