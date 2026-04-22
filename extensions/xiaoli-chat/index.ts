import { defineBundledChannelEntry } from "openclaw/plugin-sdk/channel-entry-contract";
import { createXiaoliWebhookHandler, XIAOLI_WEBHOOK_PATH } from "./src/webhook.js";
import { createXiaoliStopHandler } from "./src/stop.js";
import { getXiaoliRuntime } from "./src/runtime.js";

export const XIAOLI_STOP_PATH = "/hooks/xiaoli-chat/stop";

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
    // 注册 webhook 接收端点
    api.registerHttpRoute({
      path: XIAOLI_WEBHOOK_PATH,
      auth: "plugin",
      handler: createXiaoliWebhookHandler({ logger: api.logger }),
    });

    // 注册停止会话端点
    api.registerHttpRoute({
      path: XIAOLI_STOP_PATH,
      auth: "plugin",
      handler: createXiaoliStopHandler({
        runtime: getXiaoliRuntime(),
        logger: api.logger,
      }),
    });
  },
});
