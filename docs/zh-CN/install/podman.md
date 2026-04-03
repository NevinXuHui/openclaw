---
summary: "使用 Podman 作为 Docker 替代方案运行 OpenClaw Gateway 网关"
read_when:
  - 您更喜欢 Podman 而不是 Docker
  - 您想要无守护进程的容器运行时
  - 您在 rootless 模式下运行容器
title: "Podman"
x-i18n:
  sourceCommit: "latest"
  sourceFile: "install/podman.md"
---

# Podman

使用 Podman 作为 Docker 的替代方案运行 OpenClaw Gateway 网关。

Podman 是一个无守护进程的容器引擎，用于在 Linux 系统上开发、管理和运行 OCI 容器。它提供与 Docker 类似的 CLI 体验，但具有不同的架构。

## 先决条件

- Podman 4.0+（[安装说明](https://podman.io/getting-started/installation)）
- `podman-compose` 或 `docker-compose`（两者都可以与 Podman 一起使用）
- 至少一个模型提供商的 API 密钥

## 设置

<Steps>
  <Step title="克隆仓库">
    ```bash
    git clone https://github.com/openclaw/openclaw.git
    cd openclaw
    ```
  </Step>

  <Step title="配置环境">
    创建 `~/.openclaw/.env`：

    ```bash
    mkdir -p ~/.openclaw
    cat > ~/.openclaw/.env << 'EOF'
    # 至少添加一个提供商
    ANTHROPIC_API_KEY=sk-ant-...
    OPENAI_API_KEY=sk-...
    GEMINI_API_KEY=...
    OPENROUTER_API_KEY=sk-or-...
    EOF
    ```

    创建项目 `.env`：

    ```bash
    cat > .env << 'EOF'
    OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest
    OPENCLAW_GATEWAY_PORT=18789
    OPENCLAW_GATEWAY_TOKEN=your-secure-token-here
    EOF
    ```

    将 `your-secure-token-here` 替换为安全的随机字符串。

  </Step>

  <Step title="启动 Podman socket（如果需要）">
    如果您使用 `docker-compose` 与 Podman：

    ```bash
    systemctl --user enable --now podman.socket
    export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock
    ```

    将 `export` 行添加到您的 shell 配置文件（`~/.bashrc` 或 `~/.zshrc`）。

  </Step>

  <Step title="使用 Podman 构建和运行">
    **选项 A：使用 podman-compose**

    ```bash
    podman-compose build
    podman-compose up -d openclaw-gateway
    ```

    **选项 B：使用 docker-compose + Podman socket**

    ```bash
    docker-compose build
    docker-compose up -d openclaw-gateway
    ```

    **选项 C：直接使用 Podman**

    ```bash
    # 构建镜像
    podman build -t openclaw:local .

    # 运行容器
    podman run -d \
      --name openclaw-gateway \
      -p 18789:18789 \
      -v ~/.openclaw:/home/node/.openclaw:Z \
      --env-file ~/.openclaw/.env \
      -e OPENCLAW_GATEWAY_TOKEN=your-secure-token-here \
      openclaw:local
    ```

    注意 `:Z` 标志用于 SELinux 上下文。

  </Step>

  <Step title="验证">
    ```bash
    podman ps
    podman logs openclaw-gateway
    curl http://localhost:18789
    ```

    预期输出：

    ```
    [gateway] listening on ws://0.0.0.0:18789
    ```

  </Step>

  <Step title="访问 Control UI">
    打开 `http://localhost:18789` 并使用您的 gateway token 登录。
  </Step>
</Steps>

## Rootless 模式

Podman 默认在 rootless 模式下运行，这更安全。

关键差异：

- 容器以您的用户身份运行，而不是 root
- 端口 < 1024 需要额外配置
- 卷挂载需要正确的权限

对于 rootless 卷挂载：

```bash
# 确保 ~/.openclaw 由您的用户拥有
chown -R $USER:$USER ~/.openclaw
chmod 700 ~/.openclaw
```

## SELinux 注意事项

如果您在启用 SELinux 的系统上运行（Fedora、RHEL、CentOS）：

- 在卷挂载上使用 `:Z` 标志（如上所示）
- 或者，设置正确的 SELinux 上下文：

```bash
chcon -Rt container_file_t ~/.openclaw
```

## 从 Docker 迁移

如果您从 Docker 迁移：

1. 停止 Docker 容器：`docker-compose down`
2. 安装 Podman
3. 启用 Podman socket（如果使用 `docker-compose`）
4. 使用 Podman 重新构建：`podman-compose build` 或 `docker-compose build`
5. 使用 Podman 启动：`podman-compose up -d` 或 `docker-compose up -d`

您的配置和数据（在 `~/.openclaw` 中）保持不变。

## 故障排除

**权限被拒绝（卷挂载）** -- 检查 `~/.openclaw` 的所有权和权限。在 rootless 模式下，它必须由您的用户拥有。

**端口已被使用** -- 运行 `podman ps -a` 查找冲突的容器。停止它们或在 `.env` 中更改 `OPENCLAW_GATEWAY_PORT`。

**SELinux 阻止访问** -- 在卷挂载上使用 `:Z` 标志或运行 `chcon -Rt container_file_t ~/.openclaw`。

**Podman socket 未运行** -- 运行 `systemctl --user status podman.socket`。如果未运行，请使用 `systemctl --user start podman.socket` 启动它。

**构建失败并显示 "Killed"** -- 内存不足。增加 Podman 的内存限制或使用更小的基础镜像。

## 更新

要更新 OpenClaw：

```bash
cd openclaw
git pull
podman-compose build
podman-compose up -d
```

或使用 `docker-compose` 如果您使用 Podman socket。

## 下一步

- [Channels](/channels) -- 连接 Telegram、WhatsApp、Discord 等
- [Gateway configuration](/gateway/configuration) -- 所有配置选项
- [Updating](/install/updating) -- 保持 OpenClaw 最新
