# rem - Repository Setup Guide

> Step-by-step guide to initialize the rem repository with Flutter + Convex

---

## 1. Quick Start Checklist

```bash
□ Install Flutter SDK
□ Initialize Flutter project
□ Set up Convex project
□ Configure Clerk authentication
□ Configure GitHub Actions
□ Set up code generation
□ Add pre-commit hooks
```

---

## 2. Prerequisites

```bash
# Install Flutter
# macOS
brew install flutter

# Windows - Download from flutter.dev and add to PATH
# Verify installation
flutter doctor

# Install Dart (comes with Flutter)
dart --version

# Install Node.js (for Convex)
node --version  # Should be 20+
```

---

## 3. Project Setup

### Step 1: Create Repository Structure

```bash
# Create project directory
mkdir rem && cd rem
git init

# Create directories
mkdir -p apps docs convex
mkdir -p .github/workflows .github/ISSUE_TEMPLATE
```

### Step 2: Create Flutter App

```bash
cd apps

# Create Flutter project (Android only for MVP)
flutter create --org dev.rem --platforms=android mobile

cd mobile
```

### Step 3: Add Flutter Dependencies

```yaml
# apps/mobile/pubspec.yaml
name: rem
description: Read Everything Minder - Your content consumption vault
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

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
  
  # Routing
  go_router: ^13.0.0
  
  # UI
  flutter_animate: ^4.3.0
  cached_network_image: ^3.3.0
  google_fonts: ^6.1.0
  
  # Push Notifications
  firebase_core: ^2.24.0
  firebase_messaging: ^14.7.0
  flutter_local_notifications: ^16.2.0
  
  # Utils
  url_launcher: ^6.2.0
  share_plus: ^7.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  
  # Code Generation
  build_runner: ^2.4.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  riverpod_generator: ^2.3.0
  riverpod_lint: ^2.3.0

flutter:
  uses-material-design: true
```

### Step 4: Set Up Convex

```bash
cd ../..  # Back to rem root

# Initialize Convex
npm init -y
npm install convex

# Initialize Convex project
npx convex init
```

### Step 5: Create Convex Schema

```typescript
// convex/schema.ts
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({
    clerkId: v.string(),
    email: v.string(),
    displayName: v.optional(v.string()),
    createdAt: v.number(),
  }).index("by_clerk_id", ["clerkId"]),

  items: defineTable({
    userId: v.id("users"),
    title: v.string(),
    url: v.optional(v.string()),
    type: v.union(v.literal("link"), v.literal("image"), v.literal("book")),
    status: v.union(v.literal("unread"), v.literal("read"), v.literal("archived")),
    priority: v.union(v.literal("high"), v.literal("medium"), v.literal("low")),
    tags: v.array(v.string()),
    remindCount: v.number(),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_user_status", ["userId", "status"])
    .searchIndex("search_items", {
      searchField: "title",
      filterFields: ["userId"],
    }),
});
```

### Step 6: Create HTTP Endpoints

```typescript
// convex/http.ts
import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { api } from "./_generated/api";

const http = httpRouter();

http.route({
  path: "/api/items",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      return new Response("Unauthorized", { status: 401 });
    }
    const items = await ctx.runQuery(api.items.getItems, {});
    return new Response(JSON.stringify(items), {
      headers: { "Content-Type": "application/json" },
    });
  }),
});

http.route({
  path: "/api/items",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      return new Response("Unauthorized", { status: 401 });
    }
    const body = await request.json();
    const id = await ctx.runMutation(api.items.createItem, body);
    return new Response(JSON.stringify({ id }), {
      headers: { "Content-Type": "application/json" },
    });
  }),
});

export default http;
```

---

## 4. Flutter Project Structure

```bash
# Create folder structure
cd apps/mobile/lib

mkdir -p core/{config,constants,errors,network,utils}
mkdir -p data/{models,repositories,services}
mkdir -p domain/{entities,repositories,usecases}
mkdir -p presentation/{providers,screens,widgets,theme}
mkdir -p l10n
```

### Entry Point

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  runApp(
    const ProviderScope(
      child: RemApp(),
    ),
  );
}
```

### App Widget

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'presentation/theme/app_theme.dart';

class RemApp extends StatelessWidget {
  const RemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'rem',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: _router,
    );
  }

  static final _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      // Add more routes
    ],
  );
}
```

---

## 5. Environment Configuration

### Flutter Config

```dart
// lib/core/config/environment.dart
class Environment {
  static const String convexUrl = String.fromEnvironment(
    'CONVEX_URL',
    defaultValue: 'http://localhost:3000',
  );
  
  static const String clerkPublishableKey = String.fromEnvironment(
    'CLERK_PUBLISHABLE_KEY',
  );
  
  static bool get isProduction => convexUrl.contains('.convex.cloud');
}
```

### Build with Environment Variables

```bash
# Development
flutter run --dart-define=CONVEX_URL=https://your-project.convex.cloud

# Production build
flutter build apk --release \
  --dart-define=CONVEX_URL=https://your-project.convex.cloud \
  --dart-define=CLERK_PUBLISHABLE_KEY=pk_live_xxx
```

---

## 6. Code Generation

```bash
# Run once
dart run build_runner build --delete-conflicting-outputs

# Watch mode (during development)
dart run build_runner watch --delete-conflicting-outputs
```

---

## 7. Essential Files

### .gitignore

```gitignore
# Flutter
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
build/
*.iml

# Convex
convex/_generated/
node_modules/

# Environment
.env
.env.local
*.env

# IDE
.idea/
.vscode/
*.swp

# OS
.DS_Store
Thumbs.db

# Coverage
coverage/


# Secrets
*.keystore
*.jks
*.p12
google-services.json
GoogleService-Info.plist
```

### .env.example

```bash
# Convex
CONVEX_URL=https://your-project.convex.cloud
CONVEX_DEPLOY_KEY=prod:xxx

# Clerk
CLERK_PUBLISHABLE_KEY=pk_test_xxx
```

### README.md

```markdown
# rem - Read Everything Minder

> Your intelligent content consumption vault

## 🚀 Quick Start

### Prerequisites
- Flutter 3.19+
- Node.js 20+
- Android Studio / Xcode

### Setup

\`\`\`bash
# Clone repository
git clone https://github.com/your-org/rem.git
cd rem

# Install Convex dependencies
npm install

# Install Flutter dependencies
cd apps/mobile
flutter pub get

# Generate code
dart run build_runner build
\`\`\`

### Run

\`\`\`bash
# Terminal 1: Start Convex
npx convex dev

# Terminal 2: Run Flutter
cd apps/mobile
flutter run
\`\`\`

## 📁 Project Structure

\`\`\`
rem/
├── apps/
│   └── mobile/          # Flutter app (iOS, Android, Web)
├── convex/              # Backend (Convex)
├── docs/                # Documentation
└── .github/             # CI/CD
\`\`\`

## 🛠 Tech Stack

- **Frontend**: Flutter (Dart)
- **State**: Riverpod
- **Backend**: Convex
- **Auth**: Clerk
- **Push**: Firebase Cloud Messaging

## 📄 License

MIT License
```

---

## 8. Clerk Setup

### 1. Create Clerk Application
- Go to [clerk.com](https://clerk.com)
- Create application
- Enable OAuth providers (Google, Apple, etc.)

### 2. Configure JWT for Convex
- Clerk Dashboard → JWT Templates
- Create template "convex"
- Configure issuer URL

### 3. Convex Auth Config
```typescript
// convex/auth.config.ts
export default {
  providers: [
    {
      domain: "https://your-clerk-domain.clerk.accounts.dev",
      applicationID: "convex",
    },
  ],
};
```

---

## 9. Required Secrets (GitHub)

| Secret | Source |
|--------|--------|
| `CONVEX_DEPLOY_KEY` | Convex Dashboard → Settings |
| `CONVEX_URL` | Convex Dashboard |
| `CLERK_PUBLISHABLE_KEY` | Clerk Dashboard |
| `VERCEL_TOKEN` | Vercel Account |
| `CODECOV_TOKEN` | codecov.io |
| `ANDROID_KEYSTORE` | Base64 encoded keystore |
| `PLAY_STORE_SERVICE_ACCOUNT` | GCP Console |
| `APP_STORE_CONNECT_API_KEY` | App Store Connect |

---

## 10. Local Development Workflow

```bash
# Terminal 1: Convex dev server
npx convex dev

# Terminal 2: Flutter app
cd apps/mobile
flutter run

# Run on specific device
flutter run -d chrome      # Web
flutter run -d emulator    # Android
flutter run -d iPhone      # iOS Simulator

# Hot restart
# Press 'R' in terminal or save file

# Run tests
flutter test

# Analyze code
flutter analyze
```

---

## 11. Pre-commit Hooks (Optional)

```bash
# Install lefthook (alternative to husky for Dart)
brew install lefthook

# Initialize
lefthook install
```

```yaml
# lefthook.yml
pre-commit:
  parallel: true
  commands:
    flutter-format:
      glob: "*.dart"
      run: dart format --set-exit-if-changed {staged_files}
    flutter-analyze:
      glob: "*.dart"
      run: flutter analyze {staged_files}
```

---

*Document Version: 3.0 (Flutter + Convex)*  
*Last Updated: 2026-02-03*
