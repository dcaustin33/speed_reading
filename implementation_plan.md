# Speed Reading iOS App - Implementation Plan

This document outlines the implementation tasks for building the Speed Reading iOS app. Each task is designed to be a complete coding session for an agent.

---

## Phase 1: Foundation

### - [x] Task 1: iOS Project Setup and Architecture
Set up the Xcode project with proper structure, dependencies, and base architecture.

- **Completed**: 2026-01-26
- **Implementation**:
  - Created `SpeedReading.xcodeproj` with iOS 17.0 deployment target
  - Configured for iPhone-only, portrait orientation
  - Set up SwiftUI as primary UI framework
  - Project structure created with all specified folders (App, Core, Features, Services, UI, Resources)
  - Dark theme color palette defined in `Theme.swift` with all specified colors
  - Navigation architecture using `NavigationStack` with `NavigationRouter` for programmatic navigation
  - All placeholder screens implemented: Library, Reader, Menu (sheet), Search, TOC, Settings
  - TestFlight ready: `ITSAppUsesNonExemptEncryption = false` in Info.plist, document types configured for .txt/.md/.epub
- **Files created**:
  - `SpeedReading.xcodeproj/project.pbxproj`
  - `SpeedReading/App/SpeedReadingApp.swift`
  - `SpeedReading/App/ContentView.swift`
  - `SpeedReading/App/NavigationRouter.swift`
  - `SpeedReading/UI/Theme/Theme.swift`
  - `SpeedReading/Features/Library/LibraryView.swift`
  - `SpeedReading/Features/Reader/ReaderView.swift`
  - `SpeedReading/Features/Menu/MenuView.swift`
  - `SpeedReading/Features/Search/SearchView.swift`
  - `SpeedReading/Features/TOC/TOCView.swift`
  - `SpeedReading/Features/Settings/SettingsView.swift`
  - `SpeedReading/Resources/Info.plist`
  - `SpeedReading/Resources/Assets.xcassets/*`
- **Notes**:
  - Xcode project created manually (pbxproj format) since Xcode CLI wasn't fully available
  - Empty placeholder folders created for Core/Models, Core/ORP, Core/Tokenizer, Core/Playback, Services/*
  - All views use Theme colors for consistency
  - NavigationRouter supports Route enum with `.reader`, `.settings`, `.search`, `.toc` cases

**Scope:**
- Create new iOS project targeting iOS 17+ (iPhone only, portrait)
- Set up SwiftUI as the primary UI framework
- Configure project structure matching the app's feature areas:
  ```
  SpeedReading/
  ├── App/                    # App entry point, app delegate
  ├── Core/                   # Core business logic
  │   ├── Models/             # Data models (Book, Word, Document, Settings)
  │   ├── ORP/                # ORP calculation logic
  │   ├── Tokenizer/          # Text tokenization engine
  │   └── Playback/           # Playback engine
  ├── Features/               # Feature modules
  │   ├── Library/            # Library screen
  │   ├── Reader/             # Reading screen
  │   ├── Menu/               # Menu overlay
  │   ├── Search/             # Search screen
  │   ├── TOC/                # Table of contents
  │   └── Settings/           # Settings screen
  ├── Services/               # App services
  │   ├── FileImport/         # File import handling
  │   ├── Storage/            # Persistence layer
  │   └── EPUB/               # EPUB parsing
  ├── UI/                     # Shared UI components
  │   └── Theme/              # Colors, fonts, constants
  └── Resources/              # Assets, configs
  ```
- Define the dark theme color palette as constants:
  - Background: `#1A1A1A`
  - Card Background: `#2A2A2A`
  - Primary Text: `#E0E0E0`
  - Secondary Text: `#888888`
  - Accent Blue: `#4A90D9`
  - ORP Red: `#FF3333`
  - Track Gray: `#404040`
- Set up navigation architecture (NavigationStack with programmatic navigation)
- Configure app for TestFlight distribution
- Add placeholder screens for Library, Reader, Menu, Search, TOC, Settings

**Deliverables:**
- Buildable Xcode project with proper structure
- Navigation flow between placeholder screens
- Theme constants defined and accessible

---

### - [x] Task 2: Core Data Models
Implement all data models and their persistence layer.

- **Completed**: 2026-01-26
- **Implementation**:
  - Created all core data models with Codable conformance
  - `Book` model with id, title, author, filename, fileType, fileHash, hasCover, dateAdded, dateLastOpened, totalWords, currentWordIndex, hasTOC, progressPercentage computed property
  - `FileType` enum (.txt, .md, .epub) with `from(extension:)` factory and `fileExtension` property
  - `Word` struct with text, orpIndex, sentenceEnd, paragraphEnd, chapterIndex
  - `Chapter` struct with title and startWordIndex
  - `Document` struct with words array, chapters array, and totalWords computed property
  - `Settings` struct with clamped ranges for wpm (100-800), paragraphPause (0.25-3.0), fontSize (24-96), wordSkip (1-20), and librarySort
  - `SortOrder` enum (.recent, .title)
  - `SearchResult` struct with wordIndex, context, percentage
  - `Library` struct as root container for books array and settings
  - `StorageService` with full CRUD operations for library.json, book files, and covers
  - SHA256 hashing using CryptoKit
- **Files created**:
  - `SpeedReading/Core/Models/Book.swift`
  - `SpeedReading/Core/Models/Chapter.swift`
  - `SpeedReading/Core/Models/Document.swift`
  - `SpeedReading/Core/Models/FileType.swift`
  - `SpeedReading/Core/Models/Library.swift`
  - `SpeedReading/Core/Models/SearchResult.swift`
  - `SpeedReading/Core/Models/Settings.swift`
  - `SpeedReading/Core/Models/SortOrder.swift`
  - `SpeedReading/Core/Models/Word.swift`
  - `SpeedReading/Services/Storage/StorageService.swift`
- **Notes**:
  - Settings properties auto-clamp to valid ranges on set
  - Book stores hasCover boolean rather than Data to keep model lightweight; actual cover data accessed via StorageService
  - StorageService uses ISO8601 date encoding for JSON compatibility

**Scope:**
- Implement `Book` model with all properties:
  - id (UUID), title, author (optional), filename, fileType enum
  - fileHash (SHA256), coverImage (Data?), dateAdded, dateLastOpened
  - totalWords, currentWordIndex, hasTOC
- Implement `FileType` enum (txt, md, epub)
- Implement `Word` struct:
  - text, orpIndex, sentenceEnd, paragraphEnd, chapterIndex (optional)
- Implement `Document` struct:
  - words array, totalWords, chapters array (optional)
- Implement `Chapter` struct:
  - title, startWordIndex
- Implement `Settings` model:
  - wpm (100-800, default 300), paragraphPause (0.25-3.0, default 1.0)
  - fontSize (24-96, default 48), wordSkip (1-20, default 5)
  - librarySort enum (recent, title)
- Implement `SearchResult` struct:
  - wordIndex, context string, percentage
- Create `StorageService` for JSON persistence:
  - Save/load library.json with books array and settings
  - File operations for Books/ and Covers/ directories
  - SHA256 hashing utility

**Deliverables:**
- All model structs/classes with Codable conformance
- StorageService with full CRUD operations
- Unit tests for models and storage

---

### - [x] Task 3: ORP Calculator and Tokenizer
Implement the core text processing engine.

- **Completed**: 2026-01-26
- **Tests**: `Tests/ORPCalculatorTests.swift` (28 tests), `Tests/TokenizerTests.swift` (46 tests), all passing
- **Implementation**:
  - `ORPCalculator` enum with static `calculateORPIndex(for:)` method using switch statement for lookup table
  - ORP lookup: 1 char → 0, 2-5 → 1, 6-9 → 2, 10-13 → 3, 14+ → 4
  - `TokenizerService` enum with static `tokenize(text:chapters:)` method returning `Document`
  - Line ending normalization (\r\n and \r converted to \n)
  - Paragraph splitting on blank lines (\n\n+)
  - Hyphenated word splitting ("state-of-the-art" → ["state", "of", "the", "art"])
  - Sentence detection with full abbreviation handling (Dr., Mr., Mrs., etc. - 37 abbreviations)
  - Ellipsis handling (... does not end sentences)
  - Single-letter initials handling (J. K. not sentence ends unless at end of paragraph)
  - Quote/bracket stripping for punctuation checking (handles ", ', ', ", (, [, { and closing variants)
  - Chapter index assignment for EPUB support
- **Files created**:
  - `SpeedReading/Core/ORP/ORPCalculator.swift`
  - `SpeedReading/Core/Tokenizer/TokenizerService.swift`
  - `Tests/ORPCalculatorTests.swift` (standalone test script)
  - `Tests/TokenizerTests.swift` (standalone test script)
- **Files modified**:
  - `SpeedReading.xcodeproj/project.pbxproj` (added new source files to build)
- **Notes**:
  - Tests are standalone Swift scripts that can be run with `swift Tests/ORPCalculatorTests.swift`
  - Production code uses the Word and Document models from Core/Models
  - TokenizerService accepts optional chapters array for EPUB processing (Task 5)

**Scope:**
- Implement ORP position calculation:
  - Lookup table: 1 char → 0, 2-5 → 1, 6-9 → 2, 10-13 → 3, 14+ → 4
  - Function: `calculateORPIndex(word: String) -> Int`
- Implement text tokenizer:
  - Split text into words (whitespace-based)
  - Keep punctuation attached to words
  - Split hyphenated words into separate tokens
  - Detect sentence boundaries (., !, ?)
  - Handle abbreviations list: Dr., Mr., Mrs., Ms., Jr., Sr., vs., etc., inc., ltd., corp., co., st., ave., blvd., rd., apt., no., vol., pg., pp., fig., Jan.-Dec., Mon.-Sun.
  - Handle ellipsis (...) - not a sentence end
  - Handle single letter + period (initials) - not a sentence end unless last word
  - Strip surrounding quotes/brackets before checking punctuation
  - Detect paragraph boundaries (blank lines, \n\n+)
  - Normalize line endings (\r\n, \r → \n)
- Create `TokenizerService`:
  - `tokenize(text: String) -> Document`
  - Mark each word with orpIndex, sentenceEnd, paragraphEnd

**Deliverables:**
- ORPCalculator with lookup table implementation
- TokenizerService with full sentence/paragraph detection
- Comprehensive unit tests for edge cases (abbreviations, ellipsis, etc.)

---

## Phase 2: File Import

### - [x] Task 4: Plain Text and Markdown Import
Implement file import for .txt and .md files.

- **Completed**: 2026-01-26
- **Tests**: `Tests/FileImportServiceTests.swift` (29 tests), `Tests/FileImportServiceLoadTests.swift` (21 tests), all passing
- **Implementation**:
  - `FileImportError` enum with all error cases (fileNotFound, unsupportedFormat, encodingError, emptyFile, readError, drmProtected, corruptFile, duplicateBook, storageFull) with LocalizedError conformance
  - `MarkdownStripper` enum with comprehensive markdown syntax removal:
    - Fenced code blocks, inline code, images, links, headers, bold/italic, horizontal rules, blockquotes, list markers
    - Preserves text content and paragraph structure
  - `FileImportService` enum with static methods:
    - `loadTextFile(from:)` - UTF-8 with fallback to Latin-1, CP1252, ASCII, then UTF-16 variants
    - `loadMarkdownFile(from:)` - strips markdown, calculates hash from original data
    - `loadFile(from:fileType:)` - dispatcher for file types
    - `fileType(from:)` and `validateFileType(url:)` - extension detection
    - SHA256 hash calculation using CryptoKit
    - Security-scoped resource access for iOS Files picker
  - `DocumentPicker` SwiftUI wrapper for UIDocumentPickerViewController:
    - Filters for .txt, .md, .epub (UTTypes)
    - Single file selection with copy mode
    - View modifier for easy sheet presentation
  - `FileLoadResult` struct with content and hash
- **Files created**:
  - `SpeedReading/Services/FileImport/FileImportError.swift`
  - `SpeedReading/Services/FileImport/MarkdownStripper.swift`
  - `SpeedReading/Services/FileImport/FileImportService.swift`
  - `SpeedReading/Services/FileImport/DocumentPicker.swift`
  - `Tests/FileImportServiceTests.swift` (markdown stripping tests)
  - `Tests/FileImportServiceLoadTests.swift` (file loading tests)
- **Files modified**:
  - `SpeedReading.xcodeproj/project.pbxproj` (added new source files)
- **Notes**:
  - EPUB loading intentionally throws unsupportedFormat; EPUB support is Task 5
  - Encoding fallback prioritizes single-byte encodings (Latin-1, CP1252) before UTF-16 to avoid false decoding of random bytes as CJK characters
  - Tests are standalone Swift scripts runnable with `swift Tests/*.swift`

**Scope:**
- Create `FileImportService` protocol and base implementation
- Implement `.txt` file loading:
  - UTF-8 decoding with fallback error handling
  - Return (content, sha256Hash) tuple
- Implement `.md` file loading with markdown stripping:
  - Remove fenced code blocks (```)
  - Remove inline code (`)
  - Remove headers (#, ##, etc.) - keep text
  - Remove bold/italic markers (**, *, __, _) - keep text
  - Remove images (![alt](url)) entirely
  - Convert links [text](url) to just text
  - Remove horizontal rules (---, ***, ___)
  - Remove blockquote markers (>)
  - Remove list markers (-, *, +, 1., 2., etc.)
  - Preserve paragraph structure (blank lines)
- Integrate with iOS Files picker (UIDocumentPickerViewController):
  - Filter for .txt, .md, .epub extensions
  - Single file selection mode
  - Copy file to app's local storage
- Handle import errors:
  - File not found, encoding errors, empty files
  - Show appropriate alert messages

**Deliverables:**
- FileImportService with txt/md support
- Markdown stripping logic with all cases handled
- iOS Files picker integration
- Error handling with user-friendly alerts
- Unit tests for markdown stripping

---

### - [ ] Task 5: EPUB Import and Processing
Implement EPUB file parsing and processing.

**Scope:**
- Add EPUB parsing capability (consider using ZIPFoundation for extraction)
- Implement EPUB content extraction:
  - Extract all document items from spine
  - Strip HTML tags (remove script, style entirely)
  - Decode HTML entities (&nbsp;, &amp;, etc.)
  - Convert block-level tags to paragraph breaks (p, li, blockquote, h1-h6)
  - Handle consecutive br tags as paragraph breaks
- Implement metadata extraction:
  - Title from OPF metadata
  - Author from OPF metadata
  - Cover image extraction
- Implement DRM detection:
  - Check META-INF/encryption.xml
  - Detect Adobe ADEPT encryption
  - Detect W3C XML encryption URIs
  - Check for EncryptedData elements (exclude font obfuscation)
  - Reject DRM files with user-friendly error
- Implement TOC parsing:
  - Parse NCX document (EPUB 2)
  - Parse NAV document (EPUB 3)
  - Extract chapter titles and create word index mappings
- Calculate chapter word index ranges

**Deliverables:**
- EPUBParser service with full extraction
- DRM detection and rejection
- TOC parsing for both EPUB 2 and 3
- Cover image extraction
- Unit tests with sample EPUB files

---

### - [ ] Task 6: Library Data Management
Implement the library data layer with duplicate detection and book management.

**Scope:**
- Implement book import workflow:
  - Generate UUID for new book
  - Copy file to Books/{uuid}.{ext}
  - Extract/save cover to Covers/{uuid}.jpg if available
  - Calculate SHA256 hash
  - Tokenize content to get total word count
  - Create Book model and save to library.json
- Implement duplicate detection:
  - Normalize title + author (lowercase, trim)
  - If author missing, use title only
  - Check against existing books
  - Return appropriate error for duplicates
- Implement book deletion:
  - Remove book file from Books/
  - Remove cover from Covers/ if exists
  - Remove from library.json
  - Support bulk deletion
- Implement file hash validation:
  - On book open, verify hash matches
  - If changed, reset progress to 0
- Implement library sorting:
  - Recent (by dateLastOpened, nulls last)
  - Title (alphabetical A-Z)

**Deliverables:**
- Complete book lifecycle management
- Duplicate detection logic
- Hash validation on open
- Sorting implementation
- Integration tests for full import flow

---

## Phase 3: Library UI

### - [ ] Task 7: Library Screen UI
Build the Library screen with grid layout and book management.

**Scope:**
- Implement Library screen layout:
  - Navigation bar with "Speed Reading" title and Edit button
  - Grid layout (3 columns) of book cards
  - Floating action button (+) for import
- Implement book card component:
  - Thumbnail (cover image or book icon placeholder)
  - Title (max 2 lines, ellipsis truncation)
  - Author (1 line, gray text, ellipsis truncation)
  - Progress bar showing reading percentage
- Implement empty state:
  - Book stack icon
  - "Your library is empty" message
  - "Tap the + button to import books from Files" instruction
- Implement edit mode:
  - Selection circles on each book
  - Multi-select support
  - Bottom toolbar with Delete button
  - Confirmation alert before deletion
  - Done button to exit edit mode
- Implement interactions:
  - Tap book → navigate to Reading screen
  - Tap + → open Files picker
  - Long press book → enter edit mode with selection
- Implement sort toggle (segmented control or menu)

**Deliverables:**
- Complete Library screen UI
- Book card component with all states
- Edit mode with multi-select deletion
- Empty state view
- Navigation to Reader (placeholder)

---

## Phase 4: Reading Experience

### - [ ] Task 8: ORP Display Component
Build the core ORP word display widget.

**Scope:**
- Create ORPDisplayView component:
  - System monospace font
  - Configurable font size (24-96pt)
  - Dark background (#1A1A1A)
  - Light gray text (#E0E0E0)
  - Red ORP highlight (#FF3333)
- Implement ORP positioning:
  - Calculate character widths for monospace font
  - Position word so ORP character is at horizontal center
  - Handle variable word lengths
- Implement long word handling:
  - Detect if word overflows screen width
  - Split into display chunks that fit
  - Recalculate ORP per chunk
  - Track chunk index for playback timing
- Create preview mode for displaying word without playback
- Handle edge cases:
  - Single character words
  - Very long words (20+ characters)
  - Words with punctuation

**Deliverables:**
- ORPDisplayView with centered ORP character
- Long word chunking logic
- Font size configuration
- Visual tests/previews for various word lengths

---

### - [ ] Task 9: Playback Engine
Implement the core playback state machine and timing system.

**Scope:**
- Implement PlaybackEngine class:
  - State machine: stopped → playing ↔ paused
  - Current word index tracking
  - Document reference
- Implement timing system:
  - Word delay calculation: 60000 / WPM milliseconds
  - Paragraph pause: additional (paragraphPause * 1000) ms
  - Use DispatchSourceTimer for accurate scheduling
  - Handle chunk timing (divide word delay across chunks)
- Implement navigation methods:
  - play(), pause(), toggle()
  - skipWords(amount: Int) - forward/backward
  - nextSentence(), previousSentence()
  - nextParagraph(), previousParagraph()
  - jumpTo(wordIndex: Int)
- Implement boundary handling:
  - Stay within 0..<totalWords
  - Navigation at boundaries does nothing (no wrap)
- Implement callbacks:
  - onWordChange: (Word, Int) -> Void
  - onSentenceChange: () -> Void
  - onParagraphChange: () -> Void
  - onChapterChange: (Chapter) -> Void
  - onComplete: () -> Void
- Wire up haptic feedback on sentence change

**Deliverables:**
- PlaybackEngine with full state machine
- Accurate timing with DispatchSourceTimer
- All navigation methods implemented
- Callback system for UI updates
- Unit tests for navigation edge cases

---

### - [ ] Task 10: Reading Screen UI
Build the Reading screen with playback controls and progress.

**Scope:**
- Implement Reading screen layout:
  - Back button (always visible, top left)
  - ORP display (center, vertically centered)
  - Menu button (bottom right)
  - Progress bar (bottom, full width)
  - Stats bar (below progress: WPM, time remaining)
- Implement progress bar:
  - 8pt height, dark gray track, blue fill
  - Percentage label (right-aligned)
  - Draggable scrubbing:
    - Pause on drag start
    - Live preview word at drag position
    - Jump to position on release, stay paused
- Implement stats bar:
  - Current WPM display
  - Time remaining calculation:
    - (remainingWords / WPM) * 60 + (remainingParagraphs * paragraphPause)
    - Format: MM:SS or H:MM:SS
- Implement interactions:
  - Tap word area → toggle play/pause
  - Tap back → save progress, return to library
  - Tap menu → open menu overlay, auto-pause
- Implement initial state:
  - Always open paused
  - Show resume word (or first word if new)

**Deliverables:**
- Complete Reading screen layout
- Draggable progress bar with scrubbing
- Stats bar with time remaining
- Integration with PlaybackEngine
- Integration with ORPDisplayView

---

### - [ ] Task 11: Progress Tracking and App Lifecycle
Implement progress persistence and app lifecycle handling.

**Scope:**
- Implement progress saving triggers:
  - Every paragraph end during playback
  - App backgrounding (scenePhase changes)
  - Screen lock
  - Return to library
  - Any pause event
- Implement progress recovery:
  - Load saved currentWordIndex
  - If file hash changed, reset to 0
  - If at last word (completed), stay at last word
  - Otherwise, find paragraph start:
    - Scan backward for paragraphEnd or index 0
    - Resume from word after paragraph end
- Implement auto-pause triggers:
  - App moves to background
  - Incoming phone call (via scene phase)
  - Control Center / Notification Center
  - System overlays
- Implement resume behavior:
  - Never auto-resume
  - User must tap word area to resume
- Update dateLastOpened on book open

**Deliverables:**
- Progress saving at all trigger points
- Progress recovery with paragraph alignment
- Auto-pause on all system events
- dateLastOpened tracking
- Integration tests for progress scenarios

---

### - [ ] Task 12: Chapter Transitions and Completion
Implement chapter overlay and book completion flow.

**Scope:**
- Implement chapter transition overlay:
  - Detect chapter boundary from Word.chapterIndex
  - Show overlay with chapter title
  - Fade in animation
  - Display for 2 seconds
  - Fade out animation
  - Playback continues behind overlay (no pause)
  - Overlay cannot be dismissed early
- Implement completion flow:
  - Detect last word reached
  - Stop playback
  - Show completion overlay:
    - Book emoji icon
    - "Finished!" title
    - "You completed [Book Title]" message
    - "Return to Library" button (only dismissal option)
  - On dismiss:
    - Keep progress at 100% (last word)
    - Navigate to Library

**Deliverables:**
- Chapter transition overlay with animations
- Completion overlay UI
- Completion navigation flow
- Integration with PlaybackEngine callbacks

---

## Phase 5: Menu and Navigation

### - [ ] Task 13: Menu Overlay
Build the menu overlay with navigation controls and sliders.

**Scope:**
- Implement menu overlay layout:
  - Dark background with 95% opacity
  - Close (X) button top right
  - Navigation button row
  - WPM slider
  - Paragraph pause slider
  - Menu items section
- Implement navigation buttons:
  - Previous paragraph (⏮)
  - Previous sentence (⏪)
  - Rewind by wordSkip (◀)
  - Forward by wordSkip (▶)
  - Next sentence (⏩)
  - Next paragraph (⏭)
  - Connect to PlaybackEngine navigation methods
- Implement sliders:
  - WPM: 100-800, step 25, show current value
  - Paragraph pause: 0.25-3.0s, step 0.25, show current value
  - Immediate apply on change
- Implement menu items:
  - Search in Book → navigate to Search screen
  - Table of Contents → navigate to TOC screen (EPUB only)
  - Settings → navigate to Settings screen
- Implement behavior:
  - Auto-pause on open
  - Stay paused on close

**Deliverables:**
- Complete menu overlay UI
- Navigation buttons wired to PlaybackEngine
- Sliders with live updates
- Conditional TOC visibility (EPUB only)
- Menu item navigation

---

### - [ ] Task 14: Search Screen
Implement in-book search functionality.

**Scope:**
- Implement search screen layout:
  - Cancel button (top left)
  - "Search" title (center)
  - Search text field with clear button
  - Results count
  - Scrollable results list
- Implement search algorithm:
  - Case-insensitive exact word sequence match
  - No substring matching ("walk" ≠ "walking")
  - Multi-word queries match exact phrase
  - Maximum 50 results
  - Show "Showing first 50 results" if more exist
- Implement result display:
  - Context: ~5 words before and after match
  - Bold the matched phrase
  - Position percentage (wordIndex / totalWords * 100)
  - Results in chronological order (front to back)
- Implement interactions:
  - Type and tap Search keyboard button → execute search
  - Tap result → jump to word, close search, close menu, stay paused
  - Tap Cancel → return to menu
  - Tap X in field → clear search text
- Implement states:
  - Initial: empty field, "Enter a phrase" placeholder
  - No results: "No results found" message
  - Results: scrollable list

**Deliverables:**
- Complete search screen UI
- Search algorithm with exact matching
- Result display with context and highlighting
- Navigation integration
- Unit tests for search edge cases

---

### - [ ] Task 15: Table of Contents Screen
Build the TOC screen for EPUB navigation.

**Scope:**
- Implement TOC screen layout:
  - Back button (top left)
  - "Contents" title (center)
  - Scrollable list of chapters
- Implement chapter list:
  - Chapter title text
  - Current chapter indicator (blue checkmark)
  - Nested items indented (if EPUB has nested TOC)
- Implement current chapter detection:
  - Based on current word index
  - Find chapter whose range contains current position
- Implement interactions:
  - Tap chapter → jump to chapter start, close TOC, close menu, stay paused
  - Tap Back → return to menu
- Handle edge cases:
  - EPUB with no TOC
  - Very long chapter titles (truncation)
  - Deeply nested TOC structures

**Deliverables:**
- Complete TOC screen UI
- Current chapter highlighting
- Nested TOC support
- Navigation to chapter positions

---

### - [ ] Task 16: Settings Screen
Build the settings screen with font and word skip configuration.

**Scope:**
- Implement settings screen layout:
  - Back button (top left)
  - "Settings" title (center)
  - Font Size slider section
  - Word Skip slider section
- Implement Font Size slider:
  - Range: 24-96pt
  - Default: 48pt
  - Show current value below slider
  - Immediate apply (update ORP display)
- Implement Word Skip slider:
  - Range: 1-20 words
  - Default: 5 words
  - Show current value below slider ("X words")
  - Immediate apply
- Implement persistence:
  - Auto-save on any change
  - Settings apply globally to all books
- Implement interactions:
  - Adjust slider → immediately apply
  - Tap Back → return to menu (already saved)

**Deliverables:**
- Complete settings screen UI
- Both sliders with live preview
- Settings persistence
- Integration with ORPDisplayView and PlaybackEngine

---

## Phase 6: Polish and Integration

### - [ ] Task 17: Error Handling and Edge Cases
Implement comprehensive error handling across the app.

**Scope:**
- Implement import error handling:
  - File not found: "Could not access this file"
  - Unsupported format: "This file type is not supported..."
  - DRM protected: "This EPUB is DRM protected..."
  - Corrupt EPUB: "This EPUB file appears to be damaged..."
  - Empty file: "This file is empty"
  - Encoding error: "Could not read this file..."
  - Duplicate: "This book is already in your library"
  - Storage full: "Not enough storage space..."
- Implement runtime error handling:
  - Book file deleted while reading:
    - Detect on attempted access
    - Show "This book is no longer available"
    - Remove from library
    - Return to library screen
- Implement graceful degradation:
  - Missing cover → show placeholder
  - Missing TOC → hide TOC menu item
  - Corrupt progress → reset to beginning
- Add loading indicators:
  - File import progress
  - Large EPUB processing

**Deliverables:**
- All error alerts implemented
- Runtime error recovery
- Graceful degradation for missing data
- Loading states for async operations

---

### - [ ] Task 18: Accessibility and Final Polish
Add accessibility support and final UI polish.

**Scope:**
- Implement accessibility labels:
  - All buttons (back, menu, play/pause, navigation)
  - Progress bar (value: "X percent complete")
  - Sliders (WPM, pause, font size, word skip)
  - Book cards (title, author, progress)
- Implement accessibility values:
  - Progress bar percentage
  - Slider current values
- Implement standard iOS focus navigation
- Add haptic feedback:
  - Sentence boundary: light impact
  - Respect system Haptics setting
- Final UI polish:
  - Consistent spacing and margins
  - Smooth animations and transitions
  - Proper keyboard handling in search
  - Safe area respect
- Performance verification:
  - Import time < 1s for 100KB, < 5s for 10MB
  - Search < 500ms for 50K words
  - App launch < 1 second
  - Playback timing ± 10ms

**Deliverables:**
- All accessibility labels and values
- Haptic feedback integration
- Polished animations
- Performance within requirements
- TestFlight build ready

---

## Task Dependencies

```
Task 1 (Project Setup)
    ↓
Task 2 (Data Models) ──────────────────────┐
    ↓                                      ↓
Task 3 (ORP/Tokenizer) ──────────────→ Task 6 (Library Data)
    ↓                                      ↓
Task 4 (TXT/MD Import) ─────────────→ Task 7 (Library UI)
    ↓
Task 5 (EPUB Import)

Task 3 (ORP/Tokenizer)
    ↓
Task 8 (ORP Display) ──────────────→ Task 10 (Reading Screen)
    ↓                                      ↓
Task 9 (Playback Engine) ──────────────────┘
                                           ↓
                                    Task 11 (Progress/Lifecycle)
                                           ↓
                                    Task 12 (Chapters/Completion)
                                           ↓
                                    Task 13 (Menu Overlay)
                                           ↓
        ┌──────────────────────────────────┼──────────────────────────────────┐
        ↓                                  ↓                                  ↓
Task 14 (Search)                    Task 15 (TOC)                     Task 16 (Settings)
        └──────────────────────────────────┼──────────────────────────────────┘
                                           ↓
                                    Task 17 (Error Handling)
                                           ↓
                                    Task 18 (Accessibility/Polish)
```

---

## Notes for Agents

- Each task should be completable in a single coding session
- Write unit tests for all business logic
- Follow Swift conventions and SwiftUI best practices
- Use the PRD (`iOS_PRD.md`) as the source of truth for requirements
- Reference the theme colors defined in Task 1 throughout
- All settings are global (not per-book)
- The app is iPhone-only, portrait orientation, iOS 17+
