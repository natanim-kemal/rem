import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";

const http = httpRouter();

http.route({
    path: "/items",
    method: "POST",
    handler: httpAction(async (ctx, request) => {
        try {
            const authHeader = request.headers.get("Authorization");
            if (!authHeader || !authHeader.startsWith("Bearer ")) {
                return new Response(JSON.stringify({ error: "Unauthorized" }), {
                    status: 401,
                    headers: { "Content-Type": "application/json" },
                });
            }

            const identity = await ctx.auth.getUserIdentity();
            if (!identity) {
                return new Response(JSON.stringify({ error: "Invalid token" }), {
                    status: 401,
                    headers: { "Content-Type": "application/json" },
                });
            }

            let body;
            try {
                body = await request.json();
            } catch (e) {
                return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
                    status: 400,
                    headers: { "Content-Type": "application/json" },
                });
            }

            if (!body.title || typeof body.title !== "string" || body.title.trim().length === 0) {
                return new Response(JSON.stringify({ error: "Title is required" }), {
                    status: 400,
                    headers: { "Content-Type": "application/json" },
                });
            }

            if (body.title.length > 200) {
                return new Response(JSON.stringify({ error: "Title too long (max 200 chars)" }), {
                    status: 400,
                    headers: { "Content-Type": "application/json" },
                });
            }

            if (!body.type || !["link", "image", "video", "book", "note"].includes(body.type)) {
                return new Response(JSON.stringify({ error: "Valid type is required" }), {
                    status: 400,
                    headers: { "Content-Type": "application/json" },
                });
            }

            if (body.url !== undefined) {
                if (typeof body.url !== "string") {
                    return new Response(JSON.stringify({ error: "URL must be a string" }), {
                        status: 400,
                        headers: { "Content-Type": "application/json" },
                    });
                }
                if (body.url.length > 2048) {
                    return new Response(JSON.stringify({ error: "URL too long (max 2048 chars)" }), {
                        status: 400,
                        headers: { "Content-Type": "application/json" },
                    });
                }
                try {
                    const url = new URL(body.url);
                    if (!["http:", "https:"].includes(url.protocol)) {
                        return new Response(JSON.stringify({ error: "Invalid URL scheme" }), {
                            status: 400,
                            headers: { "Content-Type": "application/json" },
                        });
                    }
                } catch (e) {
                    return new Response(JSON.stringify({ error: "Invalid URL format" }), {
                        status: 400,
                        headers: { "Content-Type": "application/json" },
                    });
                }
            }

            if (body.description !== undefined) {
                if (typeof body.description !== "string" || body.description.length > 2000) {
                    return new Response(JSON.stringify({ error: "Description too long (max 2000 chars)" }), {
                        status: 400,
                        headers: { "Content-Type": "application/json" },
                    });
                }
            }

            if (body.thumbnailUrl !== undefined) {
                if (typeof body.thumbnailUrl !== "string" || body.thumbnailUrl.length > 2048) {
                    return new Response(JSON.stringify({ error: "Thumbnail URL too long" }), {
                        status: 400,
                        headers: { "Content-Type": "application/json" },
                    });
                }
            }

            if (body.priority !== undefined) {
                if (!["high", "medium", "low"].includes(body.priority)) {
                    return new Response(JSON.stringify({ error: "Invalid priority" }), {
                        status: 400,
                        headers: { "Content-Type": "application/json" },
                    });
                }
            }

            if (body.tags !== undefined) {
                if (!Array.isArray(body.tags) || body.tags.length > 50) {
                    return new Response(JSON.stringify({ error: "Invalid tags (max 50)" }), {
                        status: 400,
                        headers: { "Content-Type": "application/json" },
                    });
                }
                for (const tag of body.tags) {
                    if (typeof tag !== "string" || tag.length > 15) {
                        return new Response(JSON.stringify({ error: "Invalid tag format (max 15 chars)" }), {
                            status: 400,
                            headers: { "Content-Type": "application/json" },
                        });
                    }
                }
            }

            const user = await ctx.db
                .query("users")
                .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
                .first();

            if (!user) {
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
                        timezoneOffsetMinutes: 0,
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

                var newUser = await ctx.db.get(userId);
                if (!newUser) throw new Error("Failed to create user");
                var currentUser = newUser;
            } else {
                var currentUser = user;
            }

            const now = Date.now();

            if (body.url) {
                const existing = await ctx.db
                    .query("items")
                    .withIndex("by_user_status", (q) => q.eq("userId", currentUser._id))
                    .filter((q) => q.eq(q.field("url"), body.url))
                    .first();

                if (existing) {
                    return new Response(
                        JSON.stringify({ error: "Item with this URL already exists" }),
                        {
                            status: 409,
                            headers: { "Content-Type": "application/json" },
                        }
                    );
                }
            }

            const itemId = await ctx.db.insert("items", {
                userId: currentUser._id,
                type: body.type,
                url: body.url,
                title: body.title,
                description: body.description,
                thumbnailUrl: body.thumbnailUrl,
                priority: body.priority ?? "medium",
                tags: body.tags ?? [],
                status: "unread",
                remindCount: 0,
                visibility: "private",
                syncStatus: "synced",
                createdAt: now,
                updatedAt: now,
            });

            const stats = await ctx.db
                .query("userStats")
                .withIndex("by_user", (q) => q.eq("userId", currentUser._id))
                .first();

            if (stats) {
                await ctx.db.patch(stats._id, {
                    itemsSavedTotal: stats.itemsSavedTotal + 1,
                    itemsSavedThisWeek: stats.itemsSavedThisWeek + 1,
                    updatedAt: now,
                });
            }

            return new Response(
                JSON.stringify({
                    success: true,
                    itemId: itemId.toString(),
                }),
                {
                    status: 201,
                    headers: { "Content-Type": "application/json" },
                }
            );
        } catch (error) {
            return new Response(
                JSON.stringify({ error: "Internal server error" }),
                {
                    status: 500,
                    headers: { "Content-Type": "application/json" },
                }
            );
        }
    }),
});

http.route({
    path: "/users/me",
    method: "GET",
    handler: httpAction(async (ctx, request) => {
        try {
            const authHeader = request.headers.get("Authorization");
            if (!authHeader || !authHeader.startsWith("Bearer ")) {
                return new Response(JSON.stringify({ error: "Unauthorized" }), {
                    status: 401,
                    headers: { "Content-Type": "application/json" },
                });
            }

            const identity = await ctx.auth.getUserIdentity();
            if (!identity) {
                return new Response(JSON.stringify({ error: "Invalid token" }), {
                    status: 401,
                    headers: { "Content-Type": "application/json" },
                });
            }

            const user = await ctx.db
                .query("users")
                .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
                .first();

            if (!user) {
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
                        timezoneOffsetMinutes: 0,
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

                return new Response(
                    JSON.stringify({
                        id: userId.toString(),
                        email: identity.email ?? "",
                        displayName: identity.name,
                        isPremium: false,
                        created: true,
                    }),
                    {
                        status: 200,
                        headers: { "Content-Type": "application/json" },
                    }
                );
            }

            return new Response(
                JSON.stringify({
                    id: user._id.toString(),
                    email: user.email,
                    displayName: user.displayName,
                    isPremium: user.isPremium,
                }),
                {
                    status: 200,
                    headers: { "Content-Type": "application/json" },
                }
            );
        } catch (error) {
            return new Response(
                JSON.stringify({ error: "Internal server error" }),
                {
                    status: 500,
                    headers: { "Content-Type": "application/json" },
                }
            );
        }
    }),
});

export default http;
