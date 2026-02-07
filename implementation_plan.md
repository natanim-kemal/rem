# REM Implementation Plan

> Comprehensive roadmap for building the REM application

---

## Tech Stack Summary

| Layer | Technology |
|-------|------------|
| **Mobile** | Flutter (Android only for MVP) |
| **Backend** | Convex (cloud) + Drift (local SQLite) |
| **Auth** | Clerk |
| **Push** | Firebase Cloud Messaging |
| **AI** | Google Gemini API |

---

## Phase 1: Foundation (Week 1-2)

### 1.1 Project Setup
- [x] Initialize monorepo structure
- [x] Create Flutter project (`flutter create --platforms=android`)
- [x] Initialize Convex project (`npx convex init`)
- [x] Configure Clerk application
- [x] Set up GitHub repo with branch protection
- [x] Configure CI/CD workflows

### 1.2 Core Infrastructure
- [x] Set up Drift (SQLite) for local database
- [x] Create Convex schema (users, items, tags)
- [x] Build sync engine (Drift ↔ Convex)
- [x] Implement Clerk auth flow in Flutter
- [x] Create secure token storage

### 1.3 Folder Structure
```
rem/
├── apps/mobile/lib/
│   ├── core/           # Config, network, utils
│   ├── data/           # Models, repositories, services
│   ├── domain/         # Entities, use cases
│   └── presentation/   # Providers, screens, widgets
├── convex/             # Backend functions
└── extension/          # Browser extension (Phase 2)
```

---

## Phase 2: MVP Features (Week 3-5)

### 2.1 Content Ingestion
- [x] Share intent receiver (Android) - `receive_sharing_intent` package integrated
- [x] URL metadata parser (title, thumbnail, description) - `metadata_fetch` implemented
- [x] Duplicate detection - `findDuplicateItem()` method in database
- [x] Manual item creation (UI only - Add Item Sheet)
- [x] Image upload from gallery - `image_picker` integrated with AddItemSheet

### 2.2 Content Display
- [x] Home screen with item list
- [x] Pull-to-refresh - CupertinoSliverRefreshControl implemented
- [x] Item detail view
- [x] Search wired to local FTS (query + paginated results)
- [x] Filter by type/status (DB query params)
- [ ] Filter by priority

### 2.3 Item Management
- [ ] Mark as read (no swipe or action wired yet)
- [ ] Archive item (no swipe or action wired yet)
- [x] Delete item - UI with confirmation dialog + `syncEngine.deleteItem()`
- [x] Edit tags/priority - Detail sheet UI + `syncEngine.updateItemPriority/Tags()`
- [ ] Swipe gestures (not implemented)

### 2.4 Basic Notifications
- [x] FCM integration - `firebase_messaging` + `NotificationService`
- [x] Scheduled daily reminder - `zonedSchedule` in NotificationService
- [x] Snooze helper - `snoozeNotification()` in NotificationService
- [ ] Wire preferences UI to scheduling + persistence

---

## Phase 3: Offline-First (Week 6-7) - ✅ COMPLETE

### 3.1 Local Database (Drift) ✅
- [x] Define Drift tables matching Convex schema - `apps/mobile/lib/data/database/database.dart`
- [x] Create DAOs for CRUD operations - `AppDatabase` class with full CRUD
- [x] Implement local search with FTS5 - `ItemsFts` virtual table with full-text search
- [x] Queue pending changes for sync - `SyncQueue` table implemented

### 3.2 Sync Engine ✅
- [x] Bidirectional sync (local ↔ cloud) - `_pushLocalChanges()` + `_pullRemoteChanges()` complete
- [x] Conflict resolution (last-write-wins) - `_resolveConflict()` method in sync engine
- [x] Optimistic UI updates - Local DB updates immediately, syncs in background
- [x] Background sync on connectivity change - `connectivity_plus` listener
- [x] Sync status indicator - `SyncStatusIndicator` widget with real-time status stream

### 3.3 Offline Capabilities ✅
- [x] Full read access offline - Drift database enables full offline reads
- [x] Create/update items offline - Changes queued in `SyncQueue`
- [~] Pending notifications table exists, delivery logic not wired yet
- [x] Graceful degradation for cloud features - Sync engine handles offline gracefully

---

## Phase 4: Smart Features (Week 8-9)

### 4.1 AI Categorization
- [ ] Gemini API integration
- [ ] Auto-detect content type
- [ ] Generate tags from content
- [ ] Estimate read time
- [ ] Content summarization (premium)

### 4.2 Smart Notifications
- [ ] Notification rules engine
- [ ] Context-aware timing
- [ ] Escalation for ignored items
- [ ] Batch digests
- [ ] Notification analytics

### 4.3 Progress Tracking
- [ ] Weekly/monthly stats
- [ ] Consumption streaks
- [ ] Achievement badges
- [ ] Progress charts

---

## Phase 5: Monetization (Week 10)

### 5.1 Freemium Implementation
- [ ] Google Play Billing integration
- [ ] Subscription management
- [ ] Free tier limits (100 items, 3 notifs/day)
- [ ] Premium feature gates
- [ ] 14-day trial flow

### 5.2 Upgrade UX
- [ ] Paywall screens
- [ ] Limit warning dialogs
- [ ] Upgrade prompts at key moments
- [ ] Restore purchases

---

## Phase 6: Browser Extension (Week 11-12)

### 6.1 Chrome Extension
- [x] Manifest V3 setup
- [x] Popup UI (save current page)
- [x] Context menu integration
- [~] Auth sync with mobile app (manual token entry in settings)
- [x] Convex HTTP API integration (`/api/items`, `/api/me`)

### 6.2 Extension Features
- [x] One-click save (popup, context menu, shortcut)
- [ ] Tag quick-select
- [x] Priority picker (popup)
- [x] Success toast (content script)

---

## Phase 7: Social Features (Week 13-14)

### 7.1 Sharing Infrastructure
- [ ] Public/private visibility toggle
- [ ] Share link generation
- [ ] Friend connections
- [ ] Follow users

### 7.2 Social UI
- [ ] Share stash button
- [ ] Import friend's stash
- [ ] Public profile page
- [ ] Activity feed

---

## Phase 8: Voice Input (Week 15-16)

### 8.1 Speech Recognition
- [ ] Google Speech-to-Text integration
- [ ] In-app mic button
- [ ] Voice command parsing
- [ ] Time expression extraction

### 8.2 Voice Commands
- [ ] "Remind me to read this later"
- [ ] "Save this for tomorrow at 4pm"
- [ ] "Snooze for 2 hours"
- [ ] Audio/haptic feedback

---

## Phase 9: Polish & Launch (Week 17-18)

### 9.1 Testing
- [ ] Unit tests (70% coverage)
- [ ] Widget tests for core screens
- [ ] Integration tests for sync
- [ ] Manual QA on multiple devices

### 9.2 Performance
- [ ] App startup optimization
- [ ] Memory profiling
- [ ] Battery usage optimization
- [ ] APK size reduction

### 9.3 Launch Prep
- [ ] Play Store assets (screenshots, video)
- [ ] Privacy policy & terms
- [ ] App store listing
- [ ] Beta testing (internal → closed → open)
- [ ] Production release

---

## Deliverables by Phase

| Phase | Deliverable | Week |
|-------|-------------|------|
| 1 | Project skeleton, auth working | 2 |
| 2 | Core CRUD, basic notifications | 5 |
| 3 | Full offline support | 7 |
| 4 | AI features, smart notifications | 9 |
| 5 | Payments working | 10 |
| 6 | Browser extension | 12 |
| 7 | Social sharing | 14 |
| 8 | Voice commands | 16 |
| 9 | **Production launch** | 18 |

---

## Immediate Next Steps

1. **Wire notifications** - persist preferences + server push scheduling + priority cadence + quiet hours
2. **Item actions** - implement mark-as-read / archive actions and swipe gestures
3. **Priority filtering** - add filter UI + query param support
4. **Extension polish** - tag quick-select + auth flow improvements
5. **AI categorization** - integrate Gemini for auto-tags and read-time

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Sync complexity | Start simple (last-write-wins), iterate |
| Gemini costs | Cache results, rate limit, free tier limits |
| Extension review delays | Submit early, follow guidelines |
| Voice accuracy | Start with in-app button, no wake word |

---

## Current Progress Summary

| Phase | Status | Progress | Key Deliverables |
|-------|--------|----------|------------------|
| **Phase 1** | ✅ Complete | 100% | Project setup, auth (Clerk), Convex schema, Drift local DB, CI/CD |
| **Phase 2** | 🚧 In Progress | ~75% | Share receiver, metadata parser, duplicate detection, image upload, delete/edit UI, search + filters |
| **Phase 3** | ✅ Complete | 95% | FTS5 local search, bidirectional sync with conflict resolution, sync status indicator, offline-first architecture |
| **Phase 4** | ⏳ Not Started | 0% | AI features pending |
| **Phase 5** | ⏳ Not Started | 0% | Monetization pending |
| **Phase 6** | 🚧 In Progress | ~70% | Extension manifest V3, popup UI, context menu, Convex API save |
| **Phase 7** | ⏳ Not Started | 0% | Social features pending |
| **Phase 8** | ⏳ Not Started | 0% | Voice input pending |
| **Phase 9** | ⏳ Not Started | 0% | Launch prep pending |

### Recently Completed
- ✅ FTS5 full-text search - Virtual table for local item search
- ✅ Bidirectional sync - `_pullRemoteChanges()` fetches from Convex with `getItemsSince`
- ✅ Conflict resolution - Last-write-wins strategy in `_resolveConflict()`
- ✅ Sync status indicator - Real-time `SyncStatus` stream with UI widget
- ✅ Extension MVP - popup save flow + context menus + shortcut

### Next Priorities
1. Wire notifications end-to-end (preferences + scheduling)
2. Item actions (mark as read/archive + swipe gestures)
3. Priority filter
4. Extension tags + auth flow polish
5. AI categorization with Gemini API

---

*Last updated: 2026-02-07*
