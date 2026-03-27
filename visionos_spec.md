# Speed Reading visionOS — Specification & Implementation Plan

**Version:** 1.0
**Last Updated:** March 2026
**Status:** Eng Review CLEARED
**Target Platform:** visionOS 2.0+ (Apple Vision Pro)
**Approach:** Same Xcode project, new visionOS target, shared Core/Services

---

## 1. Executive Summary

Port the Speed Reading iOS app to Apple Vision Pro as a native spatial computing experience. Phase 1A delivers a working windowed visionOS app with glass material, ornaments, and all existing features. Phase 1B upgrades to a volumetric 3D bookshelf and immersive reading space.

The core reading engine (PlaybackEngine, TokenizerService, ORPCalculator, EPUB parsing) is shared between iOS and visionOS with zero changes. Only the UI layer is platform-specific.

---

## 2. Vision

A "teleprompter in space" — the ORP-highlighted word floating in your living room at 400 WPM. No phone in your hand, no screen to stare at. Books arranged on a spatial bookshelf you can browse by looking and pinching. The 10x feature (v2): eye tracking pause/resume — look at the word it plays, look away it pauses. Truly hands-free reading that only makes sense on Vision Pro.

---

## 3. Platform Research Summary

### visionOS Simulator
- Available since Xcode 15.2 (Feb 2024), current: Xcode 16.4 with visionOS 2.5 SDK
- **Requires Apple Silicon Mac** (M1/M2/M3/M4) — no Intel support
- Download: `Xcode > Settings > Platforms > visionOS` or `xcodebuild -downloadPlatform visionOS`
- Build destination: `platform=visionOS Simulator,name=Apple Vision Pro`
- Controls: mouse = eye gaze, click = pinch, Option+drag = two-handed gestures
- **Can test:** window layout, glass material, gestures, SwiftUI UI, navigation
- **Cannot test:** hand tracking, eye tracking, room scanning, spatial audio, real passthrough

### visionOS Window System
- **WindowGroup** — standard 2D windows with automatic glass material background
- **Volumes** — bounded 3D containers (`.windowStyle(.volumetric)`)
- **ImmersiveSpace** — takes over user's environment (`.mixed`, `.progressive`, `.full`)
- Windows float in space, are resizable, have no screen edges
- Glass material is translucent, adaptive, depth-aware — the signature visionOS look

### Input Model
- **Look + Pinch** — eye tracking highlights element, finger pinch = tap
- All SwiftUI gestures translate automatically:
  - `.onTapGesture` → look + pinch
  - `DragGesture` → pinch + drag
  - `LongPressGesture` → sustained pinch
- **No haptics** — visionOS has no haptic motor (no `UIImpactFeedbackGenerator`)

### SwiftUI Compatibility
- Most SwiftUI views and modifiers work unchanged on visionOS
- `@Observable`, `@State`, `@Binding`, `@Environment` all work identically
- `NavigationStack`, sheets, alerts, `.task {}` all work
- **Not available:** `UIFont`, `UIDevice`, `UIScreen`, `UIImpactFeedbackGenerator`
- **visionOS-only:** `.ornament()`, `.glassBackgroundEffect()`, `ImmersiveSpace`, `SpatialTapGesture`, `.hoverEffect()`

### Ornaments
- UI elements that float outside the window boundary, attached to window edges
- visionOS replacement for toolbars and bottom bars
- `ToolbarItemGroup(placement: .bottomOrnament)` for simple controls
- Custom `.ornament(attachmentAnchor: .scene(.bottom))` for full control
- Get glass capsule background automatically (toolbar) or via `.glassBackgroundEffect()` (custom)

### Platform Conditionals
```swift
#if os(visionOS)
// visionOS-specific code
#else
// iOS code
#endif
```

### Multi-Platform Configuration
- Add visionOS as Supported Destination in existing Xcode target, or create separate target
- Share source files between targets via target membership
- Single .xcodeproj builds both iOS and visionOS

---

## 4. Project Structure

```
SpeedReading.xcodeproj
├── Target: SpeedReading (iOS)              # EXISTING — unchanged
│   ├── App/SpeedReadingApp.swift            # iOS entry point
│   ├── Core/*                              # Shared with visionOS
│   ├── Services/*                          # Shared with visionOS
│   ├── Features/Library/*                  # iOS library UI
│   ├── Features/Reader/*                   # iOS reader UI
│   ├── Features/Menu/*                     # iOS menu
│   ├── Features/Search/*                   # Shared
│   ├── Features/Settings/*                 # Shared
│   ├── Features/TOC/*                      # Shared
│   └── UI/*                                # Shared (with #if conditionals)
│
└── Target: SpeedReading visionOS           # NEW
    ├── App/SpeedReadingVisionApp.swift      # visionOS entry point
    ├── Core/*                              # Shared (same files)
    ├── Services/*                          # Shared (same files)
    ├── Features/VisionOS/                  # NEW — visionOS-specific UI
    │   ├── SpatialNavigationState.swift    # @Observable nav state
    │   ├── SpatialLibraryView.swift        # Phase 1B: 3D bookshelf
    │   ├── SpatialBookEntity.swift         # Phase 1B: RealityKit book
    │   ├── SpatialReaderView.swift         # Phase 1B: immersive reader
    │   ├── SpatialORPView.swift            # Phase 1B: floating word
    │   ├── SpatialControlBar.swift         # Phase 1B: control ornament
    │   ├── SpatialProgressRing.swift       # Phase 1B: circular progress
    │   └── SpatialParagraphPreview.swift   # Phase 1B: glass panel
    └── UI/Helpers/FontMetrics.swift         # Cross-platform font measurement
```

### Shared Code (zero changes)
- `Core/Models/*` — Book, Word, Document, Settings, Chapter, etc.
- `Core/ORP/*` — ORPCalculator, ORPDisplayLogic
- `Core/Playback/*` — PlaybackEngine
- `Core/Tokenizer/*` — TokenizerService
- `Services/EPUB/*` — EPUBImportService, parsers
- `Services/FileImport/*` — FileImportService, MarkdownStripper (DocumentPicker deleted)
- `Services/Library/*` — LibraryDataService
- `Services/Storage/*` — StorageService
- `Services/Search/*` — SearchService

---

## 5. Architecture Decisions

| # | Decision | Choice | Rationale |
|---|----------|--------|-----------|
| 1 | Theme colors | `#if os(visionOS)` in Theme.swift | Glass material needs `.clear` backgrounds and system text colors |
| 2 | File import | Migrate to `.fileImporter()` on both platforms | SwiftUI built-in, deletes DocumentPicker.swift, works everywhere |
| 3 | Navigation | SpatialNavigationState for visionOS | NavigationStack can't span volume/immersive scenes |
| 4 | Entry point | Declare both WindowGroup + ImmersiveSpace | Full structure scaffolded from start for easy Phase 1B upgrade |
| 5 | Font measurement | FontMetrics.swift with CTFont/UIFont | UIFont unavailable on visionOS, fixes DRY violation |
| 6 | ORP rendering | SwiftUI views (v1), RealityKit text (v2) | Maximum code reuse first, upgrade visual quality later |

### Navigation Architecture

```
iOS:                                    visionOS:
┌──────────────────┐                   ┌──────────────────┐
│ NavigationRouter │                   │ SpatialNavState  │
│ (ObservableObject)│                   │ (@Observable)    │
│                  │                   │                  │
│ NavigationStack  │                   │ selectedBookId   │
│ path.append()    │                   │ isReaderOpen     │
│ path.removeLast()│                   │                  │
└──────────────────┘                   │ selectBook()     │
                                       │ closeReader()    │
                                       │                  │
                                       │ Phase 1A: Nav    │
                                       │ Phase 1B: Scenes │
                                       └──────────────────┘
```

### Scene Structure (visionOS entry point)

```swift
@main
struct SpeedReadingVisionApp: App {
    @State private var navState = SpatialNavigationState()

    var body: some Scene {
        // Library window — wider for book grid
        WindowGroup(id: "library") {
            ContentView()
                .environment(navState)
        }
        .defaultSize(width: 900, height: 600)

        // Reader window — focused for single-word ORP display
        WindowGroup(id: "reader") {
            ReaderView()
                .environment(navState)
        }
        .defaultSize(width: 600, height: 400)

        ImmersiveSpace(id: "immersiveReader") {
            // Phase 1B: SpatialReaderView()
            Text("Immersive reader — coming in Phase 1B")
                .environment(navState)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
```

---

## 6. Phase 1A: Windowed visionOS App

**Goal:** All features working in a visionOS window. Testable in simulator.

### 6.1 Files to Create

| File | Purpose |
|------|---------|
| `App/SpeedReadingVisionApp.swift` | visionOS entry point with WindowGroup + ImmersiveSpace |
| `Features/VisionOS/SpatialNavigationState.swift` | @Observable navigation state for visionOS |
| `UI/Helpers/FontMetrics.swift` | Cross-platform character width measurement (CTFont/UIFont) |

### 6.2 Files to Modify

| File | Change |
|------|--------|
| `UI/Theme/Theme.swift` | `#if os(visionOS)` for glass-compatible colors |
| `Features/Reader/ORPDisplayView.swift` | Replace 3x UIFont with FontMetrics |
| `Features/Library/LibraryView.swift` | `.fileImporter()` migration, `.hoverEffect()`, ornaments |

### 6.3 Files to Delete

| File | Reason |
|------|--------|
| `Services/FileImport/DocumentPicker.swift` | Replaced by `.fileImporter()` |

### 6.4 Xcode Project Changes

- Add visionOS target to SpeedReading.xcodeproj
- Supported Destinations: Apple Vision
- Deployment target: visionOS 2.0
- Share Core/ and Services/ source files via target membership
- Create shared Xcode scheme for visionOS builds

### 6.5 Theme Adaptation

```swift
enum Theme {
    enum Colors {
        static let background: Color = {
            #if os(visionOS)
            return .clear  // Glass material shows through
            #else
            return Color(hex: 0x1A1A1A)
            #endif
        }()

        static let cardBackground: Color = {
            #if os(visionOS)
            return .clear
            #else
            return Color(hex: 0x2A2A2A)
            #endif
        }()

        static let primaryText: Color = {
            #if os(visionOS)
            return .primary  // System-calibrated for glass
            #else
            return Color(hex: 0xE0E0E0)
            #endif
        }()

        static let secondaryText: Color = {
            #if os(visionOS)
            return .secondary
            #else
            return Color(hex: 0x888888)
            #endif
        }()

        // ORP red stays the same — contrasts well against glass
        static let orpHighlight = Color(hex: 0xFF3333)
    }

    enum Layout {
        static let defaultFontSize: CGFloat = {
            #if os(visionOS)
            return 64  // Larger for spatial viewing distance
            #else
            return 48
            #endif
        }()
    }
}
```

### 6.6 FontMetrics Utility

```swift
// UI/Helpers/FontMetrics.swift
import SwiftUI
import CoreText

enum FontMetrics {
    static func monospacedCharacterWidth(fontSize: CGFloat) -> CGFloat {
        #if os(visionOS)
        let font = CTFontCreateWithName("Menlo" as CFString, fontSize, nil)
        let characters: [UniChar] = [0x0057] // 'W'
        var glyphs: [CGGlyph] = [0]
        CTFontGetGlyphsForCharacters(font, characters, &glyphs, 1)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, &glyphs, &advance, 1)
        return advance.width
        #else
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        return ("W" as NSString).size(withAttributes: [.font: font]).width
        #endif
    }
}
```

### 6.7 visionOS Reader Layout

The reader on visionOS uses a **word-only glass window** with a **bottom ornament** for all controls. This maximizes focus on the ORP word.

**Window:** 600x400pt (smaller than library to focus attention on the single word)

```
┌───────────────────────────────────┐
│         GLASS WINDOW              │
│                                   │
│        ex[tr]aordinary            │
│    (ORP word fills window)        │
│                                   │
└───────────────────────────────────┘
  ┌─────────────────────────────────┐
  │  BOTTOM ORNAMENT (glass)        │
  │ ◀◀ ▶⏸ ▶▶ | ≡ ↔ ☰ | 300wpm    │
  │ ━━━━●━━━━━━ 42% 12:34          │
  └─────────────────────────────────┘
```

**Main window:** Only the `ORPDisplayView` — no buttons, no progress bar, no stats. Tap-to-toggle play/pause works on the main window via `SpatialTapGesture`.

**Bottom ornament contents** (via `.ornament(attachmentAnchor: .scene(.bottom))`):
- Play/pause, previous sentence, next sentence buttons
- Paragraph preview, navigation overlay toggle, menu buttons
- Progress bar with scrub support
- Stats: WPM, time remaining, percentage, chapter time
- Uses `.glassBackgroundEffect()` for capsule appearance

**Ornament visibility state machine:**

```
State: VISIBLE
  ├─ Playback starts → start 3s hide timer → HIDING
  ├─ Scrubbing starts → cancel timer, stay VISIBLE
  └─ Paused → stay VISIBLE (always visible when paused)

State: HIDING
  ├─ Timer fires → fade out (0.3s opacity animation) → HIDDEN
  └─ Any interaction (pinch/tap/scrub) → cancel timer → VISIBLE

State: HIDDEN
  ├─ Any interaction → fade in (0.3s opacity) → VISIBLE, restart 3s timer
  ├─ Playback pauses → fade in → VISIBLE (no timer)
  └─ Playback completes → fade in → VISIBLE (no timer)
```

**Timing constants** (reuse from iOS `Theme.Animation`):
- Hide delay: 3.0s (slightly longer than iOS 2.0s — spatial needs more discovery time)
- Fade duration: 0.3s (matches `navigationOverlayFadeDuration`)
- During scrubbing: ornament stays visible, timer paused
- On completion: ornament stays visible permanently (completion card overlays)

### 6.8 visionOS Library Card Styling

Book cards use `.glassBackgroundEffect()` for layered frosted-glass boundaries:

```swift
#if os(visionOS)
BookCardView(...)
    .glassBackgroundEffect()
    .hoverEffect(.highlight)
#else
BookCardView(...)
    .background(Theme.Colors.cardBackground)
#endif
```

Each card gets its own glass layer, creating subtle depth separation against the window's glass background — matching Apple's visionOS card pattern (Photos, Music apps).

### 6.9 visionOS Interaction States

All interaction states need visionOS-specific treatment. **Never use `Color.black.opacity()` overlays on glass** — they create muddy layered transparency. Use `.glassBackgroundEffect()` containers instead.

| State | iOS Pattern | visionOS Pattern |
|-------|-------------|-----------------|
| **Library empty** | Icon + "Your library is empty" + "Tap the + button to import" on dark bg | Same text content, but use `.primary`/`.secondary` system colors. Import button uses `.buttonStyle(.bordered)` with `.hoverEffect(.highlight)`. Icon uses `.primary` color. No background override — glass shows through. |
| **Import loading** | `Color.black.opacity(0.5)` fullscreen overlay + spinner in `cardBackground` card | **No dark overlay.** Centered glass card (`.glassBackgroundEffect()`) with system `ProgressView` + "Importing..." in `.secondary`. Card floats on glass without obscuring the library behind it. |
| **Reader loading** | Centered spinner + "Loading book..." on dark background | Centered system `ProgressView` + "Loading book..." in `.secondary` on the glass window. No background override — glass material provides the backdrop. |
| **Reader error** | Warning icon (`.orpHighlight` red) + error message + "Return to Library" button | Glass card container (`.glassBackgroundEffect()`) with SF Symbol `exclamationmark.triangle` in `.red`, error message in `.primary`, and "Return to Library" `.buttonStyle(.bordered)`. |
| **Book completion** | Fullscreen overlay with congratulations | Glass card overlay (`.glassBackgroundEffect()`) centered in the reader window. Shows book title, "Book Complete" heading, reading stats summary, and "Return to Library" `.buttonStyle(.borderedProminent)`. No fullscreen dark overlay. |

**Key rule:** On visionOS, use `#if os(visionOS)` to replace:
- `Color.black.opacity(0.5)` → remove (no overlay)
- `Theme.Colors.cardBackground` containers → `.glassBackgroundEffect()`
- `Theme.Colors.background` fills → `.clear` (glass shows through)
- Button styling → `.buttonStyle(.bordered)` + `.hoverEffect(.highlight)`

### 6.10 SpatialNavigationState

> *Renumbered from 6.7 — new sections 6.7-6.9 added by design review*

```swift
// Features/VisionOS/SpatialNavigationState.swift
import SwiftUI

@Observable
@MainActor
final class SpatialNavigationState {
    var selectedBookId: UUID?
    var isReaderOpen: Bool = false

    func selectBook(_ bookId: UUID) {
        selectedBookId = bookId
        isReaderOpen = true
    }

    func closeReader() {
        isReaderOpen = false
        selectedBookId = nil
    }
}
```

### 6.11 LibraryView .fileImporter Migration

```swift
// Replace:
.documentPicker(isPresented: $viewModel.showingDocumentPicker, onSelect: { ... })

// With:
.fileImporter(
    isPresented: $viewModel.showingDocumentPicker,
    allowedContentTypes: [.plainText, UTType(filenameExtension: "md") ?? .plainText, .epub],
    onCompletion: { result in
        switch result {
        case .success(let url):
            viewModel.handleFileSelected(url)
        case .failure:
            break // User cancelled or error
        }
    }
)
```

---

## 6.12 User Journey Storyboard (Phase 1A)

The moment-by-moment experience of using Speed Reading on visionOS. Each step describes what the user **sees** and **feels**.

```
STEP | USER DOES           | USER SEES                          | USER FEELS        | IMPLEMENTATION
-----|---------------------|------------------------------------|-------------------|----------------
  1  | Launch app          | Glass window fades in with library  | Calm, premium,    | WindowGroup(id:
     |                     | grid (or warm empty state if no     | "this feels       | "library") opens
     |                     | books). Glass material catches the  | spatial"          | at 900x600
     |                     | room's lighting.                    |                   |
     |                     |                                     |                   |
  2  | Tap "+" to import   | .fileImporter() sheet appears.      | Familiar (same    | .fileImporter()
     |                     | Select file. Glass card appears     | as iOS Files       | + glass loading
     |                     | with ProgressView "Importing..."    | picker)           | card per §6.9
     |                     | Book card materializes in grid      |                   |
     |                     | with .glassBackgroundEffect().      |                   |
     |                     |                                     |                   |
  3  | Tap a book card     | NEW READER WINDOW opens to the     | Expansion,        | openWindow(id:
     |                     | right of library. Library stays     | anticipation —    | "reader"). Library
     |                     | visible. Reader window (600x400)    | "two windows in   | window persists.
     |                     | contains first word with ORP red    | my space"         | dismissWindow()
     |                     | highlight. Bottom ornament slides   |                   | on back.
     |                     | in with controls.                   |                   |
     |                     |                                     |                   |
  4  | Pinch to start      | ORP word begins cycling. Bottom    | Focus, flow,      | SpatialTapGesture
     | (tap on word area)  | ornament auto-hides after 3s.      | "this is fast"    | toggles playback.
     |                     | Just the word on glass.             |                   | Ornament hides
     |                     |                                     |                   | via opacity anim.
     |                     |                                     |                   |
  5  | Reading flow        | Words appear one at a time with    | Immersed,         | PlaybackEngine
     |                     | red ORP highlight. Sentence ends   | effortless,       | drives word
     |                     | have subtle pause. Paragraph ends  | "teleprompter     | delivery. No
     |                     | have longer pause. No haptics      | in space"         | haptics on
     |                     | (visionOS has no haptic motor).    |                   | visionOS.
     |                     |                                     |                   |
  6  | Pinch to pause      | Word freezes. Bottom ornament      | Control,          | Ornament fades
     |                     | fades in with progress, stats,     | awareness of      | in on pause.
     |                     | navigation buttons.                | progress           |
     |                     |                                     |                   |
  7  | Finish book         | Glass card overlays reader window  | Accomplishment,   | CompletionOverlay
     |                     | with "Book Complete", book title,  | satisfaction      | with glass style
     |                     | "Return to Library" button.        |                   | per §6.9.
     |                     | Tap button → reader window closes, |                   | dismissWindow()
     |                     | library window still there.        |                   | returns to library.
```

**Key transition: Library → Reader (Step 3)**
- Uses `openWindow(id: "reader")` to open a second window
- Library window remains visible — user can glance back at their collection
- Reader window appears to the right (visionOS default placement for new windows)
- On "Return to Library" or back navigation: `dismissWindow(id: "reader")` closes the reader
- SpatialNavigationState coordinates which book is loaded via `selectedBookId`

**No onboarding in Phase 1A.** First-time users will discover ORP by tapping play — the red highlight is self-explanatory. Phase 1B could add a brief "how ORP works" tooltip on first launch.

---

## 7. Phase 1B: Spatial Upgrade (future)

### 7.1 Volumetric Library

- Convert WindowGroup to `.windowStyle(.volumetric)`
- Build SpatialLibraryView with RealityKit ModelEntity books
- Books as rectangular boxes with cover textures
- Look+pinch to select → opens immersive space
- `.defaultSize(width: 0.6, height: 0.4, depth: 0.3, in: .meters)`

### 7.2 Immersive Reader

- SpatialReaderView in ImmersiveSpace with `.mixed` immersion
- ORP word as SwiftUI attachment on positioned RealityKit entity
- Floating at ~2m, centered in user's forward direction
- Control ornament with play/pause, nav buttons, WPM, progress

### 7.3 Phase 1B Files

| File | Purpose |
|------|---------|
| `SpatialLibraryView.swift` | 3D bookshelf volume |
| `SpatialBookEntity.swift` | RealityKit book model |
| `SpatialReaderView.swift` | Immersive space reader |
| `SpatialORPView.swift` | ORP word as SwiftUI attachment |
| `SpatialControlBar.swift` | Control ornament |
| `SpatialProgressRing.swift` | Circular progress indicator |
| `SpatialParagraphPreview.swift` | Glass panel paragraph view |

---

## 8. Phase 2+: Future Features

| Feature | Effort | Dependencies |
|---------|--------|-------------|
| Eye tracking pause/resume | Large | visionOS 3+ APIs, ARKit privacy permission |
| Spatial audio sentence feedback | Medium | RealityKit spatial audio |
| Immersive reading environments | Medium | Custom skybox materials |
| MeshResource.generateText() ORP | Medium | RealityKit attributed text |
| iCloud sync (iOS ↔ visionOS) | Large | CloudKit or SwiftData |
| SharePlay reading sessions | Large | GroupActivities framework |

---

## 9. Gesture Mapping

| iOS Gesture | visionOS Equivalent | Context |
|-------------|---------------------|---------|
| Tap (play/pause) | Look at word area + pinch | Reader |
| Swipe left/right | Nav buttons in ornament (1A) / pinch+drag (1B) | Reader |
| Progress bar drag | Pinch + drag progress bar | Reader |
| Long press | Sustained pinch | Library (edit mode) |
| Tap book card | Look at book + pinch | Library |
| Back button | Back button / dismiss immersive space | Reader |
| File import | .fileImporter() (same on both) | Library |

---

## 10. Testing Strategy

### Unit Tests (automated)

| Test File | What It Tests |
|-----------|--------------|
| `FontMetricsTests.swift` | Character width > 0, deterministic, reasonable range |
| `SpatialNavigationStateTests.swift` | State machine: selectBook, closeReader, edge cases |
| `ORPDisplayRegressionTests.swift` | FontMetrics matches UIFont for font sizes 24-96 |

### Simulator Tests (manual)

1. Launch app — library renders in glass window
2. Import .txt file — appears in library
3. Import .epub file — chapters parsed, cover shown
4. Tap book → reader opens with ORP display
5. Tap word area → playback starts/stops
6. Verify progress bar, stats, navigation
7. Check ORP red contrast against glass material

### Device Tests (Apple Vision Pro)

1. All simulator tests
2. Font size comfort at natural viewing distance
3. Gesture reliability (pinch-to-play, drag-to-scrub)
4. Extended reading session (5+ minutes)
5. Battery impact during reading

### Build Commands

```bash
# Build for visionOS simulator
xcodebuild build -project SpeedReading.xcodeproj -scheme "SpeedReading visionOS" \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro' \
  CODE_SIGNING_ALLOWED=NO

# Run tests on visionOS simulator
xcodebuild test -project SpeedReading.xcodeproj -scheme "SpeedReading visionOS" \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro'

# Verify iOS still works
xcodebuild build -project SpeedReading.xcodeproj -scheme SpeedReading \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

---

## 11. Failure Modes & Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| ORP red not visible on glass material | High | Test in simulator early; fall back to system `.red` |
| Font too small for spatial viewing | Medium | Default 64pt on visionOS, test on device |
| openImmersiveSpace fails | Medium | Error handling in SpatialNavigationState |
| .fileImporter() regression on iOS | Low | Manual test import flows after migration |
| CTFont measurement differs from UIFont | Medium | Regression test comparing measurements |

---

## 12. Open Questions

1. **Glass material contrast** — Does ORP red (#FF3333) provide sufficient contrast against glass in all lighting? Needs device testing.
2. **Font size sweet spot** — What's comfortable for reading at arm's length on Vision Pro? Default 64pt, may need 72-96pt.
3. **Word positioning (Phase 1B)** — Should the floating word anchor to fixed space point or follow head (billboard)? Needs testing.
4. **Volume size (Phase 1B)** — How large should the bookshelf volume be? Apple HIG suggests starting with defaults.
5. **Eye tracking API (Phase 2)** — Are visionOS 3 eye-scrolling APIs sufficient, or need full ARKit eye tracking?

---

## 13. Distribution

- **Personal use:** Xcode direct install to Apple Vision Pro
- **Beta testing:** TestFlight (visionOS supported)
- **Production:** App Store (visionOS category, separate submission from iOS)
- **Build:** Single Xcode project, separate targets, same developer account

---

## 14. Prerequisites

- Apple Silicon Mac (M1/M2/M3/M4)
- Xcode 16.3+ with visionOS simulator runtime installed
- macOS Sequoia 15.2+
- Apple Vision Pro (for device testing)
- 16GB+ RAM (32GB recommended for simulator)

---

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | — |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN) | 5 issues, 1 critical gap, all resolved |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | OPEN (FULL) | score: 5/10 → 7/10, 5 decisions added |

- **UNRESOLVED:** 0 unresolved decisions across all reviews
- **VERDICT:** ENG CLEARED — ready to implement. Design score 7/10 (3 passes skipped by user choice: AI slop, design system, responsive/a11y).
