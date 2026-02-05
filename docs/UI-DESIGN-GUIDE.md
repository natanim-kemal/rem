# rem UI Design Guide

> Living document for UI components and design decisions

---

## Design Philosophy

### Style: iOS-Inspired Minimal
- Clean, sophisticated iOS aesthetic
- Focus on typography and whitespace
- Subtle animations and transitions
- Depth through shadows and layering

### Color Palette: Monochromatic
```dart
// Light Mode
background: #FFFFFF        // Pure white
surface: #F5F5F7           // Apple gray
surfaceElevated: #FFFFFF   // Cards
textPrimary: #000000       // Black
textSecondary: #86868B     // Gray
textTertiary: #AEAEB2      // Light gray
divider: #E5E5EA           // Separator

// Dark Mode
background: #000000        // Pure black
surface: #1C1C1E           // Elevated surface
surfaceElevated: #2C2C2E   // Cards
textPrimary: #FFFFFF       // White
textSecondary: #8E8E93     // Gray
textTertiary: #636366      // Dark gray
divider: #38383A           // Separator

// Accent (minimal use)
accent: #007AFF            // iOS blue (links, CTAs only)
destructive: #FF3B30       // Delete actions only
```

### Rules
1. **NO EMOJIS** - Icons only
2. **Monochromatic** - Black/white with grayscale intensity
3. **Accent sparingly** - Blue only for primary actions
4. **Icons** - SF Symbols style (user-provided)
5. **Typography** - Clean, readable, hierarchy through weight

---

## Typography

### Font: SF Pro Display / Inter
```dart
// Hierarchy
largeTitle: 34px / Bold
title1: 28px / Bold  
title2: 22px / Bold
title3: 20px / Semibold
headline: 17px / Semibold
body: 17px / Regular
callout: 16px / Regular
subhead: 15px / Regular
footnote: 13px / Regular
caption: 12px / Regular
```

---

## Spacing & Layout

### iOS-Style Metrics
```dart
// Margins
screenHorizontal: 16px
screenVertical: 20px
cardPadding: 16px
listItemSpacing: 12px

// Corners
cardRadius: 12px
buttonRadius: 10px
searchRadius: 10px

// Shadows (for elevated cards)
shadowColor: #000000 @ 8%
shadowOffset: (0, 2)
shadowBlur: 8px
```

## Components

### Top App Bar
*Reference: User-provided image*

**Style:**
- Full-width, edge-to-edge
- Background: theme.scaffoldBackground
- No elevation/shadow (flat)

**Layout:**
```
[<] -------- [Title] -------- [Icon] [Icon]
```

**Elements:**
| Position | Element | Notes |
|----------|---------|-------|
| Left | Back chevron | Only on sub-screens (not home) |
| Center | Title | Semibold, white |
| Right | Action icons | 1-2 icons max |

**Home Screen Variation:**
```
[rem] ----------------------- [Filter] [Notif]
```
- Left-aligned large title "rem"
- Right action icons

**Dimensions:**
```dart
height: 44px (content) + safeArea
horizontalPadding: 16px
iconSize: 22px
titleSize: 17px / Semibold
backChevronSize: 28px
```

**Colors (theme-aware):**
- Background: theme.scaffoldBackground
- Title: theme.textPrimary
- Icons: theme.textPrimary (or theme.textSecondary for secondary)

---

### Bottom Navigation Bar
*Reference: User-provided image*

**Style:**
- Floating pill shape
- Background: theme.surface (white in light, dark gray in dark)
- Subtle shadow
- Positioned above screen bottom with margin
- Rounded corners (full radius / pill)

**Tabs (5):**
| # | Page | Icon (outlined) | Icon (filled) |
|---|------|-----------------|---------------|
| 1 | Home | house | house.fill |
| 2 | Search | magnifyingglass | magnifyingglass |
| 3 | Add | plus.circle | plus.circle.fill |
| 4 | Stats | chart.bar | chart.bar.fill |
| 5 | Profile | person | person.fill |

**States:**
- Active: Filled icon + accent color + label
- Inactive: Outlined icon + gray + label

**Dimensions:**
```dart
height: 70px
horizontalMargin: 24px
bottomMargin: 20px
iconSize: 24px
labelSize: 11px
itemSpacing: equal distribution
```

**Implementation:**
- Use `Container` with `BoxDecoration` for pill shape
- `Row` with `Expanded` children for equal spacing
- Wrap in `Positioned` at bottom of `Stack`

---

### List Items
- Full-width tap target
- Chevron for navigation
- Trailing accessories aligned right
- Dividers between items (not on last)

---

### Search Bar
*Reference: User-provided image*

**Style:**
- Pill shape, full width
- Background: theme.surfaceContainer
- No border

**Layout:**
```
[Search Icon] [Placeholder text...] [Filter Icon]
```

**Dimensions:**
```dart
height: 44px
horizontalMargin: 16px
borderRadius: 22px (full pill)
iconSize: 20px
textSize: 16px
internalPadding: 12px
```

---

### Filter Chips
*Reference: User-provided image*

**Style:**
- Horizontal scroll (no scrollbar)
- Pill-shaped chips
- Icon (optional) + text

**States:**
- **Inactive**: Outlined border, transparent fill
- **Active**: Filled with theme.surface, darker border

**rem Filters:**
| Chip | Icon |
|------|------|
| All | none |
| Unread | circle |
| Links | link |
| Images | photo |
| Videos | play |
| Books | book |

**Dimensions:**
```dart
chipHeight: 36px
chipPadding: 12px horizontal
chipSpacing: 8px
borderRadius: 18px (full pill)
iconSize: 16px
textSize: 14px
scrollPadding: 16px (left/right edges)
```

---

### Content Cards (Item Cards)
*Reference: User-provided image*

**Style:**
- Full-width cards
- Large thumbnail image (16:9 or square)
- Rounded corners
- Action button overlay (top-right)

**Layout:**
```
+---------------------------+
|  [Image]           [Save] |
|                           |
+---------------------------+
| Title                [DL] |
| Source/URL                |
| Meta • Meta • Meta        |
+---------------------------+
```

**Elements:**
| Element | Style |
|---------|-------|
| Thumbnail | Rounded 12px, fills width |
| Save/Bookmark | Icon button, top-right overlay |
| Title | 17px Semibold, 2 lines max |
| Source | 14px Regular, theme.textSecondary |
| Metadata | 13px Regular, theme.textTertiary, dot-separated |

**rem Metadata:**
- Priority indicator (subtle)
- Estimated read time
- Date saved

**Dimensions:**
```dart
cardMargin: 16px horizontal
cardSpacing: 16px vertical
imageHeight: 200px (or aspect ratio)
imageRadius: 12px
contentPadding: 12px
actionButtonSize: 32px
actionButtonMargin: 8px from edges
```

---

### List Items (Alternative to Cards)
For compact view:

**Layout:**
```
[Thumb] | Title                    | [>]
        | Source • Read time       |
```

**Dimensions:**
```dart
height: 72px
thumbnailSize: 56px
thumbnailRadius: 8px
```

---

---

## Icons
*User will provide icon set*
- Style: SF Symbols / Outlined
- Weight: Regular (1.5px stroke)
- Size: 24px default

---

## Screens (To Be Implemented)

| Screen | Status | Notes |
|--------|--------|-------|
| Home | � Needs redesign | Apply monochrome |
| Add Item | ⬜ TODO | |
| Item Detail | ⬜ TODO | |
| Search | ⬜ TODO | |
| Settings | ⬜ TODO | iOS Settings style |
| Stats | ⬜ TODO | |

---

## User-Provided Designs

*Components will be added here as user provides them*

---

*Last updated: 2026-02-03*
