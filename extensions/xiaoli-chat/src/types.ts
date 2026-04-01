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

export type XiaoliInboundMessage = {
  senderId: string;
  chatId: string;
  messageId: string;
  text: string;
  threadId?: string;
  isDirectMessage: boolean;
};

export type XiaoliSendMessageParams = {
  chatId: string;
  text: string;
  threadId?: string;
};
