---
summary: "使用 Kustomize 将 OpenClaw Gateway 网关部署到 Kubernetes 集群"
read_when:
  - 您想在 Kubernetes 集群上运行 OpenClaw
  - 您想在 Kubernetes 环境中测试 OpenClaw
title: "Kubernetes"
x-i18n:
  sourceCommit: "latest"
  sourceFile: "install/kubernetes.md"
---

# Kubernetes 上的 OpenClaw

在 Kubernetes 上运行 OpenClaw 的最小起点 — 不是生产就绪的部署。它涵盖了核心资源，旨在适应您的环境。

## 为什么不用 Helm？

OpenClaw 是一个带有一些配置文件的单个容器。有趣的自定义在于 agent 内容（markdown 文件、skills、配置覆盖），而不是基础设施模板。Kustomize 处理覆盖而无需 Helm chart 的开销。如果您的部署变得更复杂，可以在这些清单之上分层 Helm chart。

## 您需要什么

- 正在运行的 Kubernetes 集群（AKS、EKS、GKE、k3s、kind、OpenShift 等）
- 连接到您的集群的 `kubectl`
- 至少一个模型提供商的 API 密钥

## 快速开始

```bash
# 替换为您的提供商：ANTHROPIC、GEMINI、OPENAI 或 OPENROUTER
export <PROVIDER>_API_KEY="..."
./scripts/k8s/deploy.sh

kubectl port-forward svc/openclaw 18789:18789 -n openclaw
open http://localhost:18789
```

检索 gateway token 并将其粘贴到 Control UI 中：

```bash
kubectl get secret openclaw-secrets -n openclaw -o jsonpath='{.data.OPENCLAW_GATEWAY_TOKEN}' | base64 -d
```

对于本地调试，`./scripts/k8s/deploy.sh --show-token` 在部署后打印 token。

## 使用 Kind 进行本地测试

如果您没有集群，请使用 [Kind](https://kind.sigs.k8s.io/) 在本地创建一个：

```bash
./scripts/k8s/create-kind.sh           # 自动检测 docker 或 podman
./scripts/k8s/create-kind.sh --delete  # 拆除
```

然后像往常一样使用 `./scripts/k8s/deploy.sh` 部署。

## 逐步说明

### 1) 部署

**选项 A** — 环境中的 API 密钥（一步）：

```bash
# 替换为您的提供商：ANTHROPIC、GEMINI、OPENAI 或 OPENROUTER
export <PROVIDER>_API_KEY="..."
./scripts/k8s/deploy.sh
```

脚本使用 API 密钥和自动生成的 gateway token 创建 Kubernetes Secret，然后部署。如果 Secret 已存在，它会保留当前的 gateway token 和任何未更改的提供商密钥。

**选项 B** — 单独创建 secret：

```bash
export <PROVIDER>_API_KEY="..."
./scripts/k8s/deploy.sh --create-secret
./scripts/k8s/deploy.sh
```

如果您希望为本地测试打印 token 到 stdout，请在任一命令中使用 `--show-token`。

### 2) 访问 gateway

```bash
kubectl port-forward svc/openclaw 18789:18789 -n openclaw
open http://localhost:18789
```

## 部署的内容

```
Namespace: openclaw（可通过 OPENCLAW_NAMESPACE 配置）
├── Deployment/openclaw        # 单个 pod，init 容器 + gateway
├── Service/openclaw           # 端口 18789 上的 ClusterIP
├── PersistentVolumeClaim      # 用于 agent 状态和配置的 10Gi
├── ConfigMap/openclaw-config  # openclaw.json + AGENTS.md
└── Secret/openclaw-secrets    # Gateway token + API 密钥
```

## 自定义

### Agent 指令

编辑 `scripts/k8s/manifests/configmap.yaml` 中的 `AGENTS.md` 并重新部署：

```bash
./scripts/k8s/deploy.sh
```

### Gateway 网关配置

编辑 `scripts/k8s/manifests/configmap.yaml` 中的 `openclaw.json`。完整参考请参阅 [Gateway configuration](/gateway/configuration)。

### 添加提供商

使用导出的其他密钥重新运行：

```bash
export ANTHROPIC_API_KEY="..."
export OPENAI_API_KEY="..."
./scripts/k8s/deploy.sh --create-secret
./scripts/k8s/deploy.sh
```

现有提供商密钥保留在 Secret 中，除非您覆盖它们。

或直接修补 Secret：

```bash
kubectl patch secret openclaw-secrets -n openclaw \
  -p '{"stringData":{"<PROVIDER>_API_KEY":"..."}}'
kubectl rollout restart deployment/openclaw -n openclaw
```

### 自定义命名空间

```bash
OPENCLAW_NAMESPACE=my-namespace ./scripts/k8s/deploy.sh
```

### 自定义镜像

编辑 `scripts/k8s/manifests/deployment.yaml` 中的 `image` 字段：

```yaml
image: ghcr.io/openclaw/openclaw:latest # 或从 https://github.com/openclaw/openclaw/releases 固定到特定版本
```

### 超越 port-forward 的暴露

默认清单将 gateway 绑定到 pod 内的 loopback。这适用于 `kubectl port-forward`，但不适用于需要到达 pod IP 的 Kubernetes `Service` 或 Ingress 路径。

如果您想通过 Ingress 或负载均衡器暴露 gateway：

- 将 `scripts/k8s/manifests/configmap.yaml` 中的 gateway 绑定从 `loopback` 更改为与您的部署模型匹配的非 loopback 绑定
- 保持 gateway 认证启用并使用适当的 TLS 终止入口点
- 使用支持的 Web 安全模型为远程访问配置 Control UI（例如 HTTPS/Tailscale Serve 和在需要时明确允许的来源）

## 重新部署

```bash
./scripts/k8s/deploy.sh
```

这会应用所有清单并重新启动 pod 以获取任何配置或 secret 更改。

## 拆除

```bash
./scripts/k8s/deploy.sh --delete
```

这会删除命名空间及其中的所有资源，包括 PVC。

## 架构注意事项

- 默认情况下，gateway 绑定到 pod 内的 loopback，因此包含的设置适用于 `kubectl port-forward`
- 没有集群范围的资源 — 所有内容都位于单个命名空间中
- 安全性：`readOnlyRootFilesystem`、`drop: ALL` 能力、非 root 用户（UID 1000）
- 默认配置将 Control UI 保持在更安全的本地访问路径上：loopback 绑定加上 `kubectl port-forward` 到 `http://127.0.0.1:18789`
- 如果您超越 localhost 访问，请使用支持的远程模型：HTTPS/Tailscale 加上适当的 gateway 绑定和 Control UI 来源设置
- Secrets 在临时目录中生成并直接应用于集群 — 没有 secret 材料写入 repo 检出

## 文件结构

```
scripts/k8s/
├── deploy.sh                   # 创建命名空间 + secret，通过 kustomize 部署
├── create-kind.sh              # 本地 Kind 集群（自动检测 docker/podman）
└── manifests/
    ├── kustomization.yaml      # Kustomize base
    ├── configmap.yaml          # openclaw.json + AGENTS.md
    ├── deployment.yaml         # 具有安全加固的 Pod 规范
    ├── pvc.yaml                # 10Gi 持久存储
    └── service.yaml            # 18789 上的 ClusterIP
```
