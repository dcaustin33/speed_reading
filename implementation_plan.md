# Speed Reading App - Implementation Plan

## Chunk 1: Enable Xcode Diagnostics
- [ ] **Enable sanitizers and diagnostics before any testing**

In Xcode: Edit Scheme → Run → Diagnostics:
- Enable **Thread Sanitizer** (catches threading violations)
- Enable **Zombie Objects** (catches use-after-free)
- Enable **Address Sanitizer** (catches memory corruption)

This will immediately surface issues when you run the app.

---

## Chunk 2: Audit @MainActor Isolation
- [x] **Verify all @Observable classes have @MainActor**
  - ✅ Completed: 2026-01-26
  - All 6 classes verified to have proper @MainActor isolation
  - No code changes required - all classes already correctly isolated

| File | Class | Has @Observable/@ObservableObject | Has @MainActor | Status |
|------|-------|-----------------------------------|----------------|--------|
| `Core/Playback/PlaybackEngine.swift` | `PlaybackEngine` | ✅ @Observable | ✅ Yes | ✅ OK |
| `Features/Reader/ReaderViewModel.swift` | `ReaderViewModel` | ✅ @Observable | ✅ Yes | ✅ OK |
| `Features/Library/LibraryViewModel.swift` | `LibraryViewModel` | ✅ @ObservableObject | ✅ Yes | ✅ OK |
| `Features/Search/SearchViewModel.swift` | `SearchViewModel` | ✅ @Observable | ✅ Yes | ✅ OK |
| `Features/TOC/TOCViewModel.swift` | `TOCViewModel` | ✅ @Observable | ✅ Yes | ✅ OK |
| `Features/Settings/SettingsViewModel.swift` | `SettingsViewModel` | ✅ @Observable | ✅ Yes | ✅ OK |

**Required pattern:**
```swift
@Observable
@MainActor
final class SomeViewModel {
    // ...
}
```

---

## Chunk 3: Fix PlaybackEngine Threading
- [ ] **Ensure PlaybackEngine timer runs on MainActor**

Check `PlaybackEngine.swift`:
- Timer/Task must dispatch word updates on MainActor
- All published state changes must happen on main thread
- No `DispatchQueue` usage - use `Task { @MainActor in }` instead

**Verify this pattern for async work:**
```swift
func startPlayback() {
    playbackTask = Task { @MainActor in
        while isPlaying {
            try await Task.sleep(for: .milliseconds(interval))
            advanceWord()  // State change happens on MainActor
        }
    }
}
```

---

## Chunk 4: Fix Callback Retain Cycles
- [ ] **Audit all callback closures for [weak self]**

In `ReaderViewModel` where callbacks are set on `PlaybackEngine`:
```swift
// WRONG - creates retain cycle
playbackEngine.onWordChange = { word, index in
    self.currentWord = word
}

// CORRECT - breaks retain cycle
playbackEngine.onWordChange = { [weak self] word, index in
    self?.currentWord = word
}
```

**Files to check:**
- `ReaderViewModel.swift` - sets callbacks on PlaybackEngine
- `PlaybackEngine.swift` - callback property definitions
- Any closure stored as a property

---

## Chunk 5: Add Task Cancellation
- [ ] **Cancel Tasks on view disappear/deinit**

**Pattern to implement:**
```swift
@Observable
@MainActor
final class SomeViewModel {
    private var loadTask: Task<Void, Never>?

    func load() {
        loadTask?.cancel()
        loadTask = Task {
            // async work
        }
    }

    func cleanup() {
        loadTask?.cancel()
        loadTask = nil
    }
}
```

**In Views - call cleanup on disappear:**
```swift
.onDisappear {
    viewModel.cleanup()
}
```

**Files needing task cancellation:**
- `ReaderViewModel.swift` - playback tasks
- `SearchViewModel.swift` - search tasks
- `LibraryViewModel.swift` - load tasks
- `PlaybackEngine.swift` - playback loop task

---

## Chunk 6: Remove Force Unwraps
- [ ] **Search and fix all force unwraps (!)**

Run in terminal:
```bash
grep -rn "!" --include="*.swift" SpeedReading/ | grep -v "//"
```

Replace with safe alternatives:
```swift
// WRONG
let word = words[index]!

// CORRECT
guard let word = words[safe: index] else { return }
// or
if let word = words[safe: index] { ... }
```

---

## Chunk 7: Test Core Flows
- [ ] **Test with sanitizers enabled**

Run app with Thread Sanitizer ON and test each flow:

1. [ ] Launch app - library displays
2. [ ] Import .txt file - appears in library
3. [ ] Import .epub file - chapters parsed
4. [ ] Open book - reader displays first word
5. [ ] Start playback - words advance
6. [ ] Pause playback - stops cleanly
7. [ ] Open menu - playback pauses
8. [ ] Skip forward/back - navigation works
9. [ ] Scrub progress bar - jumps to position
10. [ ] Open settings - sliders work
11. [ ] Search - results appear, tap jumps to word
12. [ ] TOC (epub) - chapters list, tap navigates

**If Thread Sanitizer flags an issue, fix it before continuing.**

---

## Chunk 8: Test Crash Scenarios
- [ ] **Stress test rapid state changes**

With sanitizers ON:
1. [ ] Rapid play/pause toggle (10+ times fast)
2. [ ] Rapid menu open/close
3. [ ] Rapid scrubbing back and forth
4. [ ] Switch books quickly
5. [ ] Background/foreground app repeatedly

---

## Chunk 9: Test Edge Cases
- [ ] **Test boundary conditions**

1. [ ] Empty book (0 words)
2. [ ] Single word book
3. [ ] Very long book (if available)
4. [ ] EPUB with no chapters
5. [ ] Import same book twice

---

## Chunk 10: Final Verification
- [ ] **Run extended playback test**

1. Start playback on a book
2. Let it run for 5+ minutes uninterrupted
3. No crashes = success

**Success criteria:**
- All flows complete without crash
- Thread Sanitizer reports zero issues
- Address Sanitizer reports zero issues
- 5+ minutes continuous playback stable

---

## Quick Reference: Execution Order

```
1. Enable diagnostics (Chunk 1)
2. Audit @MainActor (Chunk 2)
3. Fix PlaybackEngine (Chunk 3)
4. Fix retain cycles (Chunk 4)
5. Add task cancellation (Chunk 5)
6. Remove force unwraps (Chunk 6)
7. Test core flows (Chunk 7)
8. Test crash scenarios (Chunk 8)
9. Test edge cases (Chunk 9)
10. Final verification (Chunk 10)
```
