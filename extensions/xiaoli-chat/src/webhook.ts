import crypto from "node:crypto";
import type { IncomingMessage, ServerResponse } from "node:http";
import type { OpenClawConfig } from "openclaw/plugin-sdk/core";
import {
  applyBasicWebhookRequestGuards,
  createFixedWindowRateLimiter,
  readWebhookBodyOrReject,
  resolveRequestClientIp,
  WEBHOOK_RATE_LIMIT_DEFAULTS,
} from "openclaw/plugin-sdk/webhook-ingress";
import { resolveXiaoliWebhookSecurity } from "./config.js";
import { handleXiaoliInboundMessage } from "./inbound-runtime.js";
import { isValidInboundMessage, normalizeInboundMessage } from "./inbound.js";
import { tryGetXiaoliRuntime } from "./runtime.js";

type XiaoliWebhookLogger = {
  info?: (message: string) => void;
  warn?: (message: string) => void;
  error?: (message: string) => void;
};

export const XIAOLI_WEBHOOK_PATH = "/hooks/xiaoli-chat/webhook";
const XIAOLI_SIGNATURE_HEADER = "x-xiaoli-signature";
const TIMING_SAFE_COMPARE_KEY = "openclaw-xiaoli-webhook-compare";
const webhookRateLimiter = createFixedWindowRateLimiter(WEBHOOK_RATE_LIMIT_DEFAULTS);

function sendJson(res: ServerResponse, statusCode: number, body: Record<string, unknown>): true {
  res.statusCode = statusCode;
  res.setHeader("content-type", "application/json; charset=utf-8");
  res.end(JSON.stringify(body));
  return true;
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

function timingSafeEqualString(left: string, right: string): boolean {
  const leftDigest = crypto.createHmac("sha256", TIMING_SAFE_COMPARE_KEY).update(left).digest();
  const rightDigest = crypto.createHmac("sha256", TIMING_SAFE_COMPARE_KEY).update(right).digest();
  return crypto.timingSafeEqual(leftDigest, rightDigest);
}

function extractWebhookSignature(headers: IncomingMessage["headers"]): string | null {
  const headerValue = headers[XIAOLI_SIGNATURE_HEADER];
  const signature = Array.isArray(headerValue) ? headerValue[0] : headerValue;
  if (typeof signature !== "string") {
    return null;
  }
  const trimmed = signature.trim();
  if (!trimmed) {
    return null;
  }
  return trimmed.startsWith("sha256=") ? trimmed.slice("sha256=".length) : trimmed;
}

function isXiaoliWebhookSignatureValid(params: {
  headers: IncomingMessage["headers"];
  rawBody: string;
  secret: string;
}): boolean {
  const signature = extractWebhookSignature(params.headers);
  if (!signature) {
    return false;
  }

  const expectedSignature = crypto
    .createHmac("sha256", params.secret)
    .update(params.rawBody)
    .digest("hex");
  return timingSafeEqualString(expectedSignature, signature);
}

function parseJsonBody(rawBody: string): unknown {
  const trimmedBody = rawBody.trim();
  if (!trimmedBody) {
    return {};
  }
  return JSON.parse(trimmedBody) as unknown;
}

function resolveWebhookRateLimitKey(req: IncomingMessage): string {
  const clientIp = resolveRequestClientIp(req, [], false) ?? req.socket.remoteAddress ?? "unknown";
  return `${XIAOLI_WEBHOOK_PATH}:${clientIp}`;
}

export function createXiaoliWebhookHandler(params: { logger?: XiaoliWebhookLogger }) {
  return async (req: IncomingMessage, res: ServerResponse): Promise<boolean> => {
    const url = parseRequestUrl(req.url);
    if (!url || url.pathname !== XIAOLI_WEBHOOK_PATH) {
      return false;
    }

    if (req.method === "GET") {
      return sendJson(res, 200, {
        ok: true,
        channel: "xiaoli-chat",
        webhook: "ready",
        path: XIAOLI_WEBHOOK_PATH,
      });
    }

    if (
      !applyBasicWebhookRequestGuards({
        req,
        res,
        allowMethods: ["POST"],
        requireJsonContentType: true,
        rateLimiter: webhookRateLimiter,
        rateLimitKey: resolveWebhookRateLimitKey(req),
      })
    ) {
      return true;
    }

    const runtime = tryGetXiaoliRuntime();
    if (!runtime) {
      params.logger?.error?.(
        "xiaoli-chat webhook received inbound message before runtime initialization",
      );
      return sendJson(res, 503, {
        ok: false,
        error: "Xiaoli Chat runtime is not initialized",
      });
    }

    const webhookSecurity = resolveXiaoliWebhookSecurity(
      runtime.config.loadConfig() as OpenClawConfig,
    );
    if (!webhookSecurity) {
      params.logger?.error?.("xiaoli-chat webhook secret is not configured");
      return sendJson(res, 503, {
        ok: false,
        error: "Webhook secret is not configured",
      });
    }

    const body = await readWebhookBodyOrReject({
      req,
      res,
      profile: "pre-auth",
      invalidBodyMessage: "Invalid JSON body",
    });
    if (!body.ok) {
      return true;
    }

    if (
      !isXiaoliWebhookSignatureValid({
        headers: req.headers,
        rawBody: body.value,
        secret: webhookSecurity.secret,
      })
    ) {
      params.logger?.warn?.("xiaoli-chat webhook rejected request with invalid signature");
      return sendJson(res, 401, {
        ok: false,
        error: "Invalid signature",
      });
    }

    let payload: unknown;
    try {
      payload = parseJsonBody(body.value);
    } catch (error) {
      params.logger?.warn?.(`xiaoli-chat webhook received invalid JSON: ${String(error)}`);
      return sendJson(res, 400, {
        ok: false,
        error: "Invalid JSON body",
      });
    }

    const message = normalizeInboundMessage(payload);
    if (!isValidInboundMessage(message)) {
      return sendJson(res, 400, {
        ok: false,
        error: "Missing required inbound message fields",
      });
    }

    try {
      await handleXiaoliInboundMessage({
        runtime,
        message,
        logger: params.logger,
      });

      return sendJson(res, 202, {
        ok: true,
        accepted: true,
        messageId: message.messageId,
      });
    } catch (error) {
      params.logger?.error?.(`xiaoli-chat webhook handling failed: ${String(error)}`);
      return sendJson(res, 500, {
        ok: false,
        error: "Failed to process inbound message",
      });
    }
  };
}
