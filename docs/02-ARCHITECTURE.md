# rem - System Architecture

> Technical architecture and system design for the rem application (Flutter + Convex)

---

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENT LAYER                             │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Flutter App                           │    │
│  │            (iOS, Android, Web - Single Codebase)         │    │
│  └─────────────────────────┬───────────────────────────────┘    │
│                            │                                     │
│  ┌─────────────┐           │           ┌─────────────────────┐  │
│  │   Web App   │           │           │ Browser Extension   │  │
│  │  (Flutter)  │           │           │   (JS/Dart)         │  │
│  └──────┬──────┘           │           └───────────┬─────────┘  │
└─────────┼──────────────────┼───────────────────────┼────────────┘
          │                  │                       │
          └──────────────────┼───────────────────────┘
                             │ HTTPS (REST/WebSocket)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     CONVEX PLATFORM                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   Queries   │  │  Mutations  │  │        Actions          │  │
│  │ (Real-time) │  │(Transactions│  │   (External APIs)       │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
│                           │                                      │
│                    ┌──────┴──────┐                              │
│                    │  Database   │                              │
│                    │ (Document-  │                              │
│                    │ Relational) │                              │
│                    └─────────────┘                              │
└─────────────────────────────────────────────────────────────────┘
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
┌─────────────────┐ ┌─────────────┐ ┌────────────────┐
│   Clerk Auth    │ │    FCM      │ │   Gemini API   │
│ (Authentication)│ │(Push Notifs)│ │ (AI/Summaries) │
└─────────────────┘ └─────────────┘ └────────────────┘
```

---

## 2. Tech Stack

### Frontend (Flutter)

| Component | Choice | Rationale |
|-----------|--------|-----------|
| **Framework** | Flutter 3.x | Single codebase for iOS, Android, Web |
| **Language** | Dart | Type-safe, fast compilation, great DX |
| **State Management** | Riverpod | Compile-safe, testable, scalable |
| **Routing** | go_router | Declarative, deep-linking support |
| **HTTP Client** | dio | Interceptors, retry, better than http |
| **Local Storage** | flutter_secure_storage | Encrypted token storage |
| **UI Components** | Material 3 + Custom | Modern, customizable |

### Backend (Convex + Offline)

| Component | Choice | Rationale |
|-----------|--------|-----------|
| **Cloud Backend** | Convex | Real-time sync, TypeScript-first |
| **Local Database** | Drift (SQLite) | Offline-first, fast queries |
| **Sync Engine** | Custom (Drift ↔ Convex) | Conflict resolution |
| **Authentication** | Clerk | 80+ OAuth providers |
| **File Storage** | Convex Storage | Built-in, simple API |
| **Scheduled Jobs** | Convex Cron | Native support |

### External Services

| Service | Purpose | Provider |
|---------|---------|----------|
| **Push Notifications** | Reminders | Firebase Cloud Messaging |
| **AI/ML** | Categorization, summaries | Google Gemini API |
| **Voice Recognition** | "Hey rem" commands | Google Speech-to-Text / ML Kit |
| **Analytics** | Usage tracking | PostHog / Firebase Analytics |
| **Error Tracking** | Crash reporting | Sentry / Crashlytics |

---

## 3. Flutter Project Structure

```
rem/
├── apps/
│   └── mobile/                     # Flutter app (iOS, Android, Web)
│       ├── lib/
│       │   ├── main.dart           # Entry point
│       │   ├── app.dart            # App widget & routing
│       │   │
│       │   ├── core/               # Core utilities
│       │   │   ├── config/         # Environment config
│       │   │   ├── constants/      # App constants
│       │   │   ├── errors/         # Error handling
│       │   │   ├── network/        # HTTP client, interceptors
│       │   │   └── utils/          # Helper functions
│       │   │
│       │   ├── data/               # Data layer
│       │   │   ├── models/         # Data models (freezed)
│       │   │   ├── repositories/   # Repository implementations
│       │   │   └── services/       # API services (Convex client)
│       │   │
│       │   ├── domain/             # Business logic
│       │   │   ├── entities/       # Domain entities
│       │   │   ├── repositories/   # Repository interfaces
│       │   │   └── usecases/       # Use cases
│       │   │
│       │   ├── presentation/       # UI layer
│       │   │   ├── providers/      # Riverpod providers
│       │   │   ├── screens/        # Screen widgets
│       │   │   ├── widgets/        # Reusable widgets
│       │   │   └── theme/          # App theme
│       │   │
│       │   └── l10n/               # Localization
│       │
│       ├── test/                   # Tests
│       ├── android/                # Android native
│       ├── ios/                    # iOS native
│       ├── web/                    # Web specific
│       └── pubspec.yaml            # Dependencies
│
├── convex/                         # Convex backend
│   ├── schema.ts                   # Database schema
│   ├── items.ts                    # Item functions
│   ├── users.ts                    # User functions
│   ├── notifications.ts            # Notification logic + FCM dispatch
│   ├── crons.ts                    # Scheduler (priority cadence + quiet hours)
│   ├── http.ts                     # HTTP endpoints for Flutter
│   └── _generated/                 # Auto-generated
│
├── docs/                           # Documentation
└── .github/                        # CI/CD
```

---

## 4. Convex HTTP API for Flutter

Since Convex doesn't have an official Flutter SDK, we'll use HTTP endpoints:

### HTTP Router (Convex)

```typescript
// convex/http.ts
import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { api } from "./_generated/api";

const http = httpRouter();

// Query endpoint
http.route({
  path: "/api/items",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const token = request.headers.get("Authorization")?.replace("Bearer ", "");
    if (!token) {
      return new Response("Unauthorized", { status: 401 });
    }

    // Validate Clerk token and get user
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      return new Response("Invalid token", { status: 401 });
    }

    const items = await ctx.runQuery(api.items.getItems, {});
    return new Response(JSON.stringify(items), {
      headers: { "Content-Type": "application/json" },
    });
  }),
});

// Mutation endpoint
http.route({
  path: "/api/items",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      return new Response("Unauthorized", { status: 401 });
    }

    const body = await request.json();
    const itemId = await ctx.runMutation(api.items.createItem, body);
    return new Response(JSON.stringify({ id: itemId }), {
      headers: { "Content-Type": "application/json" },
    });
  }),
});

export default http;
```

### Flutter Convex Client

```dart
// lib/data/services/convex_client.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ConvexClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  
  ConvexClient({required String baseUrl})
      : _dio = Dio(BaseOptions(baseUrl: baseUrl)),
        _storage = const FlutterSecureStorage() {
    _dio.interceptors.add(_AuthInterceptor(_storage));
  }

  // Query items
  Future<List<Item>> getItems({String? status}) async {
    final response = await _dio.get('/api/items', queryParameters: {
      if (status != null) 'status': status,
    });
    return (response.data as List).map((e) => Item.fromJson(e)).toList();
  }

  // Create item
  Future<String> createItem(CreateItemRequest request) async {
    final response = await _dio.post('/api/items', data: request.toJson());
    return response.data['id'];
  }

  // Mark as read
  Future<void> markAsRead(String itemId) async {
    await _dio.patch('/api/items/$itemId', data: {'status': 'read'});
  }
}

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  
  _AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'clerk_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
```

---

## 5. Data Models (Flutter)

```dart
// lib/data/models/item.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'item.freezed.dart';
part 'item.g.dart';

enum ItemType { link, image, video, book, note }
enum ItemStatus { unread, inProgress, read, archived }
enum Priority { high, medium, low }

@freezed
class Item with _$Item {
  const factory Item({
    required String id,
    required String userId,
    required ItemType type,
    required String title,
    String? url,
    String? description,
    String? thumbnailUrl,
    int? estimatedReadTime,
    required Priority priority,
    required List<String> tags,
    required ItemStatus status,
    DateTime? readAt,
    DateTime? snoozedUntil,
    required int remindCount,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Item;

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
}

@freezed
class CreateItemRequest with _$CreateItemRequest {
  const factory CreateItemRequest({
    required String title,
    String? url,
    required ItemType type,
    @Default(Priority.medium) Priority priority,
    @Default([]) List<String> tags,
  }) = _CreateItemRequest;

  factory CreateItemRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateItemRequestFromJson(json);
}
```

---

## 6. State Management (Riverpod)

```dart
// lib/presentation/providers/items_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'items_provider.g.dart';

@riverpod
ConvexClient convexClient(ConvexClientRef ref) {
  return ConvexClient(baseUrl: Environment.convexUrl);
}

@riverpod
class ItemsNotifier extends _$ItemsNotifier {
  @override
  Future<List<Item>> build() async {
    return ref.read(convexClientProvider).getItems();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(convexClientProvider).getItems());
  }

  Future<void> addItem(CreateItemRequest request) async {
    await ref.read(convexClientProvider).createItem(request);
    await refresh();
  }

  Future<void> markAsRead(String itemId) async {
    await ref.read(convexClientProvider).markAsRead(itemId);
    await refresh();
  }
}

// Filter provider
@riverpod
class ItemFilter extends _$ItemFilter {
  @override
  ItemStatus? build() => null;

  void setFilter(ItemStatus? status) => state = status;
}

// Filtered items
@riverpod
Future<List<Item>> filteredItems(FilteredItemsRef ref) async {
  final items = await ref.watch(itemsNotifierProvider.future);
  final filter = ref.watch(itemFilterProvider);
  
  if (filter == null) return items;
  return items.where((item) => item.status == filter).toList();
}
```

---

## 7. Authentication (Clerk + Flutter)

```dart
// lib/core/auth/clerk_auth.dart
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ClerkAuthService {
  final ClerkClient _clerk;
  final FlutterSecureStorage _storage;

  ClerkAuthService({required String publishableKey})
      : _clerk = ClerkClient(publishableKey: publishableKey),
        _storage = const FlutterSecureStorage();

  Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: 'clerk_token');
    return token != null;
  }

  Future<void> signInWithGoogle() async {
    final session = await _clerk.signInWithOAuth(OAuthProvider.google);
    await _storage.write(key: 'clerk_token', value: session.token);
  }

  Future<void> signOut() async {
    await _clerk.signOut();
    await _storage.delete(key: 'clerk_token');
  }

  Future<String?> getToken() async {
    return _storage.read(key: 'clerk_token');
  }
}
```

---

## 8. Convex Schema (Unchanged)

```typescript
// convex/schema.ts
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({
    clerkId: v.string(),
    email: v.string(),
    displayName: v.optional(v.string()),
    avatarUrl: v.optional(v.string()),
    notificationPreferences: v.object({
      enabled: v.boolean(),
      dailyDigestTime: v.string(),
      maxPerDay: v.number(),
      quietHoursStart: v.string(),
      quietHoursEnd: v.string(),
      timezoneOffsetMinutes: v.optional(v.number()),
    }),
    createdAt: v.number(),
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
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_user_status", ["userId", "status"])
    .index("by_user_type", ["userId", "type"])
    .searchIndex("search_items", {
      searchField: "title",
      filterFields: ["userId", "status"],
    }),

  pushTokens: defineTable({
    userId: v.id("users"),
    token: v.string(),
    platform: v.union(v.literal("ios"), v.literal("android"), v.literal("web")),
    createdAt: v.number(),
  })
    .index("by_user", ["userId"]),
});
```

---

## 9. Key Flutter Packages

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  
  # Networking
  dio: ^5.4.0
  
  # Data Classes
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0
  
  # Storage
  flutter_secure_storage: ^9.0.0
  shared_preferences: ^2.2.0
  
  # Auth
  clerk_flutter: ^0.1.0  # Or custom HTTP implementation
  
  # UI
  go_router: ^13.0.0
  flutter_animate: ^4.3.0
  cached_network_image: ^3.3.0
  
  # Push Notifications
  firebase_messaging: ^14.7.0
  flutter_local_notifications: ^16.2.0

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  riverpod_generator: ^2.3.0
  flutter_lints: ^3.0.0
  mockito: ^5.4.0
```

---

## 10. Security Considerations

| Concern | Flutter Solution |
|---------|------------------|
| **Token Storage** | `flutter_secure_storage` (Keychain/Keystore) |
| **API Security** | Clerk JWT validation on Convex |
| **Certificate Pinning** | `dio` with custom `HttpClientAdapter` |
| **Obfuscation** | `flutter build --obfuscate --split-debug-info` |
| **Secure Network** | HTTPS only, no HTTP fallback |

---

*Document Version: 3.0 (Flutter + Convex)*  
*Last Updated: 2026-02-03*
