import { XiaoliChatClient } from "./client.js";
import type { ResolvedXiaoliAccount } from "./types.js";

export async function sendText(params: {
  account: ResolvedXiaoliAccount;
  chatId: string;
  text: string;
  threadId?: string;
}): Promise<{ messageId: string }> {
  const client = new XiaoliChatClient(params.account);
  return await client.sendMessage({
    chatId: params.chatId,
    text: params.text,
    threadId: params.threadId,
  });
}
