export function buildChatCompletionsUrl(baseUrl: string): string {
  const trimmed = baseUrl.trim().replace(/\/+$/, "");
  return `${trimmed}/v1/chat/completions`;
}

export function buildSystemPrompt(context: string, limited: boolean): string {
  const notice = limited
    ? "\nNote: The available content for this item is limited. Say so if it affects your answer."
    : "";
  return `You are rem, a friendly reading assistant. Answer the user's questions about the saved item below using only the provided content.\n\nArticle content:\n${context}${notice}`;
}

export async function streamChatCompletion(opts: {
  messages: Array<{ role: string; content: string }>;
}): Promise<Response> {
  const gatewayUrl = process.env.CHAT_GATEWAY_URL;
  const apiKey = process.env.CHAT_GATEWAY_KEY;
  const model = process.env.CHAT_MODEL || "auto";
  return await fetch(buildChatCompletionsUrl(gatewayUrl || ""), {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey || ""}`,
    },
    body: JSON.stringify({ model, stream: true, messages: opts.messages }),
  });
}
