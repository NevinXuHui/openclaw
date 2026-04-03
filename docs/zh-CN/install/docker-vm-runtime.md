---
summary: "基于 Docker 的 VM 的共享 Docker VM 运行时步骤，用于长期运行的 OpenClaw Gateway 网关主机"
read_when:
  - 您正在使用 Docker 在云 VM 上部署 OpenClaw
  - 您需要共享的二进制烘焙、持久性和更新流程
title: "Docker VM Runtime"
x-i18n:
  sourceCommit: "latest"
  sourceFile: "install/docker-vm-runtime.md"
---

# Docker VM Runtime

基于 VM 的 Docker 安装（如 GCP、Hetzner 和类似 VPS 提供商）的共享运行时步骤。

## 将所需的二进制文件烘焙到镜像中

在运行的容器内安装二进制文件是一个陷阱。
在运行时安装的任何内容都将在重启时丢失。

skills 所需的所有外部二进制文件都必须在镜像构建时安装。

下面的示例仅显示三个常见的二进制文件：

- `gog` 用于 Gmail 访问
- `goplaces` 用于 Google Places
- `wacli` 用于 WhatsApp

这些是示例，而不是完整列表。
您可以使用相同的模式安装所需的任意数量的二进制文件。

如果您稍后添加依赖于其他二进制文件的新 skills，您必须：

1. 更新 Dockerfile
2. 重建镜像
3. 重启容器

**示例 Dockerfile**

```dockerfile
FROM node:24-bookworm

RUN apt-get update && apt-get install -y socat && rm -rf /var/lib/apt/lists/*

# 示例二进制文件 1：Gmail CLI
RUN curl -L https://github.com/steipete/gog/releases/latest/download/gog_Linux_x86_64.tar.gz \
  | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/gog

# 示例二进制文件 2：Google Places CLI
RUN curl -L https://github.com/steipete/goplaces/releases/latest/download/goplaces_Linux_x86_64.tar.gz \
  | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/goplaces

# 示例二进制文件 3：WhatsApp CLI
RUN curl -L https://github.com/steipete/wacli/releases/latest/download/wacli_Linux_x86_64.tar.gz \
  | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/wacli

# 使用相同的模式在下面添加更多二进制文件

WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY scripts ./scripts

RUN corepack enable
RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm build
RUN pnpm ui:install
RUN pnpm ui:build

ENV NODE_ENV=production

CMD ["node","dist/index.js"]
```

<Note>
上面的下载 URL 适用于 x86_64（amd64）。对于基于 ARM 的 VM（例如 Hetzner ARM、GCP Tau T2A），请从每个工具的发布页面将下载 URL 替换为适当的 ARM64 变体。
</Note>

## 构建和启动

```bash
docker compose build
docker compose up -d openclaw-gateway
```

如果构建在 `pnpm install --frozen-lockfile` 期间失败并显示 `Killed` 或 `exit code 137`，则 VM 内存不足。
在重试之前使用更大的机器类。

验证二进制文件：

```bash
docker compose exec openclaw-gateway which gog
docker compose exec openclaw-gateway which goplaces
docker compose exec openclaw-gateway which wacli
```

预期输出：

```
/usr/local/bin/gog
/usr/local/bin/goplaces
/usr/local/bin/wacli
```

验证 Gateway 网关：

```bash
docker compose logs -f openclaw-gateway
```

预期输出：

```
[gateway] listening on ws://0.0.0.0:18789
```

## 什么持久化在哪里

OpenClaw 在 Docker 中运行，但 Docker 不是真相的来源。
所有长期状态都必须在重启、重建和重启后存活。

| 组件             | 位置                              | 持久化机制    | 注意事项                     |
| ---------------- | --------------------------------- | ------------- | ---------------------------- |
| Gateway 网关配置 | `/home/node/.openclaw/`           | 主机卷挂载    | 包括 `openclaw.json`、tokens |
| 模型认证配置文件 | `/home/node/.openclaw/`           | 主机卷挂载    | OAuth tokens、API 密钥       |
| Skill 配置       | `/home/node/.openclaw/skills/`    | 主机卷挂载    | Skill 级状态                 |
| Agent 工作区     | `/home/node/.openclaw/workspace/` | 主机卷挂载    | 代码和 agent 工件            |
| WhatsApp 会话    | `/home/node/.openclaw/`           | 主机卷挂载    | 保留 QR 登录                 |
| Gmail keyring    | `/home/node/.openclaw/`           | 主机卷 + 密码 | 需要 `GOG_KEYRING_PASSWORD`  |
| 外部二进制文件   | `/usr/local/bin/`                 | Docker 镜像   | 必须在构建时烘焙             |
| Node 运行时      | 容器文件系统                      | Docker 镜像   | 每次镜像构建都会重建         |
| OS 包            | 容器文件系统                      | Docker 镜像   | 不要在运行时安装             |
| Docker 容器      | 临时的                            | 可重启        | 可以安全销毁                 |

## 更新

要在 VM 上更新 OpenClaw：

```bash
git pull
docker compose build
docker compose up -d
```
