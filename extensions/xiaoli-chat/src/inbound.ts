import type { XiaoliInboundMessage } from "./types.js";

function readOptionalString(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed ? trimmed : undefined;
}

export function normalizeInboundMessage(payload: unknown): XiaoliInboundMessage {
  const data = payload as Record<string, unknown>;

  return {
    senderId: String(data.senderId ?? ""),
    chatId: String(data.chatId ?? ""),
    messageId: String(data.messageId ?? ""),
    text: String(data.text ?? ""),
    threadId: readOptionalString(data.threadId),
    isDirectMessage: Boolean(data.isDirectMessage),
  };
}

export function isValidInboundMessage(message: XiaoliInboundMessage): boolean {
  return Boolean(
    message.senderId.trim() &&
    message.chatId.trim() &&
    message.messageId.trim() &&
    message.text.trim(),
  );
}
