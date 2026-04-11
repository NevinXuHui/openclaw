export type XiaoliDmSecurityPolicy = "open" | "allowlist";

export type XiaoliChatConfig = {
  enabled?: boolean;
  token?: string;
  baseUrl?: string;
  allowFrom?: string[];
  dmSecurity?: XiaoliDmSecurityPolicy;
  webhookSecret?: string;
};

export type ResolvedXiaoliAccount = {
  accountId: string | null;
  enabled: boolean;
  token: string;
  baseUrl: string;
  allowFrom: string[];
  dmSecurity: XiaoliDmSecurityPolicy;
};

export type XiaoliWebhookSecurityConfig = {
  secret: string;
};

export type XiaoliMediaAttachment = {
  url: string;
  type?: string; // MIME type, e.g. "image/png", "application/pdf"
  name?: string; // Original file name
};

export type XiaoliInboundMessage = {
  senderId: string;
  chatId: string;
  messageId: string;
  text: string;
  threadId?: string;
  isDirectMessage: boolean;
  thinking?: string; // 思考模式: "off" | "low" | "medium" | "high" | "xhigh"
  media?: XiaoliMediaAttachment[];
};

export type XiaoliSendMessageParams = {
  chatId: string;
  text: string;
  threadId?: string;
  mediaUrl?: string;
  mediaType?: string;
};
