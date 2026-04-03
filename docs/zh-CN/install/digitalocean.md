---
summary: "在 DigitalOcean Droplet 上托管 OpenClaw"
read_when:
  - 在 DigitalOcean 上设置 OpenClaw
  - 寻找用于 OpenClaw 的简单付费 VPS
title: "DigitalOcean"
x-i18n:
  sourceCommit: "latest"
  sourceFile: "install/digitalocean.md"
---

# DigitalOcean

在 DigitalOcean Droplet 上运行持久的 OpenClaw Gateway 网关。

## 先决条件

- DigitalOcean 账户（[注册](https://cloud.digitalocean.com/registrations/new)）
- SSH 密钥对（或愿意使用密码认证）
- 约 20 分钟

## 设置

<Steps>
  <Step title="创建 Droplet">
    <Warning>
    使用干净的基础镜像（Ubuntu 24.04 LTS）。避免使用第三方 Marketplace 一键镜像，除非您已审查其启动脚本和防火墙默认值。
    </Warning>

    1. 登录 [DigitalOcean](https://cloud.digitalocean.com/)。
    2. 点击 **Create > Droplets**。
    3. 选择：
       - **Region：** 离您最近的
       - **Image：** Ubuntu 24.04 LTS
       - **Size：** Basic、Regular、1 vCPU / 1 GB RAM / 25 GB SSD
       - **Authentication：** SSH 密钥（推荐）或密码
    4. 点击 **Create Droplet** 并记下 IP 地址。

  </Step>

  <Step title="连接并安装">
    ```bash
    ssh root@YOUR_DROPLET_IP

    apt update && apt upgrade -y

    # 安装 Node.js 24
    curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
    apt install -y nodejs

    # 安装 OpenClaw
    curl -fsSL https://openclaw.ai/install.sh | bash
    openclaw --version
    ```

  </Step>

  <Step title="运行 onboarding">
    ```bash
    openclaw onboard --install-daemon
    ```

    向导会引导您完成模型认证、channel 设置、gateway token 生成和守护进程安装（systemd）。

  </Step>

  <Step title="添加 swap（推荐用于 1 GB Droplets）">
    ```bash
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    ```
  </Step>

  <Step title="验证 gateway">
    ```bash
    openclaw status
    systemctl --user status openclaw-gateway.service
    journalctl --user -u openclaw-gateway.service -f
    ```
  </Step>

  <Step title="访问 Control UI">
    gateway 默认绑定到 loopback。选择以下选项之一。

    **选项 A：SSH 隧道（最简单）**

    ```bash
    # 从您的本地机器
    ssh -L 18789:localhost:18789 root@YOUR_DROPLET_IP
    ```

    然后打开 `http://localhost:18789`。

    **选项 B：Tailscale Serve**

    ```bash
    curl -fsSL https://tailscale.com/install.sh | sh
    tailscale up
    openclaw config set gateway.tailscale.mode serve
    openclaw gateway restart
    ```

    然后从您的 tailnet 上的任何设备打开 `https://<magicdns>/`。

    **选项 C：Tailnet 绑定（无 Serve）**

    ```bash
    openclaw config set gateway.bind tailnet
    openclaw gateway restart
    ```

    然后打开 `http://<tailscale-ip>:18789`（需要 token）。

  </Step>
</Steps>

## 故障排除

**Gateway 网关无法启动** -- 运行 `openclaw doctor --non-interactive` 并使用 `journalctl --user -u openclaw-gateway.service -n 50` 检查日志。

**端口已被使用** -- 运行 `lsof -i :18789` 查找进程，然后停止它。

**内存不足** -- 使用 `free -h` 验证 swap 是否处于活动状态。如果仍然遇到 OOM，请使用基于 API 的模型（Claude、GPT）而不是本地模型，或升级到 2 GB Droplet。

## 下一步

- [Channels](/channels) -- 连接 Telegram、WhatsApp、Discord 等
- [Gateway configuration](/gateway/configuration) -- 所有配置选项
- [Updating](/install/updating) -- 保持 OpenClaw 最新
