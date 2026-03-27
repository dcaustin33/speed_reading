# Implementation Plan: Phase 1B — Spatial Volumetric & Immersive visionOS

**Spec Reference:** `PHASE_1B_SPEC.md`
**Branch:** `feature/visionos`
**Prerequisites:** Phase 1A complete — windowed visionOS app with library, reader, ornament, all features working.
**New Framework:** RealityKit (visionOS target only)

### Critical Platform Constraints (from documentation research)

1. **Volumetric windows cannot present `.fileImporter()`, sheets, or alerts** on visionOS 2.x → library stays as plain window with embedded `RealityView`
2. **Attachments must be manually added** via `content.add()` or `addChild()` — NOT auto-added to scene
3. **`BillboardComponent()`** (visionOS 2.0+) required on attachments to face user — without it, views face -Z direction only
4. **`AnchoringComponent(.head, trackingMode: .continuous)`** for head-relative positioning — no ARKit auth needed
5. **Only ONE `ImmersiveSpace`** can be open system-wide at a time
6. **Coordinate system**: +X right, +Y up, **-Z forward**. Units: meters. Origin: floor level.
7. **Interactive entities require trio**: `InputTargetComponent` + `CollisionComponent` + `HoverEffectComponent`

---

## Phase 1: Foundation & State Management

- [x] **Task 1: Upgrade SpatialNavigationState for Immersive Space Lifecycle**
  - ✅ Completed: 2026-03-27
  - Tests: `tests/SpatialNavigationStateTests.swift` (18 tests, all passing — 10 new immersive space tests)
  - Implementation: Added `isImmersiveSpaceOpen`, `immersiveSpaceError`, `immersiveSpaceOpened()`, `immersiveSpaceFailed(_:)` to `SpatialNavigationState`. Updated `closeReader()` to reset immersive state.
  - Notes: Both iOS and visionOS targets build clean. Tests cover open success, open failure, close from immersive, error then retry, double-open guard, rapid open/close cycles.
  - Files changed: `SpatialNavigationState.swift`, `SpatialNavigationStateTests.swift`

  Extend the existing navigation state machine to track immersive space open/close/error states. This is the foundation that all subsequent tasks depend on.

  **Subtasks:**
  - Add `isImmersiveSpaceOpen: Bool` property to `SpatialNavigationState`
  - Add `immersiveSpaceError: String?` property for error reporting
  - Add `immersiveSpaceOpened()` method that sets `isImmersiveSpaceOpen = true` and clears any prior error
  - Add `immersiveSpaceFailed(_ error: String)` method that sets error and marks space as not open
  - Update `closeReader()` to also set `isImmersiveSpaceOpen = false`
  - Update `SpatialNavigationStateTests.swift` with tests for all new state transitions: open success, open failure, close from immersive, error then retry, double-open guard
  - Verify both iOS and visionOS targets still build clean

  **Files:** `SpeedReading/Features/VisionOS/SpatialNavigationState.swift`, `tests/SpatialNavigationStateTests.swift`

---

- [x] **Task 2: Upgrade SpeedReadingVisionApp Scene Structure**
  - ✅ Completed: 2026-03-27
  - Tests: `tests/SpatialNavigationStateTests.swift` (18 tests, all passing — no regressions)
  - Implementation: Restructured `SpeedReadingVisionApp` with 3 scenes: library WindowGroup (plain), fallback reader WindowGroup(id: "reader"), and ImmersiveSpace(id: "immersiveReader") with placeholder `SpatialReaderView`. Created `LibraryCoordinatorView` to wire `openImmersiveSpace`/`dismissImmersiveSpace` to `SpatialNavigationState` changes. Handles all 3 result cases (opened, userCancelled, error with windowed fallback). Added `Theme.Spatial` constants (fontSize 72, viewingDistance 2.0m, controlBarOffset -0.3m).
  - Notes: Both iOS and visionOS targets build clean. `SpatialReaderView` is a placeholder with loading indicator — full implementation in Task 7.
  - Files changed: `SpeedReadingVisionApp.swift`, `SpatialReaderView.swift` (new), `Theme.swift`, `project.pbxproj`

  Restructure the visionOS app entry point to support the immersive reading space. The library window stays `.windowStyle(.plain)` (volumetric cannot present `.fileImporter()` on visionOS 2.x — see spec constraints). The `ImmersiveSpace` stub gets replaced with `SpatialReaderView` (placeholder until Task 7). Add `@State` immersion style binding.

  **Subtasks:**
  - Keep library `WindowGroup` as `.windowStyle(.plain)` — needed for `.fileImporter()` support. The 3D bookshelf will be an embedded `RealityView` inside this plain window (Task 4).
  - Add `@State private var immersionStyle: ImmersionStyle = .mixed` to the App struct
  - Replace the `ImmersiveSpace` stub `Text(...)` with a placeholder `SpatialReaderView()` (creates a minimal version that just shows a loading indicator — full implementation in Task 7)
  - Update `.immersionStyle(selection: .constant(.mixed), in: .mixed)` to use the binding: `.immersionStyle(selection: $immersionStyle, in: .mixed)`
  - Add `@Environment(\.openImmersiveSpace)` and `@Environment(\.dismissImmersiveSpace)` to a coordinator view that wraps the library content
  - Wire up `openImmersiveSpace(id: "immersiveReader")` call in the book selection flow. Handle all 3 result cases: `.opened` → `navState.immersiveSpaceOpened()`, `.userCancelled` → no-op, `.error` → `navState.immersiveSpaceFailed()` + fallback to windowed reader
  - Wire up `dismissImmersiveSpace()` when `navState.closeReader()` is called (note: `dismissImmersiveSpace()` takes no parameters — only one space can be open)
  - Keep the existing windowed `ReaderWindowView` `WindowGroup(id: "reader")` as fallback (used for settings/search/TOC overlays while immersive space is active — windows CAN coexist with ImmersiveSpace in `.mixed` mode)
  - Add Theme constants for spatial layout: `spatialFontSize` (72), `spatialViewingDistance` (2.0 meters), `controlBarOffset` (-0.3 meters below ORP)
  - Build and verify visionOS target compiles (immersive space will show placeholder)

  **Files:** `SpeedReading/App/SpeedReadingVisionApp.swift`, `SpeedReading/UI/Theme/Theme.swift`

---

## Phase 2: RealityKit Book Entities & Volumetric Library

- [x] **Task 3: SpatialBookEntity — RealityKit 3D Book Model**
  - ✅ Completed: 2026-03-27
  - Tests: `tests/SpatialBookEntityTests.swift` (7 tests, all passing — deterministic color, palette bounds, edge cases)
  - Implementation: Created `SpatialBookEntity` factory enum with `create(for:coverImage:)` async method. Box mesh (0.02×0.15×0.10m), cover image texture via `TextureResource(image:)`, deterministic djb2 fallback colors (8-color palette), interactive trio (InputTarget+Collision+Hover), custom `BookComponent` for tap identification, selection pulse and appear animations.
  - Notes: Used `@MainActor` on entity creation/animation methods for Swift 6 concurrency. Used async `TextureResource(image:)` instead of deprecated `generate(from:)`.
  - Files changed: `SpatialBookEntity.swift` (new), `SpatialBookEntityTests.swift` (new), `project.pbxproj`

  Create the RealityKit entity that represents a single book on the spatial bookshelf. Each book is a thin box with a cover image texture (or generated fallback) and input/hover components for look+pinch selection.

  **Subtasks:**
  - Create `SpeedReading/Features/VisionOS/SpatialBookEntity.swift` with `#if os(visionOS)` guard
  - Import RealityKit and RealityFoundation
  - Implement `SpatialBookEntity` as a class (or factory function) that produces a `ModelEntity` with `MeshResource.generateBox(width: 0.02, height: 0.15, depth: 0.10)`
  - Implement cover image texture loading: load `Covers/{UUID}.jpg` via `StorageService`, convert to `CGImage`, use `TextureResource.generate(from: cgImage, options: .init(semantic: .color))`, then assign to `SimpleMaterial.color = .init(texture: .init(texture))`
  - Implement deterministic fallback cover: hash the book title to pick a color from a fixed palette, create a solid-color `SimpleMaterial`. Title text will be a SwiftUI Attachment overlay (NOT `MeshResource.generateText()` — SwiftUI gives better typography and accessibility)
  - Add the interactive entity trio (ALL THREE required for gestures to work):
    - `InputTargetComponent()` — marks entity as input-targetable
    - `CollisionComponent(shapes: [ShapeResource.generateBox(size: boxSize)])` — defines hit-test shape
    - `HoverEffectComponent()` — system gaze highlight (privacy-preserving, no raw eye data exposed)
  - Create custom `BookComponent: Component` with `bookID: UUID` and `title: String` to store data on the entity for tap identification
  - Implement selection pulse: use `Entity.move(to: Transform(scale: [1.1, 1.1, 1.1], ...), relativeTo: entity.parent, duration: 0.2, timingFunction: .easeOut)` on tap before triggering navigation
  - Add the new file to the visionOS target in the Xcode project (update `project.pbxproj`)

  **Files:** `SpeedReading/Features/VisionOS/SpatialBookEntity.swift`, `SpeedReading.xcodeproj/project.pbxproj`

---

- [ ] **Task 4: SpatialLibraryView — Volumetric 3D Bookshelf**

  Build the 3D bookshelf library view inside a **plain window** (not volumetric — `.fileImporter()` requires plain window on visionOS 2.x). Books are arranged in a row using RealityKit entities inside a `RealityView`, with a bottom ornament for the import button.

  **Subtasks:**
  - Create `SpeedReading/Features/VisionOS/SpatialLibraryView.swift` with `#if os(visionOS)` guard
  - Build a `RealityView { content in ... }` that creates and positions `SpatialBookEntity` instances in a row with ~5cm (`0.05m`) spacing between books
  - Use `LibraryViewModel` (existing) to get the list of books — use the `update:` closure of `RealityView` to rebuild entities when the book list changes (the `make:` closure runs once, `update:` fires on SwiftUI state changes)
  - Implement shelf layout: center the row of books in the RealityView, position at a comfortable height
  - Handle 2-row layout when book count exceeds ~8 (stack a second row above the first)
  - Implement book selection: use `.gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { value in ... })` on the `RealityView`, identify the tapped entity via `value.entity.components[BookComponent.self]?.bookID`, call the immersive space open flow
  - For title labels on fallback covers: use `RealityView` attachments with `Attachment(id: book.id)` containing SwiftUI `Text`, add as child of the book entity. Must manually add via `bookEntity.addChild(attachments.entity(for: book.id)!)`.
  - Implement empty state: when no books exist, show a SwiftUI overlay (not RealityKit) with "Your library is empty" text and an import button, styled with `.glassBackgroundEffect()`
  - Add bottom ornament with "+" import button using `.ornament(attachmentAnchor: .scene(.bottom))` and `.fileImporter()` for book import — this works because the library is in a plain window (ornaments are supported on both plain and volumetric windows)
  - Implement book add animation: create entity at scale 0 and animate to 1 via `Entity.move(to: Transform(scale: [1,1,1], ...), duration: 0.3, timingFunction: .easeOut)`
  - Wire up the `SpatialLibraryView` in `SpeedReadingVisionApp.swift` as the content of the library window (replacing the current `ContentView()` for visionOS)
  - Add the new file to the visionOS target in the Xcode project
  - Build and test in visionOS simulator — books should render as 3D objects inside the plain window

  **Files:** `SpeedReading/Features/VisionOS/SpatialLibraryView.swift`, `SpeedReading/App/SpeedReadingVisionApp.swift`, `SpeedReading.xcodeproj/project.pbxproj`

---

## Phase 3: Immersive Reader Components

- [ ] **Task 5: SpatialORPView — Floating ORP Word Display**

  Create the ORP word display as a SwiftUI view designed to be used as a `RealityView` `Attachment` in the immersive space. This is the core visual element — the word floating in the user's room.

  **Subtasks:**
  - Create `SpeedReading/Features/VisionOS/SpatialORPView.swift` with `#if os(visionOS)` guard
  - Build the ORP display using the same pre-text / ORP-char / post-text `HStack` pattern as `ORPDisplayView`, but sized for spatial viewing (72pt monospaced font from `Theme.Spatial.fontSize`)
  - Use `.white` for non-ORP text and `Theme.Colors.orpHighlight` (red) for the ORP character
  - Add `.glassBackgroundEffect()` background with generous padding (`.horizontal, 40` and `.vertical, 24`) for readability against the real room
  - Implement word transition: use `.animation(.easeInOut(duration: 0.05))` on the text content with an `.id()` modifier keyed to the current word index to trigger crossfade
  - Add `SpatialTapGesture` for play/pause toggle — calls `viewModel.toggle()`
  - Accept `ReaderViewModel` as an observed dependency to get current word data (`currentWord`, `displayPreORPText`, `displayORPCharacter`, `displayPostORPText`)
  - Add the new file to the visionOS target in the Xcode project

  **Files:** `SpeedReading/Features/VisionOS/SpatialORPView.swift`, `SpeedReading.xcodeproj/project.pbxproj`

---

- [ ] **Task 6: SpatialControlBar — Immersive Playback Controls**

  Port the existing ornament control bar from `ReaderView` to a standalone view for use as a `RealityView` `Attachment` in the immersive space. Adds progress bar and stats that the current ornament lacks.

  **Subtasks:**
  - Create `SpeedReading/Features/VisionOS/SpatialControlBar.swift` with `#if os(visionOS)` guard
  - **Row 1 — Playback controls:** Port the `TooltipButton` HStack from `ReaderView.readerOrnament` — prev paragraph, prev sentence, play/pause, next sentence, next paragraph, menu (ellipsis)
  - **Row 2 — Progress & stats:** Add a horizontal progress bar (reuse `ProgressBarView` or build a simplified version), percentage text, time remaining text, chapter time remaining (EPUB only)
  - Stack Row 1 and Row 2 in a `VStack(spacing: 8)` with glass background
  - Implement auto-hide state machine (identical logic to existing ornament in `ReaderView`):
    - `ornamentVisible` state, `ornamentHideTask` for the 3s timer
    - `handleOrnamentInteraction()` resets timer on any button press
    - `startOrnamentHideTimer()` cancels existing and starts 3s countdown
    - `cancelOrnamentHideTimer()` stops countdown
    - `.onChange(of: viewModel.isPlaying)` — start timer when playing, cancel + show when paused
    - `.onChange(of: viewModel.isCompleted)` — cancel timer + show on completion
    - `.onChange(of: viewModel.isScrubbing)` — cancel timer during scrub, restart after
  - Apply `.opacity()` and `.allowsHitTesting()` based on `ornamentVisible`
  - Apply `.glassBackgroundEffect()` for the capsule appearance
  - Accept `ReaderViewModel` as dependency, plus closures for menu presentation (sheet the windowed settings/search/TOC)
  - Add the new file to the visionOS target in the Xcode project

  **Files:** `SpeedReading/Features/VisionOS/SpatialControlBar.swift`, `SpeedReading.xcodeproj/project.pbxproj`

---

## Phase 4: Immersive Space Integration

- [ ] **Task 7: SpatialReaderView — Immersive Space Assembly**

  Build the main immersive space view that assembles the ORP word and control bar as `RealityView` attachments, positions them in 3D space in front of the user, and handles the full reading lifecycle.

  **Subtasks:**
  - Create `SpeedReading/Features/VisionOS/SpatialReaderView.swift` with `#if os(visionOS)` guard (replace the placeholder from Task 2)
  - Build `RealityView { content, attachments in ... } update: { content, attachments in ... } attachments: { ... }` structure. The `make:` closure is async and runs once; the `update:` closure is sync and fires on state changes.
  - Create a head-anchored container entity using verified API:
    ```swift
    let headAnchor = Entity()
    headAnchor.components.set(AnchoringComponent(.head, trackingMode: .continuous))
    ```
    This requires NO ARKit authorization. Children are positioned relative to the head.
  - Register `SpatialORPView` as `Attachment(id: "orpDisplay")`. In the `make:` closure, retrieve via `attachments.entity(for: "orpDisplay")` (returns `ViewAttachmentEntity?`), set `.position = [0, 0, -2.0]` (2m forward in -Z direction), add `BillboardComponent()` to face user, then `headAnchor.addChild(orpView)`. **IMPORTANT: attachments are NOT auto-added — must explicitly call addChild().**
  - Register `SpatialControlBar` as `Attachment(id: "controlBar")`. Position at `[0, -0.3, -2.0]` (0.3m below ORP word, same distance forward). Add `BillboardComponent()`. Add as child of headAnchor.
  - Call `content.add(headAnchor)` to add the anchor to the scene
  - Initialize `ReaderViewModel` with `navState.selectedBookId` — call `viewModel.loadBook()` on appear
  - Handle book loading states: show a loading indicator (glass panel with `ProgressView`) until the book is loaded
  - Handle errors: show a glass error panel with "Return to Library" button that calls `navState.closeReader()` + `await dismissImmersiveSpace()`
  - Handle book completion: show a glass completion overlay with stats and "Return to Library" button
  - Wire up immersive space dismiss: when user taps "Return to Library" or back navigation, save progress → `navState.closeReader()` → `await dismissImmersiveSpace()` (no parameters — only one space can be open)
  - Handle menu/settings/search/TOC access: when the menu button is tapped, open the existing windowed `ReaderWindowView` via `openWindow(id: "reader")` as a floating panel alongside the immersive space (windows CAN coexist with `ImmersiveSpace` in `.mixed` mode)
  - Add `.onDisappear` to save progress when the immersive space is dismissed externally (Digital Crown press, safety boundary at ~1.5m from initial position, system preemption by another app)
  - Add the new file to the visionOS target in the Xcode project
  - Build and test in visionOS simulator — full reading flow should work

  **Files:** `SpeedReading/Features/VisionOS/SpatialReaderView.swift`, `SpeedReading.xcodeproj/project.pbxproj`

---

## Phase 5: Integration, Polish & Testing

- [ ] **Task 8: End-to-End Navigation Flow & Edge Cases**

  Wire up the complete library → immersive reader → library navigation flow and handle all edge cases. Ensure the volumetric library and immersive reader work together seamlessly.

  **Subtasks:**
  - Test and fix the full navigation flow: launch app → library (plain window with 3D books) → tap book → immersive space opens → read → pause → resume → complete → return to library → select another book
  - Handle all `openImmersiveSpace` result cases:
    - `.opened` → normal flow, `navState.immersiveSpaceOpened()`
    - `.userCancelled` → user declined the system prompt, show brief message
    - `.error` → another app's immersive space may be active, or system error. Show error toast in library + fall back to windowed reader (`ReaderWindowView`)
  - Handle app backgrounding: save progress when the app goes to `.inactive` or `.background` via `@Environment(\.scenePhase)` in the immersive space
  - Handle concurrent window management: ensure the windowed reader (for settings/search/TOC) can coexist with the immersive space without conflicts
  - Ensure book deletion in library properly handles case where deleted book is currently open in immersive reader
  - Test EPUB features in immersive context: chapter transitions, TOC navigation (opens windowed overlay), search (opens windowed overlay)
  - Verify iOS target still builds and runs with zero regressions — the `#if os(visionOS)` guards should keep iOS completely isolated
  - Build both targets in the simulator and fix any compilation issues

  **Files:** `SpeedReading/App/SpeedReadingVisionApp.swift`, `SpeedReading/Features/VisionOS/SpatialLibraryView.swift`, `SpeedReading/Features/VisionOS/SpatialReaderView.swift`

---

- [ ] **Task 9: Unit Tests for Phase 1B Components**

  Write unit tests for all new state management and testable logic. Focus on state machines, entity creation, and auto-hide behavior.

  **Subtasks:**
  - Update `tests/SpatialNavigationStateTests.swift` with tests for:
    - `immersiveSpaceOpened()` sets `isImmersiveSpaceOpen = true`
    - `immersiveSpaceFailed()` sets error and `isImmersiveSpaceOpen = false`
    - `closeReader()` resets both `isReaderOpen` and `isImmersiveSpaceOpen`
    - Error cleared on next successful open
    - State consistency after rapid open/close cycles
  - Create `tests/SpatialBookEntityTests.swift` (if testable outside RealityKit runtime):
    - Entity creation with cover image produces correct components
    - Entity creation without cover image uses fallback color
    - Deterministic fallback color: same title always produces same color
    - `BookComponent` stores correct UUID and title
    - Interactive trio all attached: `InputTargetComponent`, `CollisionComponent`, `HoverEffectComponent`
  - Create `tests/SpatialControlBarAutoHideTests.swift` (test the state machine logic if extractable):
    - Timer starts on play → hides after delay
    - Interaction resets timer
    - Pause cancels timer and shows
    - Completion cancels timer and shows
    - Scrubbing pauses timer
  - Verify all tests pass on both iOS and visionOS simulator destinations
  - Add new test files to the visionOS target in `project.pbxproj`

  **Files:** `tests/SpatialNavigationStateTests.swift`, `tests/SpatialBookEntityTests.swift`, `tests/SpatialControlBarAutoHideTests.swift`, `SpeedReading.xcodeproj/project.pbxproj`

---

- [ ] **Task 10: Simulator Build Verification & Final Polish**

  Final build verification on real visionOS simulator, fix any remaining issues, and confirm both platforms are clean.

  **Subtasks:**
  - Build visionOS target on Apple Vision Pro simulator (xrOS 26.x): `xcodebuild build -project SpeedReading.xcodeproj -scheme "SpeedReading visionOS" -destination 'platform=visionOS Simulator,name=Apple Vision Pro' CODE_SIGNING_ALLOWED=NO`
  - Build iOS target on iPhone simulator: `xcodebuild build -project SpeedReading.xcodeproj -scheme SpeedReading -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO`
  - Run all tests on visionOS simulator: `xcodebuild test -project SpeedReading.xcodeproj -scheme "SpeedReading visionOS" -destination 'platform=visionOS Simulator,name=Apple Vision Pro'`
  - Fix any compilation warnings or errors
  - Verify no regressions in the iOS reading flow
  - Optional: if the reading experience feels like it needs ambient progress awareness, implement `SpatialProgressRing.swift` (circular progress indicator around the ORP glass panel)
  - Update `CLAUDE.md` with Phase 1B architecture documentation (new files, scene structure, navigation flow)

  **Files:** Multiple (build verification), `CLAUDE.md`

---

## Claude Added Tasks

*(Reserved for tasks discovered during implementation)*
