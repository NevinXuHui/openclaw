import type { PluginRuntime } from "openclaw/plugin-sdk/core";
import { createPluginRuntimeStore } from "openclaw/plugin-sdk/runtime-store";

const {
  setRuntime: setXiaoliRuntime,
  getRuntime: getXiaoliRuntime,
  tryGetRuntime: tryGetXiaoliRuntime,
} = createPluginRuntimeStore<PluginRuntime>("Xiaoli Chat runtime not initialized");

export { getXiaoliRuntime, setXiaoliRuntime, tryGetXiaoliRuntime };
