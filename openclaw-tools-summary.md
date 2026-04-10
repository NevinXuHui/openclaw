# OpenClaw 工具系统总结

## 📊 你的 OpenClaw 配置

### 已安装的插件

根据你的配置，目前有以下插件：

1. **xiaoli-chat** (已启用)
   - 版本：2026.4.1
   - 路径：`/mine/Code/ai-tools/openclaw/extensions/xiaoli-chat`
   - 安装时间：2026-04-01

2. **kimi-claw** (未在配置中启用)
   - 路径：`~/.openclaw/extensions/kimi-claw`
   - 状态：已发现但未明确信任

3. **qqbot** (未在配置中启用)
   - 路径：`~/.openclaw/extensions/qqbot`
   - 状态：已发现但未明确信任

### ⚠️ 安全提示

系统日志显示：
```
plugins.allow is empty; discovered non-bundled plugins may auto-load
```

**建议操作**：
```bash
# 明确信任插件
openclaw config set plugins.allow '["xiaoli-chat", "kimi-claw", "qqbot"]'

# 或者只信任特定插件
openclaw config set plugins.allow '["xiaoli-chat"]'
```

---

## 🛠️ OpenClaw 核心工具

OpenClaw 内置了以下核心工具（无需插件）：

### 1. Web Tools（网络工具）
- `web_search` - 网络搜索
- `web_fetch` - 网页抓取

### 2. Image Tools（图像工具）
- `image_generate` - AI 图像生成
- `image_tool` - 图像处理

### 3. Document Tools（文档工具）
- `pdf_tool` - PDF 读取和处理

### 4. Communication Tools（通信工具）
- `message` - 发送消息到各平台
- `tts` - 文字转语音

### 5. Automation Tools（自动化工具）
- `cron` - 定时任务管理

### 6. Session Tools（会话工具）
- `sessions_list` - 列出会话
- `sessions_send` - 发送消息到会话
- `sessions_spawn` - 创建新会话
- `sessions_history` - 查看会话历史

### 7. Advanced Tools（高级工具）
- `canvas` - 可视化渲染
- `gateway` - 网关控制
- `nodes` - 节点管理

---

## 🔍 如何查看可用工具

### 方法 1：通过 AI 查询
```bash
openclaw agent --message "列出你可以使用的所有工具及其功能" --local
```

### 方法 2：查看配置
```bash
# 查看工具配置
openclaw config get tools

# 查看插件配置
openclaw config get plugins
```

### 方法 3：启动网关并查看日志
```bash
# 启动网关（详细模式）
openclaw gateway --verbose

# 工具调用会在日志中显示
```

---

## 🧪 测试工具

### 测试网络搜索
```bash
openclaw agent --message "搜索 OpenAI 最新消息" --local
```

### 测试图像生成
```bash
openclaw agent --message "生成一张日落海滩的图片" --local
```

### 测试 PDF 处理
```bash
openclaw agent --message "读取 /path/to/file.pdf 的内容" --local
```

### 测试定时任务
```bash
openclaw agent --message "每天早上9点提醒我查看邮件" --local
```

---

## 📝 开发自定义工具

如果你想开发自己的工具插件，参考：

1. **文档位置**：`/mine/Code/ai-tools/openclaw/OpenClaw项目架构分析.md`
2. **示例插件**：
   - `extensions/xiaoli-chat`
   - `extensions/kimi-claw`
   - `extensions/qqbot`

### 基本结构

```typescript
// my-tool-plugin/src/index.ts
export default {
  id: "my-tool",
  name: "My Tool Plugin",
  version: "1.0.0",

  tools: (context) => {
    return [{
      name: "my_tool",
      description: "我的自定义工具",
      parameters: { /* JSON Schema */ },
      execute: async (toolCallId, args) => {
        // 工具逻辑
        return { type: "text", text: "结果" };
      }
    }];
  }
};
```

---

## 🚀 下一步

1. **启用插件**：
   ```bash
   openclaw config set plugins.allow '["xiaoli-chat", "kimi-claw", "qqbot"]'
   ```

2. **启动网关**：
   ```bash
   openclaw gateway --verbose
   ```

3. **测试工具**：
   ```bash
   openclaw agent --message "你有哪些工具可以使用？" --local
   ```

4. **开发新工具**：
   参考文档中的"开发自定义工具插件"章节

---

**文档更新时间**：2026-04-03
