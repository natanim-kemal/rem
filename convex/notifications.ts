import {
  action,
  internalAction,
  internalMutation,
  internalQuery,
  query,
} from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";

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
const FCM_ENDPOINT = "https://fcm.googleapis.com/fcm/send";

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

async function sendFcmNotification(
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>
) {
  const serverKey = process.env.FCM_SERVER_KEY;
  if (!serverKey) {
    throw new Error("Missing FCM_SERVER_KEY env var");
  }

  const payload = {
    registration_ids: tokens,
    notification: {
      title,
      body,
    },
    data,
  };

  const response = await fetch(FCM_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `key=${serverKey}`,
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`FCM error ${response.status}: ${text}`);
  }

  return response.json();
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
    const tokens = await ctx.db
      .query("pushTokens")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .collect();

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

      await sendFcmNotification(tokenValues, candidate.title, candidate.body, data);

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
