---
summary: "OpenClaw 如何就地升级以前的 Matrix 插件，包括加密状态恢复限制和手动恢复步骤。"
read_when:
  - 升级现有的 Matrix 安装
  - 迁移加密的 Matrix 历史记录和设备状态
title: "Matrix 迁移"
x-i18n:
  sourceCommit: "latest"
  sourceFile: "install/migrating-matrix.md"
---

# Matrix 迁移

本页面涵盖从以前的公共 `matrix` 插件升级到当前实现。

对于大多数用户，升级是就地进行的：

- 插件保持为 `@openclaw/matrix`
- channel 保持为 `matrix`
- 您的配置保持在 `channels.matrix` 下
- 缓存的凭据保持在 `~/.openclaw/credentials/matrix/` 下
- 运行时状态保持在 `~/.openclaw/matrix/` 下

您不需要重命名配置键或以新名称重新安装插件。

## 迁移自动执行的操作

当 gateway 启动时，以及当您运行 [`openclaw doctor --fix`](/gateway/doctor) 时，OpenClaw 会尝试自动修复旧的 Matrix 状态。
在任何可操作的 Matrix 迁移步骤改变磁盘状态之前，OpenClaw 会创建或重用一个聚焦的恢复快照。

当您使用 `openclaw update` 时，确切的触发器取决于 OpenClaw 的安装方式：

- 源代码安装在更新流程期间运行 `openclaw doctor --fix`，然后默认重启 gateway
- 包管理器安装更新包，运行非交互式 doctor 传递，然后依赖默认的 gateway 重启，以便启动可以完成 Matrix 迁移
- 如果您使用 `openclaw update --no-restart`，基于启动的 Matrix 迁移将推迟到您稍后运行 `openclaw doctor --fix` 并重启 gateway

自动迁移涵盖：

- 在 `~/Backups/openclaw-migrations/` 下创建或重用迁移前快照
- 重用您缓存的 Matrix 凭据
- 保持相同的账户选择和 `channels.matrix` 配置
- 将最旧的扁平 Matrix 同步存储移动到当前账户范围的位置
- 当目标账户可以安全解析时，将最旧的扁平 Matrix 加密存储移动到当前账户范围的位置
- 从旧的 rust 加密存储中提取先前保存的 Matrix 房间密钥备份解密密钥（当该密钥在本地存在时）
- 当访问令牌稍后更改时，为相同的 Matrix 账户、homeserver 和用户重用最完整的现有令牌哈希存储根
- 当 Matrix 访问令牌更改但账户/设备身份保持不变时，扫描同级令牌哈希存储根以获取待处理的加密状态恢复元数据
- 在下次 Matrix 启动时将备份的房间密钥恢复到新的加密存储中

快照详细信息：

- OpenClaw 在成功快照后在 `~/.openclaw/matrix/migration-snapshot.json` 写入标记文件，以便稍后的启动和修复传递可以重用相同的存档。
- 这些自动 Matrix 迁移快照仅备份配置 + 状态（`includeWorkspace: false`）。
- 如果 Matrix 只有警告级别的迁移状态，例如因为 `userId` 或 `accessToken` 仍然缺失，OpenClaw 还不会创建快照，因为没有 Matrix 变更是可操作的。
- 如果快照步骤失败，OpenClaw 会跳过该运行的 Matrix 迁移，而不是在没有恢复点的情况下改变状态。

关于多账户升级：

- 最旧的扁平 Matrix 存储（`~/.openclaw/matrix/bot-storage.json` 和 `~/.openclaw/matrix/crypto/`）来自单存储布局，因此 OpenClaw 只能将其迁移到一个已解析的 Matrix 账户目标
- 已经是账户范围的旧版 Matrix 存储会按配置的 Matrix 账户检测和准备

## 迁移无法自动执行的操作

以前的公共 Matrix 插件**没有**自动创建 Matrix 房间密钥备份。它持久化了本地加密状态并请求了设备验证，但它没有保证您的房间密钥已备份到 homeserver。

这意味着某些加密安装只能部分迁移。

OpenClaw 无法自动恢复：

- 从未备份的仅本地房间密钥
- 当目标 Matrix 账户因为 `homeserver`、`userId` 或 `accessToken` 仍然不可用而无法解析时的加密状态
- 当配置了多个 Matrix 账户但未设置 `channels.matrix.defaultAccount` 时，一个共享扁平 Matrix 存储的自动迁移
- 固定到仓库路径而不是标准 Matrix 包的自定义插件路径安装
- 当旧存储有备份密钥但没有在本地保留解密密钥时的缺失恢复密钥

当前警告范围：

- 自定义 Matrix 插件路径安装由 gateway 启动和 `openclaw doctor` 显示

如果您的旧安装有从未备份的仅本地加密历史记录，则升级后某些较旧的加密消息可能仍然无法读取。

## 推荐的升级流程

1. 正常更新 OpenClaw 和 Matrix 插件。
   优先使用不带 `--no-restart` 的普通 `openclaw update`，以便启动可以立即完成 Matrix 迁移。
2. 运行：

   ```bash
   openclaw doctor --fix
   ```

   如果 Matrix 有可操作的迁移工作，doctor 将首先创建或重用迁移前快照并打印存档路径。

3. 启动或重启 gateway。
4. 检查当前验证和备份状态：

   ```bash
   openclaw matrix verify status
   openclaw matrix verify backup status
   ```

5. 如果 OpenClaw 告诉您需要恢复密钥，请运行：

   ```bash
   openclaw matrix verify backup restore --recovery-key "<your-recovery-key>"
   ```

6. 如果此设备仍未验证，请运行：

   ```bash
   openclaw matrix verify device "<your-recovery-key>"
   ```

7. 如果您有意放弃不可恢复的旧历史记录，并希望为未来的消息建立新的备份基线，请运行：

   ```bash
   openclaw matrix verify backup reset --yes
   ```

8. 如果尚不存在服务器端密钥备份，请为将来的恢复创建一个：

   ```bash
   openclaw matrix verify bootstrap
   ```

## 加密迁移的工作原理

加密迁移是一个两阶段过程：

1. 如果加密迁移是可操作的，启动或 `openclaw doctor --fix` 会创建或重用迁移前快照。
2. 启动或 `openclaw doctor --fix` 通过活动的 Matrix 插件安装检查旧的 Matrix 加密存储。
3. 如果找到备份解密密钥，OpenClaw 会将其写入新的恢复密钥流程，并将房间密钥恢复标记为待处理。
4. 在下次 Matrix 启动时，OpenClaw 会自动将备份的房间密钥恢复到新的加密存储中。

如果旧存储报告从未备份的房间密钥，OpenClaw 会发出警告，而不是假装恢复成功。

## 常见消息及其含义

### 升级和检测消息

`Matrix plugin upgraded in place.`

- 含义：检测到旧的磁盘 Matrix 状态并迁移到当前布局。
- 该怎么做：除非相同的输出还包含警告，否则无需操作。

`Matrix migration snapshot created before applying Matrix upgrades.`

- 含义：OpenClaw 在改变 Matrix 状态之前创建了恢复存档。
- 该怎么做：保留打印的存档路径，直到您确认迁移成功。

`Matrix migration snapshot reused before applying Matrix upgrades.`

- 含义：OpenClaw 找到了现有的 Matrix 迁移快照标记，并重用了该存档，而不是创建重复的备份。
- 该怎么做：保留打印的存档路径，直到您确认迁移成功。

`Legacy Matrix state detected at ... but channels.matrix is not configured yet.`

- 含义：存在旧的 Matrix 状态，但 OpenClaw 无法将其映射到当前的 Matrix 账户，因为 Matrix 尚未配置。
- 该怎么做：配置 `channels.matrix`，然后重新运行 `openclaw doctor --fix` 或重启 gateway。

`Legacy Matrix state detected at ... but the new account-scoped target could not be resolved yet (need homeserver, userId, and access token for channels.matrix...).`

- 含义：OpenClaw 找到了旧状态，但它仍然无法确定确切的当前账户/设备根。
- 该怎么做：使用有效的 Matrix 登录启动 gateway 一次，或在缓存凭据存在后重新运行 `openclaw doctor --fix`。

`Legacy Matrix state detected at ... but multiple Matrix accounts are configured and channels.matrix.defaultAccount is not set.`

- 含义：OpenClaw 找到了一个共享的扁平 Matrix 存储，但它拒绝猜测哪个命名的 Matrix 账户应该接收它。
- 该怎么做：将 `channels.matrix.defaultAccount` 设置为预期的账户，然后重新运行 `openclaw doctor --fix` 或重启 gateway。

`Matrix legacy sync store not migrated because the target already exists (...)`

- 含义：新的账户范围位置已经有同步或加密存储，因此 OpenClaw 没有自动覆盖它。
- 该怎么做：在手动删除或移动冲突目标之前，验证当前账户是否正确。

`Failed migrating Matrix legacy sync store (...)` 或 `Failed migrating Matrix legacy crypto store (...)`

- 含义：OpenClaw 尝试移动旧的 Matrix 状态，但文件系统操作失败。
- 该怎么做：检查文件系统权限和磁盘状态，然后重新运行 `openclaw doctor --fix`。

`Legacy Matrix encrypted state detected at ... but channels.matrix is not configured yet.`

- 含义：OpenClaw 找到了旧的加密 Matrix 存储，但没有当前的 Matrix 配置可以附加到它。
- 该怎么做：配置 `channels.matrix`，然后重新运行 `openclaw doctor --fix` 或重启 gateway。

`Legacy Matrix encrypted state detected at ... but the account-scoped target could not be resolved yet (need homeserver, userId, and access token for channels.matrix...).`

- 含义：加密存储存在，但 OpenClaw 无法安全地决定它属于哪个当前账户/设备。
- 该怎么做：使用有效的 Matrix 登录启动 gateway 一次，或在缓存凭据可用后重新运行 `openclaw doctor --fix`。

`Legacy Matrix encrypted state detected at ... but multiple Matrix accounts are configured and channels.matrix.defaultAccount is not set.`

- 含义：OpenClaw 找到了一个共享的扁平旧版加密存储，但它拒绝猜测哪个命名的 Matrix 账户应该接收它。
- 该怎么做：将 `channels.matrix.defaultAccount` 设置为预期的账户，然后重新运行 `openclaw doctor --fix` 或重启 gateway。

`Matrix migration warnings are present, but no on-disk Matrix mutation is actionable yet. No pre-migration snapshot was needed.`

- 含义：OpenClaw 检测到旧的 Matrix 状态，但迁移仍然被缺失的身份或凭据数据阻止。
- 该怎么做：完成 Matrix 登录或配置设置，然后重新运行 `openclaw doctor --fix` 或重启 gateway。

`Legacy Matrix encrypted state was detected, but the Matrix plugin helper is unavailable. Install or repair @openclaw/matrix so OpenClaw can inspect the old rust crypto store before upgrading.`

- 含义：OpenClaw 找到了旧的加密 Matrix 状态，但它无法从通常检查该存储的 Matrix 插件加载辅助入口点。
- 该怎么做：重新安装或修复 Matrix 插件（`openclaw plugins install @openclaw/matrix`，或对于仓库检出使用 `openclaw plugins install ./path/to/local/matrix-plugin`），然后重新运行 `openclaw doctor --fix` 或重启 gateway。

`Matrix plugin helper path is unsafe: ... Reinstall @openclaw/matrix and try again.`

- 含义：OpenClaw 找到了一个逃逸插件根或未通过插件边界检查的辅助文件路径，因此它拒绝导入它。
- 该怎么做：从受信任的路径重新安装 Matrix 插件，然后重新运行 `openclaw doctor --fix` 或重启 gateway。

`- Failed creating a Matrix migration snapshot before repair: ...`

`- Skipping Matrix migration changes for now. Resolve the snapshot failure, then rerun "openclaw doctor --fix".`

- 含义：OpenClaw 拒绝改变 Matrix 状态，因为它无法首先创建恢复快照。
- 该怎么做：解决备份错误，然后重新运行 `openclaw doctor --fix` 或重启 gateway。

`Failed migrating legacy Matrix client storage: ...`

- 含义：Matrix 客户端回退找到了旧的扁平存储，但移动失败。OpenClaw 现在中止该回退，而不是静默地以新存储启动。
- 该怎么做：检查文件系统权限或冲突，保持旧状态完整，并在修复错误后重试。

`Matrix is installed from a custom path: ...`

- 含义：Matrix 固定到路径安装，因此主线更新不会自动用仓库的标准 Matrix 包替换它。
- 该怎么做：当您想返回到默认 Matrix 插件时，使用 `openclaw plugins install @openclaw/matrix` 重新安装。

### 加密状态恢复消息

`matrix: restored X/Y room key(s) from legacy encrypted-state backup`

- 含义：备份的房间密钥已成功恢复到新的加密存储中。
- 该怎么做：通常无需操作。

`matrix: N legacy local-only room key(s) were never backed up and could not be restored automatically`

- 含义：一些旧的房间密钥仅存在于旧的本地存储中，从未上传到 Matrix 备份。
- 该怎么做：除非您可以从另一个已验证的客户端手动恢复这些密钥，否则预计某些旧的加密历史记录将保持不可用。

`Legacy Matrix encrypted state for account "..." has backed-up room keys, but no local backup decryption key was found. Ask the operator to run "openclaw matrix verify backup restore --recovery-key <key>" after upgrade if they have the recovery key.`

- 含义：备份存在，但 OpenClaw 无法自动恢复恢复密钥。
- 该怎么做：运行 `openclaw matrix verify backup restore --recovery-key "<your-recovery-key>"`。

`Failed inspecting legacy Matrix encrypted state for account "..." (...): ...`

- 含义：OpenClaw 找到了旧的加密存储，但它无法足够安全地检查它以准备恢复。
- 该怎么做：重新运行 `openclaw doctor --fix`。如果重复，请保持旧状态目录完整，并使用另一个已验证的 Matrix 客户端加上 `openclaw matrix verify backup restore --recovery-key "<your-recovery-key>"` 进行恢复。

`Legacy Matrix backup key was found for account "...", but .../recovery-key.json already contains a different recovery key. Leaving the existing file unchanged.`

- 含义：OpenClaw 检测到备份密钥冲突，并拒绝自动覆盖当前的恢复密钥文件。
- 该怎么做：在重试任何恢复命令之前，验证哪个恢复密钥是正确的。

`Legacy Matrix encrypted state for account "..." cannot be fully converted automatically because the old rust crypto store does not expose all local room keys for export.`

- 含义：这是旧存储格式的硬限制。
- 该怎么做：备份的密钥仍然可以恢复，但仅本地的加密历史记录可能仍然不可用。

`matrix: failed restoring room keys from legacy encrypted-state backup: ...`

- 含义：新插件尝试恢复，但 Matrix 返回了错误。
- 该怎么做：运行 `openclaw matrix verify backup status`，然后在需要时使用 `openclaw matrix verify backup restore --recovery-key "<your-recovery-key>"` 重试。

### 手动恢复消息

`Backup key is not loaded on this device. Run 'openclaw matrix verify backup restore' to load it and restore old room keys.`

- 含义：OpenClaw 知道您应该有备份密钥，但它在此设备上不活动。
- 该怎么做：运行 `openclaw matrix verify backup restore`，或在需要时传递 `--recovery-key`。

`Store a recovery key with 'openclaw matrix verify device <key>', then run 'openclaw matrix verify backup restore'.`

- 含义：此设备当前没有存储恢复密钥。
- 该怎么做：首先使用您的恢复密钥验证设备，然后恢复备份。

`Backup key mismatch on this device. Re-run 'openclaw matrix verify device <key>' with the matching recovery key.`

- 含义：存储的密钥与活动的 Matrix 备份不匹配。
- 该怎么做：使用正确的密钥重新运行 `openclaw matrix verify device "<your-recovery-key>"`。

如果您接受丢失不可恢复的旧加密历史记录，您可以改为使用 `openclaw matrix verify backup reset --yes` 重置当前备份基线。

`Backup trust chain is not verified on this device. Re-run 'openclaw matrix verify device <key>'.`

- 含义：备份存在，但此设备还不够强烈地信任交叉签名链。
- 该怎么做：重新运行 `openclaw matrix verify device "<your-recovery-key>"`。

`Matrix recovery key is required`

- 含义：您在需要恢复密钥时尝试了恢复步骤但没有提供。
- 该怎么做：使用您的恢复密钥重新运行命令。

`Invalid Matrix recovery key: ...`

- 含义：提供的密钥无法解析或与预期格式不匹配。
- 该怎么做：使用来自您的 Matrix 客户端或恢复密钥文件的确切恢复密钥重试。

`Matrix device is still unverified after applying recovery key. Verify your recovery key and ensure cross-signing is available.`

- 含义：密钥已应用，但设备仍然无法完成验证。
- 该怎么做：确认您使用了正确的密钥，并且账户上可用交叉签名，然后重试。

`Matrix key backup is not active on this device after loading from secret storage.`

- 含义：秘密存储没有在此设备上产生活动的备份会话。
- 该怎么做：首先验证设备，然后使用 `openclaw matrix verify backup status` 重新检查。

`Matrix crypto backend cannot load backup keys from secret storage. Verify this device with 'openclaw matrix verify device <key>' first.`

- 含义：在设备验证完成之前，此设备无法从秘密存储恢复。
- 该怎么做：首先运行 `openclaw matrix verify device "<your-recovery-key>"`。

### 自定义插件安装消息

`Matrix is installed from a custom path that no longer exists: ...`

- 含义：您的插件安装记录指向一个不存在的本地路径。
- 该怎么做：使用 `openclaw plugins install @openclaw/matrix` 重新安装，或者如果您从仓库检出运行，使用 `openclaw plugins install ./path/to/local/matrix-plugin`。

## 如果加密历史记录仍然没有恢复

按顺序运行这些检查：

```bash
openclaw matrix verify status --verbose
openclaw matrix verify backup status --verbose
openclaw matrix verify backup restore --recovery-key "<your-recovery-key>" --verbose
```

如果备份成功恢复但某些旧房间仍然缺少历史记录，那些缺失的密钥可能从未被以前的插件备份过。

## 如果您想为未来的消息重新开始

如果您接受丢失不可恢复的旧加密历史记录，并且只想要一个干净的备份基线，请按顺序运行这些命令：

```bash
openclaw matrix verify backup reset --yes
openclaw matrix verify backup status --verbose
openclaw matrix verify status
```

如果设备在此之后仍未验证，请通过比较 SAS 表情符号或十进制代码并确认它们匹配，从您的 Matrix 客户端完成验证。

## 相关页面

- [Matrix](/channels/matrix)
- [Doctor](/gateway/doctor)
- [Migrating](/install/migrating)
- [Plugins](/tools/plugin)
