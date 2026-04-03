---
title: OpenShell
summary: "将 OpenShell 用作 OpenClaw 智能体的托管沙箱后端"
read_when:
  - 你想使用云端托管沙箱而不是本地 Docker
  - 你正在设置 OpenShell 插件
  - 你需要在 mirror 和 remote 工作空间模式之间做选择
---

# OpenShell

OpenShell 是 OpenClaw 的托管沙箱后端。它不会在本地运行 Docker 容器，而是将沙箱生命周期委托给 `openshell` CLI，由后者提供远程环境，并通过基于 SSH 的命令执行进行操作。

OpenShell 插件复用了与通用 [SSH 后端](/gateway/sandboxing#ssh-backend) 相同的核心 SSH 传输和远程文件系统桥接能力。它增加了 OpenShell 专属生命周期（`sandbox create/get/delete`、`sandbox ssh-config`）以及可选的 `mirror` 工作空间模式。

## 前置条件

- 已安装 `openshell` CLI，且可在 `PATH` 中找到（也可以通过 `plugins.entries.openshell.config.command` 设置自定义路径）
- 拥有可访问沙箱的 OpenShell 账号
- 主机上正在运行 OpenClaw Gateway 网关

## 快速开始

1. 启用插件并设置沙箱后端：

```json5
{
  agents: {
    defaults: {
      sandbox: {
        mode: "all",
        backend: "openshell",
        scope: "session",
        workspaceAccess: "rw",
      },
    },
  },
  plugins: {
    entries: {
      openshell: {
        enabled: true,
        config: {
          from: "openclaw",
          mode: "remote",
        },
      },
    },
  },
}
```

2. 重启 Gateway 网关。下一次智能体回合中，OpenClaw 会创建一个 OpenShell 沙箱，并通过它路由工具执行。

3. 验证：

```bash
openclaw sandbox list
openclaw sandbox explain
```

## 工作空间模式

这是使用 OpenShell 时最重要的决策。

### `mirror`

当你希望**本地工作空间保持为规范来源**时，请使用 `plugins.entries.openshell.config.mode: "mirror"`。

行为如下：

- 在 `exec` 之前，OpenClaw 会将本地工作空间同步到 OpenShell 沙箱中。
- 在 `exec` 之后，OpenClaw 会将远程工作空间同步回本地工作空间。
- 文件工具仍通过沙箱桥接工作，但在各个回合之间，本地工作空间仍是事实来源。

最适合：

- 你会在 OpenClaw 之外本地编辑文件，并希望这些修改自动出现在沙箱中。
- 你希望 OpenShell 沙箱的行为尽可能接近 Docker 后端。
- 你希望主机工作空间在每次 exec 回合后都能反映沙箱中的写入。

权衡：每次 exec 前后都要额外进行同步。

### `remote`

当你希望**OpenShell 工作空间成为规范来源**时，请使用 `plugins.entries.openshell.config.mode: "remote"`。

行为如下：

- 当沙箱首次创建时，OpenClaw 会从本地工作空间向远端工作空间进行一次初始化。
- 之后，`exec`、`read`、`write`、`edit` 和 `apply_patch` 都会直接作用于远程 OpenShell 工作空间。
- OpenClaw **不会**将远程变更同步回本地工作空间。
- 提示词阶段的媒体读取仍然可以正常工作，因为文件和媒体工具都通过沙箱桥接读取。

最适合：

- 沙箱主要应驻留在远程侧。
- 你想降低每个回合的同步开销。
- 你不希望主机上的本地修改悄悄覆盖远程沙箱状态。

重要：如果在初始初始化之后，你在 OpenClaw 之外直接修改主机文件，远程沙箱**不会**看到这些改动。请使用 `openclaw sandbox recreate` 重新初始化。

### 如何选择模式

|                    | `mirror`                 | `remote`               |
| ------------------ | ------------------------ | ---------------------- |
| **规范工作空间**   | 本地主机                 | 远程 OpenShell         |
| **同步方向**       | 双向（每次 exec）        | 一次性初始化           |
| **每回合开销**     | 更高（上传 + 下载）      | 更低（直接远程操作）   |
| **本地编辑可见？** | 是，在下一次 exec 时可见 | 否，除非 recreate      |
| **最适合**         | 开发工作流               | 长时间运行的智能体、CI |

## 配置参考

所有 OpenShell 配置都位于 `plugins.entries.openshell.config` 下：

| Key                       | Type                     | Default       | Description                                        |
| ------------------------- | ------------------------ | ------------- | -------------------------------------------------- |
| `mode`                    | `"mirror"` or `"remote"` | `"mirror"`    | 工作空间同步模式                                   |
| `command`                 | `string`                 | `"openshell"` | `openshell` CLI 的路径或名称                       |
| `from`                    | `string`                 | `"openclaw"`  | 首次创建时使用的沙箱来源                           |
| `gateway`                 | `string`                 | —             | OpenShell gateway 名称（`--gateway`）              |
| `gatewayEndpoint`         | `string`                 | —             | OpenShell gateway 端点 URL（`--gateway-endpoint`） |
| `policy`                  | `string`                 | —             | 用于创建沙箱的 OpenShell policy ID                 |
| `providers`               | `string[]`               | `[]`          | 创建沙箱时附加的 provider 名称                     |
| `gpu`                     | `boolean`                | `false`       | 是否请求 GPU 资源                                  |
| `autoProviders`           | `boolean`                | `true`        | 创建沙箱时是否传入 `--auto-providers`              |
| `remoteWorkspaceDir`      | `string`                 | `"/sandbox"`  | 沙箱中的主要可写工作空间                           |
| `remoteAgentWorkspaceDir` | `string`                 | `"/agent"`    | 智能体工作空间挂载路径（用于只读访问）             |
| `timeoutSeconds`          | `number`                 | `120`         | `openshell` CLI 操作超时时间                       |

沙箱级设置（`mode`、`scope`、`workspaceAccess`）与其他后端一样，配置在 `agents.defaults.sandbox` 下。完整矩阵请参阅[沙箱隔离](/gateway/sandboxing)。

## 示例

### 最小 remote 配置

```json5
{
  agents: {
    defaults: {
      sandbox: {
        mode: "all",
        backend: "openshell",
      },
    },
  },
  plugins: {
    entries: {
      openshell: {
        enabled: true,
        config: {
          from: "openclaw",
          mode: "remote",
        },
      },
    },
  },
}
```

### 启用 GPU 的 mirror 模式

```json5
{
  agents: {
    defaults: {
      sandbox: {
        mode: "all",
        backend: "openshell",
        scope: "agent",
        workspaceAccess: "rw",
      },
    },
  },
  plugins: {
    entries: {
      openshell: {
        enabled: true,
        config: {
          from: "openclaw",
          mode: "mirror",
          gpu: true,
          providers: ["openai"],
          timeoutSeconds: 180,
        },
      },
    },
  },
}
```

### 按智能体配置 OpenShell，并使用自定义 gateway

```json5
{
  agents: {
    defaults: {
      sandbox: { mode: "off" },
    },
    list: [
      {
        id: "researcher",
        sandbox: {
          mode: "all",
          backend: "openshell",
          scope: "agent",
          workspaceAccess: "rw",
        },
      },
    ],
  },
  plugins: {
    entries: {
      openshell: {
        enabled: true,
        config: {
          from: "openclaw",
          mode: "remote",
          gateway: "lab",
          gatewayEndpoint: "https://lab.example",
          policy: "strict",
        },
      },
    },
  },
}
```

## 生命周期管理

OpenShell 沙箱通过标准 sandbox CLI 管理：

```bash
# List all sandbox runtimes (Docker + OpenShell)
openclaw sandbox list

# Inspect effective policy
openclaw sandbox explain

# Recreate (deletes remote workspace, re-seeds on next use)
openclaw sandbox recreate --all
```

对于 `remote` 模式，**recreate 尤其重要**：它会删除该 scope 下的规范远程工作空间。下一次使用时，会从本地工作空间重新初始化出一个全新的远程工作空间。

对于 `mirror` 模式，recreate 主要是重置远程执行环境，因为本地工作空间仍然是规范来源。

### 何时需要 recreate

在修改以下任一配置后，请执行 recreate：

- `agents.defaults.sandbox.backend`
- `plugins.entries.openshell.config.from`
- `plugins.entries.openshell.config.mode`
- `plugins.entries.openshell.config.policy`

```bash
openclaw sandbox recreate --all
```

## 当前限制

- OpenShell 后端不支持沙箱浏览器。
- `sandbox.docker.binds` 不适用于 OpenShell。
- `sandbox.docker.*` 下 Docker 专属运行时选项只适用于 Docker 后端。

## 工作原理

1. OpenClaw 调用 `openshell sandbox create`（按配置附带 `--from`、`--gateway`、`--policy`、`--providers`、`--gpu` 参数）。
2. OpenClaw 调用 `openshell sandbox ssh-config <name>` 获取该沙箱的 SSH 连接信息。
3. 核心层将 SSH 配置写入临时文件，并使用与通用 SSH 后端相同的远程文件系统桥接能力建立 SSH 会话。
4. 在 `mirror` 模式中：exec 前先从本地同步到远程，运行后再同步回本地。
5. 在 `remote` 模式中：创建时只初始化一次，此后直接在远程工作空间上操作。

## 另见

- [沙箱隔离](/gateway/sandboxing) —— 模式、scope 与后端对比
- [Sandbox vs Tool Policy vs Elevated](/gateway/sandbox-vs-tool-policy-vs-elevated) —— 调试被阻止的工具
- [Multi-Agent Sandbox and Tools](/tools/multi-agent-sandbox-tools) —— 按智能体覆盖配置
- [Sandbox CLI](/cli/sandbox) —— `openclaw sandbox` 命令
