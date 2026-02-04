# REM - Product Requirements Document

> **Read Everything Minder** - Your intelligent content consumption vault

---

## 1. Executive Summary

### Vision
REM is a cross-platform application that transforms passive content saving into active content consumption through intelligent, proactive notifications. It unifies links, images, videos, and books into a single queue and ensures users actually engage with their saved content.

### Problem Statement
People save content with good intentions but rarely return to consume it:
- **Pocket** reports average users save 5x more than they read
- Saved bookmarks become digital graveyards
- No existing solution treats saved content as *commitments*

### Solution
A "consumption accountability" app that:
1. Accepts any content type (links, images, books, videos)
2. Proactively reminds users based on smart, customizable rules
3. Tracks consumption habits and celebrates progress

---

## 2. Target Users

### Primary Persona: The Knowledge Collector
- **Demographics**: 22-40, professionals or students
- **Behavior**: Saves 10+ articles/week, reads <20%
- **Pain Point**: "Out of sight, out of mind"
- **Goal**: Actually learn from saved content

### Secondary Persona: The Casual Curator
- **Demographics**: 18-35, social media users
- **Behavior**: Saves memes, videos, inspiration
- **Pain Point**: Forgets what they saved
- **Goal**: Rediscover saved gems

---

## 3. Core Features (MVP)

### 3.1 Content Ingestion

| Feature | Description | Priority |
|---------|-------------|----------|
| **Link Saving** | Save URLs with auto-preview (title, thumbnail, description) | P0 |
| **Share Sheet** | Native iOS/Android share integration | P0 |
| **Browser Extension** | Chrome/Firefox one-click save | P1 |
| **Image Upload** | Save images from gallery or clipboard | P1 |
| **Manual Entry** | Add titles/notes without URL | P2 |

**Acceptance Criteria:**
- [ ] Link preview generates within 2 seconds
- [ ] Share sheet available from any app
- [ ] Duplicate detection prevents saving same URL twice

### 3.2 Content Organization

| Feature | Description | Priority |
|---------|-------------|----------|
| **Auto-Categorization** | AI-powered tagging (article, video, image, book) | P0 |
| **Manual Tags** | User-defined tags/folders | P1 |
| **Priority Levels** | High/Medium/Low urgency | P1 |
| **Search** | Full-text search across titles and notes | P1 |
| **Filters** | By type, date, priority, status | P1 |

**Acceptance Criteria:**
- [ ] Content type detected with 90%+ accuracy
- [ ] Search returns results in <200ms
- [ ] Filters can be combined

### 3.3 Notification System (Core Differentiator)

| Feature | Description | Priority |
|---------|-------------|----------|
| **Scheduled Reminders** | Daily/weekly at user-set times | P0 |
| **Smart Nudges** | Context-aware (time, frequency, type) | P1 |
| **Snooze** | Delay reminder by 1hr/1day/1week | P0 |
| **Escalation** | Increase frequency for ignored items | P2 |
| **Batch Digests** | Grouped notifications by category | P2 |

**Notification Rules Engine:**
```
IF item.age > 7 days AND item.dismissCount < 3
  THEN send reminder with message: "This has been waiting a week!"

IF user.freeTimeSlot AND item.estimatedTime <= slotDuration
  THEN suggest: "Got {duration}? Perfect for {item.title}"

IF item.type == "image" 
  THEN use micro-nudge (quick view)
ELSE IF item.type == "book"
  THEN use weekly digest
```

**Acceptance Criteria:**
- [ ] Notifications respect system DND
- [ ] Maximum 5 notifications/day (configurable)
- [ ] Snooze persists across app restarts

### 3.4 Consumption Tracking

| Feature | Description | Priority |
|---------|-------------|----------|
| **Mark as Read** | One-tap completion | P0 |
| **Archive** | Remove from active queue | P0 |
| **Progress Stats** | Items cleared this week/month | P1 |
| **Streaks** | Consecutive days of consumption | P2 |

---

## 4. User Stories

### Epic: Content Saving
```
US-001: As a user, I want to save a link from any app via share sheet
        So that I can quickly capture content without context switching

US-002: As a user, I want links to show a preview (title, image)
        So that I can recognize them later

US-003: As a user, I want duplicate URLs to be detected
        So that I don't clutter my stash
```

### Epic: Notifications
```
US-010: As a user, I want to set a daily reminder time
        So that I'm nudged when I'm most likely to read

US-011: As a user, I want to snooze a reminder
        So that I can delay without forgetting permanently

US-012: As a user, I want to see how many times I've dismissed something
        So that I can decide to archive or commit
```

### Epic: Progress
```
US-020: As a user, I want to see my weekly consumption stats
        So that I feel motivated to continue

US-021: As a user, I want to celebrate clearing my queue
        So that I feel accomplished
```

---

## 5. Non-Functional Requirements

### Performance
- App launch: <2 seconds
- Link preview generation: <3 seconds
- Search results: <200ms
- Notification delivery: Within 1 minute of scheduled time

### Reliability
- 99.9% uptime for cloud services
- Offline capability for viewing saved content
- Data sync within 5 seconds when online

### Security
- OAuth 2.0 for authentication
- All data encrypted at rest and in transit
- No third-party data sharing
- GDPR/CCPA compliant data export/deletion

### Scalability
- Support 100K+ items per user
- Handle 1M+ active users

---

## 6. Platforms & Tech Stack

### Platform Targets (MVP)
| Platform | Priority | Notes |
|----------|----------|-------|
| Android | P0 | Flutter - Primary platform |
| Browser Extension | P1 | Chrome WebExtension (Firefox later) |
| iOS | P2 | Post-MVP |
| Web | P2 | Post-MVP |

### Recommended Stack
- **Frontend**: Flutter (Dart) - Android, Web extension
- **Backend**: Convex (Database, Real-time, Scheduled Jobs)
- **Authentication**: Clerk (80+ OAuth providers)
- **Notifications**: Firebase Cloud Messaging
- **AI**: Google Gemini API (summaries, categorization)
- **Analytics**: PostHog (privacy-focused)

---

## 7. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Consumption Rate** | >40% of saved items read within 30 days | Items marked read / items saved |
| **Retention** | 60% D7, 40% D30 | Daily active users |
| **Notification Engagement** | >25% click-through rate | Clicks / notifications sent |
| **User Satisfaction** | NPS > 50 | In-app survey |

---

## 8. Roadmap

### Phase 1: MVP (Weeks 1-6)
- Core saving (links only)
- Basic list view
- Scheduled notifications
- Mark as read/archive

### Phase 2: Enhanced (Weeks 7-12)
- Image support
- AI categorization
- Smart notifications
- Browser extension
- Progress stats

### Phase 3: Growth (Weeks 13-20)
- Book/PDF support
- Social sharing
- Gamification
- Premium tier

---

## 9. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Notification fatigue | Users disable notifications | Smart caps, easy customization |
| Platform notification limits | iOS/Android restrictions | Batch digests, meaningful content |
| Competition (Pocket, Instapaper) | User acquisition | Focus on notification USP |
| AI costs | Server expenses | Cache results, rate limiting |

---

## 10. Confirmed Decisions

| Question | Decision |
|----------|----------|
| **Monetization** | Freemium model |
| **Architecture** | Offline-first (sync when online) |
| **Social features** | Yes - share stashes with friends |
| **Voice input** | Yes - "Hey REM, remind me to read this @ 4pm" |

---

## 11. Monetization (Freemium)

### Free Tier
- Save up to 100 items
- Basic notifications (3/day)
- Manual categorization
- 7-day history

### Premium Tier ($4.99/month or $39.99/year)
- Unlimited items
- Smart AI notifications
- Auto-categorization (Gemini AI)
- Voice input
- Social stash sharing
- Priority support
- Offline sync

### Conversion Strategy
- 14-day premium trial for new users
- Upgrade prompts when hitting limits
- Seasonal discounts

---

## 12. Offline-First Architecture

### Core Principles
1. **Local-first storage**: All data stored in SQLite on device
2. **Background sync**: Sync to Convex when online
3. **Conflict resolution**: Last-write-wins with timestamps
4. **Optimistic updates**: UI updates immediately, syncs later

### Offline Capabilities
| Feature | Offline | Notes |
|---------|---------|-------|
| View saved items | ✅ | Full access |
| Add new items | ✅ | Queued for sync |
| Mark as read | ✅ | Syncs later |
| Search | ✅ | Local SQLite FTS |
| AI categorization | ❌ | Requires cloud |
| Voice input | ❌ | Requires cloud STT |
| Link previews | ❌ | Requires fetch |

### Sync Strategy
```dart
// Sync on:
// 1. App foreground
// 2. Connectivity change (offline → online)
// 3. Manual pull-to-refresh
// 4. Background task (every 15 min if changes pending)
```

---

## 13. Social Features

### Stash Sharing
- **Public stashes**: Share themed collections (e.g., "Best AI articles")
- **Friend sharing**: Send specific items to friends
- **Collaborative stashes**: Multiple contributors
- **Follow users**: See friends' public stashes

### Privacy Controls
| Visibility | Description |
|------------|-------------|
| Private (default) | Only you can see |
| Friends only | Shared with connections |
| Public | Anyone with link |

### Social MVP (Phase 3)
- Share single item → messaging apps
- Share collection link
- Import friend's stash

---

## 14. Voice Input

### Supported Commands
```
"Hey REM, remind me to read this later"
"Hey REM, save this for tomorrow at 4pm"
"Hey REM, snooze this for 2 hours"
"Hey REM, mark as read"
"Hey REM, what's in my stash?"
```

### Implementation
- **Platform**: Google Speech-to-Text / on-device ML Kit
- **Trigger**: Wake word "Hey REM" or in-app mic button
- **NLU**: Parse intent + time expressions
- **Feedback**: Audio confirmation + haptic

### Voice MVP (Phase 3)
- In-app mic button only (no wake word initially)
- Basic commands: save, remind, snooze
- Time parsing: "tomorrow", "in 2 hours", "at 4pm"

---

*Document Version: 2.0*  
*Last Updated: 2026-02-03*  
*Author: AI Assistant + User*
