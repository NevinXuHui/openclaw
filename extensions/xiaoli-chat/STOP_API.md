# Xiaoli Chat 停止接口文档

## 概述

xiaoli-chat 插件提供了会话管理接口，允许通过 HTTP API 停止正在进行的对话会话。

## 端点

### 基础路径
```
http://localhost:18789/hooks/xiaoli-chat/stop
```

## API 接口

### 1. 列出活跃会话

**请求：**
```bash
GET /hooks/xiaoli-chat/stop
```

**响应示例：**
```json
{
  "ok": true,
  "count": 2,
  "sessions": [
    {
      "chatId": "user123",
      "sessionKey": "xiaoli-chat:user123:user123"
    },
    {
      "chatId": "user456",
      "sessionKey": "xiaoli-chat:user456:user456"
    }
  ]
}
```

### 2. 停止特定会话

**请求：**
```bash
DELETE /hooks/xiaoli-chat/stop?chatId=user123
```

**参数：**
- `chatId` (必需): 要停止的聊天 ID

**成功响应：**
```json
{
  "ok": true,
  "stopped": true,
  "chatId": "user123",
  "sessionKey": "xiaoli-chat:user123:user123",
  "message": "Session for chat user123 has been unregistered"
}
```

**失败响应（会话不存在）：**
```json
{
  "ok": false,
  "stopped": false,
  "chatId": "user123",
  "error": "No active session found for chat user123"
}
```

## 使用示例

### 使用 curl

**列出活跃会话：**
```bash
curl http://localhost:18789/hooks/xiaoli-chat/stop
```

**停止特定会话：**
```bash
curl -X DELETE "http://localhost:18789/hooks/xiaoli-chat/stop?chatId=user123"
```

### 使用 JavaScript/TypeScript

```typescript
// 列出活跃会话
async function listActiveSessions() {
  const response = await fetch('http://localhost:18789/hooks/xiaoli-chat/stop');
  const data = await response.json();
  console.log('Active sessions:', data.sessions);
  return data;
}

// 停止特定会话
async function stopSession(chatId: string) {
  const response = await fetch(
    `http://localhost:18789/hooks/xiaoli-chat/stop?chatId=${chatId}`,
    { method: 'DELETE' }
  );
  const data = await response.json();
  console.log('Stop result:', data);
  return data;
}

// 使用示例
await listActiveSessions();
await stopSession('user123');
```

### 使用 Python

```python
import requests

# 列出活跃会话
def list_active_sessions():
    response = requests.get('http://localhost:18789/hooks/xiaoli-chat/stop')
    data = response.json()
    print('Active sessions:', data['sessions'])
    return data

# 停止特定会话
def stop_session(chat_id):
    response = requests.delete(
        f'http://localhost:18789/hooks/xiaoli-chat/stop?chatId={chat_id}'
    )
    data = response.json()
    print('Stop result:', data)
    return data

# 使用示例
list_active_sessions()
stop_session('user123')
```

## 工作原理

1. **会话注册**：当用户发送消息时，插件会自动注册 `chatId -> sessionKey` 的映射
2. **会话追踪**：所有活跃的会话都保存在内存映射表中
3. **会话停止**：调用停止接口时，会从映射表中移除对应的会话记录
4. **自动清理**：会话完成后会自动从映射表中清理

## 注意事项

1. **会话映射是内存存储**：重启 OpenClaw Gateway 后会话映射会丢失
2. **仅移除映射**：当前实现只是从本地映射中移除会话记录，不会强制中断正在进行的 AI 处理
3. **需要 Gateway 运行**：确保 OpenClaw Gateway 正在运行且监听在正确的端口
4. **认证**：接口使用 `plugin` 级别的认证，确保请求来自可信来源

## 错误码

| 状态码 | 说明 |
|--------|------|
| 200 | 成功 |
| 400 | 请求参数错误 |
| 404 | 会话不存在 |
| 405 | 方法不允许 |
| 500 | 服务器内部错误 |

## 未来改进

计划中的功能增强：

1. **强制中断**：集成 OpenClaw 的会话中断 API，真正停止正在进行的 AI 处理
2. **持久化存储**：将会话映射持久化到数据库或文件
3. **批量操作**：支持一次停止多个会话
4. **会话统计**：提供会话持续时间、消息数量等统计信息
5. **WebSocket 通知**：实时推送会话状态变化

## 相关文件

- `extensions/xiaoli-chat/src/stop.ts` - 停止接口实现
- `extensions/xiaoli-chat/src/inbound-runtime.ts` - 会话注册逻辑
- `extensions/xiaoli-chat/index.ts` - 路由注册
