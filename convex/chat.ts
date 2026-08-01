import { httpAction } from "./_generated/server";
import { internal } from "./_generated/api";
import { fetchUrlContent } from "./chat/extract";
import { buildSystemPrompt, streamChatCompletion } from "./chat/gateway";
import { resolveModel } from "./chat/models";
import { formatSearchResults, searchWeb } from "./chat/search";

function json(status: number, error: string): Response {
  return new Response(JSON.stringify({ error }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function latestUserQuery(
  history: Array<{ role: string; content: string }>,
): string | null {
  for (let i = history.length - 1; i >= 0; i--) {
    if (history[i].role === "user") return history[i].content;
  }
  return null;
}

function concatChunks(chunks: Uint8Array[]): Uint8Array {
  const total = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    out.set(chunk, offset);
    offset += chunk.length;
  }
  return out;
}

function extractToolCalls(
  sseText: string,
): Array<{ id: string; name: string; args: string }> {
  const calls = new Map<number, { id: string; name: string; args: string }>();
  for (const line of sseText.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed.startsWith("data:")) continue;
    const payload = trimmed.slice(5).trim();
    if (!payload || payload === "[DONE]") continue;
    try {
      const parsed = JSON.parse(payload) as {
        choices?: Array<{
          delta?: {
            tool_calls?: Array<{
              index?: number;
              id?: string;
              function?: { name?: string; arguments?: string };
            }>;
          };
        }>;
      };
      const deltaCalls = parsed.choices?.[0]?.delta?.tool_calls ?? [];
      for (const call of deltaCalls) {
        const index = call.index ?? 0;
        const current = calls.get(index) ?? { id: "", name: "", args: "" };
        if (call.id) current.id = call.id;
        if (call.function?.name) current.name = call.function.name;
        if (call.function?.arguments) current.args += call.function.arguments;
        calls.set(index, current);
      }
    } catch {}
  }
  return Array.from(calls.values()).filter((c) => c.name && c.args);
}

function parseToolQuery(args: string): string {
  try {
    const parsed = JSON.parse(args) as { query?: unknown };
    return typeof parsed.query === "string" ? parsed.query : "";
  } catch {
    return "";
  }
}

const SSE_HEADERS: Record<string, string> = {
  "Content-Type": "text/event-stream",
  "Cache-Control": "no-cache",
};

function streamWithToolSupport(
  messages: Array<{ role: string; content: string }>,
  resolvedModel: { model: string; baseUrl: string; tools: boolean; provider: string },
): Promise<Response> {
  return (async () => {
    const upstream = await streamChatCompletion({ messages, resolvedModel });
    if (upstream.status >= 400) return upstream;

    const chunks: Uint8Array[] = [];
    const stream = new TransformStream<Uint8Array, Uint8Array>({
      transform(chunk, controller) {
        chunks.push(chunk);
        controller.enqueue(chunk);
      },
      async flush(controller) {
        const calls = extractToolCalls(
          new TextDecoder().decode(concatChunks(chunks)),
        );
        if (calls.length === 0) return;
        const assistantMessage = {
          role: "assistant",
          content: "",
          tool_calls: calls.map((c) => ({
            id: c.id,
            type: "function",
            function: { name: c.name, arguments: c.args },
          })),
        };
        const query = parseToolQuery(calls[0].args);
        const search = query ? await searchWeb(query) : null;
        const searchText = search
          ? formatSearchResults(search.results, search.provider)
          : "Web search returned no results for that query.";
        const nextMessages = [
          ...messages,
          assistantMessage,
          { role: "tool", tool_call_id: calls[0].id, content: searchText },
        ];
        const turn2 = await streamChatCompletion({ messages: nextMessages, resolvedModel });
        if (turn2.status >= 400) {
          controller.enqueue(
            new TextEncoder().encode("\n\n(Web search failed. Please try again.)"),
          );
          return;
        }
        const reader = turn2.body?.getReader();
        if (reader) {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            controller.enqueue(value);
          }
        }
      },
    });

    const writer = stream.writable.getWriter();
    const reader = upstream.body?.getReader();
    void (async () => {
      try {
        if (reader) {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            await writer.write(value);
          }
        }
      } catch {
      } finally {
        await writer.close().catch(() => {});
      }
    })();

    return new Response(stream.readable, {
      status: upstream.status,
      headers: SSE_HEADERS,
    });
  })();
}

export const chatStream = httpAction(async (ctx, request) => {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return json(401, "Unauthorized");
  }
  let identity;
  try {
    identity = await ctx.auth.getUserIdentity();
  } catch {
    return json(401, "Invalid or expired token");
  }
  if (!identity) {
    return json(401, "Invalid token");
  }

  const user = await ctx.runQuery(internal.chat.internal.getUserByClerkId, {
    clerkId: identity.subject,
  });
  if (!user) {
    return json(401, "User not found");
  }

  let body: {
    itemId?: unknown;
    history?: unknown;
    modelId?: unknown;
    webSearch?: unknown;
  };
  try {
    body = (await request.json()) as {
      itemId?: unknown;
      history?: unknown;
      modelId?: unknown;
      webSearch?: unknown;
    };
  } catch {
    return json(400, "Invalid JSON body");
  }

  if (typeof body.itemId !== "string" || body.itemId.length === 0) {
    return json(400, "itemId is required");
  }
  if (!Array.isArray(body.history) || body.history.length > 20) {
    return json(400, "history must be an array of at most 20 messages");
  }
  const history = body.history as Array<{ role: string; content: string }>;
  for (const message of history) {
    if (
      !message ||
      typeof message.role !== "string" ||
      !["user", "assistant"].includes(message.role)
    ) {
      return json(400, "invalid history message role");
    }
    if (
      typeof message.content !== "string" ||
      message.content.length === 0 ||
      message.content.length > 4000
    ) {
      return json(400, "invalid history message content");
    }
  }
  if (body.modelId !== undefined && typeof body.modelId !== "string") {
    return json(400, "modelId must be a string");
  }
  if (body.webSearch !== undefined && typeof body.webSearch !== "boolean") {
    return json(400, "webSearch must be a boolean");
  }

  const resolvedModel = resolveModel(body.modelId as string | undefined);
  if (body.modelId) {
    if (!resolvedModel || resolvedModel.provider === "default") {
      return json(400, "Unknown model");
    }
  } else if (!resolvedModel) {
    return json(503, "Chat is not configured yet");
  }

  const item = await ctx.runQuery(internal.chat.internal.getItemById, {
    itemId: body.itemId,
  });
  if (!item) {
    return json(404, "Item not found. Sync the app and try again.");
  }
  if (item.userId !== user._id) {
    return json(403, "Not authorized");
  }

  const maxStreams = Number(process.env.CHAT_MAX_STREAMS_PER_USER || "30") || 30;
  const active = await ctx.runQuery(internal.chat.internal.countActiveStreams, {
    userId: user._id,
    cutoff: Date.now() - 2 * 60 * 1000,
  });
  if (active >= maxStreams) {
    return json(429, "Too many active chats. Try again in a moment.");
  }
  const streamId = await ctx.runMutation(
    internal.chat.internal.startChatStream,
    {
      userId: user._id,
    },
  );

  try {
    let contextText = "";
    let limited = false;
    const url = item.url;
    if (url && /^https?:\/\//i.test(url)) {
      const cached = await ctx.runQuery(internal.chat.internal.getChatContent, {
        url,
      });
      if (cached) {
        contextText = cached.text;
      } else {
        const result = await fetchUrlContent(url);
        if (result.text) {
          contextText = result.text;
          await ctx.runMutation(internal.chat.internal.setChatContent, {
            url,
            text: result.text,
          });
        } else {
          limited = true;
        }
      }
    } else {
      limited = true;
    }
    if (!contextText) {
      contextText = [item.title, item.description].filter(Boolean).join("\n");
      if (!contextText) {
        await ctx
          .runMutation(internal.chat.internal.endChatStream, { id: streamId })
          .catch(() => {});
        return json(500, "No content available for this item.");
      }
    }

    let systemContent = buildSystemPrompt(contextText, limited);
    const shouldSearch = body.webSearch === true || limited;
    if (shouldSearch) {
      const query = latestUserQuery(history) || item.title || "";
      if (query) {
        const search = await searchWeb(query);
        if (search) {
          systemContent += formatSearchResults(search.results, search.provider);
        } else if (body.webSearch === true) {
          systemContent += "\n\nNote: Web search was requested but returned no results.";
        }
      }
    }

    const messages = [
      { role: "system", content: systemContent },
      ...history,
    ];

    let upstream: Response;
    if (resolvedModel.tools) {
      upstream = await streamWithToolSupport(messages, resolvedModel);
    } else {
      upstream = await streamChatCompletion({ messages, resolvedModel });
    }
    if (upstream.status >= 400) {
      const raw = await upstream.text().catch(() => "");
      let message: string | undefined;
      try {
        const parsed = JSON.parse(raw) as { error?: unknown };
        const error = parsed?.error;
        if (typeof error === "string") {
          message = error;
        } else if (
          typeof error === "object" &&
          error !== null &&
          typeof (error as { message?: unknown }).message === "string"
        ) {
          message = (error as { message: string }).message;
        }
      } catch {}
      await ctx
        .runMutation(internal.chat.internal.endChatStream, { id: streamId })
        .catch(() => {});
      return json(upstream.status, message || "Upstream chat service error");
    }
    const passthrough = new TransformStream<Uint8Array, Uint8Array>();
    const writer = passthrough.writable.getWriter();
    const reader = upstream.body?.getReader();

    void (async () => {
      try {
        if (reader) {
          while (true) {
            const { done, value } = await reader.read();
            if (done) {
              break;
            }
            await writer.write(value);
          }
        }
      } catch {
      } finally {
        await writer.close().catch(() => {});
        await ctx
          .runMutation(internal.chat.internal.endChatStream, { id: streamId })
          .catch(() => {});
      }
    })();

    return new Response(passthrough.readable, {
      status: upstream.status,
      headers: SSE_HEADERS,
    });
  } catch (error) {
    await ctx
      .runMutation(internal.chat.internal.endChatStream, { id: streamId })
      .catch(() => {});
    return json(500, "Chat failed. Try again.");
  }
});
