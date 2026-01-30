# Speed Reading iOS App - Product Requirements Document

**Version:** 1.0
**Last Updated:** January 2026
**Status:** Draft
**Target Platform:** iOS 17+ (iPhone only, Portrait orientation)
**Distribution:** TestFlight

---

## 1. Executive Summary

Speed Reading is an iOS application that displays text one word at a time using ORP (Optimal Recognition Point) highlighting. The ORP technique highlights a specific letter in each word where the eye naturally focuses, enabling faster reading speeds.

Users import `.txt`, `.md`, or `.epub` files from the iOS Files app into a personal library, then read them with customizable speed settings. The app tracks reading progress per book and allows users to search within books and navigate via table of contents (EPUB only).

---

## 2. Core Concepts

### 2.1 ORP (Optimal Recognition Point)

The ORP is the character position where the eye naturally focuses when reading a word. The app highlights this character in red to guide the reader's focus.

**ORP Position Lookup Table:**

| Word Length | ORP Index (0-based) |
|-------------|---------------------|
| 1 character | 0 |
| 2-5 characters | 1 |
| 6-9 characters | 2 |
| 10-13 characters | 3 |
| 14+ characters | 4 |

**Display Behavior:**
- The word is positioned so the ORP character is always at the horizontal center of the screen
- The ORP character is displayed in red (`#FF3333`)
- All other characters are displayed in light gray (`#E0E0E0`)

### 2.2 Tokenization

Text is processed into discrete units:
- **Words**: Individual tokens displayed one at a time (punctuation remains attached; hyphenated words are split into separate words)
- **Sentences**: Detected by `.`, `!`, `?` (with smart handling of abbreviations like "Dr.", "Mr.", "etc.")
- **Paragraphs**: Detected by blank lines in the source text (for EPUB, paragraph boundaries come from block-level tags)

Each word carries metadata:
- `text`: The word string
- `orp_index`: Position of the ORP character
- `sentence_end`: Boolean indicating end of sentence
- `paragraph_end`: Boolean indicating end of paragraph

### 2.3 Playback Timing

- **WPM (Words Per Minute)**: Range 100-800, default 300
  - Delay between words = `60000 / WPM` milliseconds
- **Paragraph Pause**: Range 0.25-3.0 seconds, default 1.0 seconds
  - Added to the delay when reaching a paragraph end

---

## 3. User Flows

### 3.1 First Launch Flow

```
App Opens
    │
    ▼
┌─────────────────────────────────┐
│     Empty Library Screen        │
│                                 │
│  "Import your first book"       │
│  [Instructions text]            │
│                                 │
│                           [+]   │  ← Floating action button
└─────────────────────────────────┘
    │
    ▼ (User taps +)
    │
┌─────────────────────────────────┐
│     iOS Files Picker            │
│     (Document Browser)          │
│                                 │
│  Filter: .txt, .md, .epub       │
└─────────────────────────────────┘
    │
    ▼ (User selects file)
    │
┌─────────────────────────────────┐
│     Library Screen              │
│     (Now showing 1 book)        │
└─────────────────────────────────┘
```

### 3.2 Import Flow

```
Library Screen
    │
    ▼ (User taps + button)
    │
iOS Files Picker Opens (single-file selection)
    │
    ▼ (User selects .txt/.md/.epub)
    │
    ├── Success ──────────────────┐
    │                             │
    │   File copied to app's      │
    │   local storage             │
    │   Book added to library     │
    │   Return to Library Screen  │
    │                             │
    ├── Duplicate ────────────────┐
    │                             │
    │   Alert: "This book is      │
    │   already in your library"  │
    │   [OK]                      │
    │                             │
    ├── DRM Protected ────────────┐
    │                             │
    │   Alert: "This EPUB is      │
    │   DRM protected and cannot  │
    │   be opened"                │
    │   [OK]                      │
    │                             │
    └── Invalid/Corrupt ──────────┐
                                  │
        Alert: "Could not open    │
        this file"                │
        [OK]                      │
```

**Duplicate Detection:** Based on normalized (lowercased, trimmed) title + author. If author is missing, title alone is used.

### 3.3 Reading Flow

```
Library Screen
    │
    ▼ (User taps book)
    │
┌─────────────────────────────────┐
│     Reading Screen              │
│                                 │
│  [←]                            │  ← Back button (always visible)
│                                 │
│         ╔═══════════════╗       │
│         ║    wo|rd      ║       │  ← ORP display (| = highlight)
│         ╚═══════════════╝       │  ← Starts PAUSED, user taps to play
│                                 │
│                          [☰]   │  ← Menu button
│                                 │
│  ▓▓▓▓▓▓▓▓▓░░░░░░░░░░  35%      │  ← Draggable progress bar
│  300 WPM | 12:34 remaining      │
└─────────────────────────────────┘
    │
    ▼ (User taps word area)
    │
Playback toggles (play/pause)
    │
    ▼ (On sentence change)
    │
Light haptic feedback (respects system Haptics setting)
```

**Initial State:** Book always opens in PAUSED state showing the resume word. User must tap the word area to begin playback.

### 3.4 Menu Flow

```
Reading Screen
    │
    ▼ (User taps menu button)
    │
Playback auto-pauses
    │
┌─────────────────────────────────┐
│     Menu Overlay          [X]   │
│                                 │
│  ┌─────────────────────────┐    │
│  │ Navigation Controls     │    │
│  │                         │    │
│  │ [⏮] [⏪] [◀] [▶] [⏩] [⏭]│    │
│  │                         │    │
│  │ ⏮ = Prev Paragraph      │    │
│  │ ⏪ = Prev Sentence       │    │
│  │ ◀  = Back [skip] words  │    │
│  │ ▶  = Forward [skip] wrds│    │
│  │ ⏩ = Next Sentence       │    │
│  │ ⏭ = Next Paragraph      │    │
│  └─────────────────────────┘    │
│                                 │
│  WPM: [====●=========] 300      │
│                                 │
│  Pause: [==●=========] 1.0s     │
│                                 │
│  ┌─────────────────────────┐    │
│  │ [🔍 Search]              │    │
│  │ [📑 Table of Contents]  │    │  ← EPUB only
│  │ [⚙️ Settings]            │    │
│  └─────────────────────────┘    │
└─────────────────────────────────┘
    │
    ▼ (User taps X)
    │
Menu closes, return to Reading Screen
(Playback remains paused)
```

### 3.5 Search Flow

```
Menu
    │
    ▼ (User taps Search)
    │
┌─────────────────────────────────┐
│  [Cancel]    Search       [X]   │
│                                 │
│  ┌─────────────────────────┐    │
│  │ Enter search phrase...  │    │
│  └─────────────────────────┘    │
│                                 │
│  (Keyboard appears)             │
└─────────────────────────────────┘
    │
    ▼ (User types and submits)
    │
┌─────────────────────────────────┐
│  [Cancel]    Search       [X]   │
│                                 │
│  ┌─────────────────────────┐    │
│  │ "brown fox"         [X] │    │
│  └─────────────────────────┘    │
│                                 │
│  12 results                     │
│                                 │
│  ┌─────────────────────────┐    │
│  │ "...the quick **brown   │    │
│  │ fox** jumped over..."   │    │
│  │                   3%    │    │  ← Position in book
│  └─────────────────────────┘    │
│  ┌─────────────────────────┐    │
│  │ "...a lazy **brown      │    │
│  │ fox** slept under..."   │    │
│  │                   28%   │    │
│  └─────────────────────────┘    │
│  ┌─────────────────────────┐    │
│  │ "...spotted the         │    │
│  │ **brown fox** near..."  │    │
│  │                   45%   │    │
│  └─────────────────────────┘    │
│                                 │
│  (Scrollable list)              │
└─────────────────────────────────┘
    │
    ▼ (User taps a result)
    │
Jump to that word position (paused)
Close search, close menu
Return to Reading Screen
```

### 3.6 Table of Contents Flow (EPUB Only)

```
Menu
    │
    ▼ (User taps Table of Contents)
    │
┌─────────────────────────────────┐
│  [Back]   Contents        [X]   │
│                                 │
│  ┌─────────────────────────┐    │
│  │ Chapter 1: Introduction │    │
│  └─────────────────────────┘    │
│  ┌─────────────────────────┐    │
│  │ Chapter 2: The Setup    │    │
│  └─────────────────────────┘    │
│  ┌─────────────────────────┐    │
│  │ Chapter 3: Rising Action│    │
│  └─────────────────────────┘    │
│  ┌─────────────────────────┐    │
│  │ Chapter 4: The Climax   │    │
│  └─────────────────────────┘    │
│                                 │
│  (Scrollable list)              │
└─────────────────────────────────┘
    │
    ▼ (User taps chapter)
    │
Jump to chapter start (paused)
Close TOC, close menu
Return to Reading Screen
```

### 3.7 Chapter Transition

```
During playback, when crossing chapter boundary:
    │
    ▼
┌─────────────────────────────────┐
│                                 │
│                                 │
│      Chapter 3: The Journey     │  ← Overlay fades in
│                                 │
│                                 │
└─────────────────────────────────┘
    │
    ▼ (After ~2 seconds)
    │
Overlay fades out
Playback continues with next word
```

**Behavior:**
- Playback does NOT pause during the overlay—words continue advancing behind it
- Overlay cannot be dismissed early; it always displays for the full 2 seconds
- Overlay is purely visual and does not interrupt the reading flow

### 3.8 Reading Completion Flow

```
Last word displayed
    │
    ▼
┌─────────────────────────────────┐
│                                 │
│                                 │
│        📖 Finished!             │
│                                 │
│    You completed "Book Title"   │
│                                 │
│          [Return to Library]    │  ← Only dismissal option
│                                 │
└─────────────────────────────────┘
    │
    ▼ (User taps button)
    │
Keep progress at 100% (last word)
Navigate to Library Screen
```

### 3.9 App Lifecycle & Interruptions

**Pause Triggers:** Playback automatically pauses whenever:
- App moves to background
- Screen locks
- Incoming phone call
- Control Center or Notification Center opens
- Any system overlay appears

**Resume Behavior:** Playback does NOT auto-resume when returning to the app. User must tap the word area to resume.

**Progress Saving:** Current position is saved immediately when any pause trigger occurs and at paragraph boundaries.

---

## 4. Screen Specifications

### 4.1 Library Screen

**Purpose:** Display imported books and allow management/import.

**Theme:** Dark theme consistent with reading screen
- **Background:** Dark (`#1A1A1A`)
- **Card Background:** Slightly lighter (`#2A2A2A`)
- **Primary Text:** Light gray (`#E0E0E0`)
- **Secondary Text:** Medium gray (`#888888`)
- **Accent (FAB, selection):** Blue (`#4A90D9`)

**Layout:**
```
┌─────────────────────────────────┐
│  Speed Reading        [Edit]    │  ← Navigation bar
├─────────────────────────────────┤
│                                 │
│  ┌─────┐  ┌─────┐  ┌─────┐     │
│  │     │  │     │  │     │     │
│  │ 📖  │  │ 📖  │  │ 📖  │     │
│  │     │  │     │  │     │     │
│  ├─────┤  ├─────┤  ├─────┤     │
│  │Title│  │Title│  │Title│     │
│  │Auth │  │Auth │  │Auth │     │
│  │▓▓░░ │  │▓▓▓░ │  │▓░░░ │     │  ← Progress bar
│  └─────┘  └─────┘  └─────┘     │
│                                 │
│  ┌─────┐  ┌─────┐               │
│  │     │  │     │               │
│  │ 📖  │  │ 📖  │               │
│  │     │  │     │               │
│  └─────┘  └─────┘               │
│                                 │
│                           [+]   │  ← Floating action button
└─────────────────────────────────┘
```

**Grid Item Specifications:**
- **Thumbnail:** Book icon or EPUB cover (if available)
- **Title:** Book title (from EPUB metadata or filename), max 2 lines, truncate with ellipsis
- **Author:** Author name (EPUB only), 1 line, truncate with ellipsis, gray text
- **Progress Bar:** Horizontal bar showing reading progress percentage
- **Last Opened:** Not displayed, but used for sorting

**Sorting:**
- Primary: Recently opened (most recent first)
- Secondary option: Title (A-Z)
- Toggle via segmented control or menu in navigation bar

**Edit Mode:**
- Triggered by [Edit] button in navigation bar
- Shows selection circles on each book
- Bottom toolbar appears with [Delete] button
- Supports multi-select for bulk deletion
- [Done] button exits edit mode
- Deleting shows a confirmation alert; on confirm, deletion is immediate with no undo
- If a book is deleted while open, close it and return to Library

**Empty State:**
```
┌─────────────────────────────────┐
│  Speed Reading                  │
├─────────────────────────────────┤
│                                 │
│                                 │
│           📚                    │
│                                 │
│    Your library is empty        │
│                                 │
│  Tap the + button to import     │
│  books from Files               │
│                                 │
│                                 │
│                           [+]   │
└─────────────────────────────────┘
```

**Interactions:**
| Action | Result |
|--------|--------|
| Tap book | Navigate to Reading Screen, resume at saved position |
| Tap + button | Open iOS Files picker |
| Tap Edit | Enter edit mode |
| Long press book | Enter edit mode with that book selected |

---

### 4.2 Reading Screen

**Purpose:** Display words with ORP highlighting during playback.

**Layout:**
```
┌─────────────────────────────────┐
│ [←]                             │  ← Back button
│                                 │
│                                 │
│                                 │
│                                 │
│         extraord|inary          │  ← ORP display
│                                 │
│                                 │
│                                 │
│                                 │
│                          [☰]    │  ← Menu button
│                                 │
│ ▓▓▓▓▓▓▓▓░░░░░░░░░░░  35%       │  ← Progress bar (draggable)
│ 300 WPM  •  12:34 remaining     │  ← Stats bar
└─────────────────────────────────┘
```

**ORP Display Specifications:**
- **Font:** System monospace font
- **Font Size:** User-configurable (24-96pt, default 48pt)
- **Background:** Dark (`#1A1A1A`)
- **Text Color:** Light gray (`#E0E0E0`)
- **ORP Highlight Color:** Red (`#FF3333`)
- **Positioning:** Word is horizontally positioned so the ORP character is at screen center
- **Long Words:** If a word would overflow, split it into display chunks that fit the width
  - Each chunk is shown sequentially within the original word duration
  - ORP is recalculated per chunk
  - Progress advances only after the final chunk

**Progress Bar Specifications:**
- **Height:** 8pt
- **Background (empty):** Dark gray (`#404040`)
- **Fill (progress):** Blue (`#4A90D9`)
- **Percentage Label:** Right-aligned, e.g., "35%"
- **Interaction:** Draggable - user can scrub to any position
- **Scrubbing Behavior:**
  - When user starts dragging, playback pauses
  - Live preview: show word at drag position
  - On release: jump to that position, stay paused

**Stats Bar Specifications:**
- **WPM Display:** Shows current WPM setting (e.g., "300 WPM")
- **Time Remaining:** Calculated as `(remaining_words / WPM) * 60 + (remaining_paragraphs * paragraph_pause)` seconds
  - Format: "MM:SS" if under 1 hour, "H:MM:SS" if over
- **Separator:** Bullet point (•)

**Initial State:**
- Book always opens in PAUSED state
- Displays the resume word (or first word if new book)
- User must tap word area to begin playback

**Interactions:**
| Action | Result |
|--------|--------|
| Tap word area | Toggle play/pause |
| Tap back button | Return to Library (progress auto-saved) |
| Tap menu button | Open menu overlay (auto-pause) |
| Drag progress bar | Scrub to position |
| Sentence boundary reached | Light haptic feedback (respects system Haptics setting) |
| Chapter boundary reached | Show chapter overlay (2 sec, playback continues) |

---

### 4.3 Menu Overlay

**Purpose:** Provide access to navigation, settings, search, and TOC.

**Theme:** Dark theme consistent with app
- **Overlay Background:** Dark with slight transparency (`#1A1A1A` at 95% opacity)
- **Control Background:** Slightly lighter (`#2A2A2A`)
- **Text:** Light gray (`#E0E0E0`)
- **Slider Track:** Dark gray (`#404040`)
- **Slider Fill/Thumb:** Blue (`#4A90D9`)

**Layout:**
```
┌─────────────────────────────────┐
│                           [X]   │  ← Close button
│                                 │
│  ┌─────────────────────────┐    │
│  │                         │    │
│  │ [⏮] [⏪] [◀]  [▶] [⏩] [⏭]│    │  ← Navigation buttons
│  │                         │    │
│  └─────────────────────────┘    │
│                                 │
│  WPM                            │
│  100 [═══════●═══════════] 800  │
│              300                │
│                                 │
│  Paragraph Pause                │
│  0.25s [══●══════════════] 3.0s │
│         1.0s                    │
│                                 │
│  ─────────────────────────────  │
│                                 │
│  [🔍]  Search in Book           │
│                                 │
│  [📑]  Table of Contents        │  ← Only shown for EPUB
│                                 │
│  [⚙️]  Settings                  │
│                                 │
└─────────────────────────────────┘
```

**Navigation Button Specifications:**
| Button | Symbol | Action |
|--------|--------|--------|
| Prev Paragraph | ⏮ | Jump to start of current/previous paragraph |
| Prev Sentence | ⏪ | Jump to start of current/previous sentence |
| Rewind | ◀ | Skip back by `word_skip` words (default 5) |
| Forward | ▶ | Skip forward by `word_skip` words |
| Next Sentence | ⏩ | Jump to start of next sentence |
| Next Paragraph | ⏭ | Jump to start of next paragraph |

**Boundary Behavior:** At book boundaries (start/end), navigation buttons that would go out of bounds simply do nothing. Buttons remain enabled but have no effect.

**Slider Specifications:**
- **WPM Slider:** Range 100-800, step 25, default 300
- **Pause Slider:** Range 0.25-3.0 seconds, step 0.25, default 1.0

**Menu Items:**
- **Search:** Opens search screen
- **Table of Contents:** Opens TOC screen (EPUB only, hidden for .txt/.md)
- **Settings:** Opens settings screen

**Behavior:**
- Opening menu auto-pauses playback
- Closing menu (tap X) keeps playback paused
- User must tap word area to resume

---

### 4.4 Search Screen

**Purpose:** Find text within the current book.

**Theme:** Dark theme consistent with app
- **Background:** Dark (`#1A1A1A`)
- **Search Field Background:** Slightly lighter (`#2A2A2A`)
- **Result Card Background:** Slightly lighter (`#2A2A2A`)
- **Text:** Light gray (`#E0E0E0`)
- **Match Highlight:** Bold white (`#FFFFFF`)

**Layout - Initial:**
```
┌─────────────────────────────────┐
│ [Cancel]      Search            │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ Search...                   │ │
│ └─────────────────────────────┘ │
│                                 │
│                                 │
│                                 │
│         Enter a phrase          │
│       to search in book         │
│                                 │
│                                 │
│                                 │
│ ┌─────────────────────────────┐ │
│ │        [Keyboard]           │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

**Layout - With Results:**
```
┌─────────────────────────────────┐
│ [Cancel]      Search            │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ brown fox              [X]  │ │  ← Clear button
│ └─────────────────────────────┘ │
│                                 │
│ 12 results                      │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ "...the quick brown fox     │ │
│ │ jumped over the lazy..."    │ │
│ │                        3%   │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ "...saw a brown fox         │ │
│ │ running through the..."     │ │
│ │                       28%   │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ "...the brown fox had       │ │
│ │ disappeared into..."        │ │
│ │                       45%   │ │
│ └─────────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

**Search Specifications:**
- **Algorithm:** Case-insensitive exact word sequence match (no substring matching)
- **Multi-word:** Match exact phrase (words in sequence)
- **Results Order:** Chronological (front of book to back)
- **Results Limit:** Maximum 50 results displayed (if more exist, show "Showing first 50 results")
- **Context Display:** ~5 words before and after match
- **Match Highlighting:** Bold the matched phrase in results
- **Position Indicator:** Percentage through book (word_index / total_words * 100)
- **Token Rules:** Matching uses the stored word tokens (punctuation attached)

**No Results State:**
```
│                                 │
│       No results found          │
│                                 │
│  Try a different search term    │
│                                 │
```

**Interactions:**
| Action | Result |
|--------|--------|
| Type and submit | Execute search, show results |
| Tap result | Jump to that word, close search, close menu, stay paused |
| Tap Cancel | Return to menu without searching |
| Tap X in search field | Clear search text |

**Behavior:**
- Search field starts empty each time (no persistence)
- Keyboard auto-shows on screen open
- Search executes on "Search" keyboard button tap

---

### 4.5 Table of Contents Screen (EPUB Only)

**Purpose:** Navigate to chapters within an EPUB.

**Theme:** Dark theme consistent with app
- **Background:** Dark (`#1A1A1A`)
- **Row Background:** Slightly lighter (`#2A2A2A`)
- **Text:** Light gray (`#E0E0E0`)
- **Current Chapter Indicator:** Blue checkmark (`#4A90D9`)

**Layout:**
```
┌─────────────────────────────────┐
│ [Back]    Contents              │
├─────────────────────────────────┤
│                                 │
│ ┌─────────────────────────────┐ │
│ │ Cover                       │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ Chapter 1: The Beginning    │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ Chapter 2: Rising Action    │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ Chapter 3: The Climax       │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ Chapter 4: Resolution       │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ Epilogue                    │ │
│ └─────────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

**Specifications:**
- **Source:** Parsed from EPUB NCX/NAV document
- **Current Chapter:** Highlighted or marked with checkmark
- **Nested Items:** Indented (if EPUB has nested TOC)
- **Non-EPUB Files:** No chapter detection for `.txt` or `.md` files—TOC option is hidden in menu

**Interactions:**
| Action | Result |
|--------|--------|
| Tap chapter | Jump to chapter start, close TOC, close menu, stay paused |
| Tap Back | Return to menu |

---

### 4.6 Settings Screen

**Purpose:** Configure reading preferences. All settings are global (apply to all books).

**Theme:** Dark theme consistent with app
- **Background:** Dark (`#1A1A1A`)
- **Text:** Light gray (`#E0E0E0`)
- **Slider Track:** Dark gray (`#404040`)
- **Slider Fill/Thumb:** Blue (`#4A90D9`)

**Layout:**
```
┌─────────────────────────────────┐
│ [Back]     Settings             │
├─────────────────────────────────┤
│                                 │
│  Font Size                      │
│                                 │
│  24pt [═══════●═════════] 96pt  │
│              48pt               │
│                                 │
│  ─────────────────────────────  │
│                                 │
│  Word Skip Amount               │
│                                 │
│  1 [═══●════════════════] 20    │
│       5 words                   │
│                                 │
│                                 │
│                                 │
│                                 │
│                                 │
│                                 │
└─────────────────────────────────┘
```

**Settings:**
| Setting | Type | Range | Default | Description |
|---------|------|-------|---------|-------------|
| Font Size | Slider | 24-96 pt | 48 pt | Size of word in ORP display |
| Word Skip | Slider | 1-20 | 5 | Words to skip with ◀/▶ buttons |

**Note:** ORP color is fixed at red (`#FF3333`), not user-configurable.

**Interactions:**
| Action | Result |
|--------|--------|
| Adjust slider | Immediately apply setting |
| Tap Back | Return to menu, settings auto-saved |

---

## 5. Data Models

### 5.1 Book

```
Book {
    id: UUID                    // Unique identifier
    title: String               // From EPUB metadata or filename
    author: String?             // From EPUB metadata (optional)
    filename: String            // Original filename
    file_type: FileType         // .txt, .md, .epub
    file_hash: String           // SHA256 of file content
    cover_image: Data?          // EPUB cover (optional)
    date_added: Date            // When imported
    date_last_opened: Date?     // Last reading session
    total_words: Int            // Total word count
    current_word_index: Int     // Reading progress (0-based)
    has_toc: Bool               // Whether TOC is available
}

FileType: Enum {
    txt
    md
    epub
}
```

### 5.2 Document (Runtime)

```
Document {
    words: [Word]               // All words in order
    total_words: Int            // Count of words
    chapters: [Chapter]?        // EPUB chapters (optional)
}

Word {
    text: String                // The word
    orp_index: Int              // Index of ORP character
    sentence_end: Bool          // Is this word at end of sentence?
    paragraph_end: Bool         // Is this word at end of paragraph?
    chapter_index: Int?         // Which chapter (EPUB only)
}

Chapter {
    title: String               // Chapter title
    start_word_index: Int       // First word of chapter
}
```

### 5.3 User Settings

**Scope:** All settings are global and apply to every book. There are no per-book settings.

```
Settings {
    wpm: Int                    // 100-800, default 300
    paragraph_pause: Float      // 0.25-3.0, default 1.0
    font_size: Int              // 24-96, default 48
    word_skip: Int              // 1-20, default 5
    library_sort: SortOrder     // recent or title
}

SortOrder: Enum {
    recent                      // Most recently opened first
    title                       // Alphabetical by title
}
```

---

## 6. Technical Specifications

### 6.1 File Import

**Supported Formats:**
| Format | Extension | Processing |
|--------|-----------|------------|
| Plain Text | .txt | UTF-8 decode, tokenize |
| Markdown | .md | Strip markdown syntax, tokenize |
| EPUB | .epub | Extract text from all chapters, strip HTML, tokenize |

**Files Picker:**
- Single-file selection only

**Markdown Stripping:**
Remove the following while preserving text content:
- Fenced code blocks (```)
- Inline code (`)
- Headers (#, ##, etc.)
- Bold/Italic (\*\*, \*, \_\_, \_)
- Images (!\[alt](url))
- Links (\[text](url)) → keep text
- Horizontal rules (---, \*\*\*, \_\_\_)
- Blockquotes (>)
- List markers (-, \*, +, 1., 2., etc.)

**EPUB Processing:**
1. Extract all document items from spine
2. Strip HTML tags (remove <script>, <style> entirely)
3. Decode HTML entities (&nbsp;, &amp;, etc.)
4. Convert block-level tags to paragraph breaks (<p>, <li>, <blockquote>, <h1>-<h6>)
   - Treat consecutive <br> tags as paragraph breaks
5. Parse NCX/NAV for table of contents
6. Extract cover image if present
7. Calculate word index ranges per chapter

**DRM Detection:**
1. Check for `META-INF/encryption.xml`
2. If present, check for DRM indicators:
   - Adobe ADEPT encryption
   - W3C XML encryption URIs
   - EncryptedData elements (excluding font obfuscation)
3. If DRM detected, reject file with user-friendly error

**Hash Calculation:**
- SHA256 of raw file content
- Used to detect if file content has changed (invalidate progress)
- Duplicate detection uses normalized (lowercased, trimmed) title + author; if author is missing, use title only

### 6.2 Tokenization

**Word Tokenization Rules:**
- Punctuation remains attached to the word it appears with (e.g., "word," stays as one token)
- Hyphenated words are split into separate tokens (e.g., "state-of-the-art" -> "state", "of", "the", "art")

**Sentence Boundary Rules:**
1. Sentence ends at: `.`, `!`, `?`
2. NOT a sentence end if:
   - Word is a known abbreviation (Dr., Mr., Mrs., Ms., Jr., Sr., vs., etc., inc., ltd., corp., co., st., ave., blvd., rd., apt., no., vol., pg., pp., fig., Jan., Feb., Mar., Apr., Jun., Jul., Aug., Sep., Sept., Oct., Nov., Dec., Mon., Tue., Wed., Thu., Fri., Sat., Sun.)
   - Word is an ellipsis (...)
   - Word is a single letter followed by period (initial), unless it's the last word
3. Handle quoted sentences: strip surrounding quotes/brackets before checking punctuation

**Paragraph Boundary Rules:**
1. Split text on one or more blank lines (\n\n+)
2. Normalize line endings (Windows \r\n, old Mac \r → Unix \n)
3. Last word of each paragraph marked with paragraph_end = true
4. For EPUB HTML, paragraph breaks are inserted at block-level tags (<p>, <li>, <blockquote>, <h1>-<h6>) and at consecutive <br> tags

### 6.3 Playback Engine

**State Machine:**
```
         ┌───────────────┐
         │    STOPPED    │
         │ (index = 0)   │
         └───────┬───────┘
                 │ play()
                 ▼
         ┌───────────────┐
    ┌───▶│    PLAYING    │◀───┐
    │    └───────┬───────┘    │
    │            │            │
    │  toggle()  │ toggle()   │
    │            ▼            │
    │    ┌───────────────┐    │
    └────│    PAUSED     │────┘
         └───────────────┘
```

**Timing:**
- Word delay = 60000 / WPM milliseconds
- If word.paragraph_end, add (paragraph_pause * 1000) milliseconds
- Use iOS Timer/DispatchSourceTimer for scheduling
- If a word is split into display chunks, divide the word delay evenly across chunks

**Progress Saving:**
- Trigger: Every paragraph end reached
- Also trigger: App backgrounding, returning to library, any pause event
- Save: current_word_index, date_last_opened
- Resume behavior: Start at beginning of paragraph containing saved index

**Auto-Pause Triggers:**
- App moves to background
- Screen locks
- Incoming phone call
- Control Center / Notification Center opens
- Any system overlay appears
- Playback does NOT auto-resume; user must tap to resume

**Completion Behavior:**
- When last word is displayed, playback stops
- Show completion overlay with "Finished!" message
- On dismissal: keep current_word_index at last word (100%), return to library
- Overlay is dismissed only via the "Return to Library" button

### 6.4 Progress Recovery

**On Book Open:**
1. Load book's saved current_word_index
2. If file hash changed (content modified), reset to 0
3. If current_word_index is the last word (completed), open at the last word
4. Otherwise, find start of paragraph containing that index:
   - Scan backward from index until paragraph_end = true or index = 0
   - Resume from the word after that paragraph end (or 0)

### 6.5 Search Implementation

**Algorithm:**
```
search(query: String, document: Document) -> [SearchResult]:
    results = []
    query_lower = query.lowercase()
    query_words = query.split(" ")
    MAX_RESULTS = 50

    for i in 0..<document.words.count:
        if results.count >= MAX_RESULTS:
            break

        // Check if query matches starting at word i
        // STRICT matching: each query word must match the document word exactly
        // (case-insensitive, punctuation included, no partial/substring matching)
        match = true
        for j in 0..<query_words.count:
            if i + j >= document.words.count:
                match = false
                break
            if document.words[i + j].text.lowercase() != query_words[j]:
                match = false
                break

        if match:
            results.append(SearchResult(
                word_index: i,
                context: getContext(document, i, 30 chars),
                percentage: i / document.total_words * 100
            ))

    return results
```

**Matching Rules:**
- Case-insensitive but otherwise strict (no stemming, no fuzzy matching)
- "walk" matches "Walk" but NOT "walking" or "walked"
- Multi-word queries must match exact sequence

**Result Limiting:**
- Maximum 50 results returned
- If more matches exist, UI shows "Showing first 50 results"

**Context Extraction:**
- Get ~5 words before and after match
- Reconstruct into readable string
- Highlight matched portion with bold

### 6.6 Storage

**Local Storage Structure:**
```
App Documents/
├── Books/
│   ├── {uuid}.txt          // Imported text files
│   ├── {uuid}.md           // Imported markdown files
│   └── {uuid}.epub         // Imported EPUB files
├── Covers/
│   └── {uuid}.jpg          // Extracted EPUB covers
└── library.json            // Book metadata + progress
```

**library.json Schema:**
```json
{
    "books": [
        {
            "id": "uuid-string",
            "title": "Book Title",
            "author": "Author Name",
            "filename": "original.epub",
            "file_type": "epub",
            "file_hash": "sha256-hash",
            "has_cover": true,
            "date_added": "2026-01-15T10:30:00Z",
            "date_last_opened": "2026-01-20T14:22:00Z",
            "total_words": 50000,
            "current_word_index": 12500,
            "has_toc": true
        }
    ],
    "settings": {
        "wpm": 300,
        "paragraph_pause": 1.0,
        "font_size": 48,
        "word_skip": 5,
        "library_sort": "recent"
    }
}
```

---

## 7. Error Handling

### 7.1 Import Errors

| Error | User Message | Recovery |
|-------|--------------|----------|
| File not found | "Could not access this file" | Dismiss alert |
| Unsupported format | "This file type is not supported. Please use .txt, .md, or .epub files." | Dismiss alert |
| DRM protected | "This EPUB is DRM protected and cannot be opened." | Dismiss alert |
| Corrupt EPUB | "This EPUB file appears to be damaged and cannot be opened." | Dismiss alert |
| Empty file | "This file is empty." | Dismiss alert |
| Encoding error | "Could not read this file. It may use an unsupported text encoding." | Dismiss alert |
| Duplicate file (by title + author) | "This book is already in your library." | Dismiss alert |

### 7.2 Runtime Errors

| Error | User Message | Recovery |
|-------|--------------|----------|
| Book file deleted | "This book is no longer available." | Remove from library, return to library screen |
| Storage full | "Not enough storage space to import this book." | Dismiss alert |

---

## 8. Accessibility

### 8.1 Minimum Requirements

- All buttons have accessibility labels
- Progress bar has accessibility value (percentage)
- Sliders have accessibility values
- Standard iOS focus navigation works

### 8.2 Not In Scope (v1)

- VoiceOver optimization for ORP display
- Dynamic Type support (app uses own font size setting)
- High contrast mode
- Reduce motion support

---

## 9. Performance Requirements

| Metric | Requirement |
|--------|-------------|
| Import time (100KB file) | < 1 second |
| Import time (10MB EPUB) | < 5 seconds |
| Playback timing accuracy | ± 10ms |
| App launch to library | < 1 second |
| Search (50K word book) | < 500ms |

---

## 10. Future Considerations (Out of Scope for v1)

These features are explicitly NOT included in v1 but may be considered later:

- iCloud sync
- iPad support
- Landscape orientation
- Apple Watch companion
- Siri Shortcuts
- Home screen widgets
- Bookmarks
- Multiple ORP color options
- Font family selection
- Text-to-speech hybrid mode
- Reading statistics/history
- Book organization (folders/tags)
- Importing from URLs
- Sharing progress
- Social features

---

## 11. Open Questions

1. **EPUB Cover Extraction:** Should we display EPUB covers in the library grid, or use a generic book icon for all books?
   - **Decision:** Extract and display if available, fall back to icon

2. **Large File Warning:** Should we warn users before importing very large files (>10MB)?
   - **Decision:** No warning, no size limit

3. **Reading Completion:** What happens when user finishes a book?
   - **Decision:** Show "Finished!" message with book title, then return to library. Keep progress at 100% (last word).

---

## 12. Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | January 2026 | Initial draft |
