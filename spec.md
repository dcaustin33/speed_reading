# Speed Reading App - Testing & Debugging Plan

## Fixes Applied (2026-01-26)

### Build Fixes
1. **StorageService.swift** - Changed `fileManager` to `FileManager.default` in convenience init (can't use instance property before init)
2. **Chapter.swift** - Added `Codable` conformance for JSON serialization
3. **EPUBImportService.swift** - Replaced macOS-only `Process` with pure Swift ZIP parser for iOS compatibility

### Threading Fixes (EXC_BAD_ACCESS)
1. **PlaybackEngine.swift** - Added `@MainActor`, rewrote timer using `Task.sleep` instead of `DispatchSourceTimer`
2. **ReaderViewModel.swift** - Added `@MainActor`
3. **SearchViewModel.swift** - Added `@MainActor`
4. **SettingsViewModel.swift** - Added `@MainActor`
5. **TOCViewModel.swift** - Added `@MainActor`
6. **PlaybackEngine.swift** - Rewrote playback loop to use recursive async pattern instead of while loop with weak self capture

---

## Current Issue
The app crashes with `EXC_BAD_ACCESS` in the `@Observable` macro's `withMutation` method. This indicates either:
1. Threading violations (accessing @Observable properties from wrong thread)
2. Memory corruption (accessing deallocated objects)
3. Race conditions in state updates

---

## Phase 1: Audit All @Observable Classes for Thread Safety

### Classes to Audit
All classes using `@Observable` must be `@MainActor` isolated since SwiftUI observes them from the main thread.

| File | Class | Has @MainActor? | Status |
|------|-------|-----------------|--------|
| `Core/Playback/PlaybackEngine.swift` | `PlaybackEngine` | ✅ Yes | Fixed |
| `Features/Reader/ReaderViewModel.swift` | `ReaderViewModel` | ✅ Yes | Fixed |
| `Features/Library/LibraryViewModel.swift` | `LibraryViewModel` | ✅ Yes (ObservableObject) | OK |
| `Features/Search/SearchViewModel.swift` | `SearchViewModel` | ✅ Yes | Fixed |
| `Features/TOC/TOCViewModel.swift` | `TOCViewModel` | ✅ Yes | Fixed |
| `Features/Settings/SettingsViewModel.swift` | `SettingsViewModel` | ✅ Yes | Fixed |

### Action Items
1. [ ] Add `@MainActor` to all ViewModel classes
2. [ ] Ensure all async operations dispatch back to MainActor
3. [ ] Remove any DispatchQueue usage in favor of Task/async-await

---

## Phase 2: Audit Services for Thread Safety

### Services that may be called from ViewModels
| File | Class/Enum | Thread-Safe? | Notes |
|------|------------|--------------|-------|
| `Services/Storage/StorageService.swift` | `StorageService` | Check | File I/O |
| `Services/Library/LibraryDataService.swift` | `LibraryDataService` | Check | Uses StorageService |
| `Services/FileImport/FileImportService.swift` | `FileImportService` | Check | File operations |
| `Services/EPUB/EPUBImportService.swift` | `EPUBImportService` | Check | ZIP extraction |
| `Services/Search/SearchService.swift` | `SearchService` | Check | Search operations |

### Action Items
1. [ ] Ensure services called from @MainActor contexts handle threading correctly
2. [ ] Use `nonisolated` or background Tasks for heavy operations
3. [ ] Dispatch results back to MainActor

---

## Phase 3: Memory Management Audit

### Potential Retain Cycles
Check for strong reference cycles in closures:

1. **PlaybackEngine callbacks**
   - `onWordChange`, `onSentenceChange`, `onParagraphChange`, etc.
   - These are set by ReaderViewModel - ensure weak references if needed

2. **Task captures**
   - All `Task { }` blocks should use `[weak self]` if they outlive the object

3. **Closure properties**
   - Any stored closures that capture self

### Action Items
1. [ ] Audit all callback assignments for retain cycles
2. [ ] Verify `[weak self]` usage in all long-lived Tasks
3. [ ] Check for circular references between ViewModels and Views

---

## Phase 4: Test Every User Flow

### Flow 1: App Launch
- [ ] App launches without crash
- [ ] Library screen displays
- [ ] Empty state shows if no books

### Flow 2: Import Book (TXT)
- [ ] Tap + button opens file picker
- [ ] Select .txt file imports successfully
- [ ] Book appears in library
- [ ] No crash during import

### Flow 3: Import Book (EPUB)
- [ ] Select .epub file imports successfully
- [ ] Cover image extracted (if present)
- [ ] Chapters parsed correctly
- [ ] No crash during ZIP extraction

### Flow 4: Open Book
- [ ] Tap book opens reader
- [ ] First word displays
- [ ] ORP highlighting works
- [ ] No crash on open

### Flow 5: Playback
- [ ] Tap to start playback
- [ ] Words advance at correct speed
- [ ] Tap to pause works
- [ ] No crash during playback
- [ ] No crash after extended playback (1+ minute)

### Flow 6: Navigation (Menu)
- [ ] Menu button opens menu
- [ ] Playback pauses when menu opens
- [ ] Skip forward/backward works
- [ ] Next/previous sentence works
- [ ] Next/previous paragraph works
- [ ] No crash on rapid button presses

### Flow 7: Scrubbing
- [ ] Drag progress bar shows preview
- [ ] Release jumps to position
- [ ] Playback stays paused after scrub
- [ ] No crash during scrubbing

### Flow 8: Settings
- [ ] WPM slider adjusts speed
- [ ] Paragraph pause slider works
- [ ] Font size slider works
- [ ] Word skip slider works
- [ ] Settings persist after restart

### Flow 9: Search
- [ ] Search field accepts input
- [ ] Search returns results
- [ ] Tap result jumps to position
- [ ] No crash on search

### Flow 10: Table of Contents (EPUB)
- [ ] TOC shows chapters
- [ ] Current chapter highlighted
- [ ] Tap chapter jumps to position
- [ ] No crash on TOC navigation

### Flow 11: Book Deletion
- [ ] Long press enters edit mode
- [ ] Select books works
- [ ] Delete removes books
- [ ] No crash on delete

### Flow 12: App Lifecycle
- [ ] Background app doesn't crash
- [ ] Return to app works
- [ ] Progress saved on background
- [ ] No crash on repeated background/foreground

---

## Phase 5: Specific Crash Scenarios to Test

### Rapid State Changes
- [ ] Rapid play/pause toggling (10+ times fast)
- [ ] Rapid menu open/close
- [ ] Rapid scrubbing back and forth
- [ ] Switching books quickly

### Edge Cases
- [ ] Empty book (0 words)
- [ ] Single word book
- [ ] Very large book (100k+ words)
- [ ] Book with no paragraphs
- [ ] EPUB with no TOC
- [ ] EPUB with DRM (should show error, not crash)

### Memory Pressure
- [ ] Import multiple large books
- [ ] Open/close reader repeatedly
- [ ] Search in large book multiple times

---

## Phase 6: Code Fixes Required

Based on audit findings, implement these fixes:

### Fix 1: Add @MainActor to All ViewModels
```swift
@Observable
@MainActor
class LibraryViewModel { ... }

@Observable
@MainActor
class SearchViewModel { ... }

@Observable
@MainActor
class TOCViewModel { ... }

@Observable
@MainActor
class SettingsViewModel { ... }
```

### Fix 2: Ensure Callbacks Use Weak Self
```swift
// In ReaderViewModel, when setting up PlaybackEngine callbacks:
playbackEngine.onWordChange = { [weak self] word, index in
    self?.handleWordChange(word, index: index)
}
```

### Fix 3: Cancel Tasks on Deinit/Disappear
```swift
// Store task references and cancel them
private var loadTask: Task<Void, Never>?

func loadBook() {
    loadTask?.cancel()
    loadTask = Task { ... }
}

// In view's onDisappear or viewModel cleanup
loadTask?.cancel()
```

### Fix 4: Avoid Force Unwraps
Search for and fix any `!` force unwraps that could cause crashes.

### Fix 5: Add Nil Checks
Ensure all optional accesses are safe.

---

## Phase 7: Build Verification Commands

```bash
# Clean build
xcodebuild clean -project SpeedReading.xcodeproj -scheme SpeedReading

# Build for iOS
xcodebuild -project SpeedReading.xcodeproj -scheme SpeedReading \
  -destination generic/platform=iOS \
  CODE_SIGNING_ALLOWED=NO build

# Build for Simulator (if available)
xcodebuild -project SpeedReading.xcodeproj -scheme SpeedReading \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

---

## Phase 8: Debugging Steps

### Enable Zombie Objects
In Xcode: Edit Scheme → Run → Diagnostics → Enable Zombie Objects
This helps catch use-after-free bugs.

### Enable Thread Sanitizer
In Xcode: Edit Scheme → Run → Diagnostics → Thread Sanitizer
This catches threading violations.

### Enable Address Sanitizer
In Xcode: Edit Scheme → Run → Diagnostics → Address Sanitizer
This catches memory corruption.

### Add Logging
Add strategic print statements to track:
- When ViewModels are created/destroyed
- When PlaybackEngine state changes
- When callbacks are invoked

---

## Execution Order

1. **Immediate**: Audit and fix all @Observable classes (Phase 1)
2. **Next**: Fix callback retain cycles (Phase 3)
3. **Then**: Test core flows (Phase 4, Flows 1-5)
4. **Finally**: Test edge cases (Phase 5)

---

## Success Criteria

The app is considered stable when:
- [ ] All Phase 4 flows complete without crash
- [ ] All Phase 5 scenarios complete without crash
- [ ] Thread Sanitizer reports no issues
- [ ] Address Sanitizer reports no issues
- [ ] App can run for 5+ minutes of continuous playback without crash
