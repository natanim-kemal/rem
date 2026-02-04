import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

export const getOrCreateUser = mutation({
    args: {},
    handler: async (ctx) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) throw new Error("Unauthenticated");

        const existing = await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .first();

        if (existing) return existing._id;

        const now = Date.now();

        const userId = await ctx.db.insert("users", {
            clerkId: identity.subject,
            email: identity.email ?? "",
            displayName: identity.name,
            avatarUrl: identity.pictureUrl,
            isPremium: false,
            notificationPreferences: {
                enabled: true,
                dailyDigestTime: "09:00",
                maxPerDay: 3,
                quietHoursStart: "22:00",
                quietHoursEnd: "08:00",
            },
            createdAt: now,
            updatedAt: now,
        });

        await ctx.db.insert("userStats", {
            userId,
            itemsSavedTotal: 0,
            itemsReadTotal: 0,
            itemsSavedThisWeek: 0,
            itemsReadThisWeek: 0,
            currentStreak: 0,
            longestStreak: 0,
            updatedAt: now,
        });

        return userId;
    },
});

export const getCurrentUser = query({
    args: {},
    handler: async (ctx) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) return null;

        return await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .first();
    },
});

export const updateNotificationPreferences = mutation({
    args: {
        enabled: v.optional(v.boolean()),
        dailyDigestTime: v.optional(v.string()),
        maxPerDay: v.optional(v.number()),
        quietHoursStart: v.optional(v.string()),
        quietHoursEnd: v.optional(v.string()),
    },
    handler: async (ctx, args) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) throw new Error("Unauthenticated");

        const user = await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .first();

        if (!user) throw new Error("User not found");

        const newPrefs = {
            ...user.notificationPreferences,
            ...(args.enabled !== undefined && { enabled: args.enabled }),
            ...(args.dailyDigestTime && { dailyDigestTime: args.dailyDigestTime }),
            ...(args.maxPerDay !== undefined && { maxPerDay: args.maxPerDay }),
            ...(args.quietHoursStart && { quietHoursStart: args.quietHoursStart }),
            ...(args.quietHoursEnd && { quietHoursEnd: args.quietHoursEnd }),
        };

        await ctx.db.patch(user._id, {
            notificationPreferences: newPrefs,
            updatedAt: Date.now(),
        });
    },
});

export const getStats = query({
    args: {},
    handler: async (ctx) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) throw new Error("Unauthenticated");

        const user = await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .first();

        if (!user) throw new Error("User not found");

        return await ctx.db
            .query("userStats")
            .withIndex("by_user", (q) => q.eq("userId", user._id))
            .first();
    },
});

export const registerPushToken = mutation({
    args: {
        token: v.string(),
        platform: v.union(v.literal("android"), v.literal("web")),
    },
    handler: async (ctx, args) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) throw new Error("Unauthenticated");

        const user = await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .first();

        if (!user) throw new Error("User not found");

        const existing = await ctx.db
            .query("pushTokens")
            .withIndex("by_token", (q) => q.eq("token", args.token))
            .first();

        if (existing) return existing._id;

        return await ctx.db.insert("pushTokens", {
            userId: user._id,
            token: args.token,
            platform: args.platform,
            createdAt: Date.now(),
        });
    },
});
