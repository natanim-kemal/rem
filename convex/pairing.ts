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
        const expiresAt = Date.now() + 7 * 24 * 60 * 60 * 1000;

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
        refreshSecret: v.string(),
    },
    handler: async (ctx, args) => {
        if (!args.token || args.token.trim() === "") {
            throw new Error("Token is required");
        }

        if (!args.refreshSecret || args.refreshSecret.trim() === "") {
            throw new Error("Refresh secret is required");
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

            if (existingCode.status === "approved" || existingCode.status === "claimed") {
                return { success: true, message: "Already approved" };
            }

            if (existingCode.status === "expired" || existingCode.expiresAt < Date.now()) {
                throw new Error("Code expired");
            }

            await ctx.db.patch(existingCode._id, { 
                status: "approved",
                token: args.token,
                refreshSecret: args.refreshSecret
            });
        } else {
            const expiresAt = Date.now() + 7 * 24 * 60 * 60 * 1000;
            await ctx.db.insert("pairingCodes", {
                code: args.code,
                userId: user._id,
                status: "approved",
                token: args.token,
                refreshSecret: args.refreshSecret,
                expiresAt,
                createdAt: Date.now(),
            });
        }

        return { success: true };
    },
});

export const claimPairingCredentials = mutation({
    args: {
        code: v.string(),
    },
    handler: async (ctx, args) => {
        const pairingRecord = await ctx.db
            .query("pairingCodes")
            .withIndex("by_code", (q) => q.eq("code", args.code))
            .first();

        if (!pairingRecord) {
            throw new Error("Invalid code");
        }

        if (pairingRecord.status === "expired" || pairingRecord.expiresAt < Date.now()) {
            throw new Error("Code expired");
        }

        if (pairingRecord.status === "claimed") {
            throw new Error("Code already used");
        }

        if (pairingRecord.status !== "approved") {
            throw new Error("Pairing not approved yet");
        }

        if (!pairingRecord.token || !pairingRecord.refreshSecret) {
            throw new Error("Pairing incomplete. Please re-link.");
        }

        await ctx.db.patch(pairingRecord._id, {
            status: "claimed",
        });

        return {
            success: true,
            refreshSecret: pairingRecord.refreshSecret,
            token: pairingRecord.token,
            expiresAt: pairingRecord.expiresAt,
        };
    },
});

export const refreshPairingTokens = mutation({
    args: {
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

        const now = Date.now();
        const expiresAt = now + 7 * 24 * 60 * 60 * 1000;

        const pairings = await ctx.db
            .query("pairingCodes")
            .filter((q) => q.eq(q.field("userId"), user._id))
            .collect();

        let updated = 0;
        for (const pairing of pairings) {
            if (pairing.status !== "approved" && pairing.status !== "claimed") continue;
            await ctx.db.patch(pairing._id, {
                token: args.token,
                expiresAt,
            });
            updated++;
        }

        return { success: true, updatedCount: updated };
    },
});

export const getPairingToken = query({
    args: {
        refreshSecret: v.string(),
    },
    handler: async (ctx, args) => {
        const pairingRecord = await ctx.db
            .query("pairingCodes")
            .withIndex("by_refresh_secret", (q) => q.eq("refreshSecret", args.refreshSecret))
            .first();

        if (!pairingRecord) {
            return { valid: false, reason: "invalid" };
        }

        if (pairingRecord.status === "expired" || pairingRecord.expiresAt < Date.now()) {
            return { valid: false, reason: "expired" };
        }

        if (pairingRecord.status !== "approved" && pairingRecord.status !== "claimed") {
            return { valid: false, reason: "not_active" };
        }

        if (!pairingRecord.token) {
            return { valid: false, reason: "no_token" };
        }

        return {
            valid: true,
            token: pairingRecord.token,
            expiresAt: pairingRecord.expiresAt,
        };
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
            status: pairingRecord.status
        };
    },
});

export const getLinkedDevices = query({
    args: {},
    handler: async (ctx) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) throw new Error("Unauthenticated");

        const user = await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .first();

        if (!user) throw new Error("User not found");

        const now = Date.now();
        const allPairings = await ctx.db
            .query("pairingCodes")
            .filter((q) => q.eq(q.field("userId"), user._id))
            .collect();

        const validPairings = allPairings.filter(
            (p) => (p.status === "approved" || p.status === "claimed") && p.expiresAt > now
        );

        return validPairings.map((p) => ({
            code: p.code,
            status: p.status,
            expiresAt: p.expiresAt,
            createdAt: p.createdAt,
        }));
    },
});

export const revokeAllDevices = mutation({
    args: {},
    handler: async (ctx) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) throw new Error("Unauthenticated");

        const user = await ctx.db
            .query("users")
            .withIndex("by_clerk_id", (q) => q.eq("clerkId", identity.subject))
            .first();

        if (!user) throw new Error("User not found");

        const allPairings = await ctx.db
            .query("pairingCodes")
            .filter((q) => q.eq(q.field("userId"), user._id))
            .collect();

        for (const pairing of allPairings) {
            await ctx.db.delete(pairing._id);
        }

        return { success: true, revokedCount: allPairings.length };
    },
});
