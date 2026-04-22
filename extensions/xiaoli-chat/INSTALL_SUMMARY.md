# Xiaoli Chat 插件安装总结

## 问题解决

### 1. 所有权问题
**问题**: 插件目录文件所有权混乱（部分 uid=1000，部分 root），导致 OpenClaw 拒绝加载
```
plugins: plugin: blocked plugin candidate: suspicious ownership
```

**解决方案**: 
- 统一目录所有权为 root: `chown -R root:root /mine/Code/ai-tools/openclaw/extensions/xiaoli-chat`
- 安装脚本已更新，自动检测并修复所有权（步骤 0/6）

### 2. 插件信任问题
**问题**: 插件未在白名单中，系统拒绝加载
```
plugins.entries.xiaoli-chat: plugin not found: xiaoli-chat
```

**解决方案**:
- 配置插件白名单: `openclaw config set plugins.allow '["xiaoli-chat", "kimi-claw"]'`
- 安装脚本已更新，自动添加到白名单（步骤 2/6）

### 3. 通道配置缺失
**问题**: 插件已加载但通道未配置，`openclaw channels status` 不显示

**解决方案**:
```bash
openclaw config set channels.xiaoli-chat.enabled true
openclaw config set channels.xiaoli-chat.token "your-token"
openclaw config set channels.xiaoli-chat.baseUrl "http://localhost:8088"
openclaw gateway restart
```

## 更新的安装脚本

`install-load.sh` 现在包含以下改进：

1. **步骤 0/6**: 自动修复所有权（如果以 root 运行）
2. **步骤 1/6**: 构建插件
3. **步骤 2/6**: 配置插件白名单（自动添加到 `plugins.allow`）
4. **步骤 3/6**: 安装插件
5. **步骤 4/6**: 启用插件
6. **步骤 5/6**: 配置通道
7. **步骤 6/6**: 智能重启 gateway（支持 systemctl 和手动模式）

## 验证安装

```bash
# 检查插件状态
openclaw plugins list | grep xiaoli-chat
openclaw plugins inspect xiaoli-chat

# 检查通道状态
openclaw channels status

# 检查配置
openclaw config get channels.xiaoli-chat
openclaw config get plugins.allow
```

## 当前状态

✅ 插件已成功加载
✅ 通道已配置并启用
✅ Gateway 正常运行

```
- Xiaoli Chat default: enabled, configured
- Kimi Claw main: enabled, configured
```

## 使用方法

```bash
# 开发模式（推荐）
cd /mine/Code/ai-tools/openclaw/extensions/xiaoli-chat
./install-load.sh --local

# 生产模式（复制到 ~/.openclaw/extensions/）
./install-load.sh --copy
```

## 注意事项

1. 必须以 root 身份运行安装脚本以修复所有权
2. 每次修改代码后需要重新构建并重启 gateway
3. 通道配置保存在 `~/.openclaw/openclaw.json`
4. Gateway 日志位于 `/tmp/openclaw-gateway.log`（手动模式）或通过 `journalctl` 查看（systemctl 模式）
