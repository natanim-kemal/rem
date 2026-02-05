# rem - CI/CD Pipeline Documentation

> Continuous Integration and Deployment workflows for the rem application (Flutter + Convex)

---

## 1. Pipeline Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        CI/CD PIPELINE                            │
└─────────────────────────────────────────────────────────────────┘

  Push/PR to branch
         │
         ▼
  ┌──────────────────┐
  │   Code Quality   │  ← Dart Analyze, Format Check
  └────────┬─────────┘
           │
           ▼
  ┌──────────────────┐
  │  Security Scans  │  ← CodeQL, Dependency Audit
  └────────┬─────────┘
           │
           ▼
  ┌──────────────────┐
  │      Tests       │  ← Unit, Widget, Integration
  └────────┬─────────┘
           │
           ▼
  ┌──────────────────────────────────────────────────────┐
  │                    Build & Deploy                     │
  │  ┌─────────┐  ┌─────────┐  ┌─────────────────────┐   │
  │  │ Convex  │  │ Android │  │ Browser Extension   │   │
  │  │Functions│  │   APK   │  │   (Chrome/Firefox)  │   │
  │  └─────────┘  └─────────┘  └─────────────────────┘   │
  └──────────────────────────────────────────────────────┘
```

---

## 2. Workflow Files

### 2.1 Main CI Workflow

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  FLUTTER_VERSION: '3.19.0'
  NODE_VERSION: '20'

jobs:
  # ─────────────────────────────────────────────────────────────
  # Flutter Code Quality
  # ─────────────────────────────────────────────────────────────
  flutter-quality:
    name: Flutter Code Quality
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: apps/mobile
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Check formatting
        run: dart format --set-exit-if-changed .

      - name: Analyze code
        run: flutter analyze --fatal-infos

      - name: Run generator (freezed, riverpod)
        run: dart run build_runner build --delete-conflicting-outputs

  # ─────────────────────────────────────────────────────────────
  # Convex Validation
  # ─────────────────────────────────────────────────────────────
  convex-check:
    name: Convex Validation
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Install Convex
        run: npm install convex

      - name: Generate types
        run: npx convex codegen
        env:
          CONVEX_DEPLOY_KEY: ${{ secrets.CONVEX_DEPLOY_KEY }}

      - name: Typecheck
        run: npx convex typecheck

  # ─────────────────────────────────────────────────────────────
  # Flutter Tests
  # ─────────────────────────────────────────────────────────────
  flutter-test:
    name: Flutter Tests
    runs-on: ubuntu-latest
    needs: flutter-quality
    defaults:
      run:
        working-directory: apps/mobile
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Run generator
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Run unit tests
        run: flutter test --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          file: apps/mobile/coverage/lcov.info

  # ─────────────────────────────────────────────────────────────
  # Build Android
  # ─────────────────────────────────────────────────────────────
  build-android:
    name: Build Android
    runs-on: ubuntu-latest
    needs: [flutter-test, convex-check]
    defaults:
      run:
        working-directory: apps/mobile
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Run generator
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Build APK
        run: flutter build apk --release --obfuscate --split-debug-info=build/debug-info
        env:
          CONVEX_URL: ${{ secrets.CONVEX_URL }}
          CLERK_PUBLISHABLE_KEY: ${{ secrets.CLERK_PUBLISHABLE_KEY }}

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: android-apk
          path: apps/mobile/build/app/outputs/flutter-apk/app-release.apk

  # ─────────────────────────────────────────────────────────────
  # Build iOS
  # ─────────────────────────────────────────────────────────────
  build-ios:
    name: Build iOS
    runs-on: macos-latest
    needs: [flutter-test, convex-check]
    defaults:
      run:
        working-directory: apps/mobile
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Run generator
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Build iOS (no codesign)
        run: flutter build ios --release --no-codesign --obfuscate --split-debug-info=build/debug-info
        env:
          CONVEX_URL: ${{ secrets.CONVEX_URL }}
          CLERK_PUBLISHABLE_KEY: ${{ secrets.CLERK_PUBLISHABLE_KEY }}

  # ─────────────────────────────────────────────────────────────
  # Build Web
  # ─────────────────────────────────────────────────────────────
  build-web:
    name: Build Web
    runs-on: ubuntu-latest
    needs: [flutter-test, convex-check]
    defaults:
      run:
        working-directory: apps/mobile
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Run generator
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Build Web
        run: flutter build web --release --wasm
        env:
          CONVEX_URL: ${{ secrets.CONVEX_URL }}
          CLERK_PUBLISHABLE_KEY: ${{ secrets.CLERK_PUBLISHABLE_KEY }}

      - name: Upload Web Build
        uses: actions/upload-artifact@v4
        with:
          name: web-build
          path: apps/mobile/build/web

  # ─────────────────────────────────────────────────────────────
  # Deploy Production
  # ─────────────────────────────────────────────────────────────
  deploy-production:
    name: Deploy Production
    runs-on: ubuntu-latest
    needs: [build-android, build-ios, build-web]
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: production
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      # Deploy Convex
      - name: Install Convex
        run: npm install convex

      - name: Deploy Convex
        run: npx convex deploy
        env:
          CONVEX_DEPLOY_KEY: ${{ secrets.CONVEX_DEPLOY_KEY }}

      # Deploy Web to Vercel
      - name: Download Web Build
        uses: actions/download-artifact@v4
        with:
          name: web-build
          path: web-dist

      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: '--prod'
          working-directory: web-dist
```

### 2.2 Release Workflow (App Stores)

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

env:
  FLUTTER_VERSION: '3.19.0'

jobs:
  release-android:
    name: Release Android
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: apps/mobile
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}

      - name: Decode Keystore
        run: echo "${{ secrets.ANDROID_KEYSTORE }}" | base64 -d > android/app/keystore.jks

      - name: Build App Bundle
        run: |
          flutter pub get
          dart run build_runner build --delete-conflicting-outputs
          flutter build appbundle --release
        env:
          KEY_STORE_PASSWORD: ${{ secrets.KEY_STORE_PASSWORD }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}

      - name: Upload to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_STORE_SERVICE_ACCOUNT }}
          packageName: dev.rem.app
          releaseFiles: apps/mobile/build/app/outputs/bundle/release/app-release.aab
          track: internal

  release-ios:
    name: Release iOS
    runs-on: macos-latest
    defaults:
      run:
        working-directory: apps/mobile
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}

      - name: Install Fastlane
        run: gem install fastlane

      - name: Build & Upload to TestFlight
        run: |
          flutter pub get
          dart run build_runner build --delete-conflicting-outputs
          flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
          cd ios && fastlane upload_testflight
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APP_STORE_CONNECT_API_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY }}
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
```

---

## 3. Branch Protection Rules

**Settings → Branches → Add rule for `main`:**

```yaml
Branch name pattern: main

Protect matching branches:
  ✅ Require pull request before merging
     ✅ Require approvals: 1
  ✅ Require status checks to pass:
     - flutter-quality
     - flutter-test
     - convex-check
     - build-android
     - build-web
  ✅ Require linear history
```

---

## 4. Required Secrets

| Secret | Description | Source |
|--------|-------------|--------|
| `CONVEX_DEPLOY_KEY` | Convex deployment key | Convex Dashboard |
| `CONVEX_URL` | Convex deployment URL | Convex Dashboard |
| `CLERK_PUBLISHABLE_KEY` | Clerk frontend key | Clerk Dashboard |
| `VERCEL_TOKEN` | Vercel deployment | Vercel Account |
| `VERCEL_ORG_ID` | Vercel org ID | Vercel Settings |
| `VERCEL_PROJECT_ID` | Vercel project ID | Vercel Project |
| `CODECOV_TOKEN` | Coverage reports | codecov.io |
| `ANDROID_KEYSTORE` | Base64 keystore | `base64 keystore.jks` |
| `KEY_STORE_PASSWORD` | Keystore password | Your password |
| `KEY_PASSWORD` | Key password | Your password |
| `KEY_ALIAS` | Key alias | Your alias |
| `PLAY_STORE_SERVICE_ACCOUNT` | Google Play JSON | GCP Console |
| `APPLE_ID` | Apple ID email | Apple Account |
| `APP_STORE_CONNECT_API_KEY` | App Store key | App Store Connect |

---

## 5. Local Development

```bash
# Terminal 1: Start Convex
npx convex dev

# Terminal 2: Run Flutter app
cd apps/mobile
flutter run

# Run tests
flutter test

# Generate code (freezed, riverpod)
dart run build_runner watch --delete-conflicting-outputs

# Analyze code
flutter analyze

# Format code
dart format .
```

---

## 6. Deployment Commands

```bash
# Deploy Convex to production
npx convex deploy

# Build Android APK
flutter build apk --release

# Build iOS
flutter build ios --release

# Build Web
flutter build web --release --wasm

# Build all with obfuscation
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
```

---

*Document Version: 3.0 (Flutter + Convex)*  
*Last Updated: 2026-02-03*
