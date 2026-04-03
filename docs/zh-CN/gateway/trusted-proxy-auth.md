---
title: "Trusted Proxy Auth"
summary: "将 gateway 认证委托给受信任的反向代理（Pomerium、Caddy、nginx + OAuth）"
read_when:
  - 在身份感知代理后面运行 OpenClaw
  - 在 OpenClaw 前面设置 Pomerium、Caddy 或 nginx with OAuth
  - 修复反向代理设置的 WebSocket 1008 未授权错误
  - 决定在哪里设置 HSTS 和其他 HTTP 加固标头
x-i18n:
  sourceCommit: "latest"
  sourceFile: "gateway/trusted-proxy-auth.md"
---

# Trusted Proxy Auth

> ⚠️ **安全敏感功能。** 此模式将认证完全委托给您的反向代理。配置错误可能会使您的 Gateway 网关暴露于未经授权的访问。在启用之前请仔细阅读本页。

## 何时使用

在以下情况下使用 `trusted-proxy` 认证模式：

- 您在**身份感知代理**后面运行 OpenClaw（Pomerium、Caddy + OAuth、nginx + oauth2-proxy、Traefik + forward auth）
- 您的代理处理所有认证并通过标头传递用户身份
- 您处于 Kubernetes 或容器环境中，代理是到 Gateway 网关的唯一路径
- 您遇到 WebSocket `1008 unauthorized` 错误，因为浏览器无法在 WS 负载中传递 tokens

## 何时不使用

- 如果您的代理不对用户进行认证（只是 TLS 终止器或负载均衡器）
- 如果有任何绕过代理的 Gateway 网关路径（防火墙漏洞、内部网络访问）
- 如果您不确定代理是否正确剥离/覆盖转发的标头
- 如果您只需要个人单用户访问（考虑 Tailscale Serve + loopback 以获得更简单的设置）

## 工作原理

1. 您的反向代理对用户进行认证（OAuth、OIDC、SAML 等）
2. 代理添加带有认证用户身份的标头（例如 `x-forwarded-user: nick@example.com`）
3. OpenClaw 检查请求是否来自**受信任的代理 IP**（在 `gateway.trustedProxies` 中配置）
4. OpenClaw 从配置的标头中提取用户身份
5. 如果一切正常，请求被授权

## Control UI 配对行为

当 `gateway.auth.mode = "trusted-proxy"` 处于活动状态且请求通过
trusted-proxy 检查时，Control UI WebSocket 会话可以在没有设备
配对身份的情况下连接。

影响：

- 在此模式下，配对不再是 Control UI 访问的主要门控。
- 您的反向代理认证策略和 `allowUsers` 成为有效的访问控制。
- 保持 gateway 入口仅锁定到受信任的代理 IP（`gateway.trustedProxies` + 防火墙）。

## 配置

```json5
{
  gateway: {
    // 对于同主机代理设置使用 loopback；对于远程代理主机使用 lan/custom
    bind: "loopback",

    // 关键：仅在此处添加您的代理 IP
    trustedProxies: ["10.0.0.1", "172.17.0.1"],

    auth: {
      mode: "trusted-proxy",
      trustedProxy: {
        // 包含认证用户身份的标头（必需）
        userHeader: "x-forwarded-user",

        // 可选：必须存在的标头（代理验证）
        requiredHeaders: ["x-forwarded-proto", "x-forwarded-host"],

        // 可选：限制为特定用户（空 = 允许所有）
        allowUsers: ["nick@example.com", "admin@company.org"],
      },
    },
  },
}
```

如果 `gateway.bind` 是 `loopback`，在
`gateway.trustedProxies` 中包含一个 loopback 代理地址（`127.0.0.1`、`::1` 或等效的 loopback CIDR）。

### 配置参考

| 字段                                        | 必需 | 描述                                                 |
| ------------------------------------------- | ---- | ---------------------------------------------------- |
| `gateway.trustedProxies`                    | 是   | 要信任的代理 IP 地址数组。来自其他 IP 的请求被拒绝。 |
| `gateway.auth.mode`                         | 是   | 必须是 `"trusted-proxy"`                             |
| `gateway.auth.trustedProxy.userHeader`      | 是   | 包含认证用户身份的标头名称                           |
| `gateway.auth.trustedProxy.requiredHeaders` | 否   | 请求被信任必须存在的其他标头                         |
| `gateway.auth.trustedProxy.allowUsers`      | 否   | 用户身份允许列表。空表示允许所有认证用户。           |

## TLS 终止和 HSTS

使用一个 TLS 终止点并在那里应用 HSTS。

### 推荐模式：代理 TLS 终止

当您的反向代理为 `https://control.example.com` 处理 HTTPS 时，在
代理处为该域设置 `Strict-Transport-Security`。

- 适合面向互联网的部署。
- 将证书 + HTTP 加固策略保持在一个地方。
- OpenClaw 可以在代理后面保持在 loopback HTTP 上。

示例标头值：

```text
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

### Gateway 网关 TLS 终止

如果 OpenClaw 本身直接提供 HTTPS（没有 TLS 终止代理），请设置：

```json5
{
  gateway: {
    tls: { enabled: true },
    http: {
      securityHeaders: {
        strictTransportSecurity: "max-age=31536000; includeSubDomains",
      },
    },
  },
}
```

`strictTransportSecurity` 接受字符串标头值，或 `false` 以明确禁用。

### 推出指南

- 首先从短的 max age 开始（例如 `max-age=300`），同时验证流量。
- 仅在信心高后才增加到长期值（例如 `max-age=31536000`）。
- 仅当每个子域都准备好 HTTPS 时才添加 `includeSubDomains`。
- 仅当您有意满足完整域集的预加载要求时才使用 preload。
- 仅 loopback 的本地开发不会从 HSTS 中受益。

## 代理设置示例

### Pomerium

Pomerium 在 `x-pomerium-claim-email`（或其他声明标头）和 `x-pomerium-jwt-assertion` 中的 JWT 中传递身份。

```json5
{
  gateway: {
    bind: "lan",
    trustedProxies: ["10.0.0.1"], // Pomerium 的 IP
    auth: {
      mode: "trusted-proxy",
      trustedProxy: {
        userHeader: "x-pomerium-claim-email",
        requiredHeaders: ["x-pomerium-jwt-assertion"],
      },
    },
  },
}
```

Pomerium 配置片段：

```yaml
routes:
  - from: https://openclaw.example.com
    to: http://openclaw-gateway:18789
    policy:
      - allow:
          or:
            - email:
                is: nick@example.com
    pass_identity_headers: true
```

### Caddy with OAuth

带有 `caddy-security` 插件的 Caddy 可以对用户进行认证并传递身份标头。

```json5
{
  gateway: {
    bind: "lan",
    trustedProxies: ["127.0.0.1"], // Caddy 的 IP（如果在同一主机上）
    auth: {
      mode: "trusted-proxy",
      trustedProxy: {
        userHeader: "x-forwarded-user",
      },
    },
  },
}
```

Caddyfile 片段：

```
openclaw.example.com {
    authenticate with oauth2_provider
    authorize with policy1

    reverse_proxy openclaw:18789 {
        header_up X-Forwarded-User {http.auth.user.email}
    }
}
```

### nginx + oauth2-proxy

oauth2-proxy 对用户进行认证并在 `x-auth-request-email` 中传递身份。

```json5
{
  gateway: {
    bind: "lan",
    trustedProxies: ["10.0.0.1"], // nginx/oauth2-proxy IP
    auth: {
      mode: "trusted-proxy",
      trustedProxy: {
        userHeader: "x-auth-request-email",
      },
    },
  },
}
```

nginx 配置片段：

```nginx
location / {
    auth_request /oauth2/auth;
    auth_request_set $user $upstream_http_x_auth_request_email;

    proxy_pass http://openclaw:18789;
    proxy_set_header X-Auth-Request-Email $user;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

### Traefik with Forward Auth

```json5
{
  gateway: {
    bind: "lan",
    trustedProxies: ["172.17.0.1"], // Traefik 容器 IP
    auth: {
      mode: "trusted-proxy",
      trustedProxy: {
        userHeader: "x-forwarded-user",
      },
    },
  },
}
```

## 混合 token 配置

当 `gateway.auth.token`（或 `OPENCLAW_GATEWAY_TOKEN`）和 `trusted-proxy` 模式同时处于活动状态时，OpenClaw 会拒绝模糊配置。混合 token 配置可能导致 loopback 请求在错误的认证路径上静默认证。

如果您在启动时看到 `mixed_trusted_proxy_token` 错误：

- 使用 trusted-proxy 模式时删除共享 token，或
- 如果您打算使用基于 token 的认证，请将 `gateway.auth.mode` 切换为 `"token"`。

Loopback trusted-proxy 认证也会失败关闭：同主机调用者必须通过受信任的代理提供配置的身份标头，而不是被静默认证。

## 安全检查清单

在启用 trusted-proxy 认证之前，请验证：

- [ ] **代理是唯一路径**：Gateway 网关端口被防火墙阻止，除了您的代理之外的所有内容
- [ ] **trustedProxies 是最小的**：仅您的实际代理 IP，而不是整个子网
- [ ] **代理剥离标头**：您的代理覆盖（不追加）来自客户端的 `x-forwarded-*` 标头
- [ ] **TLS 终止**：您的代理处理 TLS；用户通过 HTTPS 连接
- [ ] **设置了 allowUsers**（推荐）：限制为已知用户，而不是允许任何认证的人
- [ ] **没有混合 token 配置**：不要同时设置 `gateway.auth.token` 和 `gateway.auth.mode: "trusted-proxy"`

## 安全审计

`openclaw security audit` 将使用**关键**严重性发现标记 trusted-proxy 认证。这是有意的 — 这是一个提醒，您正在将安全性委托给您的代理设置。

审计检查：

- 缺少 `trustedProxies` 配置
- 缺少 `userHeader` 配置
- 空的 `allowUsers`（允许任何认证用户）

## 故障排除

### "trusted_proxy_untrusted_source"

请求不是来自 `gateway.trustedProxies` 中的 IP。检查：

- 代理 IP 是否正确？（Docker 容器 IP 可能会更改）
- 您的代理前面是否有负载均衡器？
- 使用 `docker inspect` 或 `kubectl get pods -o wide` 查找实际 IP

### "trusted_proxy_user_missing"

用户标头为空或缺失。检查：

- 您的代理是否配置为传递身份标头？
- 标头名称是否正确？（不区分大小写，但拼写很重要）
- 用户是否在代理处实际认证？

### "trusted*proxy_missing_header*\*"

所需的标头不存在。检查：

- 您的代理配置中的那些特定标头
- 标头是否在链中的某处被剥离

### "trusted_proxy_user_not_allowed"

用户已认证但不在 `allowUsers` 中。添加它们或删除允许列表。

### WebSocket 仍然失败

确保您的代理：

- 支持 WebSocket 升级（`Upgrade: websocket`、`Connection: upgrade`）
- 在 WebSocket 升级请求上传递身份标头（不仅仅是 HTTP）
- 没有用于 WebSocket 连接的单独认证路径

## 从 Token Auth 迁移

如果您要从 token 认证迁移到 trusted-proxy：

1. 配置您的代理以对用户进行认证并传递标头
2. 独立测试代理设置（使用标头的 curl）
3. 使用 trusted-proxy 认证更新 OpenClaw 配置
4. 重新启动 Gateway 网关
5. 从 Control UI 测试 WebSocket 连接
6. 运行 `openclaw security audit` 并审查发现

## 相关

- [Security](/gateway/security) — 完整安全指南
- [Configuration](/gateway/configuration) — 配置参考
- [Remote Access](/gateway/remote) — 其他远程访问模式
- [Tailscale](/gateway/tailscale) — 仅 tailnet 访问的更简单替代方案
