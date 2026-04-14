import { defineBundledChannelEntry } from "openclaw/plugin-sdk/channel-entry-contract";
import { createXiaoliWebhookHandler, XIAOLI_WEBHOOK_PATH } from "./src/webhook.js";

export default defineBundledChannelEntry({
  id: "xiaoli-chat",
  name: "Xiaoli Chat",
  description: "Xiaoli Chat channel plugin",
  importMetaUrl: import.meta.url,
  plugin: {
    specifier: "./channel-plugin-api.js",
    exportName: "xiaoliChatPlugin",
  },
  runtime: {
    specifier: "./runtime-api.js",
    exportName: "setXiaoliRuntime",
  },
  registerFull(api) {
    api.registerHttpRoute({
      path: XIAOLI_WEBHOOK_PATH,
      auth: "plugin",
      handler: createXiaoliWebhookHandler({ logger: api.logger }),
    });
  },
});
