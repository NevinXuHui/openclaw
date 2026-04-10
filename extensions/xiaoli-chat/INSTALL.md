# Xiaoli Chat 插件安装指南

## 安装模式

### 1. 本地路径模式 (开发模式, 默认)

```bash
./install-load.sh
# 或
./install-load.sh --local
```

**特点**:
- 直接引用源码目录
- 修改代码后重新编译即可生效
- `installPath` = `sourcePath` = `/mine/Code/ai-tools/openclaw/extensions/xiaoli-chat`
- 适合开发调试

**工作流程**:
1. 修改代码
2. 运行 `./build.sh` 重新编译
3. 运行 `openclaw gateway restart` 重启 gateway
4. 更改生效

### 2. 复制模式 (生产模式)

```bash
./install-load.sh --copy
```

**特点**:
- 复制到 `~/.openclaw/extensions/xiaoli-chat/`
- 独立副本,不受源码目录影响
- 模拟 npm 安装的行为
- 适合测试正式安装流程

**工作流程**:
1. 脚本自动编译并复制到用户目录
2. 从复制的目录安装
3. 更新代码需要重新运行 `./install-load.sh --copy`

## 安装步骤

脚本会自动执行以下步骤:

1. **[1/5] Building** - 编译插件 (调用 `build.sh`)
2. **[2/5] Copying/Installing** - 根据模式复制或直接安装
3. **[3/5] Installing** - 注册插件到 OpenClaw
4. **[4/5] Enabling** - 启用插件
5. **[5/5] Restarting** - 重启 gateway

## 验证安装

```bash
# 查看插件列表
openclaw plugins list

# 查看插件详情
openclaw plugins inspect xiaoli-chat
```

## 卸载

```bash
# 卸载插件 (只删除元数据)
openclaw plugins uninstall xiaoli-chat

# 完全移除 (包括文件)
openclaw plugins uninstall xiaoli-chat
rm -rf ~/.openclaw/extensions/xiaoli-chat  # 仅复制模式需要
openclaw gateway restart
```

## 故障排查

### 插件未加载

```bash
# 检查插件状态
openclaw plugins inspect xiaoli-chat

# 查看 gateway 日志
openclaw gateway logs
```

### 编译失败

```bash
# 检查依赖
cd /mine/Code/ai-tools/openclaw
pnpm install

# 手动编译
cd extensions/xiaoli-chat
./build.sh
```

### 权限问题

```bash
# 确保脚本可执行
chmod +x build.sh install-load.sh
```
