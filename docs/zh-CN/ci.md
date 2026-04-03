---
title: "CI 流水线"
summary: "CI 作业图、范围门禁与本地等价命令"
read_when:
  - 你需要了解某个 CI 作业为何运行或未运行
  - 你正在调试失败的 GitHub Actions 检查
---

# CI 流水线

CI 会在每次推送到 `main` 以及每个 pull request 上运行。它使用智能范围判断，在只改动无关区域时跳过高开销作业。

## 作业概览

| Job               | 用途                                                   | 运行时机                                       |
| ----------------- | ------------------------------------------------------ | ---------------------------------------------- |
| `preflight`       | 文档范围、变更范围、密钥扫描、工作流审计、生产依赖审计 | 始终运行；基于 Node 的审计仅在非文档变更时运行 |
| `docs-scope`      | 检测是否仅改动文档                                     | 始终运行                                       |
| `changed-scope`   | 检测哪些区域发生了变化（node/macos/android/windows）   | 非文档变更                                     |
| `check`           | TypeScript 类型、lint、format                          | 非文档且涉及 node 变更                         |
| `check-docs`      | Markdown lint + 失效链接检查                           | 文档发生变化时                                 |
| `secrets`         | 检测泄露的密钥                                         | 始终运行                                       |
| `build-artifacts` | 构建一次 dist，并与 `release-check` 共享               | 推送到 `main` 且涉及 node 变更时               |
| `release-check`   | 验证 npm pack 内容                                     | 推送到 `main` 且 build 之后                    |
| `checks`          | PR 上运行 Node 测试 + 协议检查；push 时运行 Bun 兼容性 | 非文档且涉及 node 变更                         |
| `compat-node22`   | 最低支持的 Node 运行时兼容性                           | 推送到 `main` 且涉及 node 变更时               |
| `checks-windows`  | Windows 特定测试                                       | 非文档且变更与 windows 相关时                  |
| `macos`           | Swift lint/build/test + TS 测试                        | PR 且包含 macos 相关变更时                     |
| `android`         | Gradle 构建 + 测试                                     | 非文档且涉及 android 变更                      |

## 快速失败顺序

作业按顺序排列，让廉价检查先于高开销检查失败：

1. `docs-scope` + `changed-scope` + `check` + `secrets`（并行，先跑便宜的门禁）
2. PR：`checks`（Linux Node 测试拆成 2 个分片）、`checks-windows`、`macos`、`android`
3. 推送到 `main`：`build-artifacts` + `release-check` + Bun 兼容性 + `compat-node22`

范围判断逻辑位于 `scripts/ci-changed-scope.mjs`，并由 `src/scripts/ci-changed-scope.test.ts` 中的单元测试覆盖。
同一个共享范围模块也驱动独立的 `install-smoke` 工作流，通过更窄的 `changed-smoke` 门禁，因此 Docker/安装 smoke 仅会在安装、打包和容器相关变更时运行。

## Runner

| Runner                           | Job                             |
| -------------------------------- | ------------------------------- |
| `blacksmith-16vcpu-ubuntu-2404`  | 大多数 Linux 作业，包括范围检测 |
| `blacksmith-32vcpu-windows-2025` | `checks-windows`                |
| `macos-latest`                   | `macos`、`ios`                  |

## 本地等价命令

```bash
pnpm check          # types + lint + format
pnpm test           # vitest tests
pnpm check:docs     # docs format + lint + broken links
pnpm release:check  # validate npm pack
```
