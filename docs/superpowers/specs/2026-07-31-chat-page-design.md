# Chat Page Design

> 4th tab: chat with LLMs grounded on a saved item's article content

---

## Overview

Add a 4th tab, **Chat**, alongside Home / Stats / Profile. Users select a saved
item (or enter from the item detail screen) and have a streaming conversation
with an LLM whose context is the item's article content.

The LLM backend is a **configurable OpenAI-compatible gateway** (default target:
[OmniRoute](https://github.com/diegosouzapw/OmniRoute), self-hosted). The gateway
base URL, API key, and model are Convex env vars, so the provider can change
without an app update.

### Decisions (confirmed with user)

- **Approach**: Convex HTTP action proxies the upstream SSE stream (keys stay
  server-side).
- **Content**: fetch + extract article text on demand; cached per URL so later
  messages skip the fetch. Falls back to stored title/description for images,
  videos, notes, and blocked/paywalled pages.
- **History**: persisted locally in Drift (offline-first, private). One
  conversation per item; reopening an item resumes it.
- **Entry points**: Chat tab (conversation list + new-chat item picker) and a
  chat action on item cards / detail.
- **Streaming**: token-by-token via SSE.
- **Model selection**: single server-configured default (`CHAT_MODEL`); no
  per-user picker in MVP.

---

## Data Flow

```
Flutter ChatScreen
  │  POST {CONVEX_URL}/api/chat/stream   (Authorization: Bearer <Clerk session token>)
  ▼
Convex HTTP action chatStream
  1. Verify Clerk identity + item ownership (userId matches identity.subject)
  2. content = cached extracted text (chatContent table)
             ?: fetch URL → extract readable text → store in cache
  3. POST {CHAT_GATEWAY_URL}/v1/chat/completions
        { model: CHAT_MODEL, stream: true,
          messages: [ system(article context), ...last N history ] }
  4. Pipe upstream SSE response body back to the phone
  ▼
ChatScreen renders tokens live; persisted to Drift on completion
```

### Convex environment variables (new)

| Variable | Purpose |
|---|---|
| `CHAT_GATEWAY_URL` | OpenAI-compatible base URL, e.g. `http://localhost:20128` (OmniRoute) |
| `CHAT_GATEWAY_KEY` | Gateway API key (server-side only) |
| `CHAT_MODEL` | Default model id, e.g. `auto` |
| `CHAT_MAX_STREAMS_PER_USER` | Optional per-user in-flight stream guard |

---

## Components

### Backend (Convex, TypeScript)

| Component | File | Responsibility |
|---|---|---|
| HTTP action | `convex/chat.ts` | `chatStream` httpAction — auth + ownership check, orchestrate extract + gateway call, stream SSE back |
| Content extractor | `convex/chat/extract.ts` | `fetchUrlContent(url)` — fetch page, strip HTML to plain text, truncate to a cap (e.g. 20k chars); no heavy DOM libs |
| Content cache | `convex/schema.ts` | `chatContent` table: `{ url (pk), text, fetchedAt }` |
| Gateway client | `convex/chat/gateway.ts` | `streamChatCompletion(messages)` — POST `CHAT_GATEWAY_URL/v1/chat/completions` with `stream:true`; returns upstream `Response` body |

### Mobile (Flutter, Dart)

| Component | File | Responsibility |
|---|---|---|
| Drift tables | `apps/mobile/lib/data/database/database.dart` | `Conversations` (id, itemId, createdAt, updatedAt), `Messages` (id, conversationId, role, content, status, createdAt); migration to schemaVersion 5 |
| SSE client | `apps/mobile/lib/core/services/chat_stream_client.dart` | POST `/api/chat/stream` with auth token; parse `data:` lines via `http` stream transform |
| Chat service | `apps/mobile/lib/core/services/chat_service.dart` | Orchestrate: load/create conversation, persist user message, stream, persist assistant message |
| Providers | `apps/mobile/lib/providers/chat_providers.dart` | `conversationProvider(itemId)`, `messagesProvider(conversationId)` (Riverpod codegen) |
| Chat screen | `apps/mobile/lib/presentation/screens/chat_screen.dart` | Streaming bubble list, input bar, stop button, error/retry |
| Sessions screen | `apps/mobile/lib/presentation/screens/chat_sessions_screen.dart` | Conversation list (item title + last message), new-chat item picker |
| Shell nav | `apps/mobile/lib/presentation/screens/shell_screen.dart` | Add 4th tab; update `_pageIndexForNavIndex` / `_navIndexForPageIndex` |
| Entry point | item card / detail | "Chat" action → open chat for that item |

---

## Edge Cases

- **No article text** (image/video/note, paywall): fall back to title +
  description as context; include a system note "limited context available".
- **Extraction failure / dead URL**: still allow chat on stored metadata; show a
  subtle warning.
- **Content cap**: truncate extracted text (~20k chars) to fit the gateway
  context window.
- **Existing conversation**: opening chat for an item with a conversation
  resumes it (one conversation per item).
- **Long history**: send only the last N messages (e.g. 20) to the gateway.
- **Stream interrupted**: message stays `incomplete`/`failed`; retry re-streams.
- **Item deleted while chatting**: notice shown; conversation remains readable,
  send disabled.
- **Offline**: stream unavailable → clear error + retry; history viewable.
- **Rapid sends**: send button disabled while a stream is active.

---

## Error Handling

- Gateway 401 (bad key) / 429 (quota): specific user-facing messages.
- `CHAT_GATEWAY_URL` unset/empty: friendly "Chat is not configured yet" state.
- Auth expiry mid-stream: reuse existing re-sign-in path.

---

## Security

- Gateway key lives only in Convex env — never in the APK or bundled assets.
- Ownership enforced server-side: user may only chat items whose `userId`
  matches their identity.
- Rate limiting: per-user in-flight stream guard (`CHAT_MAX_STREAMS_PER_USER`)
  plus per-message length cap.

---

## Testing

- **Convex**: unit tests for extractor (HTML→text, cap, failure) and gateway URL
  building; HTTP action tests with a mocked gateway.
- **Flutter**: widget tests for ChatScreen (empty state, streaming bubble, error
  state); provider/service tests with a fake SSE client; Drift migration test
  v4→v5.
- **Manual**: end-to-end chat against a free gateway provider.

---

## Out of Scope (MVP)

- Per-user model picker.
- Cross-device history sync.
- Chat history in Convex (stays local).
- Rate limiting beyond the per-user stream guard.
