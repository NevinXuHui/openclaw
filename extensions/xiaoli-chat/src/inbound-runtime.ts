import { dispatchInboundDirectDmWithRuntime } from "openclaw/plugin-sdk/channel-inbound";
import type { OpenClawConfig, PluginRuntime } from "openclaw/plugin-sdk/core";
import {
  type OutboundReplyPayload,
  resolveSendableOutboundReplyParts,
} from "openclaw/plugin-sdk/reply-payload";
import { resolveXiaoliAccount } from "./config.js";
import { sendMedia, sendText } from "./outbound.js";
import { registerChatSession } from "./stop.js";
import type { XiaoliInboundMessage, XiaoliMediaAttachment } from "./types.js";

type XiaoliInboundLogger = {
  info?: (message: string) => void;
  error?: (message: string) => void;
};

function buildMediaContext(
  media: XiaoliMediaAttachment[] | undefined,
): Record<string, unknown> | undefined {
  if (!media || media.length === 0) {
    return undefined;
  }
  const urls = media.map((m) => m.url);
  const types = media.map((m) => m.type).filter(Boolean) as string[];
  return {
    MediaUrl: urls[0],
    MediaPath: urls[0],
    MediaUrls: urls,
    MediaPaths: urls,
    ...(types.length > 0 ? { MediaType: types[0], MediaTypes: types } : {}),
  };
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
  const accountId = "default";
  const account = resolveXiaoliAccount(cfg, accountId);

  // 构建 sessionKey 用于会话管理
  const sessionKey = `xiaoli-chat:${message.chatId}:${message.senderId}`;

  const mediaContext = buildMediaContext(message.media);
  const bodyForAgent = message.text.trim()
    ? message.text
    : message.media?.length
      ? message.media.map((m) => `[${m.type ?? "file"}: ${m.name ?? m.url}]`).join(" ")
      : message.text;

  console.log(`[xiaoli-chat] Received message:`, {
    messageId: message.messageId,
    senderId: message.senderId,
    chatId: message.chatId,
    text: message.text,
    bodyForAgent,
    hasMedia: !!message.media?.length,
  });

  // Create deliver function
  const deliver = async (payload: OutboundReplyPayload): Promise<void> => {
    const deliverTime = Date.now();
    const reply = resolveSendableOutboundReplyParts(payload);

    console.log(
      `[xiaoli-chat] [${deliverTime}] deliver called, hasContent=${reply.hasContent}, text="${reply.text.substring(0, 50)}"`,
    );

    if (!reply.hasContent) {
      return;
    }

    if (reply.hasMedia) {
      for (const [index, mediaUrl] of reply.mediaUrls.entries()) {
        const sendTime = Date.now();
        console.log(`[xiaoli-chat] [${sendTime}] sending media ${index}`);
        await sendMedia({
          account,
          chatId: message.chatId,
          text: index === 0 ? reply.text : "",
          mediaUrl,
          threadId: message.threadId,
        }).catch((error) => {
          params.logger?.error?.(`xiaoli-chat media send failed: ${String(error)}`);
        });
      }
      return;
    }

    const sendTime = Date.now();
    console.log(`[xiaoli-chat] [${sendTime}] sending text, starting fetch`);
    await sendText({
      account,
      chatId: message.chatId,
      text: reply.text,
      threadId: message.threadId,
    }).catch((error) => {
      params.logger?.error?.(`xiaoli-chat text send failed: ${String(error)}`);
    });

    const returnTime = Date.now();
    console.log(
      `[xiaoli-chat] [${returnTime}] deliver completed, took ${returnTime - deliverTime}ms`,
    );
  };

  // 注册会话映射
  registerChatSession(message.chatId, sessionKey);

  // Use standard dispatch flow with runtime
  await dispatchInboundDirectDmWithRuntime({
    cfg,
    runtime,
    channel: "xiaoli-chat",
    channelLabel: "xiaoli-chat",
    accountId,
    peer: { kind: "direct", id: message.senderId },
    senderId: message.senderId,
    senderAddress: `xiaoli-chat:${message.senderId}`,
    recipientAddress: `xiaoli-chat:${message.chatId}`,
    conversationLabel: message.senderId,
    rawBody: message.text,
    messageId: message.messageId,
    bodyForAgent,
    commandBody: message.text,
    provider: "xiaoli-chat",
    surface: "xiaoli-chat",
    originatingChannel: "xiaoli-chat",
    originatingTo: message.chatId,
    extraContext: {
      ...(message.threadId ? { ThreadId: message.threadId } : {}),
      ...(message.thinking ? { thinking: message.thinking } : {}),
      ...mediaContext,
    },
    deliver,
    onRecordError: (error: unknown) => {
      params.logger?.error?.(`xiaoli-chat failed to record inbound session: ${String(error)}`);
    },
    onDispatchError: (error: unknown, info: { kind: string }) => {
      params.logger?.error?.(`xiaoli-chat ${info.kind} reply failed: ${String(error)}`);
    },
  });
}
