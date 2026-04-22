import type { IncomingMessage, ServerResponse } from "node:http";
import type { PluginRuntime } from "openclaw/plugin-sdk/core";

type StopLogger = {
  info?: (message: string) => void;
  warn?: (message: string) => void;
  error?: (message: string) => void;
};

// 维护 chatId -> sessionKey 的映射
const chatSessionMap = new Map<string, string>();

export function registerChatSession(chatId: string, sessionKey: string): void {
  chatSessionMap.set(chatId, sessionKey);
}

export function unregisterChatSession(chatId: string): void {
  chatSessionMap.delete(chatId);
}

export function getChatSessionKey(chatId: string): string | undefined {
  return chatSessionMap.get(chatId);
}

function sendJson(res: ServerResponse, statusCode: number, body: Record<string, unknown>): void {
  res.statusCode = statusCode;
  res.setHeader("content-type", "application/json; charset=utf-8");
  res.end(JSON.stringify(body));
}

function parseRequestUrl(rawUrl?: string): URL | null {
  if (!rawUrl) {
    return null;
  }

  try {
    return new URL(rawUrl, "http://127.0.0.1");
  } catch {
    return null;
  }
}

/**
 * 停止正在进行的会话
 *
 * 支持两种方式：
 * 1. 通过 chatId 停止: DELETE /hooks/xiaoli-chat/stop?chatId=xxx
 * 2. 列出活跃会话: GET /hooks/xiaoli-chat/stop
 */
export function createXiaoliStopHandler(params: {
  runtime: PluginRuntime;
  logger?: StopLogger;
}) {
  return async (req: IncomingMessage, res: ServerResponse): Promise<boolean> => {
    const url = parseRequestUrl(req.url);
    if (!url || !url.pathname.startsWith("/hooks/xiaoli-chat/stop")) {
      return false;
    }

    // GET 请求：列出活跃会话
    if (req.method === "GET") {
      const sessions = Array.from(chatSessionMap.entries()).map(([chatId, sessionKey]) => ({
        chatId,
        sessionKey,
      }));

      sendJson(res, 200, {
        ok: true,
        count: sessions.length,
        sessions,
      });
      return true;
    }

    // DELETE 请求：停止会话
    if (req.method !== "DELETE") {
      sendJson(res, 405, {
        ok: false,
        error: "Method not allowed. Use DELETE to stop sessions or GET to list active sessions.",
      });
      return true;
    }

    const chatId = url.searchParams.get("chatId");

    if (!chatId) {
      sendJson(res, 400, {
        ok: false,
        error: "Missing required parameter: chatId",
      });
      return true;
    }

    try {
      const sessionKey = getChatSessionKey(chatId);
      
      if (!sessionKey) {
        sendJson(res, 404, {
          ok: false,
          stopped: false,
          chatId,
          error: `No active session found for chat ${chatId}`,
        });
        return true;
      }

      params.logger?.info?.(`xiaoli-chat: stopping session for chat ${chatId} (sessionKey: ${sessionKey})`);
      
      // 从映射中移除
      unregisterChatSession(chatId);
      
      // 注意：实际的会话停止需要通过 OpenClaw Gateway API 或其他机制实现
      // 这里我们只是从本地映射中移除，表示不再接受该 chat 的新消息
      
      sendJson(res, 200, {
        ok: true,
        stopped: true,
        chatId,
        sessionKey,
        message: `Session for chat ${chatId} has been unregistered`,
      });
      return true;
    } catch (error) {
      params.logger?.error?.(
        `xiaoli-chat stop handler failed: ${String(error)}`,
      );
      sendJson(res, 500, {
        ok: false,
        error: "Failed to stop session",
      });
      return true;
    }
  };
}
