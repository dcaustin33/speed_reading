# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Speed Reading is a dual-platform application that displays text one word at a time using **ORP (Optimal Recognition Point)** highlighting. The ORP technique highlights a specific letter in each word where the eye naturally focuses, enabling faster reading speeds by reducing eye movement.

### What is ORP?

When reading, the eye doesn't scan every letter—it fixates on a specific point in each word, typically slightly left of center. ORP highlighting marks this focal point (usually in red), allowing the reader to instantly recognize words without searching for the focus point. Combined with RSVP (Rapid Serial Visual Presentation), this enables reading speeds of 300-800+ WPM.

### Platforms

| Platform | Technology | Status |
|----------|------------|--------|
| iOS/iPadOS | SwiftUI, Swift 6 | Full-featured |
| Desktop | Python 3.13+, Tkinter | Full-featured |

---

## Architecture Overview

### Core Reading Pipeline (Both Platforms)

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  File Load  │───▶│  Tokenizer  │───▶│  Playback   │───▶│  ORP        │
│  (txt/epub) │    │  (→ Words)  │    │  Engine     │    │  Display    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                  │                  │                  │
       ▼                  ▼                  ▼                  ▼
   Hash for         Word objects        Timed word         Centered word
   change detect    with boundaries     delivery           with highlight
```

### Cross-Platform Consistency

Both iOS and Python apps share identical core algorithms:

| Component | iOS | Python | Shared Logic |
|-----------|-----|--------|--------------|
| ORP Lookup | `ORPCalculator.swift` | `orp.py` | Same lookup table |
| Tokenizer | `TokenizerService.swift` | `tokenizer.py` | Same boundary detection |
| Playback | `PlaybackEngine.swift` | `reader.py` | Same WPM→delay calculation |

**ORP Lookup Table** (identical on both platforms):
```
Word Length  →  ORP Index
1 char       →  0
2-5 chars    →  1
6-9 chars    →  2
10-13 chars  →  3
14+ chars    →  4
```

---

## iOS App (SpeedReading/)

Built with SwiftUI and Swift 6. Requires Xcode 16+ and iOS 17+.

### Commands

```bash
# Build via Xcode
open SpeedReading.xcodeproj

# Build from command line
xcodebuild -project SpeedReading.xcodeproj -scheme SpeedReading -destination 'platform=iOS Simulator,name=iPhone 15'

# Run tests
xcodebuild test -project SpeedReading.xcodeproj -scheme SpeedReading -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Architecture Pattern: MVVM with Callbacks

```
┌──────────────────────────────────────────────────────────────────┐
│                         ReaderView                                │
│  (SwiftUI View - gestures, layout, overlays)                     │
└───────────────────────────┬──────────────────────────────────────┘
                            │ observes
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│                      ReaderViewModel                              │
│  (@Observable - book loading, progress, scrubbing, settings)     │
└───────────────────────────┬──────────────────────────────────────┘
                            │ owns & configures callbacks
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│                       PlaybackEngine                              │
│  (@Observable - state machine, timing, word delivery)            │
└──────────────────────────────────────────────────────────────────┘
```

### Project Structure

```
SpeedReading/
├── App/                         # App entry point and navigation
│   ├── SpeedReadingApp.swift    # @main entry point, dark theme
│   ├── ContentView.swift        # Root view with NavigationStack
│   └── NavigationRouter.swift   # Centralized navigation state
│
├── Core/                        # Core reading engine (platform-agnostic logic)
│   ├── Models/
│   │   ├── Book.swift           # Book metadata, progress, file hash
│   │   ├── Chapter.swift        # Chapter title + startWordIndex
│   │   ├── Document.swift       # words: [Word], chapters: [Chapter]?
│   │   ├── Word.swift           # text, orpIndex, sentenceEnd, paragraphEnd
│   │   ├── Settings.swift       # wpm, paragraphPause, fontSize, wordSkip
│   │   └── Library.swift        # books: [Book], settings: Settings
│   ├── ORP/
│   │   ├── ORPCalculator.swift  # Static lookup by word length
│   │   └── ORPDisplayLogic.swift # Chunking for long words
│   ├── Playback/
│   │   └── PlaybackEngine.swift # Heart of the app - see detailed docs below
│   └── Tokenizer/
│       └── TokenizerService.swift # Text → Document conversion
│
├── Services/                    # Business logic services
│   ├── FileImport/
│   │   ├── FileImportService.swift  # .txt/.md loading with hash
│   │   ├── MarkdownStripper.swift   # Removes markdown syntax
│   │   └── DocumentPicker.swift     # iOS file picker wrapper
│   ├── EPUB/
│   │   ├── EPUBImportService.swift  # Native ZIP + EPUB parsing
│   │   ├── OPFParser.swift          # Package metadata + spine
│   │   ├── NAVParser.swift          # EPUB3 nav.xhtml TOC
│   │   ├── NCXParser.swift          # EPUB2 toc.ncx TOC
│   │   ├── HTMLStripper.swift       # HTML → plain text
│   │   └── DRMDetector.swift        # encryption.xml check
│   ├── Library/
│   │   └── LibraryDataService.swift # CRUD for books, settings
│   ├── Storage/
│   │   └── StorageService.swift     # File system operations
│   └── Search/
│       └── SearchService.swift      # Word sequence search
│
├── Features/                    # Feature modules (Views + ViewModels)
│   ├── Library/
│   │   ├── LibraryView.swift        # Grid of books, import button
│   │   ├── LibraryViewModel.swift   # Book list management
│   │   └── BookCardView.swift       # Individual book card
│   ├── Reader/
│   │   ├── ReaderView.swift         # Main reading screen
│   │   ├── ReaderViewModel.swift    # Coordinates playback + persistence
│   │   ├── ORPDisplayView.swift     # Centered word with ORP highlight
│   │   ├── ProgressBarView.swift    # Scrubbing-enabled progress
│   │   ├── StatsBarView.swift       # WPM, time remaining, %, chapter time
│   │   ├── ChapterOverlayView.swift # Chapter transition display
│   │   ├── CompletionOverlayView.swift # Book finished screen
│   │   └── NavigationOverlayView.swift # Sentence/paragraph buttons
│   ├── Menu/
│   │   └── MenuView.swift           # In-reader menu sheet
│   ├── TOC/
│   │   ├── TOCView.swift            # Chapter list
│   │   └── TOCViewModel.swift
│   ├── Search/
│   │   ├── SearchView.swift         # Search interface
│   │   └── SearchViewModel.swift
│   └── Settings/
│       ├── SettingsView.swift       # Preferences UI
│       └── SettingsViewModel.swift
│
└── UI/
    ├── Theme/
    │   └── Theme.swift              # Colors, fonts, spacing
    └── Layout/
        └── LayoutHelper.swift       # Adaptive grid calculations
```

### Key Components Deep Dive

#### PlaybackEngine (`Core/Playback/PlaybackEngine.swift`)

The heart of the iOS app. A `@MainActor @Observable` class implementing a state machine.

**State Machine:**
```
         start()              pause()
.stopped ───────▶ .playing ◀──────▶ .paused
    ▲                │                 │
    └────────────────┴─────────────────┘
                    stop()
```

**Playback Loop (async recursive):**
```swift
private func playbackLoopIteration() async {
    // 1. Fire onWordChange callback
    // 2. Check sentence/paragraph boundaries, fire callbacks
    // 3. Calculate delay: 60000/wpm (+ paragraphPause if needed)
    // 4. await Task.sleep(nanoseconds:)
    // 5. Advance word index
    // 6. Recurse or complete
}
```

**Callbacks** (set by ReaderViewModel):
- `onWordChange: (Word, Int) -> Void` — Updates display
- `onSentenceChange: () -> Void` — Triggers haptic feedback
- `onParagraphChange: () -> Void` — Triggers progress save
- `onChapterChange: (Chapter) -> Void` — Shows chapter overlay
- `onComplete: () -> Void` — Shows completion screen
- `onStateChange: (PlaybackState) -> Void` — Triggers progress save

**Chapter Time Remaining** (EPUB only):
- `chapterRemainingTime: TimeInterval?` — Remaining time in current chapter, nil for non-EPUB
- `chapterRemainingTimeFormatted: String?` — Formatted as M:SS or H:MM:SS
- Uses `Word.chapterIndex` to find chapter boundaries, counts remaining words and paragraph pauses

**Important Implementation Detail:**
Cannot use `didSet` on `@Observable` properties (causes stack overflow on re-entry). Uses private backing properties with computed getters/setters:
```swift
private var _wpm: Int = 300
var wpm: Int {
    get { _wpm }
    set { _wpm = newValue.clamped(to: 100...800) }
}
```

#### ReaderViewModel (`Features/Reader/ReaderViewModel.swift`)

Coordinates between PlaybackEngine and UI. Key responsibilities:

1. **Book Loading** (`performLoadBook`):
   - Loads library, validates file hash (resets position if changed)
   - Loads EPUB chapters from `Chapters/{bookId}.json` via `LibraryDataService.loadChapters(for:)`
   - Tokenizes content with chapter info (assigns `Word.chapterIndex`)
   - Handles jump priorities: search result > TOC selection > saved position

2. **Progress Persistence**:
   - Saves on every paragraph end and every pause
   - **Resume aligns to paragraph start** (except search/TOC jumps)

3. **Scrubbing** (progress bar drag):
   - `startScrubbing()` — Pauses playback, enables preview
   - `updateScrubPosition(percentage)` — Shows word at position
   - `endScrubbing()` — Jumps to position, stays paused

4. **Chapter Overlay**:
   - Shows for 2 seconds on chapter boundary
   - Skips initial chapter on first load

#### TokenizerService (`Core/Tokenizer/TokenizerService.swift`)

Converts raw text to a `Document` with `Word` objects.

**Sentence End Detection:**
- Checks for `.`, `!`, `?` after stripping trailing quotes/brackets
- **Excludes:** ellipsis (`...`), abbreviations (dr., mr., mrs., ms., etc., inc., ltd., vs.), single-letter initials (except last word)

**Paragraph Detection:**
- Double newline (`\n\n`) splits paragraphs
- Last word of each paragraph (except final) marked `paragraphEnd = true`

#### EPUBImportService (`Services/EPUB/EPUBImportService.swift`)

Native EPUB parsing without external dependencies.

**ZIP Extraction:**
- Manual binary parsing (signature `0x04034b50`)
- Supports stored (method 0) and deflate (method 8) compression
- Uses `Compression` framework for zlib

**EPUB Flow:**
```
container.xml → OPF path → metadata + spine → content documents → plain text
                               ↓
                          TOC path → NAV or NCX → chapter boundaries
```

### iOS User Interactions

| Gesture/Control | Action |
|-----------------|--------|
| Tap (main area) | Play/Pause toggle |
| Swipe Left | Previous sentence |
| Swipe Right | Next sentence |
| Progress bar drag | Scrub to position |
| Navigation overlay | Sentence/paragraph jump buttons |
| Menu button | Opens settings sheet (pauses playback) |

### Data Persistence

**Storage Location:** `Documents/`
- `library.json` — Book metadata + global settings
- `Books/{UUID}.{ext}` — Imported book files
- `Covers/{UUID}.jpg` — EPUB cover images
- `Chapters/{UUID}.json` — EPUB chapter data (title + startWordIndex)

**Library JSON Structure:**
```json
{
  "books": [
    {
      "id": "uuid",
      "title": "Book Title",
      "author": "Author Name",
      "filename": "uuid.epub",
      "fileType": "epub",
      "fileHash": "sha256...",
      "totalWords": 50000,
      "currentWordIndex": 1234,
      "dateAdded": "2024-01-01T00:00:00Z"
    }
  ],
  "settings": {
    "wpm": 300,
    "paragraphPause": 1.0,
    "fontSize": 28,
    "wordSkip": 5
  }
}
```

---

## Python App (speed_reading/)

**Python 3.13+ required.** Package management via `uv`.

### Commands

```bash
# Activate virtual environment
source .venv/bin/activate

# Run the application
uv run python -m speed_reading
uv run python -m speed_reading path/to/book.txt

# Run tests
uv run pytest

# Add dependencies
uv add <package>
uv add --dev <package>
```

### Project Structure

```
speed_reading/
├── __main__.py              # Entry point
├── app.py                   # Launches MainWindow
├── core/
│   ├── orp.py              # ORP calculation (same lookup as iOS)
│   ├── tokenizer.py        # Text → Document (same logic as iOS)
│   └── reader.py           # Playback engine with Tkinter timers
├── io/
│   ├── file_loader.py      # .txt, .md, .epub loading
│   ├── config.py           # JSON settings persistence
│   └── progress.py         # Per-file reading progress
├── gui/
│   ├── display.py          # Canvas-based ORP display
│   ├── controls.py         # Buttons, sliders, progress bar
│   ├── main_window.py      # Main application window
│   ├── settings.py         # Settings dialog
│   └── search_dialog.py    # Search dialog
└── utils/
    └── constants.py        # Theme colors, ORP table, defaults

tests/
├── test_orp.py
├── test_tokenizer.py
├── test_reader.py
└── test_file_loader.py
```

### Key Differences from iOS

| Aspect | iOS | Python |
|--------|-----|--------|
| Timer mechanism | `Task.sleep(nanoseconds:)` | `root.after(ms, callback)` |
| State machine | 3 states (stopped/playing/paused) | 2 states (playing/not playing) |
| Navigation | `NavigationStack` + Router | Modal dialogs |
| Persistence | Single `library.json` | Separate config + progress files |
| EPUB parsing | Native ZIP extraction | `ebooklib` library |

### Python Dependencies

- `ebooklib>=0.18` — EPUB parsing
- `pytest>=9.0.2` (dev) — Testing

---

## Common Development Tasks

### Adding a New Setting

1. **iOS:**
   - Add property to `Settings` struct (`Core/Models/Settings.swift`)
   - Add UI control in `SettingsView.swift`
   - Connect in `SettingsViewModel.swift`
   - If affects playback, sync in `ReaderViewModel.setupCallbacks()`

2. **Python:**
   - Add to `Config` class (`io/config.py`)
   - Add control in `settings.py` dialog
   - Connect in `main_window.py`

### Adding a New File Format

1. **iOS:**
   - Create parser in `Services/` (e.g., `PDFImportService.swift`)
   - Add case to `FileType` enum in `Book.swift`
   - Update `FileImportService.swift` to route by extension
   - Handle in `LibraryDataService.importBook()`

2. **Python:**
   - Add loader function in `io/file_loader.py`
   - Update `load_file()` to check extension

### Modifying Sentence Detection

Both platforms use the same logic. Update in:
- **iOS:** `TokenizerService.swift` → `isSentenceEnd()` method
- **Python:** `tokenizer.py` → `_is_sentence_end()` function

Keep both in sync.

---

## Code Style

### General
- Keep code clean, concise, and reusable
- Comments should provide insight, not explain what the code does
- No over-engineering—only add complexity when needed

### Swift (iOS)
- Swift 6 strict concurrency
- `@Observable` macro for reactive state (not `ObservableObject`)
- `@MainActor` for all UI-related classes
- Prefer `async/await` over callbacks where possible
- Use `Result` types and `throws` for error handling

### Python
- Type hints (Python 3.10+ style: `list[X]`, `X | None`)
- `@dataclass` for data structures
- No external dependencies except where necessary

---

## Testing

### iOS Tests (`tests/`)
```bash
xcodebuild test -project SpeedReading.xcodeproj -scheme SpeedReading -destination 'platform=iOS Simulator,name=iPhone 15'
```

Key test files:
- `FileImportServiceTests.swift` — File loading
- `LibraryDataServiceTests.swift` — Book management
- `NavigationOverlayTests.swift` — Navigation UI
- `ReaderViewModelNavigationTests.swift` — Navigation logic
- `SwipeGestureTests.swift` — Gesture handling
- `ChapterTimeRemainingTests.swift` — Chapter time remaining calculation

### Python Tests (`tests/`)
```bash
uv run pytest
uv run pytest -v  # verbose
uv run pytest tests/test_tokenizer.py  # specific file
```

Key test files:
- `test_orp.py` — ORP calculation
- `test_tokenizer.py` — Text tokenization
- `test_reader.py` — Playback engine
- `test_file_loader.py` — File loading

---

## Troubleshooting

### iOS

**"@Observable re-entry" crashes:**
Don't use `didSet` on `@Observable` properties. Use private backing + computed property pattern.

**Playback timing issues:**
Check `PlaybackEngine.playbackLoopIteration()` — timing is calculated as `60000 / wpm` milliseconds per word.

**EPUB not loading:**
Check for DRM (`DRMDetector`), malformed ZIP, or missing spine items.

### Python

**Tkinter not responding:**
Ensure `root.after()` callbacks don't block. Long operations should use threading.

**EPUB chapter positions wrong:**
Check `char_to_word` mapping in tokenizer — character positions from EPUB TOC must map to word indices.

---

*Last updated: f1d4ecf6a4299fd407960d8234fd6ee2120028d3*
