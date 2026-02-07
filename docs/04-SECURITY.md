# rem - Security Guidelines

> Security best practices and implementation guidelines for the rem application (Convex + Clerk)

---

## 1. Security Principles

| Principle | Description |
|-----------|-------------|
| **Defense in Depth** | Multiple security layers, never rely on one |
| **Least Privilege** | Grant minimum permissions needed |
| **Secure by Default** | Security ON by default, opt-out if needed |
| **Fail Securely** | Errors should not expose sensitive data |
| **Zero Trust** | Verify everything, trust nothing |

---

## 2. Authentication & Authorization (Clerk + Convex)

### Authentication Flow

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│  Client  │────▶│  Clerk   │────▶│  Convex  │
│  (App)   │     │  (Auth)  │     │(Backend) │
└──────────┘     └──────────┘     └──────────┘
     │                │                 │
     │  1. Login      │                 │
     │───────────────▶│                 │
     │                │                 │
     │  2. JWT Token  │                 │
     │◀───────────────│                 │
     │                │                 │
     │  3. Query with JWT              │
     │─────────────────────────────────▶│
     │                │                 │
     │                │  4. Validate    │
     │                │◀────────────────│
     │                │                 │
     │  5. Data                         │
     │◀─────────────────────────────────│
```

### Implementation

```typescript
// convex/auth.config.ts
export default {
  providers: [
    {
      domain: "https://your-clerk-instance.clerk.accounts.dev",
      applicationID: "convex",
    },
  ],
};
```

```typescript
// Every Convex function validates auth
export const getItems = query({
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new Error("Unauthenticated");
    }
    // identity.subject = Clerk user ID
    // identity.email, identity.name, etc.
  },
});
```

### Authorization Requirements

| Requirement | Implementation |
|-------------|----------------|
| **All queries check auth** | `ctx.auth.getUserIdentity()` at start of every function |
| **Data isolation** | Filter by `userId` in every query |
| **No cross-user access** | Index queries always include `userId` |
| **Token validation** | Convex validates Clerk JWT automatically |

---

## 3. Data Protection

### How Convex Secures Data

| Layer | Protection |
|-------|------------|
| **At Rest** | AES-256 encryption (AWS RDS) |
| **In Transit** | TLS 1.3 enforced |
| **Backups** | Automatic, encrypted |
| **Isolation** | Per-deployment data isolation |

### Sensitive Data Handling

```dart
// ✅ DO: Use flutter_secure_storage on mobile
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();

// Store Clerk session securely
await storage.write(key: 'clerk_token', value: token);

// Read securely
final token = await storage.read(key: 'clerk_token');

// ❌ DON'T: Store in SharedPreferences
import 'package:shared_preferences/shared_preferences.dart';
// SharedPreferences is NOT secure for tokens!
```

### Data Classification

| Level | Examples | Handling |
|-------|----------|----------|
| **Public** | App version | No restrictions |
| **Internal** | Item titles | Auth required, encrypted |
| **Confidential** | Email, preferences | Auth + userId filter |
| **Restricted** | Auth tokens | Secure enclave only |

---

## 4. Input Validation (Convex Validators)

Convex provides built-in type validation:

```typescript
import { mutation } from "./_generated/server";
import { v } from "convex/values";

export const createItem = mutation({
  // Schema validation - rejects invalid input automatically
  args: {
    url: v.optional(v.string()),
    title: v.string(),
    type: v.union(
      v.literal("link"),
      v.literal("image"),
      v.literal("book")
    ),
    priority: v.optional(
      v.union(v.literal("high"), v.literal("medium"), v.literal("low"))
    ),
    tags: v.optional(v.array(v.string())),
  },
  handler: async (ctx, args) => {
    // Additional validation
    if (args.url) {
      validateUrl(args.url); // Custom SSRF check
    }
    
    if (args.title.length > 500) {
      throw new Error("Title too long");
    }
    
    // ... create item
  },
});
```

### Custom Validators

```typescript
// convex/lib/validators.ts
export function validateUrl(url: string): void {
  const parsed = new URL(url);
  
  // Block internal networks (SSRF prevention)
  const blockedHosts = [
    'localhost',
    '127.0.0.1',
    '0.0.0.0',
    '169.254.',
    '10.',
    '172.16.',
    '192.168.',
  ];
  
  if (blockedHosts.some(h => parsed.hostname.includes(h))) {
    throw new Error("Invalid URL: internal network not allowed");
  }
  
  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new Error("Invalid URL: only HTTP(S) allowed");
  }
}
```

---

## 5. API Security

### Convex Function Types

| Type | Security Properties |
|------|---------------------|
| **Query** | Read-only, deterministic, no side effects |
| **Mutation** | ACID transactions, automatic retry on conflict |
| **Action** | Can call external APIs, run in isolated environment |
| **Internal** | Only callable from other Convex functions |

### Rate Limiting

Convex has built-in rate limiting, but add application-level limits for expensive operations:

```typescript
// convex/notifications.ts (planned)
export const sendTestNotification = action({
  args: { itemId: v.id("items") },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthenticated");

    // Check rate limit
    const recentNotifs = await ctx.runQuery(
      internal.notifications.getRecentForUser,
      { userId: identity.subject, minutes: 60 }
    );
    
    if (recentNotifs.length >= 10) {
      throw new Error("Rate limit exceeded: max 10 notifications per hour");
    }
    
    // ... send notification (respect quiet hours + per-user daily cap)
  },
});
```

### Security Headers (Web App)

```typescript
// vite.config.ts or vercel.json
export const securityHeaders = {
  'Content-Security-Policy': `
    default-src 'self';
    script-src 'self' 'unsafe-inline' https://clerk.com;
    style-src 'self' 'unsafe-inline';
    img-src 'self' data: https:;
    connect-src 'self' https://*.convex.cloud https://clerk.com;
    frame-ancestors 'none';
  `.replace(/\s+/g, ' '),
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
};
```

---

## 6. Secret Management

### Environment Variables

| Environment | Storage | Access |
|-------------|---------|--------|
| **Local Dev** | `.env.local` | Developer only |
| **CI/CD** | GitHub Secrets | Workflow only |
| **Production** | Convex Dashboard + Vercel | Service only |

### Convex Environment Variables

```bash
# Set via CLI
npx convex env set FCM_SERVER_KEY "your-key"
npx convex env set GEMINI_API_KEY "your-key"

# Access in actions (not queries/mutations)
const apiKey = process.env.GEMINI_API_KEY;
```

### Never Commit Secrets

```gitignore
# .gitignore
.env
.env.local
.env.production
*.pem
*.key
```

---

## 7. OWASP Top 10 Checklist

| Risk | Status | Mitigation |
|------|--------|------------|
| **A01: Broken Access Control** | ✅ | Auth check in every function, userId filtering |
| **A02: Cryptographic Failures** | ✅ | TLS everywhere, Convex encrypts at rest |
| **A03: Injection** | ✅ | Convex validators, no raw SQL |
| **A04: Insecure Design** | ✅ | Clerk for auth, Convex for data isolation |
| **A05: Security Misconfiguration** | ✅ | No debug in prod, secure defaults |
| **A06: Vulnerable Components** | ✅ | Dependabot, regular audits |
| **A07: Auth Failures** | ✅ | Clerk handles auth, rate limiting |
| **A08: Data Integrity Failures** | ✅ | Convex validators, typed schema |
| **A09: Logging Failures** | ✅ | Convex logs (no PII), Sentry |
| **A10: SSRF** | ✅ | URL validation in actions |

---

## 8. Mobile-Specific Security (Flutter)

### Secure Token Storage

```dart
// lib/core/auth/secure_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  final FlutterSecureStorage _storage;

  SecureTokenStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
        );

  Future<String?> getToken() async {
    return _storage.read(key: 'clerk_token');
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'clerk_token', value: token);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'clerk_token');
  }
}
```

### Deep Link Validation (go_router)

```dart
// lib/core/router/deep_link_guard.dart
import 'package:go_router/go_router.dart';

class DeepLinkValidator {
  static const _allowedSchemes = ['rem', 'https'];
  static const _allowedHosts = ['app.rem.dev'];

  static bool isValid(Uri uri) {
    if (uri.scheme == 'rem') return true;
    if (uri.scheme == 'https' && _allowedHosts.contains(uri.host)) {
      return true;
    }
    return false;
  }
}

// In router configuration
final router = GoRouter(
  redirect: (context, state) {
    final uri = Uri.parse(state.uri.toString());
    if (!DeepLinkValidator.isValid(uri)) {
      return '/'; // Redirect invalid deep links to home
    }
    return null;
  },
  routes: [...],
);
```

---

## 9. Incident Response

### Severity Levels

| Level | Description | Response Time | Example |
|-------|-------------|---------------|---------|
| **P0** | Critical, data breach | <1 hour | Auth bypass |
| **P1** | High, service down | <4 hours | Convex outage |
| **P2** | Medium, degraded | <24 hours | Slow queries |
| **P3** | Low, minor issue | <1 week | UI bug |

### Response Checklist

```markdown
## Incident: [TITLE]
- [ ] Identify and contain
- [ ] Assess impact
- [ ] Notify stakeholders
- [ ] Fix and deploy
- [ ] Post-mortem
- [ ] Preventive measures
```

---

## 10. Security Review Checklist

Before each release:

- [ ] All functions check authentication
- [ ] Queries filter by userId
- [ ] No console.log with sensitive data
- [ ] Dependencies audited
- [ ] Environment variables not in code
- [ ] HTTPS enforced
- [ ] Error messages don't leak internals
- [ ] Rate limiting on expensive operations

---

## 11. Compliance

| Standard | Status | Notes |
|----------|--------|-------|
| **GDPR** | ✅ | Data export/deletion via Convex |
| **SOC 2** | ✅ | Convex is SOC 2 Type II compliant |
| **HIPAA** | ✅ | Convex is HIPAA compliant |

---

*Document Version: 2.0 (Convex + Clerk)*  
*Last Updated: 2026-02-02*
