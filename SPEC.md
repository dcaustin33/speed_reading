# Phase 1B: Spatial Volumetric & Immersive visionOS Upgrade

**Version:** 1.0
**Date:** 2026-03-27
**Status:** Draft
**Depends on:** Phase 1A complete (windowed visionOS app, all features working)
**Branch:** `feature/visionos`

---

## 1. Goal

Convert the Phase 1A windowed visionOS app into a true spatial computing experience:
- **Volumetric library** — 3D bookshelf with RealityKit book entities
- **Mixed immersive reader** — ORP word floating in the user's physical room
- **Spatial controls** — ornament-based control bar and circular progress ring

Phase 1A proved the engine works on visionOS. Phase 1B delivers the "teleprompter in space" wow factor — the core value proposition of the visionOS port.

---

## 2. Architecture Overview

### Critical Platform Constraint: Volumetric Presentation Limitation

> **visionOS 2.x does NOT support presentations (sheets, alerts, `.fileImporter()`) inside volumetric windows.** Attempting to present from a volumetric context produces: *"Presentations are not currently supported in Volumetric contexts"*. This restriction is lifted in visionOS 26 (WWDC25), but we target visionOS 2.0+.
>
> **Impact:** The library needs `.fileImporter()` for book import. We must keep a **plain window** for the library and use a `RealityView` inside it to render 3D book entities. The volumetric window style is not viable for the library in this release.
>
> **Alternative chosen:** Use `.windowStyle(.plain)` with a `RealityView` embedded inside it. This still renders 3D book entities with full RealityKit interaction while retaining access to `.fileImporter()`, sheets, and alerts. The visual difference from a true volumetric window is minimal — books render in 3D within the window bounds.

### Scene Structure (after Phase 1B)

```
SpeedReadingVisionApp
├── WindowGroup(id: "library")           # PLAIN window with embedded RealityView
│   └── SpatialLibraryView               # RealityView with 3D book entities
│       ├── SpatialBookEntity[]           # ModelEntity books with cover textures
│       ├── Import button (ornament)      # Bottom ornament for "+" import
│       └── .fileImporter()              # Works because window is .plain
│
├── ImmersiveSpace(id: "immersiveReader") # UPGRADED → real content
│   └── SpatialReaderView                 # Mixed immersive space
│       ├── SpatialORPView                # SwiftUI attachment: floating ORP word
│       ├── SpatialControlBar             # SwiftUI attachment: play/pause, nav
│       ├── SpatialProgressRing           # Circular progress indicator (optional)
│       └── SpatialParagraphPreview       # Glass panel paragraph context (optional)
│
└── WindowGroup(id: "reader")            # KEPT as fallback (settings, search, TOC)
    └── ReaderWindowView                  # Existing windowed reader
```

**Note:** Only ONE `ImmersiveSpace` can be open system-wide at a time. If another app's immersive space is already active, `openImmersiveSpace` returns `.error`.

### Navigation Flow

```
┌──────────────────────────┐
│  PLAIN WINDOW + 3D       │
│  (RealityView bookshelf) │
│                          │
│  📕 📗 📘 📙             │  ← Look + pinch to select
│                          │
│  [+ Import]              │  ← Bottom ornament (.fileImporter works here)
└──────────┬───────────────┘
           │ selectBook() → openImmersiveSpace("immersiveReader")
           │ Result: .opened / .userCancelled / .error
           ▼
┌──────────────────────────────────────────┐
│  MIXED IMMERSIVE SPACE                   │
│  (user's room is visible)                │
│                                          │
│        extraord|inary                    │  ← Floating ORP word at ~2m
│                                          │     (head-anchored, BillboardComponent)
│  ┌──────────────────────────────┐        │
│  │ ◀◀  ⏯  ▶▶ │ ≡ ☰ │ 300wpm  │        │  ← Control bar (SwiftUI attachment)
│  │ ━━━●━━━━━━  42%  12:34      │        │
│  └──────────────────────────────┘        │
│                                          │
└──────────────────────────────────────────┘
           │ closeReader() → dismissImmersiveSpace()
           │ Also triggered by: Digital Crown, system preemption
           ▼
┌──────────────────────────┐
│  PLAIN WINDOW + 3D       │
│  (back to bookshelf)     │
└──────────────────────────┘
```

### State Management

```swift
@Observable
@MainActor
final class SpatialNavigationState {
    // Existing (Phase 1A)
    var selectedBookId: UUID?
    var isReaderOpen: Bool = false

    // New (Phase 1B)
    var isImmersiveSpaceOpen: Bool = false
    var immersiveSpaceError: String?

    func selectBook(_ bookId: UUID) {
        selectedBookId = bookId
        isReaderOpen = true
    }

    func closeReader() {
        isReaderOpen = false
        isImmersiveSpaceOpen = false
        selectedBookId = nil
    }

    func immersiveSpaceOpened() {
        isImmersiveSpaceOpen = true
    }

    func immersiveSpaceFailed(_ error: String) {
        immersiveSpaceError = error
        isImmersiveSpaceOpen = false
    }
}
```

---

## 3. Component Specifications

### 3.1 SpatialLibraryView — 3D Bookshelf in Plain Window

**What:** Replace the flat library grid with a `RealityView` containing 3D book entities, hosted inside a **plain window** (not volumetric — see Architecture constraint above).

**Window config:**
```swift
WindowGroup(id: "library") {
    SpatialLibraryView()
}
.windowStyle(.plain)  // NOT .volumetric — needed for .fileImporter() support
.defaultSize(width: 900, height: 600)
```

**Why plain, not volumetric:** Volumetric windows on visionOS 2.x cannot present sheets, alerts, or `.fileImporter()`. Since the library needs file import, we use a plain window with an embedded `RealityView` for 3D content. This still renders 3D book entities with hover/tap interaction — the books just live within the window frame rather than floating in unbounded space.

**Book layout:**
- Books arranged on a single shelf row (or 2 rows if many books)
- Each book is a `SpatialBookEntity` — a rectangular `MeshResource.generateBox()` with cover image as texture
- Books stand upright, spines facing the user
- Spacing: ~5cm between books
- Selection: look at book → system hover highlight via `HoverEffectComponent` → pinch to open

**Empty state:**
- Glass panel in the center: "Your library is empty"
- "Import a book" button with `.hoverEffect(.highlight)`

**Import button:**
- Bottom ornament with "+" button (ornaments ARE supported on plain windows)
- Triggers `.fileImporter()` (works in plain window context)
- On successful import → new `SpatialBookEntity` materializes with scale-up animation via `Entity.move(to:relativeTo:duration:timingFunction:)`

**Interactions:**
| Input | Action |
|-------|--------|
| Look at book | System hover highlight via `HoverEffectComponent` |
| Pinch (tap) book | `SpatialTapGesture.targetedToAnyEntity()` → identify via `BookComponent` → open immersive reader |
| Look at "+" | Highlight |
| Pinch "+" | Open file importer |

### 3.2 SpatialBookEntity — RealityKit Book Model

**What:** A RealityKit `ModelEntity` representing a book on the shelf.

**Geometry:**
- `MeshResource.generateBox(width: 0.02, height: 0.15, depth: 0.10)` — thin book shape
- Front face: cover image texture (from `Covers/{UUID}.jpg`) or generated gradient with title text
- Spine: title text (truncated to fit)
- Material: `SimpleMaterial` with cover image, or `PhysicallyBasedMaterial` for more realism

**Default cover (no image):**
- Solid color `SimpleMaterial` based on book title hash (deterministic color from fixed palette)
- Title text rendered as SwiftUI `Attachment` overlaying the front face (preferred over `MeshResource.generateText()` for readability, Dynamic Type support, and accessibility)
- Author name smaller below title

**Cover image texture loading (verified API):**
```swift
guard let cgImage = uiImage.cgImage else { return }
let texture = try TextureResource.generate(from: cgImage, options: .init(semantic: .color))
var material = SimpleMaterial()
material.color = .init(texture: .init(texture))
```

**Components (all three required for interactive entities):**
- `InputTargetComponent()` — marks entity as input-targetable; without this, no gestures work
- `CollisionComponent(shapes: [ShapeResource.generateBox(size: boxSize)])` — defines hit-test shape; required alongside InputTargetComponent
- `HoverEffectComponent()` — system highlight on gaze; privacy-preserving (app never receives raw eye data)

**Custom data component:**
```swift
struct BookComponent: Component {
    var bookID: UUID
    var title: String
}
// Attach: entity.components.set(BookComponent(bookID: book.id, title: book.title))
// Read:   value.entity.components[BookComponent.self]?.bookID
```

**Selection feedback:**
- On hover: system-provided highlight via `HoverEffectComponent` (no custom animation needed for v1)
- On select: scale pulse via `Entity.move(to: Transform(scale: [1.1, 1.1, 1.1], ...), relativeTo: entity.parent, duration: 0.2, timingFunction: .easeOut)` then opens immersive reader

### 3.3 SpatialReaderView — Immersive Space Reader

**What:** The core reading experience in `.mixed` immersive space. The user's real room is visible; the ORP word floats in front of them.

**Immersive space config (verified API):**
```swift
// In App body — selection binding allows runtime style switching
@State private var immersionStyle: ImmersionStyle = .mixed

ImmersiveSpace(id: "immersiveReader") {
    SpatialReaderView()
}
.immersionStyle(selection: $immersionStyle, in: .mixed)
```

**Opening (from library view):**
```swift
@Environment(\.openImmersiveSpace) private var openImmersiveSpace

let result = await openImmersiveSpace(id: "immersiveReader")
switch result {
case .opened: navState.immersiveSpaceOpened()
case .userCancelled: break  // User declined
case .error: navState.immersiveSpaceFailed("System error")
@unknown default: break
}
```

**Dismissing:**
```swift
@Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
await dismissImmersiveSpace()  // No parameters — only one can be open
```

**System-initiated dismissals (Digital Crown, safety boundary, other app):** Detected via `.onDisappear` on the immersive content view. Always save progress in `.onDisappear`.

**Layout:**
```
                    User's physical room
                    ┌─────────────────────────────────┐
                    │                                 │
                    │                                 │
    ~2m from user → │     extraord|inary              │  ← SpatialORPView
                    │                                 │     (SwiftUI attachment)
                    │                                 │
                    │  ┌────────────────────────┐     │
                    │  │ Controls + Progress    │     │  ← SpatialControlBar
                    │  └────────────────────────┘     │     (below ORP word)
                    │                                 │
                    └─────────────────────────────────┘
```

**Positioning (verified API):**
- ORP word anchored ~2m in front of user via `AnchoringComponent(.head, trackingMode: .continuous)`
- This is **privacy-preserving** — no ARKit authorization prompt needed
- Child entities are positioned relative to the head anchor: `[0, 0, -2.0]` means 2m forward (-Z is forward in visionOS coordinate system)
- **`BillboardComponent()`** (visionOS 2.0+) must be added to attachments so they always face the user
- If head-locked content causes discomfort, switch to `.predicted` tracking mode (visionOS 2.0+) for smoother updates, or use world-anchored positioning with `BillboardComponent` only

**Coordinate system (visionOS immersive spaces):**
- Origin: floor level directly below user's feet when space opens
- +X: right, +Y: up, **-Z: forward** (away from user), +Z: toward user
- Units: 1 unit = 1 meter
- Head-anchored children: `[0, 0, -2.0]` = 2m directly ahead of eyes

**RealityView structure (verified API):**
```swift
struct SpatialReaderView: View {
    @Environment(SpatialNavigationState.self) var navState
    @StateObject private var viewModel: ReaderViewModel

    var body: some View {
        RealityView { content, attachments in
            // Head-anchored container — no ARKit auth required
            let headAnchor = Entity()
            headAnchor.components.set(
                AnchoringComponent(.head, trackingMode: .continuous)
            )

            // IMPORTANT: Attachments are NOT auto-added.
            // Must explicitly addChild() or content.add()

            // Add ORP word attachment — 2m forward from head
            if let orpView = attachments.entity(for: "orpDisplay") {
                orpView.position = [0, 0, -2.0]
                orpView.components.set(BillboardComponent())  // Always face user
                headAnchor.addChild(orpView)
            }

            // Add control bar — 0.3m below the ORP word
            if let controls = attachments.entity(for: "controlBar") {
                controls.position = [0, -0.3, -2.0]
                controls.components.set(BillboardComponent())
                headAnchor.addChild(controls)
            }

            content.add(headAnchor)
        } update: { content, attachments in
            // Fires when SwiftUI state changes — use for dynamic attachment updates
        } attachments: {
            Attachment(id: "orpDisplay") {
                SpatialORPView(viewModel: viewModel)
            }

            Attachment(id: "controlBar") {
                SpatialControlBar(viewModel: viewModel)
            }
        }
    }
}
```

**Key API notes:**
- `make` closure runs once on appear (async). `update` closure runs on every SwiftUI state change (sync).
- `Attachment(id:)` accepts any `Hashable` ID. `attachments.entity(for:)` returns `ViewAttachmentEntity?`.
- `ViewAttachmentEntity` inherits from `Entity` — has `.position`, `.scale`, `.components`, full entity hierarchy.
- Attachments are **live SwiftUI views**, not snapshots — they respond to state changes and handle gestures.

**Lifecycle:**
1. Immersive space opens → load book from `navState.selectedBookId`
2. ReaderViewModel initializes with book data
3. Playback begins on user tap (pinch)
4. On close: save progress → dismiss immersive space → return to library

### 3.4 SpatialORPView — Floating ORP Word

**What:** The ORP-highlighted word displayed as a SwiftUI `Attachment` in the immersive space.

**Display:**
- Same ORP logic as iOS: pre-text (white) + ORP char (red) + post-text (white)
- Font: `.system(size: 72, weight: .medium, design: .monospaced)` — larger for spatial viewing
- Background: glass panel behind the word for readability against the room
- Panel size: adapts to longest word, with comfortable padding

**Styling:**
```swift
struct SpatialORPView: View {
    @ObservedObject var viewModel: ReaderViewModel

    var body: some View {
        HStack(spacing: 0) {
            Text(preORPText)
                .foregroundStyle(.white)
            Text(orpCharacter)
                .foregroundStyle(Theme.Colors.orpHighlight)
            Text(postORPText)
                .foregroundStyle(.white)
        }
        .font(.system(size: 72, weight: .medium, design: .monospaced))
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
        .glassBackgroundEffect()
        .onTapGesture {
            viewModel.togglePlayback()
        }
    }
}
```

**Word transition animation:**
- Subtle opacity crossfade between words (0.05s) for smooth flow
- No jarring snap — maintains the "teleprompter" feel

### 3.5 SpatialControlBar — Immersive Space Controls

**What:** Playback controls, stats, and navigation rendered below the floating word.

**Layout:**
```
┌──────────────────────────────────────────────┐
│  ◀◀  ◀  ⏯  ▶  ▶▶  │  ≡  ↔  ☰  │  300wpm  │
│  ━━━━━━●━━━━━━━━━━━  42%  12:34 remaining   │
└──────────────────────────────────────────────┘
```

**Controls (row 1):**
- Previous paragraph, previous sentence, play/pause, next sentence, next paragraph
- Paragraph preview toggle, navigation overlay toggle, menu button
- WPM display

**Controls (row 2):**
- Progress bar (draggable for scrubbing)
- Percentage complete
- Time remaining
- Chapter time remaining (EPUB only)

**Visibility:** Same auto-hide state machine as Phase 1A ornament:
- Visible when paused
- 3s hide timer when playing
- Fades back on any interaction
- Always visible on completion

**Glass styling:** `.glassBackgroundEffect()` with comfortable padding

### 3.6 SpatialProgressRing — Circular Progress (Optional)

**What:** A subtle circular progress indicator around the ORP word panel, visible during playback.

**Purpose:** Gives ambient progress awareness without requiring the control bar to be visible.

**Design:**
- Thin ring (2pt stroke) around the glass panel
- Fills clockwise as reading progresses
- Color: `Theme.Colors.accentBlue` at 30% opacity (subtle, not distracting)
- Full ring = book complete

**Implementation:**
```swift
struct SpatialProgressRing: View {
    let progress: Double  // 0.0 - 1.0

    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(Theme.Colors.accentBlue.opacity(0.3), lineWidth: 2)
            .rotationEffect(.degrees(-90))
    }
}
```

**Decision:** This is a nice-to-have. Implement only if the reading experience feels like it lacks progress awareness without the control bar visible.

### 3.7 SpatialParagraphPreview — Glass Context Panel (Optional)

**What:** A small glass panel showing the upcoming sentence/paragraph context, positioned to the side of the ORP word.

**Purpose:** Helps readers maintain context, especially at higher WPM where individual words blur together.

**Position:** To the right and slightly below the ORP word (offset `[0.5, -0.1, 0]`).

**Content:**
- Current paragraph text with the current word highlighted
- Scrolls to keep the current word visible
- Only visible when paragraph preview is toggled on

**Decision:** Defer to Phase 1B stretch goals. Implement if time permits.

---

## 4. Files to Create

| File | Purpose | Effort |
|------|---------|--------|
| `Features/VisionOS/SpatialLibraryView.swift` | Volumetric 3D bookshelf | Large |
| `Features/VisionOS/SpatialBookEntity.swift` | RealityKit book model entity | Medium |
| `Features/VisionOS/SpatialReaderView.swift` | Immersive space reader with RealityView | Large |
| `Features/VisionOS/SpatialORPView.swift` | Floating ORP word as SwiftUI attachment | Medium |
| `Features/VisionOS/SpatialControlBar.swift` | Playback controls for immersive space | Medium |
| `Features/VisionOS/SpatialProgressRing.swift` | Circular progress indicator (optional) | Small |
| `Features/VisionOS/SpatialParagraphPreview.swift` | Paragraph context panel (optional) | Small |

## 5. Files to Modify

| File | Change |
|------|--------|
| `App/SpeedReadingVisionApp.swift` | Upgrade library to volumetric, fill in ImmersiveSpace content, add scene lifecycle handlers |
| `Features/VisionOS/SpatialNavigationState.swift` | Add `isImmersiveSpaceOpen`, `immersiveSpaceError`, `immersiveSpaceOpened()`, `immersiveSpaceFailed()` |
| `Features/VisionOS/ReaderWindowView.swift` | May demote to fallback for settings/search/TOC only |
| `UI/Theme/Theme.swift` | Add spatial-specific constants (font sizes, distances, animation timings) |

## 6. Files Unchanged

All Core/ and Services/ code remains untouched:
- `Core/Playback/PlaybackEngine.swift`
- `Core/ORP/ORPCalculator.swift`, `ORPDisplayLogic.swift`
- `Core/Tokenizer/TokenizerService.swift`
- `Core/Models/*`
- `Services/*`

---

## 7. Implementation Tasks

### Task 1: Upgrade SpatialNavigationState & App Entry Point
**Effort:** Small
**Files:** `SpatialNavigationState.swift`, `SpeedReadingVisionApp.swift`

- Add immersive space tracking to `SpatialNavigationState` (`isImmersiveSpaceOpen`, error handling)
- Upgrade `SpeedReadingVisionApp` scene structure:
  - Library window → `.windowStyle(.volumetric)` with `.defaultSize(width: 0.6, height: 0.4, depth: 0.3, in: .meters)`
  - Fill in `ImmersiveSpace(id: "immersiveReader")` with `SpatialReaderView()`
  - Add `@Environment(\.openImmersiveSpace)` and `@Environment(\.dismissImmersiveSpace)` handling
- Wire up scene lifecycle: dismiss immersive space when library window closes, handle errors

**Test:** Build compiles. SpatialNavigationState unit tests pass with new state transitions.

### Task 2: SpatialBookEntity — RealityKit Book Model
**Effort:** Medium
**Files:** `SpatialBookEntity.swift`

- Create `SpatialBookEntity` as a `ModelEntity` subclass or factory
- Generate box mesh: `MeshResource.generateBox(width: 0.02, height: 0.15, depth: 0.10)`
- Apply cover image texture if available (`Covers/{UUID}.jpg`)
- Generate deterministic gradient cover + title text for books without cover images
- Add `InputTargetComponent`, `CollisionComponent`, `HoverEffectComponent`
- Implement hover scale animation (1.0 → 1.05)
- Implement selection pulse animation (1.05 → 1.1 → 1.0)

**Test:** Entity creation with and without cover images. Components attached correctly.

### Task 3: SpatialLibraryView — Volumetric Bookshelf
**Effort:** Large
**Files:** `SpatialLibraryView.swift`

- Build `RealityView` with shelf layout
- Position `SpatialBookEntity` instances in a row with ~5cm spacing
- Handle book selection via `SpatialTapGesture` → `navState.selectBook()` → `openImmersiveSpace()`
- Empty state: glass panel with import prompt
- Bottom ornament: "+" import button with `.fileImporter()`
- Book add/remove animations (scale up on import, fade out on delete)
- Connect to `LibraryViewModel` for book data

**Test:** Books render in simulator. Tap selects book and triggers immersive space.

### Task 4: SpatialORPView — Floating ORP Word
**Effort:** Medium
**Files:** `SpatialORPView.swift`

- Implement the ORP-highlighted word display for immersive space
- Monospaced font at 72pt with red ORP highlight
- Glass background panel with adaptive sizing
- Tap gesture for play/pause toggle
- Subtle opacity crossfade between words
- Connect to `ReaderViewModel` for word data

**Test:** Word displays correctly with ORP highlight. Tap toggles playback.

### Task 5: SpatialControlBar — Immersive Controls
**Effort:** Medium
**Files:** `SpatialControlBar.swift`

- Playback controls: prev paragraph, prev sentence, play/pause, next sentence, next paragraph
- Menu access buttons: paragraph preview, navigation, settings menu
- Stats display: WPM, time remaining, percentage, chapter time
- Progress bar with drag-to-scrub
- Auto-hide state machine (3s timer, fade animation, interaction resets)
- Glass background styling

**Test:** All controls functional. Auto-hide behavior correct.

### Task 6: SpatialReaderView — Immersive Space Integration
**Effort:** Large
**Files:** `SpatialReaderView.swift`

- Build `RealityView` with entity anchoring
- Position ORP word at ~2m in front of user (head-anchored)
- Position control bar below the ORP word
- Wire up `ReaderViewModel` with book loading and playback
- Handle immersive space lifecycle (open, dismiss, error)
- Save progress on pause, paragraph end, and dismiss
- Handle completion overlay → dismiss immersive space → return to library
- Connect settings/search/TOC access (may open windowed overlays)

**Test:** Full reading flow in simulator: open book → play → pause → navigate → complete → return to library.

### Task 7: Integration & Polish
**Effort:** Medium
**Files:** Multiple

- Wire up library-to-immersive-to-library full navigation flow
- Handle edge cases: immersive space fails to open, book file deleted, app backgrounding
- Add Theme constants for spatial distances, font sizes, timing
- Ensure iOS target still builds and works (no regressions)
- Test all EPUB features (chapters, TOC navigation, search) in immersive context
- Optional: implement `SpatialProgressRing` if needed

**Test:** Full end-to-end flow. Both iOS and visionOS targets build clean. No regressions.

### Task 8: Unit Tests
**Effort:** Small
**Files:** `tests/`

- Update `SpatialNavigationStateTests.swift` for new state transitions
- Test `SpatialBookEntity` creation (with/without cover, deterministic colors)
- Test control bar auto-hide state machine
- Test immersive space lifecycle state management
- Verify both targets build and all tests pass

---

## 8. Open Design Decisions

| # | Decision | Options | Recommendation | Notes |
|---|----------|---------|----------------|-------|
| 1 | ORP word anchoring | Head-anchored vs world-anchored | **Head-anchored** via `AnchoringComponent(.head, trackingMode: .continuous)` | No ARKit auth needed. Add `BillboardComponent()` on attachments. If causes discomfort, try `.predicted` tracking (visionOS 2.0+) or switch to world-anchor. |
| 2 | Library window style | Volumetric vs plain with embedded RealityView | **Plain with RealityView** | **DECIDED by platform constraint**: volumetric windows cannot present `.fileImporter()` on visionOS 2.x. Plain window + RealityView gives 3D books + full presentation support. |
| 3 | Book entity complexity | Simple boxes vs detailed models | **Simple boxes** for v1 | Focus on functionality. `MeshResource.generateBox()` + `SimpleMaterial` with texture. |
| 4 | Settings/Search/TOC in immersive | Windowed overlay vs in-space attachment | **Windowed overlay** via `openWindow(id: "reader")` | WindowGroup can coexist with ImmersiveSpace in `.mixed` mode. Re-use existing views. |
| 5 | Book title on fallback covers | `MeshResource.generateText()` vs SwiftUI Attachment | **SwiftUI Attachment** | Better typography, Dynamic Type, accessibility. `generateText()` exists but produces extruded 3D text — overkill for cover labels. |
| 6 | Progress ring | Include vs defer | **Defer** | Nice-to-have. Implement if playback without visible controls feels disorienting. |
| 7 | Paragraph preview | Include vs defer | **Defer** | Nice-to-have. Start without it; add if users request context. |

---

## 9. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| Head-anchored entity causes motion sickness | High | Low | Use `.continuous` tracking first, then `.predicted` (visionOS 2.0+). Fallback: world-anchored + `BillboardComponent`. Test on device early. |
| `openImmersiveSpace` returns `.error` | Medium | Medium | Handle all 3 result cases (`.opened`, `.userCancelled`, `.error`). Fallback to windowed reader. Only ONE immersive space system-wide. |
| Another app's immersive space blocks ours | Medium | Medium | `openImmersiveSpace` returns `.error`. Show clear message + fall back to windowed reader. |
| Cover `TextureResource.generate(from:)` fails | Low | Medium | Graceful fallback to solid-color `SimpleMaterial` with SwiftUI attachment title overlay. |
| SwiftUI attachment scale in RealityKit | Medium | Medium | SwiftUI points ≠ meters. Attachments render at point scale. May need `.scaleEffect()` or entity `.scale` adjustment. Test early. |
| `BillboardComponent` not available (visionOS <2.0) | Low | Low | We target visionOS 2.0+. If needed, implement manual billboard via `entity.look(at:from:relativeTo:)`. |
| Immersive space dismissed by system (Digital Crown, safety boundary) | Medium | High | Save progress in `.onDisappear`. Track state via `navState.isImmersiveSpaceOpen`. Safety boundary triggers at ~1.5m from initial position. |
| Mixed immersion + glass readability | High | Medium | Test ORP red against real room backgrounds. May need larger/opaquer glass panel or larger font. |
| Performance with many books in RealityView | Low | Low | Lazy loading. Cap visible entities. Each book is a simple box — lightweight. |

---

## 10. Acceptance Criteria

### Must Have
- [ ] Volumetric library window with 3D book entities
- [ ] Books display cover images or generated fallback covers
- [ ] Look+pinch to select book → opens immersive reader
- [ ] ORP word floating in mixed immersive space with glass background
- [ ] Tap to play/pause in immersive space
- [ ] Full playback controls in spatial control bar
- [ ] Progress bar with scrubbing
- [ ] Auto-hide controls during playback
- [ ] Save/restore reading progress
- [ ] Return to library on book completion or back navigation
- [ ] Both iOS and visionOS targets build clean
- [ ] No regressions on iOS

### Should Have
- [ ] Smooth book selection animation
- [ ] Hover highlight on books
- [ ] Word transition animation (crossfade)
- [ ] Error handling for failed immersive space

### Nice to Have
- [ ] Circular progress ring around ORP word
- [ ] Paragraph preview panel
- [ ] Book add/remove animations in library

---

## 11. Testing Strategy

### Unit Tests
- SpatialNavigationState: all state transitions including immersive space
- SpatialBookEntity: entity creation, components, fallback covers
- Control bar auto-hide: timer, interaction reset, state transitions

### Simulator Tests
- Volumetric window renders with books
- Book selection triggers immersive space
- ORP word displays correctly in immersive space
- All controls work (play, pause, navigate, scrub)
- Settings/search/TOC accessible from immersive context
- Navigation back to library works
- Import new book from library

### Device Tests (Apple Vision Pro)
- Font size comfortable at natural viewing distance
- ORP red visible against real room backgrounds
- Gesture reliability in immersive space
- Extended reading session comfort (5+ minutes)
- Performance/battery impact

### Build Commands
```bash
# visionOS simulator
xcodebuild build -project SpeedReading.xcodeproj \
  -scheme "SpeedReading visionOS" \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro' \
  CODE_SIGNING_ALLOWED=NO

# iOS regression check
xcodebuild build -project SpeedReading.xcodeproj \
  -scheme SpeedReading \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

---

## 12. Dependencies & Frameworks

| Framework | Purpose | Already in project? |
|-----------|---------|-------------------|
| SwiftUI | All UI | Yes |
| RealityKit | 3D book entities, spatial anchoring | **No — new** |
| RealityFoundation | Entity, Component, Attachment | **No — new** |
| CoreText | Font metrics (existing) | Yes |

**Note:** RealityKit is only linked to the visionOS target. iOS target is unaffected.

---

## 13. Verified API Reference (from Apple documentation, March 2026)

### RealityView with Attachments (visionOS 1.0+)
```swift
// Make closure is async, runs once. Update closure is sync, runs on state change.
RealityView { content, attachments in  // inout RealityViewContent, RealityViewAttachments
    // MUST manually add attachments — NOT auto-added
    if let entity = attachments.entity(for: "id") {  // returns ViewAttachmentEntity?
        content.add(entity)  // or parentEntity.addChild(entity)
    }
} update: { content, attachments in
    // Fires on every SwiftUI state change
} attachments: {  // @AttachmentContentBuilder
    Attachment(id: "id") { Text("Hello") }  // id: AnyHashable
}
```

### Entity Anchoring (visionOS 1.0+)
```swift
// Head-anchored — NO ARKit authorization needed
let anchor = Entity()
anchor.components.set(AnchoringComponent(.head, trackingMode: .continuous))
// .continuous = follows every frame. .predicted (visionOS 2.0+) = smoother.
// Children positioned relative to head: [0, 0, -2.0] = 2m forward

// Available targets on visionOS:
// .head (1.0+), .hand(_:location:) (1.0+), .world(transform:),
// .plane(_:classification:minimumBounds:), .image(group:name:)
// NOT available: .camera, .face, .body (all unavailable on visionOS)
```

### BillboardComponent (visionOS 2.0+)
```swift
entity.components.set(BillboardComponent())  // Always faces user
// .blendFactor: Float — 0.0=no billboard, 1.0=full billboard (default)
```

### Interactive Entity Setup (required trio)
```swift
let boxSize = SIMD3<Float>(0.02, 0.15, 0.10)
let entity = ModelEntity(mesh: .generateBox(size: boxSize),
                         materials: [SimpleMaterial(color: .blue, isMetallic: false)])
entity.components.set(InputTargetComponent())  // Enable input
entity.components.set(CollisionComponent(      // Hit-test shape
    shapes: [ShapeResource.generateBox(size: boxSize)]))
entity.components.set(HoverEffectComponent())  // System gaze highlight

// Custom data
struct BookComponent: Component { var bookID: UUID; var title: String }
entity.components.set(BookComponent(bookID: id, title: "Book"))
```

### SpatialTapGesture
```swift
.gesture(
    SpatialTapGesture()
        .targetedToAnyEntity()
        .onEnded { value in
            let entity = value.entity  // The tapped entity
            if let book = entity.components[BookComponent.self] {
                openBook(book.bookID)
            }
        }
)
```

### TextureResource from CGImage
```swift
// Synchronous
let texture = try TextureResource.generate(from: cgImage, options: .init(semantic: .color))
var material = SimpleMaterial()
material.color = .init(texture: .init(texture))

// Async
let texture = try await TextureResource(image: cgImage, options: .init(semantic: .color))
```

### Entity Animation
```swift
// Animate to new transform over duration
entity.move(
    to: Transform(scale: [1.1, 1.1, 1.1], rotation: entity.transform.rotation,
                  translation: entity.transform.translation),
    relativeTo: entity.parent,
    duration: 0.2,
    timingFunction: .easeOut  // .linear, .easeIn, .easeOut, .easeInOut
)
```

### ImmersiveSpace Lifecycle
```swift
// Only ONE immersive space can be open system-wide at a time
@Environment(\.openImmersiveSpace) var open   // OpenImmersiveSpaceAction
@Environment(\.dismissImmersiveSpace) var dismiss  // DismissImmersiveSpaceAction

let result = await open(id: "immersiveReader")
// Result: .opened | .userCancelled | .error
await dismiss()  // No parameters needed

// System dismissals: Digital Crown, safety boundary (~1.5m), other app
// Detect via .onDisappear on the immersive content view
```

### Volumetric Window Limitations (visionOS 2.x)
```
- NO presentations: .fileImporter(), sheets, alerts, popovers all fail
  Error: "Presentations are not currently supported in Volumetric contexts"
  Fixed in visionOS 26 (WWDC25)
- Max size: 2 meters in any dimension
- Size immutable in visionOS 1.x; resizable in 2.0+ with .windowResizability(.contentSize)
- Ornaments ARE supported
- RealityView + SwiftUI mixing IS supported
```

### visionOS Coordinate System
```
Origin: floor level, below user's feet when space opens
+X: right    -X: left
+Y: up       -Y: down
-Z: forward  +Z: toward user
Units: 1 unit = 1 meter
```
