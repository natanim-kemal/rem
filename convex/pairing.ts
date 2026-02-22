import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

function generateCode(): string {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 8; i++) {
        if (i === 4) code += '-';
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
}

export const startPairing = mutation({
    args: {},
    handler: async (ctx) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) throw new Error("Unauthenticated");

        const user = await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .first();

        if (!user) throw new Error("User not found");

        const existingPending = await ctx.db
            .query("pairingCodes")
            .withIndex("by_code")
            .filter((q) => q.and(
                q.eq(q.field("userId"), user._id),
                q.eq(q.field("status"), "pending")
            ))
            .first();

        if (existingPending) {
            const now = Date.now();
            if (existingPending.expiresAt > now) {
                return { code: existingPending.code };
            } else {
                await ctx.db.patch(existingPending._id, { status: "expired" });
            }
        }

        const code = generateCode();
        const expiresAt = Date.now() + 5 * 60 * 1000;

        await ctx.db.insert("pairingCodes", {
            code,
            userId: user._id,
            status: "pending",
            expiresAt,
            createdAt: Date.now(),
        });

        return { code };
    },
});

export const approvePairing = mutation({
    args: {
        code: v.string(),
        deviceName: v.string(),
        token: v.string(),
    },
    handler: async (ctx, args) => {
        if (!args.token || args.token.trim() === "") {
            throw new Error("Token is required");
        }

        const identity = await ctx.auth.getUserIdentity();
        if (!identity) throw new Error("Unauthenticated");

        const user = await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .first();

        if (!user) throw new Error("User not found");

        const existingCode = await ctx.db
            .query("pairingCodes")
            .withIndex("by_code", (q) => q.eq("code", args.code))
            .first();

        if (existingCode) {
            if (existingCode.userId.toString() !== user._id.toString()) {
                throw new Error("Invalid code");
            }

            if (existingCode.status === "approved") {
                return { success: true, message: "Already approved" };
            }

            if (existingCode.status === "expired" || existingCode.expiresAt < Date.now()) {
                throw new Error("Code expired");
            }

            await ctx.db.patch(existingCode._id, { 
                status: "approved",
                token: args.token 
            });
        } else {
            const expiresAt = Date.now() + 5 * 60 * 1000;
            await ctx.db.insert("pairingCodes", {
                code: args.code,
                userId: user._id,
                status: "approved",
                token: args.token,
                expiresAt,
                createdAt: Date.now(),
            });
        }

        return { success: true };
    },
});

export const getPairingStatus = query({
    args: {
        code: v.string(),
    },
    handler: async (ctx, args) => {
        const pairingRecord = await ctx.db
            .query("pairingCodes")
            .withIndex("by_code", (q) => q.eq("code", args.code))
            .first();

        if (!pairingRecord) {
            return { status: "invalid" };
        }

        if (pairingRecord.status === "expired" || pairingRecord.expiresAt < Date.now()) {
            return { status: "expired" };
        }

        return { 
            status: pairingRecord.status,
            token: pairingRecord.status === "approved" ? pairingRecord.token : null
        };
    },
});
