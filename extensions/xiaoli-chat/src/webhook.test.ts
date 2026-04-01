import crypto from "node:crypto";
import type { IncomingMessage, ServerResponse } from "node:http";
import { beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import { createMockIncomingRequest } from "../../../test/helpers/mock-incoming-request.js";

const readWebhookBodyOrReject = vi.hoisted(() => vi.fn());
const resolveRequestClientIp = vi.hoisted(() => vi.fn(() => null));
const handleXiaoliInboundMessage = vi.hoisted(() => vi.fn());

vi.mock("openclaw/plugin-sdk/webhook-ingress", async () => {
  const actual = await vi.importActual<typeof import("openclaw/plugin-sdk/webhook-ingress")>(
    "openclaw/plugin-sdk/webhook-ingress",
  );
  return {
    ...actual,
    readWebhookBodyOrReject,
    resolveRequestClientIp,
  };
});

vi.mock("./inbound-runtime.js", () => ({
  handleXiaoliInboundMessage,
}));

let createXiaoliWebhookHandler: typeof import("./webhook.js").createXiaoliWebhookHandler;
let XIAOLI_WEBHOOK_PATH: typeof import("./webhook.js").XIAOLI_WEBHOOK_PATH;
let setXiaoliRuntime: typeof import("./runtime.js").setXiaoliRuntime;

const WEBHOOK_SECRET = "test-secret";
const VALID_BODY = JSON.stringify({
  senderId: "sender-1",
  chatId: "chat-1",
  messageId: "msg-1",
  text: "hello",
  isDirectMessage: true,
});

function createSignature(body: string): string {
  return crypto.createHmac("sha256", WEBHOOK_SECRET).update(body).digest("hex");
}

function createRequest(params?: {
  method?: string;
  url?: string;
  body?: string;
  signature?: string;
  remoteAddress?: string;
  contentType?: string;
}): IncomingMessage {
  const body = params?.body ?? VALID_BODY;
  const req = createMockIncomingRequest([body]);
  Object.assign(req, {
    method: params?.method ?? "POST",
    url: params?.url ?? XIAOLI_WEBHOOK_PATH,
    headers: {
      "content-type": params?.contentType ?? "application/json",
      "x-xiaoli-signature": params?.signature ?? createSignature(body),
    },
    socket: {
      remoteAddress: params?.remoteAddress ?? "203.0.113.10",
    },
  });
  return req;
}

function createResponse(): ServerResponse & { body: string; headers: Record<string, string> } {
  return {
    statusCode: 200,
    body: "",
    headers: {},
    setHeader(name: string, value: string) {
      this.headers[name.toLowerCase()] = value;
    },
    end(payload?: string | Buffer) {
      this.body = payload ? String(payload) : "";
      return this;
    },
  } as ServerResponse & { body: string; headers: Record<string, string> };
}

describe("xiaoli webhook", () => {
  beforeAll(async () => {
    ({ createXiaoliWebhookHandler, XIAOLI_WEBHOOK_PATH } = await import("./webhook.js"));
    ({ setXiaoliRuntime } = await import("./runtime.js"));
  });

  beforeEach(() => {
    vi.clearAllMocks();
    readWebhookBodyOrReject.mockResolvedValue({ ok: true, value: VALID_BODY });
    handleXiaoliInboundMessage.mockResolvedValue(undefined);
    resolveRequestClientIp.mockReturnValue(null);
    setXiaoliRuntime({
      config: {
        loadConfig: () => ({
          channels: {
            "xiaoli-chat": {
              webhookSecret: WEBHOOK_SECRET,
            },
          },
        }),
      },
    } as never);
  });

  it("returns webhook readiness on GET", async () => {
    const handler = createXiaoliWebhookHandler({});
    const res = createResponse();

    await expect(handler(createRequest({ method: "GET" }), res)).resolves.toBe(true);

    expect(res.statusCode).toBe(200);
    expect(JSON.parse(res.body)).toEqual({
      ok: true,
      channel: "xiaoli-chat",
      webhook: "ready",
      path: XIAOLI_WEBHOOK_PATH,
    });
    expect(readWebhookBodyOrReject).not.toHaveBeenCalled();
  });

  it("reads pre-auth body limits before validating signed payloads", async () => {
    const handler = createXiaoliWebhookHandler({});
    const res = createResponse();

    await expect(
      handler(createRequest({ body: VALID_BODY, remoteAddress: "203.0.113.11" }), res),
    ).resolves.toBe(true);

    expect(readWebhookBodyOrReject).toHaveBeenCalledWith(
      expect.objectContaining({
        profile: "pre-auth",
        invalidBodyMessage: "Invalid JSON body",
      }),
    );
    expect(handleXiaoliInboundMessage).toHaveBeenCalledWith(
      expect.objectContaining({
        message: expect.objectContaining({
          senderId: "sender-1",
          chatId: "chat-1",
          messageId: "msg-1",
          text: "hello",
          isDirectMessage: true,
        }),
      }),
    );
    expect(res.statusCode).toBe(202);
    expect(JSON.parse(res.body)).toEqual({
      ok: true,
      accepted: true,
      messageId: "msg-1",
    });
  });

  it("rejects invalid webhook signatures", async () => {
    const handler = createXiaoliWebhookHandler({});
    const res = createResponse();

    await expect(
      handler(
        createRequest({
          body: VALID_BODY,
          signature: "bad-signature",
          remoteAddress: "203.0.113.12",
        }),
        res,
      ),
    ).resolves.toBe(true);

    expect(handleXiaoliInboundMessage).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(401);
    expect(JSON.parse(res.body)).toEqual({
      ok: false,
      error: "Invalid signature",
    });
  });

  it("rate limits repeated requests from the same client IP", async () => {
    const handler = createXiaoliWebhookHandler({});
    const remoteAddress = "198.51.100.77";

    for (let index = 0; index < 120; index += 1) {
      const res = createResponse();
      await expect(handler(createRequest({ body: VALID_BODY, remoteAddress }), res)).resolves.toBe(
        true,
      );
      expect(res.statusCode).toBe(202);
    }

    const limitedResponse = createResponse();
    await expect(
      handler(createRequest({ body: VALID_BODY, remoteAddress }), limitedResponse),
    ).resolves.toBe(true);

    expect(limitedResponse.statusCode).toBe(429);
    expect(limitedResponse.body).toBe("Too Many Requests");
    expect(handleXiaoliInboundMessage).toHaveBeenCalledTimes(120);
  });
});
