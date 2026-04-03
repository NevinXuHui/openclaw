---
title: "认证凭证语义"
summary: "认证配置文件的规范凭证资格与解析语义"
read_when:
  - 你正在处理认证配置文件解析或凭证路由
  - 你正在调试模型认证失败或配置文件顺序
---

# 认证凭证语义

本文档定义了以下各处共用的规范凭证资格与解析语义：

- `resolveAuthProfileOrder`
- `resolveApiKeyForProfile`
- `models status --probe`
- `doctor-auth`

目标是让选择阶段与运行时行为保持一致。

## 稳定原因代码

- `ok`
- `missing_credential`
- `invalid_expires`
- `expired`
- `unresolved_ref`

## Token 凭证

Token 凭证（`type: "token"`）支持内联 `token` 和/或 `tokenRef`。

### 资格规则

1. 当 `token` 和 `tokenRef` 都缺失时，token 配置文件不具备资格。
2. `expires` 是可选项。
3. 如果提供了 `expires`，它必须是大于 `0` 的有限数字。
4. 如果 `expires` 无效（`NaN`、`0`、负数、非有限值或类型错误），该配置文件会因 `invalid_expires` 而不具备资格。
5. 如果 `expires` 已经过期，该配置文件会因 `expired` 而不具备资格。
6. `tokenRef` 不会绕过对 `expires` 的校验。

### 解析规则

1. 解析器对 `expires` 的语义与资格判断保持一致。
2. 对于具备资格的配置文件，token 内容可以来自内联值或 `tokenRef`。
3. 无法解析的引用会在 `models status --probe` 输出中显示为 `unresolved_ref`。

## OAuth SecretRef 策略保护

- SecretRef 输入仅用于静态凭证。
- 如果配置文件凭证的 `type` 为 `"oauth"`，则该配置文件凭证内容不支持 SecretRef 对象。
- 如果 `auth.profiles.<id>.mode` 为 `"oauth"`，则会拒绝该配置文件上的 SecretRef 支持的 `keyRef`/`tokenRef` 输入。
- 在启动/重载的认证解析路径中，违反这些规则会被视为硬失败。

## 兼容旧版的消息文案

为了兼容脚本，探测错误的第一行必须保持不变：

`Auth profile credentials are missing or expired.`

后续行可以补充更友好的说明和稳定原因代码。
