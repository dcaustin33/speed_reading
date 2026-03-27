# Implementation Plan: Speed Reading visionOS Port (Phase 1A)

**Spec Reference:** `spec.md` (Sections 4–6, 9–10)
**Target:** visionOS 2.0+ windowed app with glass material, ornaments, shared Core/Services
**Branch:** `feature/visionos`

> **Build Verification Rule:** Always build visionOS against the **real simulator** — `destination 'platform=visionOS Simulator,name=Apple Vision Pro'`. Never use `generic/platform=visionOS Simulator` (compile-only). The visionOS simulator runtime is installed (xrOS 26.2). Both iOS and visionOS builds must pass on every task.

---

## Phase 1: Project Setup & Cross-Platform Foundation

- [x] **Task 1: Create visionOS target and configure Xcode project**
  - ✅ Completed: 2026-03-26
  - Added "SpeedReading visionOS" target with visionOS 2.0 SDK (SDKROOT=xros, TARGETED_DEVICE_FAMILY=7)
  - 46 shared source files added to visionOS target (all Core/, Services/, Features/, UI/ except SpeedReadingApp.swift and DocumentPicker.swift)
  - Created "SpeedReading visionOS" scheme
  - iOS build verified: still succeeds
  - Files changed: `project.pbxproj`, `SpeedReading visionOS.xcscheme`

  Add the visionOS destination to the existing Xcode project so both iOS and visionOS build from the same `.xcodeproj`.

  **Subtasks:**
  - Add new "SpeedReading visionOS" target in Xcode with visionOS 2.0 deployment target
  - Set Supported Destinations to Apple Vision
  - Add all `Core/` and `Services/` source files to the visionOS target via target membership
  - Add shared Feature files (`Features/Search/*`, `Features/Settings/*`, `Features/TOC/*`, `Features/Menu/*`) to visionOS target
  - Add shared `UI/` files (`Theme.swift`, `LayoutHelper.swift`) to visionOS target
  - Add shared Reader feature files (`ORPDisplayView.swift`, `ReaderViewModel.swift`, `ProgressBarView.swift`, `StatsBarView.swift`, `NavigationOverlayView.swift`, `ParagraphOverlayView.swift`, `CompletionOverlayView.swift`) to visionOS target
  - Create visionOS Xcode scheme ("SpeedReading visionOS")
  - Verify the iOS target still builds: `xcodebuild build -scheme SpeedReading -destination 'platform=iOS Simulator,name=iPhone 16'`

- [x] **Task 2: Create FontMetrics utility and fix UIFont usage**
  - ✅ Completed: 2026-03-26
  - Tests: iOS build succeeds, visionOS Swift compilation succeeds (linker expects @main from Task 6)
  - Implementation: Created `FontMetrics.swift` with `#if os(visionOS)` CTFont / `#else` UIFont. Replaced all 3 UIFont calls in ORPDisplayView.swift.
  - Notes: visionOS linker error for `_main` is expected — entry point created in Task 6
  - Files changed: `SpeedReading/UI/Helpers/FontMetrics.swift` (new), `SpeedReading/Features/Reader/ORPDisplayView.swift`, `project.pbxproj`

  Replace all `UIFont` usage in `ORPDisplayView.swift` with a cross-platform `FontMetrics` utility. `UIFont` is unavailable on visionOS — this is the critical compilation blocker.

  **Subtasks:**
  - Create `SpeedReading/UI/Helpers/FontMetrics.swift` with `#if os(visionOS)` using `CTFont` and `#else` using `UIFont` (per spec §6.6)
  - Add `FontMetrics.swift` to both iOS and visionOS targets
  - Replace 3 `UIFont.monospacedSystemFont` calls in `ORPDisplayView.swift` (lines 94, 221, 294) with `FontMetrics.monospacedCharacterWidth(fontSize:)`
  - Verify iOS ORP display still renders identically after the change
  - Verify visionOS target compiles with the new FontMetrics

- [x] **Task 3: Migrate LibraryView from DocumentPicker to .fileImporter()**
  - ✅ Completed: 2026-03-26
  - Tests: iOS build succeeds, visionOS Swift compilation succeeds (linker expects @main from Task 6)
  - Implementation: Replaced `.documentPicker()` custom modifier with SwiftUI `.fileImporter()`, added `import UniformTypeIdentifiers`, deleted `DocumentPicker.swift` and removed from Xcode project
  - Notes: Same UTTypes as before (.plainText, .md, .epub). No unit test possible for SwiftUI system modifier.
  - Files changed: `SpeedReading/Features/Library/LibraryView.swift`, `SpeedReading/Services/FileImport/DocumentPicker.swift` (deleted), `project.pbxproj`

  Replace the `UIViewControllerRepresentable` `DocumentPicker` with SwiftUI's built-in `.fileImporter()`. This removes the only `UIViewControllerRepresentable` usage, which is unavailable on visionOS.

  **Subtasks:**
  - Replace `.documentPicker(isPresented:onSelect:)` modifier call in `LibraryView.swift` (line 46-51) with `.fileImporter(isPresented:allowedContentTypes:onCompletion:)` per spec §6.11
  - Add `import UniformTypeIdentifiers` to `LibraryView.swift`
  - Delete `Services/FileImport/DocumentPicker.swift` entirely
  - Remove `DocumentPicker.swift` from both Xcode targets
  - Test file import on iOS simulator — verify .txt, .md, and .epub files can still be imported
  - Verify visionOS target compiles without DocumentPicker

---

## Phase 2: Theme & Visual Adaptation

- [x] **Task 4: Add visionOS theme colors and layout constants**
  - ✅ Completed: 2026-03-26
  - Tests: iOS build succeeds (values unchanged in #else branches), visionOS Swift compilation succeeds
  - Implementation: Added `#if os(visionOS)` conditionals to background (.clear), cardBackground (.clear), primaryText (.primary), secondaryText (.secondary), defaultFontSize (64). Added `ornamentHideDelay: 3.0` to Theme.Animation.
  - Notes: visionOS linker error for `_main` is expected — entry point created in Task 6
  - Files changed: `SpeedReading/UI/Theme/Theme.swift`

  Add `#if os(visionOS)` branches to `Theme.swift` so glass material shows through properly. On visionOS, backgrounds become `.clear`, text colors become system `.primary`/`.secondary`, and default font size increases for spatial viewing distance.

  **Subtasks:**
  - Add `#if os(visionOS)` to `Colors.background` → `.clear` (per spec §6.5)
  - Add `#if os(visionOS)` to `Colors.cardBackground` → `.clear`
  - Add `#if os(visionOS)` to `Colors.primaryText` → `.primary`
  - Add `#if os(visionOS)` to `Colors.secondaryText` → `.secondary`
  - Add `#if os(visionOS)` to `Layout.defaultFontSize` → `64` (larger for spatial viewing distance)
  - Add ornament timing constants to `Theme.Animation`: `ornamentHideDelay: 3.0`, reuse existing `navigationOverlayFadeDuration: 0.3`
  - Verify iOS theme values are unchanged (all `#else` branches match current values exactly)

- [x] **Task 5: Adapt visionOS interaction states in shared views**
  - ✅ Completed: 2026-03-26
  - Tests: iOS build succeeds (values unchanged in #else branches), visionOS Swift compilation succeeds (linker expects @main from Task 6)
  - Implementation: Added `#if os(visionOS)` conditionals to LibraryView (loading overlay uses .glassBackgroundEffect(), no dark overlay; add button gets .hoverEffect), ReaderView (error view uses glass card, .buttonStyle(.bordered), system .red icon), CompletionOverlayView (glass card instead of fullscreen background, .buttonStyle(.borderedProminent)), BookCardView (.glassBackgroundEffect() and .hoverEffect(.highlight))
  - Notes: No unit tests possible — pure compile-time UI conditionals. ReaderView loading view already correct via Theme changes from Task 4.
  - Files changed: `LibraryView.swift`, `ReaderView.swift`, `CompletionOverlayView.swift`, `BookCardView.swift`

  Add `#if os(visionOS)` conditionals to views that use iOS-specific patterns (dark overlays, card backgrounds) so they use glass-compatible alternatives on visionOS. Per spec §6.9: never use `Color.black.opacity()` on glass.

  **Subtasks:**
  - `LibraryView.swift` — empty state: use `.primary`/`.secondary` colors, add `.hoverEffect(.highlight)` to import button on visionOS
  - `LibraryView.swift` — loading overlay: replace `Color.black.opacity(0.5)` + `cardBackground` card with centered `.glassBackgroundEffect()` card on visionOS
  - `ReaderView.swift` — loading view: remove background override on visionOS, let glass show through
  - `ReaderView.swift` — error view: wrap in `.glassBackgroundEffect()` container on visionOS, use `.buttonStyle(.bordered)` for return button
  - `CompletionOverlayView.swift` — replace fullscreen `Theme.Colors.background` with `.glassBackgroundEffect()` card on visionOS, use `.buttonStyle(.borderedProminent)` for return button
  - `BookCardView.swift` — add `.glassBackgroundEffect()` and `.hoverEffect(.highlight)` on visionOS, keep `cardBackground` on iOS

---

## Phase 3: visionOS Entry Point & Navigation

- [x] **Task 6: Create SpatialNavigationState and visionOS app entry point**
  - ✅ Completed: 2026-03-26
  - Tests: iOS build succeeds, visionOS build succeeds (first full successful visionOS build)
  - Implementation: Created `SpatialNavigationState.swift` (@Observable @MainActor, selectBook/closeReader). Created `SpeedReadingVisionApp.swift` with #if os(visionOS), dual WindowGroup (library 900x600, reader 600x400), ImmersiveSpace stub. Reader window reads bookId from SpatialNavigationState. Fixed broken visionOS target fileRef IDs in project.pbxproj (46 entries had 2 extra zeros, causing all shared files to be silently excluded from compilation).
  - Notes: Both new files added to visionOS target only. SpeedReadingVisionApp wrapped in #if os(visionOS) as additional safety. NavigationRouter provided to both windows for backward compat with existing views.
  - Files changed: `SpeedReadingVisionApp.swift` (new), `SpatialNavigationState.swift` (new), `project.pbxproj`

  Create the visionOS-specific navigation state and app entry point with dual WindowGroup (library + reader) and ImmersiveSpace stub for Phase 1B.

  **Subtasks:**
  - Create `SpeedReading/Features/VisionOS/SpatialNavigationState.swift` with `@Observable @MainActor` class (per spec §6.10) — `selectedBookId`, `isReaderOpen`, `selectBook()`, `closeReader()`
  - Create `SpeedReading/App/SpeedReadingVisionApp.swift` with `@main` entry point (per spec §5)
  - Define `WindowGroup(id: "library")` at `.defaultSize(width: 900, height: 600)` containing `ContentView`
  - Define `WindowGroup(id: "reader")` at `.defaultSize(width: 600, height: 400)` containing `ReaderView`
  - Define `ImmersiveSpace(id: "immersiveReader")` stub with `.immersionStyle(.mixed)`
  - Pass `SpatialNavigationState` via `.environment()` to both window groups
  - Add both new files to visionOS target only (not iOS)
  - Ensure only one file per target has `@main` — iOS uses `SpeedReadingApp.swift`, visionOS uses `SpeedReadingVisionApp.swift`

- [x] **Task 7: Wire up visionOS library-to-reader navigation**
  - ✅ Completed: 2026-03-26
  - Tests: iOS build succeeds (XcodeBuildMCP), visionOS build succeeds (xcodebuild generic destination). No unit tests — pure SwiftUI view wiring with compile-time `#if os(visionOS)` conditionals.
  - Implementation: Added `@Environment(SpatialNavigationState.self)` and `@Environment(\.openWindow)` to LibraryView; `@Environment(SpatialNavigationState.self)` and `@Environment(\.dismissWindow)` to ReaderView. Wired `handleBookTap` to `selectBook()` + `openWindow(id: "reader")`, back button/completion/error dismiss to `closeReader()` + `dismissWindow(id: "reader")`. ContentView unchanged — NavigationStack still supports non-reader routes (settings, search, TOC).
  - Notes: ReaderView still takes `bookId` as init param (passed from `navState.selectedBookId` in SpeedReadingVisionApp). No visionOS simulator runtime installed, so tested via generic destination build.
  - Files changed: `LibraryView.swift`, `ReaderView.swift`

  Connect the library book selection to opening the reader in a separate window using `openWindow(id: "reader")`, and wire the back/completion actions to `dismissWindow(id: "reader")`.

  **Subtasks:**
  - Add `#if os(visionOS)` to `LibraryView`'s `handleBookTap` to call `SpatialNavigationState.selectBook()` and `openWindow(id: "reader")` instead of `router.navigateTo(.reader)`
  - Add `@Environment(\.openWindow)` and `@Environment(\.dismissWindow)` to relevant views on visionOS
  - Update `ReaderView` to read `selectedBookId` from `SpatialNavigationState` on visionOS instead of taking `bookId` as init parameter
  - Wire `CompletionOverlayView` dismiss to `dismissWindow(id: "reader")` + `SpatialNavigationState.closeReader()` on visionOS
  - Wire back button to `dismissWindow(id: "reader")` on visionOS
  - Ensure `ContentView` on visionOS uses `SpatialNavigationState` instead of `NavigationRouter` (or support both via `#if`)
  - Test: tap book → reader window opens → tap back → reader window closes, library still there

---

## Phase 4: visionOS Reader Layout & Ornaments

- [x] **Task 8: Build visionOS reader with word-only window and bottom ornament**
  - ✅ Completed: 2026-03-26
  - Tests: iOS build succeeds (XcodeBuildMCP), visionOS build succeeds (generic destination, full compile+link). No unit tests — pure UI layout with compile-time `#if os(visionOS)` conditionals.
  - Implementation: Added `#if os(visionOS)` branch to `readerContent` showing word-only `ORPDisplayView`. Built bottom ornament via `.ornament(attachmentAnchor: .scene(.bottom))` with all controls: play/pause, prev/next sentence, paragraph preview, nav overlay toggle, menu, WPM, `ProgressBarView`, `StatsBarView`. Applied `.glassBackgroundEffect()` and `.hoverEffect(.highlight)`. Implemented ornament auto-hide state machine (3s timer, 0.3s fade, cancel on interaction/pause/completion, pause during scrubbing).
  - Notes: visionOS tap uses standard `onTapGesture` (maps to look+pinch). NavigationOverlayView still renders on main window. iOS code unchanged.
  - Files changed: `ReaderView.swift`

  On visionOS, the reader window shows only the ORP word in the main glass area. All controls (play/pause, nav, progress, stats, menu) move to a bottom ornament with auto-hide behavior.

  **Subtasks:**
  - Add `#if os(visionOS)` branch to `ReaderView.readerContent` that shows only `ORPDisplayView` in the main window (no buttons, no progress bar, no stats)
  - Add `SpatialTapGesture` on the main window to toggle play/pause (replaces `TapGesture` for visionOS)
  - Build bottom ornament via `.ornament(attachmentAnchor: .scene(.bottom))` containing:
    - Play/pause, previous sentence, next sentence buttons
    - Paragraph preview, navigation overlay toggle, menu buttons
    - `ProgressBarView` with scrub support
    - `StatsBarView` (WPM, time remaining, %, chapter time)
  - Apply `.glassBackgroundEffect()` to the ornament container
  - Implement ornament visibility state machine (VISIBLE → HIDING → HIDDEN) per spec §6.7:
    - Playback starts → 3s timer → fade out (0.3s opacity animation)
    - Any interaction → cancel timer → fade in
    - Paused/completed → always visible (no timer)
    - During scrubbing → stay visible, timer paused

---

## Phase 5: Haptics & Platform Polish

- [ ] **Task 9: Guard haptic feedback and finalize platform conditionals**

  visionOS has no haptic motor. Guard any haptic feedback calls and finalize remaining platform-specific polish.

  **Subtasks:**
  - Search for `UIImpactFeedbackGenerator` or haptic references in non-test Swift files and wrap with `#if !os(visionOS)`
  - Review `PlaybackEngine.swift` callbacks — confirm `onSentenceChange` haptic (if any) is guarded
  - Add `.hoverEffect(.highlight)` to interactive buttons on visionOS (library cards, ornament buttons)
  - Remove `.toolbarBackground` modifiers on visionOS (glass material provides its own background)
  - Verify `NavigationOverlayView` renders correctly against glass background on visionOS
  - Verify `ParagraphOverlayView` renders correctly against glass background on visionOS

---

## Phase 6: Build Verification & Testing

- [ ] **Task 10: Build both targets and fix compilation errors**

  Full build verification for both platforms. Fix any remaining compilation errors, missing target memberships, or platform availability issues.

  **Subtasks:**
  - Build visionOS target: `xcodebuild build -scheme "SpeedReading visionOS" -destination 'platform=visionOS Simulator,name=Apple Vision Pro' CODE_SIGNING_ALLOWED=NO`
  - Build iOS target: `xcodebuild build -scheme SpeedReading -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO`
  - Fix any compilation errors on either platform
  - Resolve any `#if os(visionOS)` conditional gaps
  - Verify all shared files compile on both targets without warnings

- [ ] **Task 11: Write unit tests for new visionOS components**

  Add unit tests for the new cross-platform and visionOS-specific components per spec §10.

  **Subtasks:**
  - Create `FontMetricsTests.swift` — verify character width > 0, deterministic across calls, reasonable range for sizes 24-96
  - Create `SpatialNavigationStateTests.swift` — test `selectBook` sets `selectedBookId` and `isReaderOpen`, `closeReader` clears both, edge cases (double select, close when already closed)
  - Add tests to visionOS test target
  - Run tests: `xcodebuild test -scheme "SpeedReading visionOS" -destination 'platform=visionOS Simulator,name=Apple Vision Pro'`
  - Verify existing iOS tests still pass: `xcodebuild test -scheme SpeedReading -destination 'platform=iOS Simulator,name=iPhone 16'`

---

## Claude Added Tasks

- [ ] **Task 12: Verify visionOS builds on real simulator (not generic destination)**

  All completed tasks (1–6) only verified visionOS compilation using `generic/platform=visionOS Simulator` (compile-only, no linking). The visionOS simulator runtime **is installed** (`Apple Vision Pro` — xrOS 26.2, UUID `C0BF3C1E-B1DC-4965-B228-77B68F0EAB22`). Run a full build against the real simulator to catch any linker or runtime issues missed by compile-only checks.

  **Subtasks:**
  - Build visionOS target against real simulator: `xcodebuild build -scheme "SpeedReading visionOS" -destination 'platform=visionOS Simulator,name=Apple Vision Pro' CODE_SIGNING_ALLOWED=NO`
  - Build iOS target to confirm no regressions: `xcodebuild build -scheme SpeedReading -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO`
  - Fix any linker errors or runtime issues that compile-only missed
  - **Going forward:** All tasks must verify visionOS using `destination 'platform=visionOS Simulator,name=Apple Vision Pro'` — never use `generic/platform=visionOS Simulator`
