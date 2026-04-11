import type { XiaoliInboundMessage, XiaoliMediaAttachment } from "./types.js";

function readOptionalString(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed ? trimmed : undefined;
}

function normalizeMediaAttachments(value: unknown): XiaoliMediaAttachment[] | undefined {
  if (!Array.isArray(value)) {
    return undefined;
  }
  const attachments: XiaoliMediaAttachment[] = [];
  for (const item of value) {
    if (item && typeof item === "object") {
      const entry = item as Record<string, unknown>;
      const url = typeof entry.url === "string" ? entry.url.trim() : "";
      if (!url) {
        continue;
      }
      attachments.push({
        url,
        type: readOptionalString(entry.type),
        name: readOptionalString(entry.name),
      });
    }
  }
  return attachments.length > 0 ? attachments : undefined;
}

export function normalizeInboundMessage(payload: unknown): XiaoliInboundMessage {
  const data = payload as Record<string, unknown>;

  const senderId = typeof data.senderId === "string" ? data.senderId : "";
  const chatId = typeof data.chatId === "string" ? data.chatId : "";
  const messageId = typeof data.messageId === "string" ? data.messageId : "";
  const text = typeof data.text === "string" ? data.text : "";

  return {
    senderId,
    chatId,
    messageId,
    text,
    threadId: readOptionalString(data.threadId),
    isDirectMessage: Boolean(data.isDirectMessage),
    thinking: readOptionalString(data.thinking),
    media: normalizeMediaAttachments(data.media),
  };
}

export function isValidInboundMessage(message: XiaoliInboundMessage): boolean {
  const hasText = Boolean(message.text.trim());
  const hasMedia = Boolean(message.media && message.media.length > 0);
  return Boolean(
    message.senderId.trim() &&
    message.chatId.trim() &&
    message.messageId.trim() &&
    (hasText || hasMedia),
  );
}
