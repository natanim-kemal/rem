import {
  action,
  internalAction,
  internalMutation,
  internalQuery,
  query,
} from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";

function getServiceAccountCredentials(): { credentials: any; projectId: string } {
  const raw = process.env.FCM_SERVICE_ACCOUNT_KEY;
  if (!raw) {
    throw new Error("Missing FCM_SERVICE_ACCOUNT_KEY env var");
  }
  const credentials = JSON.parse(raw);
  const projectId = credentials.project_id;
  if (!projectId) {
    throw new Error("Missing project_id in service account key");
  }
  return { credentials, projectId };
}

const PRIORITY_DAILY_LIMITS: Record<string, number> = {
  high: 3,
  medium: 2,
  low: 1,
};

const PRIORITY_COOLDOWN_MINUTES: Record<string, number> = {
  high: 4 * 60,
  medium: 6 * 60,
  low: 12 * 60,
};

const MAX_NOTIFICATIONS_PER_DAY = 5;

type NotificationCandidate = {
  itemId?: string;
  userId: string;
  title: string;
  body: string;
  priority: "high" | "medium" | "low";
  type: "reminder" | "digest";
};

function parseTimeString(value: string): { hour: number; minute: number } {
  const [hour, minute] = value.split(":").map((part) => Number(part));
  return {
    hour: Number.isFinite(hour) ? hour : 0,
    minute: Number.isFinite(minute) ? minute : 0,
  };
}

function toMinutesOfDay(hour: number, minute: number) {
  return hour * 60 + minute;
}

function isWithinQuietHours(
  nowMinutes: number,
  startMinutes: number,
  endMinutes: number
) {
  if (startMinutes === endMinutes) return false;
  if (startMinutes < endMinutes) {
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }
  return nowMinutes >= startMinutes || nowMinutes < endMinutes;
}

function applyTimezoneOffset(timestamp: number, offsetMinutes?: number) {
  if (offsetMinutes === undefined) return timestamp;
  return timestamp + offsetMinutes * 60 * 1000;
}

function buildCandidate(item: any): NotificationCandidate {
  return {
    itemId: item._id,
    userId: item.userId,
    title: item.title,
    body: "Time to read this from your vault",
    priority: item.priority,
    type: "reminder",
  };
}

function buildDigestCandidate(
  userId: string,
  count: number,
  titles: string[]
): NotificationCandidate {
  const itemLabel = count === 1 ? "item" : "items";
  const preview = titles.filter(Boolean).slice(0, 3).join(" • ");
  const extra = count > 3 ? ` and ${count - 3} more` : "";
  const bodyBase = `${count} unread ${itemLabel} waiting in your vault`;
  const body = preview ? `${bodyBase}: ${preview}${extra}` : bodyBase;
  return {
    userId,
    title: "Daily digest",
    body,
    priority: "low",
    type: "digest",
  };
}

async function getFcmAccessToken(): Promise<string> {
  const { credentials } = getServiceAccountCredentials();
  const now = Math.floor(Date.now() / 1000);
  const expiry = now + 3600;

  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const claim = {
    iss: credentials.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: expiry,
  };

  const base64UrlEncode = (str: string) =>
    btoa(str)
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedClaim = base64UrlEncode(JSON.stringify(claim));
  const signatureInput = `${encodedHeader}.${encodedClaim}`;

  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = credentials.private_key
    .replace(pemHeader, "")
    .replace(pemFooter, "")
    .replace(/\s/g, "");
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const encoder = new TextEncoder();
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    encoder.encode(signatureInput)
  );

  const encodedSignature = base64UrlEncode(
    String.fromCharCode(...new Uint8Array(signature))
  );

  const jwt = `${signatureInput}.${encodedSignature}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    throw new Error(`OAuth2 error: ${errorText}`);
  }

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

async function sendFcmNotification(
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>,
  projectId: string
) {
  const accessToken = await getFcmAccessToken();

  const results = [];
  for (const token of tokens) {
    const payload = {
      message: {
        token,
        notification: {
          title,
          body,
        },
        data,
        android: {
          priority: data.priority === "high" ? "high" : "normal",
          notification: {
            channelId: "rem_channel",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
      },
    };

    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(payload),
      }
    );

    if (!response.ok) {
      const text = await response.text();
      console.error(`FCM error for token ${token.substring(0, 20)}...: ${text}`);
    } else {
      results.push(await response.json());
    }
  }

  return results;
}

export const getRecentNotificationsForUser = internalQuery({
  args: { userId: v.id("users"), since: v.number() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("notificationLog")
      .withIndex("by_user_sent_at", (q) =>
        q.eq("userId", args.userId).gte("sentAt", args.since)
      )
      .collect();
  },
});

export const logNotification = internalMutation({
  args: {
    userId: v.id("users"),
    itemId: v.optional(v.id("items")),
    type: v.union(
      v.literal("reminder"),
      v.literal("digest"),
      v.literal("streak"),
      v.literal("celebration")
    ),
    title: v.string(),
    body: v.string(),
    sentAt: v.number(),
  },
  handler: async (ctx, args) => {
    await ctx.db.insert("notificationLog", {
      userId: args.userId,
      itemId: args.itemId,
      type: args.type,
      title: args.title,
      body: args.body,
      sentAt: args.sentAt,
    });
  },
});

export const getUser = internalQuery({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db.get(args.userId);
  },
});

export const getPushTokens = internalQuery({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("pushTokens")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .collect();
  },
});

export const upsertPushToken = internalMutation({
  args: {
    userId: v.id("users"),
    token: v.string(),
    platform: v.union(v.literal("android"), v.literal("web")),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("pushTokens")
      .withIndex("by_token", (q) => q.eq("token", args.token))
      .first();

    if (existing) {
      if (existing.userId !== args.userId) {
        await ctx.db.patch(existing._id, {
          userId: args.userId,
          platform: args.platform,
          createdAt: Date.now(),
        });
      }
      return existing._id;
    }

    return await ctx.db.insert("pushTokens", {
      userId: args.userId,
      token: args.token,
      platform: args.platform,
      createdAt: Date.now(),
    });
  },
});

export const markItemReminded = internalMutation({
  args: { itemId: v.id("items"), remindAt: v.number() },
  handler: async (ctx, args) => {
    const item = await ctx.db.get(args.itemId);
    if (!item) return;
    await ctx.db.patch(args.itemId, {
      lastRemindedAt: args.remindAt,
      remindCount: (item.remindCount ?? 0) + 1,
      updatedAt: Date.now(),
    });
  },
});

export const getUsersToNotify = internalQuery({
  args: {},
  handler: async (ctx) => {
    const users = await ctx.db.query("users").collect();
    return users.filter((user) => user.notificationPreferences?.enabled);
  },
});

export const selectNotificationCandidates = internalQuery({
  args: { userId: v.id("users"), now: v.number() },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user || !user.notificationPreferences?.enabled) return [];

    const prefs = user.notificationPreferences;
    const quietStart = parseTimeString(prefs.quietHoursStart || "22:00");
    const quietEnd = parseTimeString(prefs.quietHoursEnd || "08:00");
    const nowLocal = applyTimezoneOffset(args.now, prefs.timezoneOffsetMinutes);
    const nowDate = new Date(nowLocal);
    const nowMinutes = toMinutesOfDay(nowDate.getHours(), nowDate.getMinutes());
    const quietStartMinutes = toMinutesOfDay(quietStart.hour, quietStart.minute);
    const quietEndMinutes = toMinutesOfDay(quietEnd.hour, quietEnd.minute);

    if (isWithinQuietHours(nowMinutes, quietStartMinutes, quietEndMinutes)) {
      return [];
    }

    const startOfDay = new Date(nowLocal);
    startOfDay.setHours(0, 0, 0, 0);
    const dayStartUtc = applyTimezoneOffset(
      startOfDay.getTime(),
      -(prefs.timezoneOffsetMinutes ?? 0)
    );

    const recent = await ctx.db
      .query("notificationLog")
      .withIndex("by_user_sent_at", (q) =>
        q.eq("userId", args.userId).gte("sentAt", dayStartUtc)
      )
      .collect();

    const dailyCap = prefs.maxPerDay ?? MAX_NOTIFICATIONS_PER_DAY;
    const digestAlreadySent = recent.some(
      (entry) => entry.type === "digest"
    );

    const perItemCounts = new Map<string, number>();
    const lastSentAt = new Map<string, number>();
    for (const notif of recent) {
      if (!notif.itemId) continue;
      const key = notif.itemId as string;
      perItemCounts.set(key, (perItemCounts.get(key) ?? 0) + 1);
      lastSentAt.set(key, Math.max(lastSentAt.get(key) ?? 0, notif.sentAt));
    }

    const items = await ctx.db
      .query("items")
      .withIndex("by_user_status", (q) =>
        q.eq("userId", args.userId).eq("status", "unread")
      )
      .collect();

    if (recent.length >= dailyCap) {
      if (items.length > 0 && !digestAlreadySent) {
        const priorityOrder = { high: 0, medium: 1, low: 2 } as const;
        const titles = [...items]
          .sort((a, b) => {
            const prioDiff =
              priorityOrder[a.priority ?? "medium"] -
              priorityOrder[b.priority ?? "medium"];
            if (prioDiff !== 0) return prioDiff;
            return (a.title ?? "").localeCompare(b.title ?? "");
          })
          .map((item) => item.title as string)
          .slice(0, 3);
        return [buildDigestCandidate(args.userId, items.length, titles)];
      }
      return [];
    }

    const candidates: NotificationCandidate[] = [];
    for (const item of items) {
      if (item.snoozedUntil && item.snoozedUntil > args.now) continue;

      const priority = item.priority ?? "medium";
      const maxPerItem = PRIORITY_DAILY_LIMITS[priority] ?? 1;
      const alreadySent = perItemCounts.get(item._id as string) ?? 0;
      if (alreadySent >= maxPerItem) continue;

      const cooldownMinutes = PRIORITY_COOLDOWN_MINUTES[priority] ?? 360;
      const lastSent = lastSentAt.get(item._id as string) ?? 0;
      if (lastSent && args.now - lastSent < cooldownMinutes * 60 * 1000) continue;

      candidates.push(buildCandidate(item));
    }

    const priorityOrder = { high: 0, medium: 1, low: 2 } as const;
    return candidates.sort((a, b) => {
      const prioDiff = priorityOrder[a.priority] - priorityOrder[b.priority];
      if (prioDiff !== 0) return prioDiff;
      return a.title.localeCompare(b.title);
    });
  },
});

export const getNotificationHistory = query({
  args: { limit: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthenticated");

    const user = await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
      .first();

    if (!user) throw new Error("User not found");

    const limit = args.limit ?? 30;
    return await ctx.db
      .query("notificationLog")
      .withIndex("by_user_sent_at", (q) => q.eq("userId", user._id))
      .order("desc")
      .take(limit);
  },
});

export const sendNotificationBatch = action({
  args: { userId: v.id("users"), candidates: v.array(v.any()) },
  handler: async (ctx, args) => {
    const { projectId } = getServiceAccountCredentials();

    const tokens = await ctx.runQuery(internal.notifications.getPushTokens, {
      userId: args.userId,
    });

    if (!tokens.length) return { sent: 0 };

    const tokenValues = tokens.map((token) => token.token);
    const now = Date.now();
    for (const candidate of args.candidates) {
      const data: Record<string, string> = {
        itemId: candidate.itemId ?? "",
        type: candidate.type,
        priority: candidate.priority,
      };
      if (candidate.type === "digest") {
        data.action = "open_unread_list";
      }

      await sendFcmNotification(tokenValues, candidate.title, candidate.body, data, projectId);

      await ctx.runMutation(internal.notifications.logNotification, {
        userId: args.userId,
        itemId: candidate.itemId,
        type: candidate.type,
        title: candidate.title,
        body: candidate.body,
        sentAt: now,
      });

      if (candidate.type === "reminder" && candidate.itemId) {
        await ctx.runMutation(internal.notifications.markItemReminded, {
          itemId: candidate.itemId,
          remindAt: now,
        });
      }
    }

    return { sent: args.candidates.length };
  },
});

export const runNotificationCron = internalAction({
  args: {},
  handler: async (ctx) => {
    const users = await ctx.runQuery(internal.notifications.getUsersToNotify, {});
    const now = Date.now();

    for (const user of users) {
      const candidates = await ctx.runQuery(
        internal.notifications.selectNotificationCandidates,
        {
          userId: user._id,
          now,
        }
      );

      if (!candidates.length) continue;

      const slice = candidates.slice(
        0,
        user.notificationPreferences?.maxPerDay ?? 5
      );

      await ctx.runAction(internal.notifications.sendNotificationBatch, {
        userId: user._id,
        candidates: slice,
      });
    }
  },
});

export const sendTestNotification = action({
  args: { userId: v.id("users"), fcmToken: v.optional(v.string()) },
  handler: async (ctx, args) => {
    const user = await ctx.runQuery(internal.notifications.getUser, {
      userId: args.userId,
    });
    if (!user) throw new Error("User not found");

    // If a fresh FCM token was provided, register it first
    if (args.fcmToken) {
      await ctx.runMutation(internal.notifications.upsertPushToken, {
        userId: args.userId,
        token: args.fcmToken,
        platform: "android",
      });
    }

    // Use the provided token, or fall back to stored tokens
    let tokenToUse = args.fcmToken;
    if (!tokenToUse) {
      const tokens = await ctx.runQuery(internal.notifications.getPushTokens, {
        userId: args.userId,
      });
      if (tokens.length === 0) {
        throw new Error("No push token registered. Please open the app and wait for sync.");
      }
      tokenToUse = tokens[0].token;
    }

    const { projectId } = getServiceAccountCredentials();
    const accessToken = await getFcmAccessToken();

    const payload = {
      message: {
        token: tokenToUse,
        notification: {
          title: "Test Notification",
          body: "Notifications are working!",
        },
        data: { type: "test", itemId: "" },
        android: {
          priority: "high" as const,
          notification: {
            channelId: "rem_channel",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
      },
    };

    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(payload),
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`FCM send failed: ${errorText}`);
    }

    await ctx.runMutation(internal.notifications.logNotification, {
      userId: args.userId,
      itemId: undefined,
      type: "reminder",
      title: "Test Notification",
      body: "Notifications are working!",
      sentAt: Date.now(),
    });

    return { success: true };
  },
});
