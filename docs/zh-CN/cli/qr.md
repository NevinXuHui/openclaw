---
summary: "CLI reference for `openclaw qr`（生成 iOS 配对二维码和设置码）"
read_when:
  - 你想快速将 iOS 应用与 Gateway 网关配对
  - 你需要输出设置码以便远程或手动分享
title: "qr"
---

# `openclaw qr`

根据你当前的 Gateway 网关配置生成 iOS 配对二维码和设置码。

## Usage

```bash
openclaw qr
openclaw qr --setup-code-only
openclaw qr --json
openclaw qr --remote
openclaw qr --url wss://gateway.example/ws
```

## 选项

- `--remote`：使用配置中的 `gateway.remote.url` 以及远程 token/password
- `--url <url>`：覆盖写入载荷中的 gateway URL
- `--public-url <url>`：覆盖写入载荷中的 public URL
- `--token <token>`：覆盖 bootstrap 流程用于认证的 gateway token
- `--password <password>`：覆盖 bootstrap 流程用于认证的 gateway password
- `--setup-code-only`：只打印设置码
- `--no-ascii`：跳过 ASCII 二维码渲染
- `--json`：输出 JSON（`setupCode`、`gatewayUrl`、`auth`、`urlSource`）

## 说明

- `--token` 和 `--password` 互斥。
- 设置码本身现在携带的是一个短期有效的透明 `bootstrapToken`，而不是共享的 gateway token/password。
- 使用 `--remote` 时，如果当前生效的远程凭证被配置为 SecretRef，且你没有显式传入 `--token` 或 `--password`，命令会从当前激活的 gateway snapshot 中解析它们。如果 gateway 不可用，命令会快速失败。
- 不使用 `--remote` 时，只要没有通过 CLI 显式覆盖认证，本地 gateway 的认证 SecretRef 就会被解析：
  - 当 token 认证可能胜出时，解析 `gateway.auth.token`（显式 `gateway.auth.mode="token"`，或推断模式下没有 password 来源胜出）。
  - 当 password 认证可能胜出时，解析 `gateway.auth.password`（显式 `gateway.auth.mode="password"`，或推断模式下不存在胜出的 token 来源）。
- 如果同时配置了 `gateway.auth.token` 与 `gateway.auth.password`（包括 SecretRef），但 `gateway.auth.mode` 未设置，则在显式设置 mode 之前，设置码解析会失败。
- Gateway 网关版本偏差说明：这个命令路径要求 gateway 支持 `secrets.resolve`；较老的 gateway 会返回 unknown-method 错误。
- 扫码后，可使用以下命令批准设备配对：
  - `openclaw devices list`
  - `openclaw devices approve <requestId>`
