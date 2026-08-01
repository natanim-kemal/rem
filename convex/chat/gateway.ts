import { providerApiKey, type ResolvedModel } from "./models";

export function buildChatCompletionsUrl(baseUrl: string): string {
  const trimmed = baseUrl.trim().replace(/\/+$/, "");
  const alreadyV1 = /\/v1$/.test(trimmed) || trimmed.includes("/chat/completions");
  return alreadyV1
    ? `${trimmed}/chat/completions`
    : `${trimmed}/v1/chat/completions`;
}

export function buildSystemPrompt(context: string, limited: boolean): string {
  const notice = limited
    ? "\nNote: The available content for this item is limited. Say so if it affects your answer."
    : "";
  return `You are rem, a friendly reading assistant. Answer the user's questions about the saved item below using only the provided content.\n\nArticle content:\n${context}${notice}`;
}

const SEARCH_TOOL = {
  type: "function",
  function: {
    name: "searchWeb",
    description:
      "Search the web when the user asks about something not covered by the article content, current events, or up-to-date facts.",
    parameters: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "A concise search query to look up on the web.",
        },
      },
      required: ["query"],
    },
  },
} as const;

export async function streamChatCompletion(opts: {
  messages: Array<{ role: string; content: string }>;
  resolvedModel?: ResolvedModel;
}): Promise<Response> {
  const { resolvedModel } = opts;
  const baseUrl =
    resolvedModel?.baseUrl || process.env.CHAT_GATEWAY_URL || "";
  const apiKey = providerApiKey(resolvedModel?.provider || "default") || "";
  const model = resolvedModel?.model || process.env.CHAT_MODEL || "auto";

  const body: Record<string, unknown> = {
    model,
    stream: true,
    messages: opts.messages,
  };
  if (resolvedModel?.tools) {
    body.tools = [SEARCH_TOOL];
  }

  return await fetch(buildChatCompletionsUrl(baseUrl), {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  });
}
