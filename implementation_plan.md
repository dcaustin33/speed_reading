# Speed Reading App - Implementation Plan

## Chunk 1: Enable Xcode Diagnostics
- [x] **Enable sanitizers and diagnostics before any testing**
  - ✅ Completed: 2026-01-26
  - ✅ Fixed: 2026-01-26 - Disabled ASan to allow builds (ASan+TSan mutually exclusive)
  - Implementation: Created shared Xcode scheme with diagnostics pre-configured
  - File created: `SpeedReading.xcodeproj/xcshareddata/xcschemes/SpeedReading.xcscheme`
  - Diagnostics enabled:
    - ✅ **Thread Sanitizer** (`enableThreadSanitizer = "YES"`)
    - ❌ **Address Sanitizer** (`enableAddressSanitizer = "NO"`) - disabled (mutually exclusive with TSan)
    - ✅ **Zombie Objects** (`NSZombieEnabled = "YES"`)
    - ✅ **MallocScribble** (fills freed memory with 0x55)
    - ✅ **MallocGuardEdges** (adds guard pages around allocations)
  - Notes:
    - Address Sanitizer and Thread Sanitizer are mutually exclusive at compile time
    - To use ASan instead of TSan, manually edit scheme: set `enableAddressSanitizer = "YES"` and `enableThreadSanitizer = "NO"`
    - Scheme is shared (in xcshareddata) so it's version-controlled and available to all developers
  - Build verified: ✅ XML valid (scheme file verified with xmllint)

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
- [x] **Ensure PlaybackEngine timer runs on MainActor**
  - ✅ Completed: 2026-01-26
  - Tests: 10 static analysis tests, all passing
  - Verification: PlaybackEngine already correctly implemented
  - Findings:
    - ✅ `@Observable` and `@MainActor` present on class
    - ✅ Uses `Task.sleep` for timing (not Timer/DispatchSourceTimer)
    - ✅ No `DispatchQueue` usage anywhere in file
    - ✅ Recursive async pattern with proper cancellation handling
    - ✅ All state changes are direct assignments (MainActor handles thread safety)
    - ✅ `playbackTask?.cancel()` called before creating new task
    - ✅ State checked before continuing loop (`guard state == .playing`)
  - No code changes required - implementation already follows spec

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
- [x] **Audit all callback closures for [weak self]**
  - Completed: 2026-01-26
  - Tests: `tests/RetainCycleAuditTests.swift` (12 tests, all passing)
  - Implementation: Audit verified all callbacks already correctly use [weak self]
  - Findings:
    - `ReaderViewModel.setupCallbacks()` - All 6 PlaybackEngine callbacks use `[weak self]`
    - `ReaderViewModel.handleChapterChange()` - Timer callback uses `[weak self]`
    - `ReaderView.setupHapticCallback()` - Captures `[hapticGenerator]` (value type, safe)
    - `PlaybackEngine` - Only defines callback properties, never assigns them (correct)
    - `LibraryViewModel.handleFileSelected()` - Uses `Task { }` without weak self but is short-lived and acceptable
  - No code changes required - implementation already follows best practices

**Verified patterns (all correct):**
```swift
// ReaderViewModel.swift - All callbacks use [weak self]
playbackEngine.onWordChange = { [weak self] word, index in
    self?.currentWord = word.text
    self?.currentOrpIndex = word.orpIndex
}

// Timer callback also uses [weak self]
chapterOverlayTimer = Timer.scheduledTimer(...) { [weak self] _ in
    self?.hideChapterOverlay()
}
```

**Files audited:**
- `ReaderViewModel.swift` - sets callbacks on PlaybackEngine
- `PlaybackEngine.swift` - callback property definitions
- `ReaderView.swift` - haptic feedback callback
- `LibraryViewModel.swift` - Task closures

---

## Chunk 5: Add Task Cancellation
- [x] **Cancel Tasks on view disappear/deinit**
  - ✅ Completed: 2026-01-26
  - Tests: Static code analysis tests (10 tests, all passing) - tests deleted after verification
  - Implementation: Added task references and cancellation to all ViewModels with async operations
  - Files changed:
    - `ReaderViewModel.swift` - Added `loadTask: Task<Void, Never>?`, refactored `loadBook()` to store task, added cancellation in `onDisappear()`
    - `ReaderView.swift` - Updated to call synchronous `loadBook()` (internally wraps async)
    - `SearchViewModel.swift` - Added `loadTask: Task<Void, Never>?`, refactored `loadDocument()` to store task, added `cleanup()` method
    - `SearchView.swift` - Added `.onDisappear { viewModel.cleanup() }`
    - `LibraryViewModel.swift` - Added `importTask: Task<Void, Never>?`, refactored `handleFileSelected()` to cancel existing and store new task
  - Notes:
    - `PlaybackEngine.swift` already had correct task management (verified: `playbackTask` stored, cancelled before new, nullified on stop)
    - `TOCViewModel.swift` and `SettingsViewModel.swift` have no async operations - no changes needed
  - Build verified: ✅ BUILD SUCCEEDED

**Pattern implemented:**
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

**Files audited and fixed:**
- `ReaderViewModel.swift` - ✅ Fixed (loadTask + cancellation in onDisappear)
- `SearchViewModel.swift` - ✅ Fixed (loadTask + cleanup method)
- `LibraryViewModel.swift` - ✅ Fixed (importTask + cancellation before new)
- `PlaybackEngine.swift` - ✅ Already correct (playbackTask)

---

## Chunk 6: Remove Force Unwraps
- [x] **Search and fix all force unwraps (!)**
  - ✅ Completed: 2026-01-26
  - ✅ Verified: 2026-01-26 (comprehensive audit confirmed zero force unwraps remain)
  - Tests: Static code analysis + build verification (BUILD SUCCEEDED)
  - Audit method: Searched all 46 Swift files using multiple grep patterns for:
    - `variable!` (force unwrap)
    - `as!` (force cast)
    - `try!` (force try)
  - Findings: **No force unwraps found** - codebase already uses safe patterns:
    - All `!` characters are: logical NOT operators (`!isEmpty`), inequality checks (`!=`), regex patterns, or string literals
    - Documents directory access uses `guard let ... else { fatalError() }` - correct iOS pattern
    - Optional unwrapping uses `guard let`, `if let`, `??`, and optional chaining
  - Files verified (sample):
    - `ReaderViewModel.swift` - uses `guard let`, optional chaining, nil-coalescing
    - `PlaybackEngine.swift` - uses `guard let doc = document`, safe array bounds
    - `LibraryDataService.swift` - uses `fatalError` for Documents (invariant on iOS)
    - `StorageService.swift` - uses `fatalError` for Documents (invariant on iOS)
    - `TokenizerService.swift` - uses `guard let firstChar = word.first`
    - `ORPDisplayView.swift` - uses `guard let word = words.randomElement()`
    - All EPUB parsers - use `guard let`, `if let`, optional chaining
  - Build verified: ✅ BUILD SUCCEEDED
  - Notes:
    - The `fatalError()` calls for Documents directory are the standard iOS pattern since this directory is always accessible
    - No code changes were required - implementation already follows best practices

**Patterns verified in codebase:**
```swift
// Documents directory access (always available on iOS)
guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
    fatalError("Unable to access Documents directory - this should never happen on iOS")
}

// Safe first character access
guard let firstChar = word.first else { return false }

// Safe random element
guard let word = words.randomElement() else { return }

// Safe optional unwrapping throughout codebase
guard let doc = document, totalWords > 0 else { return }
if let word = playbackEngine.currentWord { ... }
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
