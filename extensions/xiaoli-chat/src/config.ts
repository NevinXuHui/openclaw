import type { OpenClawConfig } from "openclaw/plugin-sdk/core";
import type {
  ResolvedXiaoliAccount,
  XiaoliChatConfig,
  XiaoliDmSecurityPolicy,
  XiaoliWebhookSecurityConfig,
} from "./types.js";

const DEFAULT_BASE_URL = "https://api.example.com";
const DEFAULT_DM_SECURITY_POLICY: XiaoliDmSecurityPolicy = "allowlist";

function readChannelConfig(cfg: OpenClawConfig): XiaoliChatConfig | undefined {
  const channels = cfg.channels as Record<string, unknown> | undefined;
  return channels?.["xiaoli-chat"] as XiaoliChatConfig | undefined;
}

export function resolveXiaoliAccount(
  cfg: OpenClawConfig,
  accountId?: string | null,
): ResolvedXiaoliAccount {
  const section = readChannelConfig(cfg);

  if (!section?.token) {
    throw new Error("xiaoli-chat: token is required");
  }

  return {
    accountId: accountId ?? null,
    enabled: section.enabled !== false,
    token: section.token,
    baseUrl: section.baseUrl ?? DEFAULT_BASE_URL,
    allowFrom: section.allowFrom ?? [],
    dmSecurity: section.dmSecurity ?? DEFAULT_DM_SECURITY_POLICY,
  };
}

export function resolveXiaoliWebhookSecurity(
  cfg: OpenClawConfig,
): XiaoliWebhookSecurityConfig | null {
  const secret = readChannelConfig(cfg)?.webhookSecret?.trim();
  if (!secret) {
    return null;
  }
  return { secret };
}

export function inspectXiaoliAccount(cfg: OpenClawConfig, accountId?: string | null) {
  try {
    const account = resolveXiaoliAccount(cfg, accountId);
    return {
      enabled: account.enabled,
      configured: Boolean(account.token),
      tokenStatus: account.token ? "available" : "missing",
    };
  } catch {
    return {
      enabled: false,
      configured: false,
      tokenStatus: "missing",
    };
  }
}
