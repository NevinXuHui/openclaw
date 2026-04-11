import { beforeEach, describe, expect, it, vi } from "vitest";

const dispatchInboundDirectDmWithRuntime = vi.hoisted(() =>
  vi.fn<(params: { deliver: (payload: unknown) => Promise<void> }) => Promise<void>>(
    async () => {},
  ),
);
const sendText = vi.hoisted(() => vi.fn(async () => ({ messageId: "text-1" })));
const sendMedia = vi.hoisted(() => vi.fn(async () => ({ messageId: "media-1" })));

vi.mock("openclaw/plugin-sdk/channel-inbound", () => ({
  dispatchInboundDirectDmWithRuntime,
}));

vi.mock("./outbound.js", () => ({
  sendText,
  sendMedia,
}));

import { handleXiaoliInboundMessage } from "./inbound-runtime.js";

function getDispatchDeliver() {
  expect(dispatchInboundDirectDmWithRuntime).toHaveBeenCalled();
  const firstCall = dispatchInboundDirectDmWithRuntime.mock.calls[0];
  const args = firstCall[0];
  return args.deliver;
}

function createRuntime() {
  return {
    config: {
      loadConfig: () => ({
        channels: {
          "xiaoli-chat": {
            token: "test-token",
          },
        },
      }),
    },
  } as never;
}

function createMessage() {
  return {
    senderId: "user-1",
    chatId: "chat-1",
    messageId: "msg-1",
    text: "hello",
    isDirectMessage: true,
    threadId: "thread-1",
  };
}

describe("xiaoli inbound runtime", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("skips non-DM inbound messages", async () => {
    const logger = { info: vi.fn() };

    await handleXiaoliInboundMessage({
      runtime: createRuntime(),
      message: {
        ...createMessage(),
        isDirectMessage: false,
      },
      logger,
    });

    expect(dispatchInboundDirectDmWithRuntime).not.toHaveBeenCalled();
    expect(logger.info).toHaveBeenCalledWith(
      expect.stringContaining("inbound group message is not wired into the reply pipeline yet"),
    );
  });

  it("delivers text payloads", async () => {
    await handleXiaoliInboundMessage({
      runtime: createRuntime(),
      message: createMessage(),
    });

    const deliver = getDispatchDeliver();
    await deliver({ text: "tool result text" });

    expect(sendText).toHaveBeenCalledWith(
      expect.objectContaining({
        chatId: "chat-1",
        text: "tool result text",
        threadId: "thread-1",
      }),
    );
    expect(sendMedia).not.toHaveBeenCalled();
  });

  it("delivers media payloads with leading caption", async () => {
    await handleXiaoliInboundMessage({
      runtime: createRuntime(),
      message: createMessage(),
    });

    const deliver = getDispatchDeliver();
    await deliver({
      text: "tool media caption",
      mediaUrls: ["https://example.com/a.png", "https://example.com/b.png"],
    });

    expect(sendMedia).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining({
        chatId: "chat-1",
        text: "tool media caption",
        mediaUrl: "https://example.com/a.png",
        threadId: "thread-1",
      }),
    );
    expect(sendMedia).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        chatId: "chat-1",
        text: "",
        mediaUrl: "https://example.com/b.png",
        threadId: "thread-1",
      }),
    );
    expect(sendText).not.toHaveBeenCalled();
  });

  it("ignores empty payloads", async () => {
    await handleXiaoliInboundMessage({
      runtime: createRuntime(),
      message: createMessage(),
    });

    const deliver = getDispatchDeliver();
    await deliver({ text: "   " });

    expect(sendText).not.toHaveBeenCalled();
    expect(sendMedia).not.toHaveBeenCalled();
  });
});
