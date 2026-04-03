---
summary: "CLI reference for `openclaw completion`（生成和安装 shell 补全脚本）"
read_when:
  - 你想为 zsh/bash/fish/PowerShell 启用 shell 补全
  - 你需要将补全脚本缓存到 OpenClaw 状态目录
title: "completion"
---

# `openclaw completion`

生成 shell 补全脚本，并可选择将其安装到你的 shell profile 中。

## Usage

```bash
openclaw completion
openclaw completion --shell zsh
openclaw completion --install
openclaw completion --shell fish --install
openclaw completion --write-state
openclaw completion --shell bash --write-state
```

## 选项

- `-s, --shell <shell>`：目标 shell（`zsh`、`bash`、`powershell`、`fish`；默认：`zsh`）
- `-i, --install`：通过向 shell profile 写入一条 source 语句来安装补全
- `--write-state`：将补全脚本写入 `$OPENCLAW_STATE_DIR/completions`，而不是打印到 stdout
- `-y, --yes`：跳过安装确认提示

## 说明

- `--install` 会在你的 shell profile 中写入一个简短的 “OpenClaw Completion” 片段，并让它指向缓存后的脚本。
- 如果既不传 `--install` 也不传 `--write-state`，该命令会将脚本打印到 stdout。
- 补全生成会预先加载命令树，因此嵌套子命令也会被包含进去。
