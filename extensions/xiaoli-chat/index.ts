import { defineChannelPluginEntry } from "openclaw/plugin-sdk/core";
import { xiaoliChatPlugin } from "./src/channel.js";
import { setXiaoliRuntime } from "./src/runtime.js";
import { createXiaoliWebhookHandler, XIAOLI_WEBHOOK_PATH } from "./src/webhook.js";

export default defineChannelPluginEntry({
  id: "xiaoli-chat",
  name: "Xiaoli Chat",
  description: "Xiaoli Chat channel plugin",
  plugin: xiaoliChatPlugin,
  setRuntime: setXiaoliRuntime,
  registerFull(api) {
    api.registerHttpRoute({
      path: XIAOLI_WEBHOOK_PATH,
      auth: "plugin",
      handler: createXiaoliWebhookHandler({ logger: api.logger }),
    });
  },
});
