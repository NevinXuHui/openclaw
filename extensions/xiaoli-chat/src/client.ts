import type { ResolvedXiaoliAccount, XiaoliSendMessageParams } from "./types.js";

export class XiaoliChatClient {
  public constructor(private readonly account: ResolvedXiaoliAccount) {}

  public async sendMessage(params: XiaoliSendMessageParams): Promise<{ messageId: string }> {
    const response = await fetch(`${this.account.baseUrl}/messages`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${this.account.token}`,
      },
      body: JSON.stringify({
        chatId: params.chatId,
        text: params.text,
        threadId: params.threadId,
      }),
    });

    if (!response.ok) {
      const body = await response.text();
      throw new Error(`xiaoli-chat send failed: ${response.status} ${body}`);
    }

    const data = (await response.json()) as { id?: string };
    if (!data.id) {
      throw new Error("xiaoli-chat send failed: missing message id");
    }

    return { messageId: data.id };
  }
}
