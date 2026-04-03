---
summary: "在 WSL2 Gateway 网关 + Windows Chrome 远程 CDP 场景中按层排查问题"
read_when:
  - 你在 WSL2 中运行 OpenClaw Gateway 网关，而 Chrome 在 Windows 上运行
  - 你在 WSL2 和 Windows 之间看到浏览器 / control-ui 重叠错误
  - 你需要在分离主机场景中判断应使用主机本地 Chrome MCP 还是原始远程 CDP
title: "WSL2 + Windows + 远程 Chrome CDP 故障排除"
---

# WSL2 + Windows + 远程 Chrome CDP 故障排除

本指南覆盖一种常见的分离主机部署方式，其中：

- OpenClaw Gateway 网关运行在 WSL2 内部
- Chrome 运行在 Windows 上
- 浏览器控制必须跨越 WSL2 / Windows 边界

它还涵盖了 [issue #39369](https://github.com/openclaw/openclaw/issues/39369) 中的分层故障模式：多个独立问题可能同时出现，从而让最先暴露出来的错误层看起来像是真正损坏的那一层。

## 先选择正确的浏览器模式

你有两种有效模式：

### 选项 1：从 WSL2 到 Windows 的原始远程 CDP

使用一个远程浏览器 profile，从 WSL2 指向 Windows 上的 Chrome CDP 端点。

适用场景：

- Gateway 网关保留在 WSL2 内部运行
- Chrome 在 Windows 上运行
- 你需要让浏览器控制跨越 WSL2 / Windows 边界

### 选项 2：主机本地 Chrome MCP

仅当 Gateway 网关与 Chrome 运行在同一台主机上时，才使用 `existing-session` / `user`。

适用场景：

- OpenClaw 与 Chrome 运行在同一台机器上
- 你希望使用本地已登录的浏览器状态
- 你不需要跨主机的浏览器传输

对于 “WSL2 Gateway 网关 + Windows Chrome” 这一组合，请优先使用原始远程 CDP。Chrome MCP 是主机本地方案，不是 WSL2 到 Windows 的桥接层。

## 可工作的架构

参考拓扑：

- WSL2 在 `127.0.0.1:18789` 上运行 Gateway 网关
- Windows 在普通浏览器中打开 Control UI：`http://127.0.0.1:18789/`
- Windows 上的 Chrome 在端口 `9222` 暴露 CDP 端点
- WSL2 可以访问这个 Windows CDP 端点
- OpenClaw 将浏览器 profile 指向 WSL2 可访问的地址

## 为什么这个配置容易让人困惑

多个故障可能会重叠：

- WSL2 无法访问 Windows 的 CDP 端点
- Control UI 是从不安全的来源打开的
- `gateway.controlUi.allowedOrigins` 与页面来源不匹配
- token 或 pairing 缺失
- 浏览器 profile 指向了错误地址

因此，即使修复了一层，界面上仍然可能看到来自另一层的错误。

## Control UI 的关键规则

当 UI 从 Windows 打开时，除非你明确配置了 HTTPS，否则请使用 Windows localhost。

请使用：

`http://127.0.0.1:18789/`

不要默认对 Control UI 使用局域网 IP。局域网或 tailnet 地址上的明文 HTTP 可能触发不安全来源 / 设备认证行为，而这与 CDP 本身无关。参见 [Control UI](/web/control-ui)。

## 分层验证

请按从上到下的顺序排查。不要跳步。

### 第 1 层：确认 Chrome 在 Windows 上提供 CDP

在 Windows 上启动 Chrome，并开启远程调试：

```powershell
chrome.exe --remote-debugging-port=9222
```

先从 Windows 自身验证 Chrome：

```powershell
curl http://127.0.0.1:9222/json/version
curl http://127.0.0.1:9222/json/list
```

如果这一步在 Windows 上都失败，那问题还不在 OpenClaw。

### 第 2 层：确认 WSL2 可以访问该 Windows 端点

在 WSL2 中，测试你计划在 `cdpUrl` 中使用的准确地址：

```bash
curl http://WINDOWS_HOST_OR_IP:9222/json/version
curl http://WINDOWS_HOST_OR_IP:9222/json/list
```

正确结果：

- `/json/version` 返回带 Browser / Protocol-Version 元数据的 JSON
- `/json/list` 返回 JSON（如果当前没有打开页面，空数组也正常）

如果失败：

- Windows 还没有把该端口暴露给 WSL2
- 这个地址对 WSL2 一侧来说是错误的
- 仍然缺少防火墙 / 端口转发 / 本地代理

在改动 OpenClaw 配置之前，先把这一层修好。

### 第 3 层：配置正确的浏览器 profile

对于原始远程 CDP，请让 OpenClaw 指向 WSL2 可访问的地址：

```json5
{
  browser: {
    enabled: true,
    defaultProfile: "remote",
    profiles: {
      remote: {
        cdpUrl: "http://WINDOWS_HOST_OR_IP:9222",
        attachOnly: true,
        color: "#00AA00",
      },
    },
  },
}
```

说明：

- 使用 WSL2 可访问的地址，而不是仅在 Windows 上有效的地址
- 对于外部管理的浏览器，请保持 `attachOnly: true`
- 先用 `curl` 测试同一个 URL，再期望 OpenClaw 正常工作

### 第 4 层：单独验证 Control UI 层

从 Windows 打开 UI：

`http://127.0.0.1:18789/`

然后确认：

- 页面来源与 `gateway.controlUi.allowedOrigins` 的预期一致
- token 认证或 pairing 配置正确
- 你没有把 Control UI 的认证问题误当作浏览器问题来排查

参考页面：

- [Control UI](/web/control-ui)

### 第 5 层：验证端到端浏览器控制

在 WSL2 中执行：

```bash
openclaw browser open https://example.com --browser-profile remote
openclaw browser tabs --browser-profile remote
```

正确结果：

- 标签页会在 Windows Chrome 中打开
- `openclaw browser tabs` 能返回目标标签页
- 后续操作（`snapshot`、`screenshot`、`navigate`）能在同一 profile 上工作

## 常见但容易误导的错误

请把每条消息视为与某一层对应的线索：

- `control-ui-insecure-auth`
  - UI 来源 / 安全上下文问题，不是 CDP 传输问题
- `token_missing`
  - 认证配置问题
- `pairing required`
  - 设备批准问题
- `Remote CDP for profile "remote" is not reachable`
  - WSL2 无法访问配置的 `cdpUrl`
- `gateway timeout after 1500ms`
  - 通常仍然是 CDP 可达性问题，或远程端点缓慢 / 无法访问
- `No Chrome tabs found for profile="user"`
  - 选中了本地 Chrome MCP profile，但当前没有可用的主机本地标签页

## 快速排查清单

1. Windows：`curl http://127.0.0.1:9222/json/version` 是否正常？
2. WSL2：`curl http://WINDOWS_HOST_OR_IP:9222/json/version` 是否正常？
3. OpenClaw 配置：`browser.profiles.<name>.cdpUrl` 是否使用了完全相同的 WSL2 可访问地址？
4. Control UI：你打开的是 `http://127.0.0.1:18789/` 而不是局域网 IP 吗？
5. 你是否误把 `existing-session` 当作跨 WSL2 / Windows 的方案，而不是使用原始远程 CDP？

## 实际结论

这个部署通常是可行的。真正困难的地方在于：浏览器传输、Control UI 来源安全性，以及 token / pairing 都可能各自独立失败，而从用户角度看起来却很相似。

当你不确定时：

- 先在 Windows 本地验证 Chrome 端点
- 再从 WSL2 验证同一个端点
- 只有在这两步都通过后，再去排查 OpenClaw 配置或 Control UI 认证
