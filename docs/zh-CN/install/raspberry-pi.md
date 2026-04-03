---
summary: "在 Raspberry Pi 上运行 OpenClaw Gateway 网关"
read_when:
  - 在 Raspberry Pi 上设置 OpenClaw
  - 在低功耗 ARM 设备上运行 OpenClaw
title: "Raspberry Pi"
x-i18n:
  sourceCommit: "latest"
  sourceFile: "install/raspberry-pi.md"
---

# Raspberry Pi

在 Raspberry Pi 上运行 OpenClaw Gateway 网关。

## 先决条件

- Raspberry Pi 4 或 5（推荐 4 GB+ RAM）
- Raspberry Pi OS（64 位）或 Ubuntu Server 24.04 ARM64
- 至少一个模型提供商的 API 密钥
- 约 30 分钟

## 设置

<Steps>
  <Step title="更新系统">
    ```bash
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y build-essential git curl
    ```
  </Step>

  <Step title="安装 Node.js 24">
    ```bash
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo bash -
    sudo apt install -y nodejs
    node --version  # 应该显示 v24.x.x
    ```
  </Step>

  <Step title="安装 OpenClaw">
    ```bash
    curl -fsSL https://openclaw.ai/install.sh | bash
    source ~/.bashrc
    openclaw --version
    ```
  </Step>

  <Step title="运行 onboarding">
    ```bash
    openclaw onboard --install-daemon
    ```

    向导会引导您完成模型认证、channel 设置、gateway token 生成和守护进程安装（systemd）。

  </Step>

  <Step title="添加 swap（推荐用于 2 GB Pi）">
    ```bash
    sudo dphys-swapfile swapoff
    sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
    sudo dphys-swapfile setup
    sudo dphys-swapfile swapon
    ```

    对于 Ubuntu Server，请使用：

    ```bash
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
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
    ssh -L 18789:localhost:18789 pi@YOUR_PI_IP
    ```

    然后打开 `http://localhost:18789`。

    **选项 B：Tailscale Serve**

    ```bash
    curl -fsSL https://tailscale.com/install.sh | sh
    sudo tailscale up
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

## 性能提示

- **使用基于 API 的模型**（Claude、GPT）而不是本地模型。Pi 没有足够的 RAM/CPU 用于本地 LLM。
- **限制并发会话**。Pi 可以处理 1-2 个活动对话；更多会导致交换。
- **使用 lite skills**。避免需要大量依赖项或二进制文件的 skills。
- **监控资源**。使用 `htop` 和 `free -h` 监视 CPU/RAM 使用情况。

## 故障排除

**Gateway 网关无法启动** -- 运行 `openclaw doctor --non-interactive` 并使用 `journalctl --user -u openclaw-gateway.service -n 50` 检查日志。

**内存不足** -- 使用 `free -h` 验证 swap 是否处于活动状态。如果仍然遇到 OOM，请减少并发会话或升级到 8 GB Pi。

**ARM 二进制问题** -- 大多数 npm 包在 ARM64 上工作。对于原生二进制文件，查找 `linux-arm64` 或 `aarch64` 版本。使用 `uname -m` 验证架构。

**慢速构建** -- 如果从源代码构建，请在更强大的机器上构建并复制二进制文件，或使用预构建的 npm 包。

## 下一步

- [Channels](/channels) -- 连接 Telegram、WhatsApp、Discord 等
- [Gateway configuration](/gateway/configuration) -- 所有配置选项
- [Updating](/install/updating) -- 保持 OpenClaw 最新
