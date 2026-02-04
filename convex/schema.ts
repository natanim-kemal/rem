import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
    users: defineTable({
        clerkId: v.string(),
        email: v.string(),
        displayName: v.optional(v.string()),
        avatarUrl: v.optional(v.string()),
        isPremium: v.boolean(),
        notificationPreferences: v.object({
            enabled: v.boolean(),
            dailyDigestTime: v.string(),
            maxPerDay: v.number(),
            quietHoursStart: v.string(),
            quietHoursEnd: v.string(),
        }),
        createdAt: v.number(),
        updatedAt: v.number(),
    })
        .index("by_clerk_id", ["clerkId"])
        .index("by_email", ["email"]),

    items: defineTable({
        userId: v.id("users"),
        type: v.union(
            v.literal("link"),
            v.literal("image"),
            v.literal("video"),
            v.literal("book"),
            v.literal("note")
        ),
        url: v.optional(v.string()),
        title: v.string(),
        description: v.optional(v.string()),
        thumbnailUrl: v.optional(v.string()),
        estimatedReadTime: v.optional(v.number()),
        priority: v.union(v.literal("high"), v.literal("medium"), v.literal("low")),
        tags: v.array(v.string()),
        status: v.union(
            v.literal("unread"),
            v.literal("in_progress"),
            v.literal("read"),
            v.literal("archived")
        ),
        readAt: v.optional(v.number()),
        lastRemindedAt: v.optional(v.number()),
        remindCount: v.number(),
        snoozedUntil: v.optional(v.number()),
        visibility: v.union(v.literal("private"), v.literal("friends"), v.literal("public")),
        syncStatus: v.union(v.literal("synced"), v.literal("pending"), v.literal("conflict")),
        localId: v.optional(v.string()),
        createdAt: v.number(),
        updatedAt: v.number(),
    })
        .index("by_user_status", ["userId", "status"])
        .index("by_user_type", ["userId", "type"])
        .index("by_snoozed", ["snoozedUntil"])
        .index("by_visibility", ["visibility"])
        .searchIndex("search_items", {
            searchField: "title",
            filterFields: ["userId", "status", "type"],
        }),

    tags: defineTable({
        userId: v.id("users"),
        name: v.string(),
        color: v.optional(v.string()),
        createdAt: v.number(),
    })
        .index("by_user", ["userId"])
        .index("by_user_name", ["userId", "name"]),

    notificationLog: defineTable({
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
        clickedAt: v.optional(v.number()),
        dismissedAt: v.optional(v.number()),
    })
        .index("by_user", ["userId"])
        .index("by_item", ["itemId"]),

    userStats: defineTable({
        userId: v.id("users"),
        itemsSavedTotal: v.number(),
        itemsReadTotal: v.number(),
        itemsSavedThisWeek: v.number(),
        itemsReadThisWeek: v.number(),
        currentStreak: v.number(),
        longestStreak: v.number(),
        lastReadAt: v.optional(v.number()),
        updatedAt: v.number(),
    }).index("by_user", ["userId"]),

    pushTokens: defineTable({
        userId: v.id("users"),
        token: v.string(),
        platform: v.union(v.literal("android"), v.literal("web")),
        createdAt: v.number(),
    })
        .index("by_user", ["userId"])
        .index("by_token", ["token"]),

    sharedStashes: defineTable({
        ownerId: v.id("users"),
        name: v.string(),
        description: v.optional(v.string()),
        itemIds: v.array(v.id("items")),
        visibility: v.union(v.literal("private"), v.literal("friends"), v.literal("public")),
        shareCode: v.optional(v.string()),
        createdAt: v.number(),
        updatedAt: v.number(),
    })
        .index("by_owner", ["ownerId"])
        .index("by_share_code", ["shareCode"]),
});
