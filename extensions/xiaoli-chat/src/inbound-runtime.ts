import { dispatchInboundDirectDmWithRuntime } from "openclaw/plugin-sdk/channel-inbound";
import {
  DEFAULT_ACCOUNT_ID,
  type OpenClawConfig,
  type PluginRuntime,
} from "openclaw/plugin-sdk/core";
import { resolveXiaoliAccount } from "./config.js";
import { sendText } from "./outbound.js";
import type { XiaoliInboundMessage } from "./types.js";

type XiaoliInboundLogger = {
  info?: (message: string) => void;
  error?: (message: string) => void;
};

function extractReplyText(payload: unknown): string {
  if (typeof payload === "string") {
    return payload;
  }
  if (payload && typeof payload === "object" && "text" in payload) {
    return String((payload as { text?: unknown }).text ?? "");
  }
  return "";
}

export async function handleXiaoliInboundMessage(params: {
  runtime: PluginRuntime;
  message: XiaoliInboundMessage;
  logger?: XiaoliInboundLogger;
}): Promise<void> {
  const { message, runtime } = params;

  if (!message.isDirectMessage) {
    params.logger?.info?.(
      `xiaoli-chat inbound group message is not wired into the reply pipeline yet: ${message.messageId}`,
    );
    return;
  }

  const cfg = runtime.config.loadConfig() as OpenClawConfig;
  const accountId = DEFAULT_ACCOUNT_ID;
  const account = resolveXiaoliAccount(cfg, accountId);

  await dispatchInboundDirectDmWithRuntime({
    cfg,
    runtime,
    channel: "xiaoli-chat",
    channelLabel: "Xiaoli Chat",
    accountId,
    peer: {
      kind: "direct",
      id: message.senderId,
    },
    senderId: message.senderId,
    senderAddress: `xiaoli-chat:${message.senderId}`,
    recipientAddress: `xiaoli-chat:${message.chatId}`,
    conversationLabel: message.senderId,
    rawBody: message.text,
    messageId: message.messageId,
    bodyForAgent: message.text,
    commandBody: message.text,
    extraContext: message.threadId ? { ThreadId: message.threadId } : undefined,
    deliver: async (payload) => {
      const replyText = extractReplyText(payload);
      if (!replyText.trim()) {
        return;
      }
      await sendText({
        account,
        chatId: message.chatId,
        text: replyText,
        threadId: message.threadId,
      });
    },
    onRecordError: (error) => {
      params.logger?.error?.(`xiaoli-chat failed to record inbound session: ${String(error)}`);
    },
    onDispatchError: (error, info) => {
      params.logger?.error?.(`xiaoli-chat ${info.kind} reply failed: ${String(error)}`);
    },
  });
}
