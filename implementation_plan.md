# Implementation Plan: Speed Reading visionOS Port (Phase 1A)

**Spec Reference:** `spec.md` (Sections 4–6, 9–10)
**Target:** visionOS 2.0+ windowed app with glass material, ornaments, shared Core/Services
**Branch:** `feature/visionos`

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

- [ ] **Task 3: Migrate LibraryView from DocumentPicker to .fileImporter()**

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

- [ ] **Task 4: Add visionOS theme colors and layout constants**

  Add `#if os(visionOS)` branches to `Theme.swift` so glass material shows through properly. On visionOS, backgrounds become `.clear`, text colors become system `.primary`/`.secondary`, and default font size increases for spatial viewing distance.

  **Subtasks:**
  - Add `#if os(visionOS)` to `Colors.background` → `.clear` (per spec §6.5)
  - Add `#if os(visionOS)` to `Colors.cardBackground` → `.clear`
  - Add `#if os(visionOS)` to `Colors.primaryText` → `.primary`
  - Add `#if os(visionOS)` to `Colors.secondaryText` → `.secondary`
  - Add `#if os(visionOS)` to `Layout.defaultFontSize` → `64` (larger for spatial viewing distance)
  - Add ornament timing constants to `Theme.Animation`: `ornamentHideDelay: 3.0`, reuse existing `navigationOverlayFadeDuration: 0.3`
  - Verify iOS theme values are unchanged (all `#else` branches match current values exactly)

- [ ] **Task 5: Adapt visionOS interaction states in shared views**

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

- [ ] **Task 6: Create SpatialNavigationState and visionOS app entry point**

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

- [ ] **Task 7: Wire up visionOS library-to-reader navigation**

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

- [ ] **Task 8: Build visionOS reader with word-only window and bottom ornament**

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

*(Reserved for tasks discovered during implementation)*
