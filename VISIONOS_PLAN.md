# Speed Reading App - visionOS Port Plan

**Version:** 1.0
**Last Updated:** March 2026
**Status:** Draft
**Target Platform:** visionOS 2.0+ (Apple Vision Pro)
**Approach:** Multi-platform single target (shared with iOS)

---

## 1. Executive Summary

Port the existing Speed Reading iOS app to visionOS as a native spatial computing experience. The app displays text one word at a time with ORP (Optimal Recognition Point) highlighting. On visionOS, the app will leverage the glass material window system, ornaments for controls, and spatial audio for feedback — while sharing 100% of core logic with iOS.

### Why visionOS?

- **Distraction-free reading**: Vision Pro eliminates phone notifications, surrounding visual noise — the user's entire visual field can be dedicated to reading
- **Natural eye tracking**: visionOS input is already eye-based (look + pinch) — a speed reading app where you stare at one fixed point is a perfect fit
- **Immersive mode**: Full immersion can create the ultimate focused reading environment
- **Larger canvas**: Floating windows provide more visual real estate than a phone screen

---

## 2. Platform Strategy

### Single Target, Conditional UI

Add visionOS as a Supported Destination to the existing `SpeedReading` Xcode target. Use `#if os(visionOS)` for platform-specific UI code.

**Shared (zero changes):**
- `Core/Models/*` — Book, Word, Document, Settings, Chapter
- `Core/ORP/*` — ORPCalculator, ORPDisplayLogic
- `Core/Tokenizer/*` — TokenizerService
- `Core/Playback/*` — PlaybackEngine
- `Services/*` — All services (EPUB, FileImport, Library, Storage, Search)
- `Features/*/ViewModel` — All ViewModels (with minor `#if` blocks)

**Platform-specific (new or conditional):**
- `Features/Reader/ReaderView.swift` — Ornaments, glass material, hover effects
- `Features/Reader/ORPDisplayView.swift` — Contrast adjustments for glass background
- `Features/Library/LibraryView.swift` — Hover effects on book cards
- `App/SpeedReadingApp.swift` — Window sizing, optional ImmersiveSpace scene
- `ReaderViewModel.swift` — Replace haptic with audio feedback

### Project Configuration

```
Xcode Target: SpeedReading
├── Supported Destinations: iPhone, Apple Vision
├── Deployment Target: iOS 17.0, visionOS 2.0
└── Shared scheme with visionOS Simulator destination
```

Build commands:
```bash
# iOS Simulator
xcodebuild -project SpeedReading.xcodeproj -scheme SpeedReading \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# visionOS Simulator
xcodebuild -project SpeedReading.xcodeproj -scheme SpeedReading \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro'
```

---

## 3. UI Architecture on visionOS

### Window Layout

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│                                                     │
│                                                     │
│              extraord|inary                         │  ← ORP display (glass bg)
│                                                     │
│                                                     │
│                                                     │
└─────────────────────────────────────────────────────┘
         ┌─────────────────────────────────┐
         │ [⏮] [⏪] [◀] ⏯ [▶] [⏩] [⏭]    │  ← Bottom ornament
         │ ▓▓▓▓▓░░░░░░░░  35%  300 WPM    │     (controls + progress)
         └─────────────────────────────────┘
```

**Main window**: Clean, minimal — just the ORP word display with glass background
**Bottom ornament**: Playback controls, progress bar, stats (WPM, time remaining)
**Menu**: Sheet presentation (same as iOS)

### App Entry Point

```swift
@main
struct SpeedReadingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(visionOS)
        .defaultSize(width: 900, height: 500)
        #endif

        #if os(visionOS)
        ImmersiveSpace(id: "focusMode") {
            FocusModeView()
        }
        .immersionStyle(selection: .constant(.full), in: .full)
        #endif
    }
}
```

---

## 4. Component-by-Component Changes

### 4.1 ReaderView — Ornament-based Controls

**iOS (current):**
- Controls overlay the main view
- Navigation overlay with buttons
- Progress bar at bottom
- Stats bar below progress

**visionOS:**
- Controls move to bottom ornament
- Main window is purely the ORP display
- Tap-to-play works via look + pinch

```swift
struct ReaderView: View {
    var body: some View {
        ZStack {
            // Main ORP display area
            ORPDisplayView(...)
                .onTapGesture { viewModel.togglePlayback() }
                #if os(visionOS)
                .hoverEffect()
                #endif
        }
        #if os(visionOS)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            VStack(spacing: 8) {
                // Playback controls
                HStack {
                    Button(action: prevParagraph) { Image(systemName: "backward.end") }
                    Button(action: prevSentence) { Image(systemName: "backward") }
                    Button(action: togglePlay) {
                        Image(systemName: isPlaying ? "pause" : "play")
                    }
                    Button(action: nextSentence) { Image(systemName: "forward") }
                    Button(action: nextParagraph) { Image(systemName: "forward.end") }
                }
                // Progress + stats
                ProgressBarView(...)
                StatsBarView(...)
            }
            .padding()
            .glassBackgroundEffect()
        }
        #else
        .overlay(alignment: .bottom) {
            // iOS overlay layout (existing)
        }
        #endif
    }
}
```

### 4.2 ORPDisplayView — Glass Material Adaptation

**Challenge:** Current design uses dark background (#1A1A1A) with light gray text (#E0E0E0) and red ORP highlight (#FF3333). On visionOS, the glass material replaces the dark background.

**Approach:**
- On visionOS, use the system glass background (automatic)
- Keep red ORP highlight — should contrast well against glass
- Use `.primary` color for non-ORP text (adapts to glass automatically)
- Increase default font size for spatial viewing (48pt → 64pt)

```swift
struct ORPDisplayView: View {
    var body: some View {
        HStack(spacing: 0) {
            // Pre-ORP text
            Text(preText)
                .foregroundStyle(.primary)
            // ORP character
            Text(orpChar)
                .foregroundStyle(.red)
            // Post-ORP text
            Text(postText)
                .foregroundStyle(.primary)
        }
        .font(.system(size: fontSize, weight: .medium, design: .monospaced))
    }

    var fontSize: CGFloat {
        #if os(visionOS)
        return max(settings.fontSize, 64) // Minimum 64pt for spatial
        #else
        return settings.fontSize
        #endif
    }
}
```

### 4.3 Haptic Feedback → Spatial Audio

**iOS:** `UIImpactFeedbackGenerator` on sentence boundaries
**visionOS:** No haptic hardware. Replace with subtle spatial audio cue.

```swift
// In ReaderViewModel
func setupCallbacks() {
    playbackEngine.onSentenceChange = { [weak self] in
        #if os(visionOS)
        self?.playSpatialAudioCue()
        #else
        self?.triggerHaptic()
        #endif
    }
}

#if os(visionOS)
private func playSpatialAudioCue() {
    // Use AVFoundation for a subtle click/tick sound
    // Or: use RealityKit spatial audio for positioned sound
}
#endif
```

### 4.4 LibraryView — Hover Effects

Add hover effects to book cards so they highlight when the user looks at them:

```swift
struct BookCardView: View {
    var body: some View {
        VStack { ... }
        #if os(visionOS)
        .hoverEffect()
        #endif
    }
}
```

### 4.5 Settings Adjustments

**New visionOS-specific setting:**
- Font size minimum raised to 48pt (from 24pt on iOS) for comfortable spatial reading
- Default font size: 64pt on visionOS vs 48pt on iOS

**Settings that work identically:**
- WPM (100-800)
- Paragraph pause (0.25-3.0s)
- Word skip (1-20)
- Library sort

### 4.6 File Import

Document picker works identically on visionOS. The `UIDocumentPickerViewController` is available and functions the same way. No changes needed.

### 4.7 Data Persistence

Documents directory, `library.json`, book storage — all work identically on visionOS. No changes needed.

---

## 5. Immersive Focus Mode (Phase 2 Feature)

### Concept

An optional "Focus Mode" that uses `ImmersiveSpace` with `.full` immersion to create a completely distraction-free reading environment. The real world disappears and the reader sees only:

- The ORP word floating in a calm, minimal environment
- Soft ambient lighting
- Optional: gentle background (starfield, gradient, etc.)

### Implementation

```swift
struct FocusModeView: View {
    @Environment(\.dismissImmersiveSpace) var dismiss

    var body: some View {
        RealityView { content in
            // Create a minimal environment
            // Add ambient lighting entity
            // Position text entity at comfortable reading distance
        }
    }
}
```

### User Flow

```
Reader View
    │
    ▼ (Menu → "Enter Focus Mode")
    │
┌───────────────────────────┐
│   Full Immersion          │
│                           │
│     extraord|inary        │  ← Floating text in space
│                           │
│   (real world hidden)     │
└───────────────────────────┘
    │
    ▼ (Pinch menu button or Digital Crown)
    │
Return to windowed reader
```

**Note:** This is a Phase 2 feature. Phase 1 focuses on the windowed experience.

---

## 6. Implementation Phases

### Phase 1: Native Windowed App (MVP)

**Goal:** Ship a functional speed reading app as a native visionOS window.

| Task | Effort | Description |
|------|--------|-------------|
| Add visionOS destination | Small | Add Apple Vision to Supported Destinations in Xcode |
| Conditional compilation | Small | Add `#if os(visionOS)` guards for platform-specific code |
| Bottom ornament | Medium | Move playback controls + progress to ornament |
| Glass material adaptation | Small | Test and adjust ORP colors for glass background |
| Remove haptics | Small | `#if os(visionOS)` to skip haptic feedback |
| Hover effects | Small | Add `.hoverEffect()` to interactive elements |
| Font size defaults | Small | Increase defaults for spatial viewing |
| Simulator testing | Medium | Test all user flows in visionOS Simulator |
| Device testing | Medium | Test on real Apple Vision Pro |

**Estimated total:** 2-3 coding sessions

### Phase 2: Spatial Enhancements

| Task | Effort | Description |
|------|--------|-------------|
| Spatial audio feedback | Medium | Audio cue on sentence boundaries |
| Focus Mode (ImmersiveSpace) | Large | Full immersion reading environment |
| Reading environment options | Medium | Different immersive backgrounds |
| Window size memory | Small | Remember preferred window size |

### Phase 3: Advanced Features

| Task | Effort | Description |
|------|--------|-------------|
| Multi-window | Medium | Separate stats/controls window |
| SharePlay reading | Large | Shared reading sessions |
| Eye tracking analytics | Large | Reading speed adaptation based on comprehension |

---

## 7. Testing Strategy

### Simulator Testing (All Phase 1 items)

The visionOS Simulator supports testing:
- [x] Window rendering and glass material appearance
- [x] Ornament placement and interaction
- [x] Tap gestures (mouse click = pinch)
- [x] Drag gestures (progress bar scrubbing)
- [x] Navigation flow (Library → Reader → Menu → etc.)
- [x] File import via document picker
- [x] Book loading and playback
- [x] Settings persistence

**Cannot test in simulator:**
- Eye tracking precision
- Real spatial audio positioning
- Comfort/ergonomics of font sizes
- Hand gesture reliability
- Battery impact

### Device Testing (Apple Vision Pro)

Required for:
- [ ] Confirm font sizes are comfortable at natural viewing distance
- [ ] Verify ORP red highlight visibility against real glass material
- [ ] Test gesture reliability (pinch-to-play, drag-to-scrub)
- [ ] Verify reading comfort for extended sessions (5+ minutes)
- [ ] Test spatial audio feedback (if implemented)
- [ ] Performance profiling (memory, CPU, battery)

### Build Commands

```bash
# Build for visionOS Simulator
xcodebuild build -project SpeedReading.xcodeproj -scheme SpeedReading \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro' \
  CODE_SIGNING_ALLOWED=NO

# Run tests on visionOS Simulator
xcodebuild test -project SpeedReading.xcodeproj -scheme SpeedReading \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro'

# Build for device
xcodebuild build -project SpeedReading.xcodeproj -scheme SpeedReading \
  -destination 'generic/platform=xrOS'
```

---

## 8. App Store Considerations

- visionOS apps are submitted separately in App Store Connect (even with a shared target)
- Can initially run as "Designed for iPad" compatibility mode while building native experience
- Native visionOS app provides better experience and is recommended
- Same Apple Developer account and certificates work for visionOS
- TestFlight supports visionOS for beta testing

---

## 9. Technical Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| ORP red not visible on glass | High | Test early; fall back to system `.red` or brighter accent |
| Font too small for spatial | Medium | Increase minimum, test on device at natural distance |
| No haptic replacement feels empty | Low | Spatial audio cue; or simply omit feedback |
| Gestures unreliable for scrubbing | Medium | Test on device; consider larger hit targets |
| Apple Silicon Mac required for dev | Low | User confirmed they have a Vision Pro device (implies Apple Silicon Mac) |

---

## 10. Open Questions

1. **Glass material contrast:** Does the ORP red (#FF3333) provide sufficient contrast against the glass material in all lighting conditions? Needs device testing.
2. **Font size sweet spot:** What's the comfortable default font size for reading at arm's length on Vision Pro? Likely 64-96pt.
3. **Immersive reading value:** Is full immersion actually better for speed reading, or is the windowed experience sufficient? User testing needed.
4. **Audio feedback preference:** Do users want audio feedback on sentence boundaries, or is the visual flow sufficient? Should be a setting.
5. **Window placement:** Should the app remember where the user positioned their reading window? visionOS may handle this automatically.
