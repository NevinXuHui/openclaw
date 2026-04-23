# Install Script Fix - 2026-04-22

## 问题描述

`install.sh` 脚本复制的文件不完整，导致安装后的服务无法正常工作：

1. **缺少源码文件**：`run.sh` 依赖 `main.go` 和 `go.mod` 进行自动编译
2. **缺少测试脚本**：无法在安装目录进行功能测试
3. **缺少卸载脚本**：无法方便地卸载服务

## 根本原因

`install.sh` 和 `run.sh` 的逻辑不一致：

- `run.sh`：如果二进制文件不存在，会自动从 `main.go` 编译
- `install.sh`：只复制二进制文件，不复制源码

这导致在安装目录中，如果二进制文件被删除或损坏，`run.sh` 无法重新编译。

## 修复内容

### 新增复制的文件

```bash
# 1. 源码文件（必需，用于 run.sh 自动编译）
cp "$SCRIPT_DIR/main.go" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/go.mod" "$INSTALL_DIR/"

# 2. 测试脚本（可选，方便测试）
cp "$SCRIPT_DIR/send-test-message.sh" "$INSTALL_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/send-and-wait-reply.sh" "$INSTALL_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/send-with-sse.sh" "$INSTALL_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/test-receive-message.sh" "$INSTALL_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/chat-multiround.sh" "$INSTALL_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/test-multiround-auto.sh" "$INSTALL_DIR/" 2>/dev/null || true

# 3. 卸载脚本（可选，方便卸载）
cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/" 2>/dev/null || true

# 4. 设置所有 .sh 文件的执行权限
chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true
```

## 修复后的文件结构

安装后 `/opt/xiaoli-webhook/` 目录包含：

```
/opt/xiaoli-webhook/
├── .env                          # 环境配置
├── .env.example                  # 配置示例
├── main.go                       # 源码（用于自动编译）
├── go.mod                        # Go 模块定义
├── webhook-server                # x86_64 二进制
├── webhook-server-arm64          # ARM64 二进制
├── run.sh                        # 启动脚本
├── uninstall.sh                  # 卸载脚本
├── README.md                     # 文档
├── send-test-message.sh          # 测试脚本
├── send-and-wait-reply.sh        # 测试脚本
├── send-with-sse.sh              # 测试脚本
├── test-receive-message.sh       # 测试脚本
├── chat-multiround.sh            # 测试脚本
└── test-multiround-auto.sh       # 测试脚本
```

## 验证

```bash
# 1. 语法检查
bash -n install.sh

# 2. 测试安装（需要 root 权限）
sudo ./install.sh

# 3. 验证文件完整性
ls -la /opt/xiaoli-webhook/

# 4. 测试服务
sudo systemctl status xiaoli-webhook
curl http://localhost:8088/health

# 5. 测试自动编译（删除二进制后重启）
sudo rm /opt/xiaoli-webhook/webhook-server*
sudo systemctl restart xiaoli-webhook
# run.sh 应该自动重新编译
```

## 与 run.sh 的一致性

现在 `install.sh` 和 `run.sh` 的逻辑完全一致：

| 功能 | run.sh | install.sh（修复后） |
|------|--------|---------------------|
| 检测架构 | ✓ | ✓ |
| 自动编译 | ✓ | ✓（通过复制源码） |
| 停止旧进程 | ✓ | ✓（通过 systemd） |
| 启动服务 | ✓ | ✓（通过 systemd） |
| 测试脚本 | ✓ | ✓（复制到安装目录） |

## 使用建议

1. **开发环境**：直接使用 `./run.sh`
2. **生产环境**：使用 `sudo ./install.sh` 安装为系统服务
3. **测试**：在 `/opt/xiaoli-webhook/` 目录使用测试脚本
4. **卸载**：使用 `sudo ./uninstall.sh` 或 `sudo systemctl disable xiaoli-webhook`
