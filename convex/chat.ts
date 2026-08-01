import { httpAction } from "./_generated/server";
import { internal } from "./_generated/api";
import { fetchUrlContent } from "./chat/extract";
import { buildSystemPrompt, streamChatCompletion } from "./chat/gateway";

function json(status: number, error: string): Response {
  return new Response(JSON.stringify({ error }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
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

  let body: { itemId?: unknown; history?: unknown };
  try {
    body = (await request.json()) as { itemId?: unknown; history?: unknown };
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

  const gatewayUrl = process.env.CHAT_GATEWAY_URL;
  if (!gatewayUrl) {
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

  const maxStreams = Number(process.env.CHAT_MAX_STREAMS_PER_USER || "2") || 2;
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

    const messages = [
      { role: "system", content: buildSystemPrompt(contextText, limited) },
      ...history,
    ];

    const upstream = await streamChatCompletion({ messages });
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
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
      },
    });
  } catch (error) {
    await ctx
      .runMutation(internal.chat.internal.endChatStream, { id: streamId })
      .catch(() => {});
    return json(500, "Chat failed. Try again.");
  }
});
