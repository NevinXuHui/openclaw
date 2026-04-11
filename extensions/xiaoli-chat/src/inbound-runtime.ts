import { dispatchInboundDirectDmWithRuntime } from "openclaw/plugin-sdk/channel-inbound";
import {
  DEFAULT_ACCOUNT_ID,
  type OpenClawConfig,
  type PluginRuntime,
} from "openclaw/plugin-sdk/core";
import {
  type OutboundReplyPayload,
  resolveSendableOutboundReplyParts,
} from "openclaw/plugin-sdk/reply-payload";
import { resolveXiaoliAccount } from "./config.js";
import { sendMedia, sendText } from "./outbound.js";
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
  const accountId = DEFAULT_ACCOUNT_ID;
  const account = resolveXiaoliAccount(cfg, accountId);

  const mediaContext = buildMediaContext(message.media);
  const bodyForAgent = message.text.trim()
    ? message.text
    : message.media?.length
      ? message.media.map((m) => `[${m.type ?? "file"}: ${m.name ?? m.url}]`).join(" ")
      : message.text;

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
    bodyForAgent,
    commandBody: message.text,
    extraContext: {
      ...(message.threadId ? { ThreadId: message.threadId } : {}),
      ...mediaContext,
      ...(message.thinking ? { thinking: message.thinking } : {}),
    },
    deliver: async (payload: OutboundReplyPayload) => {
      const reply = resolveSendableOutboundReplyParts(payload);
      if (!reply.hasContent) {
        return;
      }

      if (reply.hasMedia) {
        for (const [index, mediaUrl] of reply.mediaUrls.entries()) {
          await sendMedia({
            account,
            chatId: message.chatId,
            text: index === 0 ? reply.text : "",
            mediaUrl,
            threadId: message.threadId,
          });
        }
        return;
      }

      await sendText({
        account,
        chatId: message.chatId,
        text: reply.text,
        threadId: message.threadId,
      });
    },
    onRecordError: (error: unknown) => {
      params.logger?.error?.(`xiaoli-chat failed to record inbound session: ${String(error)}`);
    },
    onDispatchError: (error: unknown, info: { kind: string }) => {
      params.logger?.error?.(`xiaoli-chat ${info.kind} reply failed: ${String(error)}`);
    },
  });
}
