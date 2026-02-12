# AGENTS.md

This file is for agentic coding assistants working in this repo.
Follow these rules and commands when making changes.

## Project Snapshot
- App: Flutter (Dart) mobile client in `apps/mobile/`
- Backend: Convex (TypeScript) via `convex` CLI (root `package.json`)
- Node: >= 20 (per root `package.json`)
- Hooks: `lefthook.yml` (pre-commit + commit-msg)

## Quick Commands (Most Used)
Run these from the repo root unless noted.

### Flutter app (apps/mobile)
- Install deps: `cd apps/mobile && flutter pub get`
- Run app: `cd apps/mobile && flutter run`
- Run app with env: `cd apps/mobile && flutter run --dart-define=CONVEX_URL=...`
- Build release APK: `cd apps/mobile && flutter build apk --release --dart-define=CONVEX_URL=... --dart-define=CLERK_PUBLISHABLE_KEY=...`

### Lint / Analyze
- Analyze: `cd apps/mobile && flutter analyze`
- Format: `cd apps/mobile && dart format .`
- Format check (CI-style): `cd apps/mobile && dart format --set-exit-if-changed .`

### Tests
- Run all tests: `cd apps/mobile && flutter test`
- Run a single test file: `cd apps/mobile && flutter test test/path/to/file_test.dart`
- Run a single test by name: `cd apps/mobile && flutter test --name "test name or regex"`
- Integration tests: `cd apps/mobile && flutter test integration_test/app_test.dart`
- Coverage: `cd apps/mobile && flutter test --coverage`

### Codegen
- Build once: `cd apps/mobile && dart run build_runner build --delete-conflicting-outputs`
- Watch: `cd apps/mobile && dart run build_runner watch --delete-conflicting-outputs`

### Convex (root)
- Dev server: `npx convex dev`
- Deploy: `npm run convex:deploy`
- Logs: `npm run convex:logs`

## Hooks You Must Respect
These run automatically and will fail commits if violated.

### Lefthook (repo root `lefthook.yml`)
- Pre-commit:
  - `dart format` runs on staged Dart files under `apps/mobile/**`
  - `scripts/no-comments-in-added.ps1` blocks new comments in added lines
- Commit-msg:
  - `scripts/validate-commit-msg.ps1` enforces Conventional Commits

Implication: do not add new comments unless you are forced to explain non-obvious code.

## Code Style and Conventions (Dart / Flutter)
Follow these repo standards from `docs/05-DEVELOPMENT-STANDARDS.md`.

### Formatting
- Use `dart format` (always run before committing)
- Lints: `analysis_options.yaml` includes `flutter_lints`

### Naming
- Classes, enums, extensions: `PascalCase`
- Methods, variables, params: `camelCase`
- Constants: `camelCase` (unless a file already uses `SCREAMING_SNAKE_CASE`)
- Private symbols: prefix with `_`
- Files / folders: `snake_case`

### Imports
- Use absolute package imports for app code: `import 'package:rem/...';`
- Group imports in this order:
  1. Dart SDK
  2. Flutter / 3rd-party packages
  3. Local project imports
- Keep imports minimal and sorted.

### Types and Null Safety
- Avoid `dynamic`; prefer explicit types
- Use `final` by default; `const` where possible
- Avoid implicit `var` when it obscures types

### Widgets
- Prefer `const` widgets when possible
- Use `ConsumerWidget` with Riverpod; avoid global state
- Keep widgets small and focused; extract reusable components
- Prefer `ListView.builder` for large lists

### Riverpod
- Use `@riverpod` and generated providers
- Name notifiers with suffix `Notifier` or `Controller`
- Async state handling via `AsyncValue` (`when` / `maybeWhen`)

### Data Models
- Use `freezed` + `json_serializable`
- Put `part` files next to the source file
- Prefer immutable models and `copyWith`

### Error Handling
- Use app exceptions (see `docs/05-DEVELOPMENT-STANDARDS.md`)
- Catch specific exceptions (e.g., `DioException`)
- Avoid swallowing errors; surface actionable messages

## Convex (TypeScript) Standards
From `docs/05-DEVELOPMENT-STANDARDS.md`:

- Validate all args with `v.*`
- Check auth in every mutation/query
- Validate input sizes and constraints
- Use transactions for multi-step writes

## UI Design Rules (Flutter)
From `docs/UI-DESIGN-GUIDE.md`:

- iOS-inspired minimal aesthetic
- Monochromatic palette (black/white/gray); blue accent only for primary actions
- No emojis; use iconography
- Typography hierarchy, whitespace, subtle motion

## Repository Docs (Read First)
- `docs/01-PRD.md`
- `docs/02-ARCHITECTURE.md`
- `docs/03-CICD.md`
- `docs/04-SECURITY.md`
- `docs/05-DEVELOPMENT-STANDARDS.md`
- `docs/06-REPOSITORY-SETUP.md`
- `docs/UI-DESIGN-GUIDE.md`

## If You Need to Add Comments
Avoid new comments due to the pre-commit hook. Only add comments to explain
non-obvious logic or critical constraints, and keep them short.

## Common Pitfalls
- Running Flutter commands from repo root without `cd apps/mobile`
- Forgetting `--dart-define` for Convex and Clerk in production builds
- Adding comments (blocked by hook)
- Using `dynamic` or loosening types

## Notes for Agents
- Keep changes focused and small; avoid unrelated formatting churn
- Respect existing file structure and naming
- Update codegen outputs only when you changed annotations
- Do not touch generated files unless required by a change
