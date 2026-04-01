import { DEFAULT_ACCOUNT_ID, createChatChannelPlugin } from "openclaw/plugin-sdk/core";
import type { OpenClawConfig } from "openclaw/plugin-sdk/core";
import { inspectXiaoliAccount, resolveXiaoliAccount } from "./config.js";
import { sendText } from "./outbound.js";
import type { ResolvedXiaoliAccount, XiaoliChatConfig } from "./types.js";

const xiaoliChannelMeta = {
  id: "xiaoli-chat",
  label: "Xiaoli Chat",
  selectionLabel: "Xiaoli Chat",
  docsPath: "/channels/xiaoli-chat",
  docsLabel: "xiaoli-chat",
  blurb: "Connect OpenClaw to Xiaoli Chat.",
  order: 50,
} as const;

function resolveAccount(cfg: OpenClawConfig, accountId?: string | null): ResolvedXiaoliAccount {
  return resolveXiaoliAccount(cfg, accountId);
}

function listAccountIds(): string[] {
  return [DEFAULT_ACCOUNT_ID];
}

function applyAccountConfig(params: {
  cfg: OpenClawConfig;
  input: { token?: string; url?: string };
}): OpenClawConfig {
  const channels = (params.cfg.channels as Record<string, unknown> | undefined) ?? {};
  const currentSection = (channels["xiaoli-chat"] as XiaoliChatConfig | undefined) ?? {};

  return {
    ...params.cfg,
    channels: {
      ...channels,
      "xiaoli-chat": {
        ...currentSection,
        enabled: true,
        ...(params.input.token ? { token: params.input.token } : {}),
        ...(params.input.url ? { baseUrl: params.input.url } : {}),
      },
    },
  };
}

export const xiaoliChatPlugin = createChatChannelPlugin<ResolvedXiaoliAccount>({
  base: {
    id: "xiaoli-chat",
    meta: xiaoliChannelMeta,
    capabilities: {
      chatTypes: ["direct", "group", "thread"],
      media: false,
      reactions: false,
      threads: true,
      edit: false,
      unsend: false,
      reply: true,
      effects: false,
      nativeCommands: false,
      blockStreaming: false,
    },
    config: {
      listAccountIds,
      resolveAccount,
      inspectAccount: inspectXiaoliAccount,
      defaultAccountId: () => DEFAULT_ACCOUNT_ID,
    },
    setup: {
      resolveAccountId: () => DEFAULT_ACCOUNT_ID,
      applyAccountConfig: ({ cfg, input }) =>
        applyAccountConfig({
          cfg,
          input: {
            token: input.token,
            url: input.url,
          },
        }),
    },
  },

  security: {
    dm: {
      channelKey: "xiaoli-chat",
      resolvePolicy: (account) => account.dmSecurity,
      resolveAllowFrom: (account) => account.allowFrom,
      defaultPolicy: "allowlist",
    },
  },

  pairing: {
    text: {
      idLabel: "Xiaoli Chat user id",
      message: "Send this code to verify your identity:",
      notify: async ({ cfg, id, message, accountId }) => {
        const account = resolveXiaoliAccount(cfg, accountId);
        await sendText({
          account,
          chatId: id,
          text: message,
        });
      },
    },
  },

  threading: {
    topLevelReplyToMode: "reply",
  },

  outbound: {
    base: {
      deliveryMode: "direct",
    },
    attachedResults: {
      channel: "xiaoli-chat",
      sendText: async (params) => {
        const result = await sendText({
          account: resolveXiaoliAccount(params.cfg, params.accountId),
          chatId: params.to,
          text: params.text,
          threadId: params.threadId == null ? undefined : String(params.threadId),
        });
        return { messageId: result.messageId };
      },
    },
  },
});
