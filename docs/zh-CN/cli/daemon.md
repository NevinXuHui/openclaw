---
summary: "CLI reference for `openclaw daemon`（Gateway 网关服务管理的旧别名）"
read_when:
  - 你仍在脚本中使用 `openclaw daemon ...`
  - 你需要服务生命周期命令（install/start/stop/restart/status）
title: "daemon"
---

# `openclaw daemon`

Gateway 网关服务管理命令的旧别名。

`openclaw daemon ...` 会映射到与 `openclaw gateway ...` 服务命令相同的服务控制界面。

## Usage

```bash
openclaw daemon status
openclaw daemon install
openclaw daemon start
openclaw daemon stop
openclaw daemon restart
openclaw daemon uninstall
```

## 子命令

- `status`：显示服务安装状态并探测 Gateway 网关健康状况
- `install`：安装服务（`launchd`/`systemd`/`schtasks`）
- `uninstall`：移除服务
- `start`：启动服务
- `stop`：停止服务
- `restart`：重启服务

## 常用选项

- `status`：`--url`、`--token`、`--password`、`--timeout`、`--no-probe`、`--require-rpc`、`--deep`、`--json`
- `install`：`--port`、`--runtime <node|bun>`、`--token`、`--force`、`--json`
- 生命周期命令（`uninstall|start|stop|restart`）：`--json`

说明：

- `status` 会在可能时解析已配置的认证 SecretRef，用于探测认证。
- 如果该命令路径中某个必需的认证 SecretRef 无法解析，并且探测连接/认证失败，`daemon status --json` 会报告 `rpc.authWarning`；你可以显式传入 `--token`/`--password`，或先修复 secret 来源。
- 如果探测成功，则会抑制未解析的 auth-ref 警告，以避免误报。
- 在 Linux systemd 安装中，`status` 的 token 漂移检查会同时覆盖 `Environment=` 和 `EnvironmentFile=` 的 unit 来源。
- 漂移检查会使用合并后的运行时环境来解析 `gateway.auth.token` SecretRef（优先服务命令环境，其次回退到进程环境）。
- 如果 token 认证实际上没有启用（显式 `gateway.auth.mode` 为 `password`/`none`/`trusted-proxy`，或 mode 未设置且 password 可以生效、同时不存在可胜出的 token 候选值），则会跳过 token 漂移检查中的配置 token 解析。
- 如果 token 认证要求必须存在 token，并且 `gateway.auth.token` 由 SecretRef 管理，`install` 会验证该 SecretRef 可解析，但不会把解析出的 token 持久化到服务环境元数据中。
- 如果 token 认证要求必须存在 token，而配置的 token SecretRef 无法解析，则安装会以 fail-closed 方式失败。
- 如果同时配置了 `gateway.auth.token` 和 `gateway.auth.password`，但 `gateway.auth.mode` 未设置，则在明确设置 mode 之前会阻止安装。

## 推荐做法

请优先使用 [`openclaw gateway`](/cli/gateway) 查看最新文档与示例。
