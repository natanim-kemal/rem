import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

export const getItems = query({
    args: {
        status: v.optional(v.string()),
        type: v.optional(v.string()),
        limit: v.optional(v.number()),
    },
    handler: async (ctx, args) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) throw new Error("Unauthenticated");

        const user = await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .first();

        if (!user) throw new Error("User not found");

        let query = ctx.db
            .query("items")
            .withIndex("by_user_status", (q) => {
                let q2 = q.eq("userId", user._id);
                if (args.status) {
                    q2 = q2.eq("status", args.status as any);
                }
                return q2;
            })
            .order("desc");

        if (args.limit) {
            return await query.take(args.limit);
        }
        return await query.collect();
    },
});

export const getItem = query({
    args: { itemId: v.id("items") },
    handler: async (ctx, args) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) throw new Error("Unauthenticated");

        const item = await ctx.db.get(args.itemId);
        if (!item) return null;

        const user = await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .first();

        if (!user || item.userId !== user._id) {
            throw new Error("Not authorized");
        }

        return item;
    },
});

export const createItem = mutation({
    args: {
        url: v.optional(v.string()),
        title: v.string(),
        description: v.optional(v.string()),
        thumbnailUrl: v.optional(v.string()),
        type: v.union(
            v.literal("link"),
            v.literal("image"),
            v.literal("video"),
            v.literal("book"),
            v.literal("note")
        ),
        priority: v.optional(v.union(v.literal("high"), v.literal("medium"), v.literal("low"))),
        tags: v.optional(v.array(v.string())),
        localId: v.optional(v.string()),
        remindCount: v.optional(v.number()),
    },
    handler: async (ctx, args) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) throw new Error("Unauthenticated");

        const user = await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .first();

        if (!user) throw new Error("User not found");

        const now = Date.now();

        if (args.url) {
            const existing = await ctx.db
                .query("items")
                .withIndex("by_user_status", (q) => q.eq("userId", user._id))
                .filter((q) => q.eq(q.field("url"), args.url))
                .first();

            if (existing) {
                throw new Error("Duplicate URL");
            }
        }

        const itemId = await ctx.db.insert("items", {
            userId: user._id,
            type: args.type,
            url: args.url,
            title: args.title,
            description: args.description,
            thumbnailUrl: args.thumbnailUrl,
            priority: args.priority ?? "medium",
            tags: args.tags ?? [],
            status: "unread",
            remindCount: args.remindCount ?? 0,
            visibility: "private",
            syncStatus: "synced",
            localId: args.localId,
            createdAt: now,
            updatedAt: now,
        });

        const stats = await ctx.db
            .query("userStats")
            .withIndex("by_user", (q) => q.eq("userId", user._id))
            .first();

        if (stats) {
            await ctx.db.patch(stats._id, {
                itemsSavedTotal: stats.itemsSavedTotal + 1,
                itemsSavedThisWeek: stats.itemsSavedThisWeek + 1,
                updatedAt: now,
            });
        }

        return itemId;
    },
});

export const updateItem = mutation({
    args: {
        itemId: v.id("items"),
        title: v.optional(v.string()),
        description: v.optional(v.string()),
        priority: v.optional(v.union(v.literal("high"), v.literal("medium"), v.literal("low"))),
        tags: v.optional(v.array(v.string())),
        status: v.optional(v.union(v.literal("unread"), v.literal("read"), v.literal("archived"))),
        snoozedUntil: v.optional(v.number()),
    },
    handler: async (ctx, args) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) throw new Error("Unauthenticated");

        const item = await ctx.db.get(args.itemId);
        if (!item) throw new Error("Item not found");

        const user = await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .first();

        if (!user || item.userId !== user._id) {
            throw new Error("Not authorized");
        }

        const updateData: any = {
            updatedAt: Date.now(),
        };

        if (args.title !== undefined) updateData.title = args.title;
        if (args.description !== undefined) updateData.description = args.description;
        if (args.priority !== undefined) updateData.priority = args.priority;
        if (args.tags !== undefined) updateData.tags = args.tags;
        if (args.status !== undefined) {
            updateData.status = args.status;
            if (args.status === "read") {
                updateData.readAt = Date.now();
            }
        }
        if (args.snoozedUntil !== undefined) {
            updateData.snoozedUntil = args.snoozedUntil;
        }

        await ctx.db.patch(args.itemId, updateData);
    },
});

export const markAsRead = mutation({
    args: { itemId: v.id("items") },
    handler: async (ctx, args) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) throw new Error("Unauthenticated");

        const item = await ctx.db.get(args.itemId);
        if (!item) throw new Error("Item not found");

        const now = Date.now();
        await ctx.db.patch(args.itemId, {
            status: "read",
            readAt: now,
            updatedAt: now,
        });
    },
});

export const archiveItem = mutation({
    args: { itemId: v.id("items") },
    handler: async (ctx, args) => {
        const item = await ctx.db.get(args.itemId);
        if (!item) throw new Error("Item not found");

        await ctx.db.patch(args.itemId, {
            status: "archived",
            updatedAt: Date.now(),
        });
    },
});

export const snoozeItem = mutation({
    args: {
        itemId: v.id("items"),
        durationMs: v.number(),
    },
    handler: async (ctx, args) => {
        const item = await ctx.db.get(args.itemId);
        if (!item) throw new Error("Item not found");

        const now = Date.now();
        await ctx.db.patch(args.itemId, {
            snoozedUntil: now + args.durationMs,
            updatedAt: now,
        });
    },
});

export const deleteItem = mutation({
    args: { itemId: v.id("items") },
    handler: async (ctx, args) => {
        await ctx.db.delete(args.itemId);
    },
});

export const searchItems = query({
    args: { searchTerm: v.string() },
    handler: async (ctx, args) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) throw new Error("Unauthenticated");

        const user = await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .first();

        if (!user) throw new Error("User not found");

        return await ctx.db
            .query("items")
            .withSearchIndex("search_items", (q) =>
                q.search("title", args.searchTerm).eq("userId", user._id)
            )
            .take(20);
    },
});

export const getItemsSince = query({
    args: { since: v.optional(v.number()) },
    handler: async (ctx, args) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) throw new Error("Unauthenticated");

        const user = await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .first();

        if (!user) throw new Error("User not found");

        let query = ctx.db
            .query("items")
            .withIndex("by_user_status", (q) => q.eq("userId", user._id))
            .order("desc");

        if (args.since && args.since > 0) {
            query = query.filter((q) => q.gt(q.field("updatedAt"), args.since as number));
        }

        return await query.take(100);
    },
});
