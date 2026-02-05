import { httpAction } from "./_generated/server";

export const createItem = httpAction(async (ctx, request) => {
    if (request.method !== "POST") {
        return new Response(JSON.stringify({ error: "Method not allowed" }), {
            status: 405,
            headers: { "Content-Type": "application/json" },
        });
    }

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

        const body = await request.json();

        if (!body.title) {
            return new Response(JSON.stringify({ error: "Title is required" }), {
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

        const user = await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .first();

        if (!user) {
            return new Response(JSON.stringify({ error: "User not found" }), {
                status: 404,
                headers: { "Content-Type": "application/json" },
            });
        }

        const now = Date.now();

        if (body.url) {
            const existing = await ctx.db
                .query("items")
                .withIndex("by_user_status", (q) => q.eq("userId", user._id))
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
            userId: user._id,
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
            .withIndex("by_user", (q) => q.eq("userId", user._id))
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
        console.error("Error creating item:", error);
        return new Response(
            JSON.stringify({ error: "Internal server error" }),
            {
                status: 500,
                headers: { "Content-Type": "application/json" },
            }
        );
    }
});

export const getCurrentUser = httpAction(async (ctx, request) => {
    if (request.method !== "GET") {
        return new Response(JSON.stringify({ error: "Method not allowed" }), {
            status: 405,
            headers: { "Content-Type": "application/json" },
        });
    }

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
            return new Response(JSON.stringify({ error: "User not found" }), {
                status: 404,
                headers: { "Content-Type": "application/json" },
            });
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
        console.error("Error getting user:", error);
        return new Response(
            JSON.stringify({ error: "Internal server error" }),
            {
                status: 500,
                headers: { "Content-Type": "application/json" },
            }
        );
    }
});
