---
summary: "CLI reference for `openclaw backup`（创建本地备份归档）"
read_when:
  - 你想为本地 OpenClaw 状态创建一份正式的备份归档
  - 你想在 reset 或 uninstall 之前预览会包含哪些路径
title: "backup"
---

# `openclaw backup`

为 OpenClaw 的状态、配置、凭证、会话，以及可选的工作区创建本地备份归档。

```bash
openclaw backup create
openclaw backup create --output ~/Backups
openclaw backup create --dry-run --json
openclaw backup create --verify
openclaw backup create --no-include-workspace
openclaw backup create --only-config
openclaw backup verify ./2026-03-09T00-00-00.000Z-openclaw-backup.tar.gz
```

## 说明

- 归档中会包含一个 `manifest.json` 文件，记录解析后的源路径和归档布局。
- 默认输出位置是当前工作目录中的一个带时间戳的 `.tar.gz` 归档。
- 如果当前工作目录位于某个将被备份的源树内部，OpenClaw 会回退到你的主目录作为默认归档输出位置。
- 现有归档文件永远不会被覆盖。
- 如果输出路径位于源状态树或工作区树内部，则会被拒绝，以避免把归档文件自身再次打包进去。
- `openclaw backup verify <archive>` 会校验归档中是否只包含一个根清单文件、拒绝路径穿越样式的归档路径，并检查清单声明的每个负载是否都存在于 tarball 中。
- `openclaw backup create --verify` 会在写入归档后立即执行这项校验。
- `openclaw backup create --only-config` 只会备份当前激活的 JSON 配置文件。

## 会备份什么

`openclaw backup create` 会根据你本地的 OpenClaw 安装来规划备份源：

- OpenClaw 本地状态解析器返回的状态目录，通常是 `~/.openclaw`
- 当前激活的配置文件路径
- OAuth / 凭证目录
- 从当前配置中发现的工作区目录，除非你传入 `--no-include-workspace`

如果你使用 `--only-config`，OpenClaw 会跳过状态、凭证和工作区发现，只归档当前激活的配置文件路径。

OpenClaw 会在构建归档前对路径做规范化处理。如果配置、凭证或某个工作区本身已经位于状态目录中，它们不会再作为独立的顶层备份源重复收录。缺失路径会被跳过。

归档负载会保存这些源树中的文件内容，而内嵌的 `manifest.json` 会记录解析后的绝对源路径，以及每项资产在归档中的布局方式。

## 配置无效时的行为

`openclaw backup` 会有意绕过正常的配置预检，因此即使在恢复场景下也依然可用。由于工作区发现依赖有效配置，当配置文件存在但无效、且工作区备份仍启用时，`openclaw backup create` 现在会快速失败。

如果你仍然想在这种情况下做部分备份，请重新运行：

```bash
openclaw backup create --no-include-workspace
```

这样仍会保留状态、配置和凭证，但会完全跳过工作区发现。

如果你只需要配置文件本身的一份副本，`--only-config` 在配置格式损坏时同样可用，因为它不依赖解析配置来发现工作区。

## 大小与性能

OpenClaw 不会对备份总大小或单文件大小施加内置上限。

实际限制主要来自本地机器与目标文件系统：

- 写入临时归档和最终归档所需的可用空间
- 遍历大型工作区树并压缩为 `.tar.gz` 所需的时间
- 使用 `openclaw backup create --verify` 或运行 `openclaw backup verify` 时重新扫描归档所需的时间
- 目标路径所在文件系统的行为。OpenClaw 会优先使用“不覆盖”的硬链接发布步骤；如果不支持硬链接，则回退为排他性复制

大型工作区通常是归档体积增长的主要来源。如果你想获得更小或更快的备份，请使用 `--no-include-workspace`。

如果你想要最小的归档，请使用 `--only-config`。
