# Bug Report — SpeedReading iOS App

**Date:** 2026-02-14
**Scope:** Full audit of iOS codebase (`SpeedReading/`)
**Total bugs found:** 32 (0 critical, 4 high, 12 medium, 16 low)

---

## Summary

| Severity | Count | Areas |
|----------|-------|-------|
| Critical | 0 | — |
| High | 4 | Services (EPUB parsing), UI (state management, accessibility) |
| Medium | 12 | Core, Services, UI |
| Low | 16 | Core, Services, UI |

---

## Critical (0)

*None — S1 was originally reported here but determined not to be a real bug after investigation.*

---

## High (4)

### S2. DRM false positive — font obfuscation blocks EPUB loading
- **File:** `Services/EPUB/DRMDetector.swift:32-33`
- **Description:** The check `xml.contains("http://www.w3.org/2001/04/xmlenc")` triggers on the W3C XML Encryption namespace URI, present in virtually every `encryption.xml` — including those with only font obfuscation (not DRM). The early return on line 33 fires *before* the font obfuscation whitelist check on lines 44-65, making that logic dead code.
- **Impact:** Common commercial EPUBs with obfuscated fonts are incorrectly rejected as "DRM protected."
- **Fix:** Remove the broad namespace check on lines 32-33. The algorithm-level check on lines 44-65 already correctly distinguishes DRM from font obfuscation — it just needs to be reachable.

### S3. ZIP parser ignores data descriptor flag (bit 3), breaking many EPUBs
- **File:** `Services/EPUB/EPUBImportService.swift:194-253`
- **Description:** The ZIP parser reads `compressedSize`/`uncompressedSize` from the local file header. If general purpose bit flag bit 3 is set, these fields are 0 in the local header and the actual sizes are in a *data descriptor* after the compressed data. The code doesn't check bit 3, so entries with data descriptors read 0 bytes and fail.
- **Impact:** Many ZIP tools (including macOS Archive Utility and Java's ZipOutputStream) produce files with data descriptors. Such EPUBs fail to load or load with missing content.
- **Fix:** Check bit 3 of the general purpose flag. If set, scan for the data descriptor signature after the compressed data, or fall back to the Central Directory for sizes.

### U1. ProgressBarView accessibility adjustable action is completely broken
- **File:** `Features/Reader/ProgressBarView.swift:62-71`
- **Description:** The `accessibilityAdjustableAction` calls `onScrubChange(position)` which maps to `viewModel.updateScrubPosition(position)`. But that method has a `guard isScrubbing` check — and `isScrubbing` is never set to true because `onScrubStart()` is never called first.
- **Impact:** VoiceOver users cannot adjust the progress bar at all. The accessibility adjustment silently does nothing.
- **Fix:** Wrap the adjustable action to call `onScrubStart()` before and `onScrubEnd()` after adjusting.

### U2. Settings changes (font size, word skip) don't propagate to Reader
- **Files:** `Features/Reader/ReaderViewModel.swift:88-95`, `Features/Settings/SettingsViewModel.swift:44-69`
- **Description:** Each ViewModel creates its own `LibraryDataService` instance. When the user changes font size in Settings, the change is saved to disk by SettingsViewModel's instance. But ReaderViewModel reads from its own instance, which still has the stale in-memory copy.
- **Impact:** Font size and word skip changes appear to not work until the user fully exits and re-enters the reader.
- **Fix:** Share a single `LibraryDataService` instance, or reload settings from disk when ReaderView reappears.

---

## Medium (12)

### C1. Last word gets zero display time
- **File:** `Core/Playback/PlaybackEngine.swift:464-469`
- **Description:** When the playback loop reaches the last word, it fires `onWordChange` but immediately returns without sleeping. The last word effectively flashes for 0ms before the completion overlay appears.
- **Fix:** Sleep for the normal word delay before firing `onComplete`.

### - [x] C2. Pressing play after completion replays last word in a loop
- **File:** `Core/Playback/PlaybackEngine.swift:224, 464-469`
- **Description:** After completion, `currentWordIndex` is `totalWords - 1`. The reset check in `play()` only triggers when `currentWordIndex >= totalWords`, so it doesn't reset. Pressing play again replays the last word and immediately re-triggers `onComplete`.
- **Fix:** After completion, set `currentWordIndex = totalWords` so the reset check catches it.

### - [x] C3. Missing common abbreviations cause false sentence breaks
- **File:** `Core/Tokenizer/TokenizerService.swift:6-13`
- **Description:** The abbreviation list is missing common abbreviations that cause false sentence-end detection: "e.g.", "i.e.", "a.m.", "p.m.", "u.s.", "u.k.", "prof.", "gen.", "dept.", etc.
- **Fix:** Add missing abbreviations to the set.

### - [x] S4. Chapter word-index drift — simple word count vs. tokenizer mismatch
- **File:** `Services/EPUB/EPUBImportService.swift:152-155`
- **Description:** Chapter `startWordIndex` values use `components(separatedBy: .whitespacesAndNewlines)` (simple split), but reading uses `TokenizerService` which splits hyphenated words. Chapter boundaries progressively drift as hyphenated words accumulate.
- **Fix:** Use the same tokenization logic when computing chapter `startWordIndex`.

### - [x] S5. ISO-8859-1 always succeeds, making CP-1252/ASCII fallback unreachable
- **File:** `Services/FileImport/FileImportService.swift:116-126`
- **Description:** `.isoLatin1` maps every byte 0x00-0xFF to a character, so the fallback paths to CP-1252 and ASCII are dead code. Windows-1252 files render smart quotes and em-dashes incorrectly.
- **Fix:** Check for CP-1252 before ISO-8859-1, or use heuristic detection.

### S6. HTML entity double-decoding
- **File:** `Services/EPUB/HTMLStripper.swift:94-135`
- **Description:** `&amp;` is decoded to `&` *before* numeric entities are processed. So `&amp;#169;` becomes `&#169;` then `©` — the correct output should be literal `&#169;`.
- **Fix:** Decode numeric entities first, then named entities, or use a single-pass approach.

### S7. NCX parser mishandles nested navPoints
- **File:** `Services/EPUB/NCXParser.swift:65`
- **Description:** The regex `<navPoint[^>]*>([\s\S]*?)</navPoint>` uses non-greedy matching to the first `</navPoint>`. Nested navPoints (common with parts containing chapters) produce duplicate/incorrect TOC entries.
- **Fix:** Use an iterative/stack-based parser instead of regex for nested structures.

### S8. NAV parser misses anchor titles with inline HTML
- **File:** `Services/EPUB/NAVParser.swift:162`
- **Description:** The pattern `([^<]+)` fails when the anchor contains inner elements like `<span>Chapter 1</span>`. The title is not captured.
- **Fix:** Change `([^<]+)` to `([\s\S]*?)` and strip inner HTML tags from the captured title.

### U3. SettingsViewModel uses `didSet` on `@Observable` properties
- **File:** `Features/Settings/SettingsViewModel.swift:17-25`
- **Description:** `fontSize` and `wordSkip` use `didSet` with `@Observable`, which risks stack overflow on re-entry per the project's established pattern. Fragile even if currently safe.
- **Fix:** Use private backing + computed property pattern like PlaybackEngine.

### U4. Library doesn't refresh book progress after reading
- **File:** `Features/Library/LibraryView.swift`
- **Description:** No `.onAppear` or similar mechanism refreshes the book list when navigating back from the Reader. Book card progress bars show old reading positions until the app restarts.
- **Fix:** Add `.onAppear { viewModel.loadLibrary() }` to LibraryView.

### U5. Tap gesture delayed by long press in Library grid
- **File:** `Features/Library/LibraryView.swift:101-106`
- **Description:** `.onTapGesture` + `.onLongPressGesture` causes SwiftUI to delay tap recognition (~0.5s) while disambiguating gestures.
- **Fix:** Use `.simultaneousGesture(LongPressGesture(...))` or restructure.

### U6. Back button double-calls onDisappear causing redundant file I/O
- **File:** `Features/Reader/ReaderView.swift:249, :63`
- **Description:** The back button manually calls `viewModel.onDisappear()`, then `router.pop()` triggers `.onDisappear` which calls it again. `saveProgress()` writes to disk twice.
- **Fix:** Remove `viewModel.onDisappear()` from the back button; rely on `.onDisappear`.

---

## Low (16)

### C4. Progress percentage can never reach 1.0 (100%)
- **Files:** `Core/Playback/PlaybackEngine.swift:89`, `Core/Models/Book.swift:44`
- **Description:** `currentWordIndex / totalWords` maxes at `(n-1)/n`. Progress bar never shows 100%.
- **Fix:** Use `Double(currentWordIndex) / Double(totalWords - 1)` with guard for `totalWords > 1`.

### C5. Settings Codable doesn't handle missing keys (forward-compat risk)
- **File:** `Core/Models/Settings.swift:80-95`
- **Description:** `init(from decoder:)` uses `container.decode(...)` for all keys. Old `library.json` files missing new keys will fail to decode entirely.
- **Fix:** Use `decodeIfPresent(_:forKey:) ?? defaultValue` for all keys.

### C6. `findChapterIndex` assumes chapters are sorted by startWordIndex
- **File:** `Core/Tokenizer/TokenizerService.swift:85-98`
- **Description:** Iterates chapters and breaks when `startWordIndex > wordIndex`. Out-of-order chapters from malformed EPUBs would produce wrong assignments.
- **Fix:** Sort chapters before use, or remove early break.

### C7. `remainingTime` over-counts by including the current word
- **File:** `Core/Playback/PlaybackEngine.swift:93-110`
- **Description:** `remainingWords = totalWords - currentWordIndex` includes the current word already being displayed. Time estimate is consistently ~1 word too high.
- **Fix:** Use `totalWords - currentWordIndex - 1`.

### S9. Percent-encoded EPUB paths not decoded
- **File:** `Services/EPUB/EPUBImportService.swift:318`
- **Description:** EPUB TOC hrefs can be URL-encoded (e.g., `Chapter%201.html`). The code doesn't decode percent-encoding, so chapters with spaces in filenames won't be detected.
- **Fix:** Apply `removingPercentEncoding` to hrefs before comparison.

### S10. Regex injection in OPFParser.parseTOCPath
- **File:** `Services/EPUB/OPFParser.swift:82-90`
- **Description:** Manifest IDs are interpolated directly into regex patterns without escaping. IDs with regex metacharacters could cause incorrect matching or crashes.
- **Fix:** Use `NSRegularExpression.escapedPattern(for:)` on the ID.

### S11. Decompression buffer may silently truncate
- **File:** `Services/EPUB/EPUBImportService.swift:263-286`
- **Description:** `decompressDeflate` allocates a buffer based on `uncompressedSize` from the ZIP header. If this value is wrong, `compression_decode_buffer` silently truncates output.
- **Fix:** Verify `result == uncompressedSize`. If not, retry with a larger buffer or report an error.

### S12. Double file read for EPUB hash + extraction
- **File:** `Services/EPUB/EPUBImportService.swift:43, :188`
- **Description:** EPUB file data is read twice: once for hash calculation and again for extraction. Doubles memory usage and I/O for large EPUBs.
- **Fix:** Read once and pass data to both `calculateHash` and `parseZIP`.

### S13. Multi-chapter documents lose all but last chapter
- **File:** `Services/EPUB/EPUBImportService.swift:119-126`
- **Description:** When building `chapterMap`, entries for the same document file (after fragment stripping) overwrite each other. Many EPUBs have multiple chapters per XHTML file with fragment identifiers — all lost except the last.
- **Fix:** Store an array of entries per href, or preserve fragment identifiers.

### S14. Search doesn't match words with trailing punctuation
- **File:** `Services/Search/SearchService.swift:84-94`
- **Description:** Search compares `words[wordIndex].text.lowercased()` (includes punctuation) against query. Searching for "hello" won't match "hello," or "hello." in text.
- **Fix:** Strip punctuation from both query words and document words before comparison.

### U7. Menu navigation may cause animation glitches
- **File:** `Features/Menu/MenuView.swift:127-136`
- **Description:** `showMenu = false` (sheet dismiss) and `router.navigateTo(...)` (push) happen simultaneously. Navigation push during sheet dismiss animation can cause visual glitches.
- **Fix:** Use the sheet's `onDismiss` callback to trigger navigation.

### U8. Cover image loading blocks main thread during body evaluation
- **File:** `Features/Library/LibraryViewModel.swift:239-249`
- **Description:** `loadCoverImage(for:)` does synchronous file I/O and is called in the view body. With many books, this causes scroll jank.
- **Fix:** Use async image loading with an in-memory cache.

### U9. Progress inconsistency between playback and scrubbing
- **File:** `Core/Playback/PlaybackEngine.swift:87-90`, `Features/Reader/ReaderViewModel.swift:403`
- **Description:** Playback uses `currentWordIndex / totalWords` but scrubbing uses `totalWords - 1` as denominator. Inconsistent progress values between natural reading and scrub position.
- **Fix:** Use `totalWords - 1` as denominator consistently.

### U10. ORPDisplayView has unreachable public API (dead code)
- **File:** `Features/Reader/ORPDisplayView.swift:119-151`
- **Description:** Methods `advanceChunk()`, `resetChunks()` and related properties are defined on the View struct but can never be called from outside (Views are value types).
- **Fix:** Remove dead code.

### U11. Mixed @Observable and ObservableObject patterns
- **File:** `App/NavigationRouter.swift`
- **Description:** NavigationRouter uses older `ObservableObject`/`@Published` while all ViewModels use `@Observable`. Forces mixing `@StateObject`/`@EnvironmentObject` with newer patterns.
- **Fix:** Migrate NavigationRouter to `@Observable`.

### U12. Inconsistent UserDefaults read pattern between Search and TOC
- **Files:** `Features/Search/SearchViewModel.swift:151-160`, `Features/TOC/TOCViewModel.swift:96-103`
- **Description:** TOC checks key existence then reads value; Search reads value then checks existence. Functionally equivalent but inconsistent.
- **Fix:** Use consistent pattern across both.

---

## Files Audited With No Bugs Found

### Core
- `Core/Models/Chapter.swift`
- `Core/Models/Document.swift`
- `Core/Models/Word.swift`
- `Core/Models/Library.swift`
- `Core/Models/FileType.swift`
- `Core/Models/SortOrder.swift`
- `Core/ORP/ORPCalculator.swift` — Lookup table matches spec
- `Core/ORP/ORPDisplayLogic.swift` — Edge cases handled correctly

### Concurrency
PlaybackEngine is `@MainActor`, so all state mutations happen on the main actor. The async playback loop inherits the actor context. No race conditions or concurrency bugs found. The cancellation flow is safe.

---

*Generated by 3-agent audit team on 2026-02-14*
