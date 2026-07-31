import { internalMutation, internalQuery } from "../_generated/server";
import { v } from "convex/values";

export const getUserByClerkId = internalQuery({
  args: { clerkId: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("users")
      .withIndex("by_clerk_id", (q) => q.eq("clerkId", args.clerkId))
      .first();
  },
});

export const getItemById = internalQuery({
  args: { itemId: v.id("items") },
  handler: async (ctx, args) => {
    return await ctx.db.get(args.itemId);
  },
});

export const getChatContent = internalQuery({
  args: { url: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("chatContent")
      .withIndex("by_url", (q) => q.eq("url", args.url))
      .first();
  },
});

export const setChatContent = internalMutation({
  args: { url: v.string(), text: v.string() },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("chatContent")
      .withIndex("by_url", (q) => q.eq("url", args.url))
      .first();
    const now = Date.now();
    if (existing) {
      await ctx.db.patch(existing._id, { text: args.text, fetchedAt: now });
    } else {
      await ctx.db.insert("chatContent", {
        url: args.url,
        text: args.text,
        fetchedAt: now,
      });
    }
  },
});

export const countActiveStreams = internalQuery({
  args: { userId: v.id("users"), cutoff: v.number() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("chatStreams")
      .withIndex("by_user_started", (q) => q.eq("userId", args.userId))
      .filter((q) => q.gt(q.field("startedAt"), args.cutoff))
      .count();
  },
});

export const startChatStream = internalMutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db.insert("chatStreams", {
      userId: args.userId,
      startedAt: Date.now(),
    });
  },
});

export const endChatStream = internalMutation({
  args: { id: v.id("chatStreams") },
  handler: async (ctx, args) => {
    await ctx.db.delete(args.id);
  },
});
