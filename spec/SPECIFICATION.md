# Speed Reading App Specification

## Overview

A Python desktop application that enables speed reading using the ORP (Optimal Recognition Point) technique with visual highlighting. Words are displayed one at a time with a single letter highlighted in red at the optimal recognition point to help the brain process text faster.

## Technical Stack

- **Language:** Python 3.13+
- **Package Manager:** uv
- **GUI Framework:** Tkinter (built-in)
- **File Formats:** Plain text, Markdown, EPUB
- **Additional Libraries:**
  - `ebooklib` - EPUB file parsing
  - `markdown` or `beautifulsoup4` - Markdown/HTML stripping

---

## Core Features

### 1. ORP Display Engine

The Optimal Recognition Point is the letter position where the eye naturally focuses when reading a word. For most words, this is slightly left of center.

**ORP Calculation:**
| Word Length | ORP Position (0-indexed) |
|-------------|--------------------------|
| 1           | 0                        |
| 2-5         | 1                        |
| 6-9         | 2                        |
| 10-13       | 3                        |
| 14+         | 4                        |

**Display Format:**
- Word displayed centered on screen
- ORP letter highlighted in **red**
- All other letters in default text color (light gray/white)
- Fixed-width font for consistent positioning

**Example:**
```
    r e a d i n g
        ^
       (red)
```

### 2. Configurable Reading Speed

- **Range:** 100 - 800 words per minute (WPM)
- **Default:** 300 WPM
- **Adjustment:** Real-time slider or +/- buttons
- **Calculation:** `delay_ms = 60000 / WPM`

### 3. Paragraph Pause

- Brief pause inserted after paragraph endings
- **Configurable duration:** 0.25s - 3.0s
- **Default:** 1.0 second
- **Detection:** Double newline (`\n\n`) in source text

### 4. Word Timing

- **Fixed timing:** All words displayed for the same duration regardless of length
- Timing calculated from WPM setting

---

## User Interface

### Main Window Layout

```
+----------------------------------------------------------+
|  Speed Reading                               [_] [□] [X]  |
+----------------------------------------------------------+
|                                                          |
|                                                          |
|                     r e a d i n g                        |
|                         ^                                |
|                       (red)                              |
|                                                          |
|                                                          |
+----------------------------------------------------------+
|  [|◄] [◄◄] [◄]    [ ▶ / ❚❚ ]    [►] [►►] [►|]           |
+----------------------------------------------------------+
|  WPM: [====●======] 300    Pause: [===●====] 1.0s       |
+----------------------------------------------------------+
|  ▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░  Word 127/892  |  3:42    |
+----------------------------------------------------------+
|  [Open File]  [Settings]                    [Recent ▼]   |
+----------------------------------------------------------+
```

### Control Buttons

| Button | Function | Keyboard Shortcut |
|--------|----------|-------------------|
| `▶ / ❚❚` | Play / Pause | `Space` |
| `◄` | Rewind 5 words | `Left Arrow` |
| `►` | Skip 5 words | `Right Arrow` |
| `◄◄` | Previous sentence | `Ctrl + Left` |
| `►►` | Next sentence | `Ctrl + Right` |
| `\|◄` | Previous paragraph | `Shift + Left` |
| `►\|` | Next paragraph | `Shift + Right` |
| Restart | Go to beginning | `R` |
| Open File | File dialog | `Ctrl + O` |

### Additional Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Up Arrow` | Increase WPM by 25 |
| `Down Arrow` | Decrease WPM by 25 |
| `Escape` | Stop and reset |
| `Q` | Quit application |

### Theme: Dark Mode

| Element | Color |
|---------|-------|
| Background | `#1a1a1a` (near black) |
| Text (default) | `#e0e0e0` (light gray) |
| ORP Highlight | `#ff3333` (red) |
| Controls background | `#2d2d2d` (dark gray) |
| Progress bar filled | `#4a90d9` (blue) |
| Progress bar empty | `#404040` (gray) |

### Font

- **Display font:** Monospace (e.g., `Consolas`, `Monaco`, `Courier New`)
- **Default size:** 48px for word display
- **Configurable:** 24px - 96px range

---

## Status Display

### Progress Bar
- Visual bar showing percentage through document
- Updates in real-time during playback

### Statistics Panel
- **Current word / Total words:** `Word 127/892`
- **Time remaining:** Calculated from remaining words and current WPM
- **Format:** `MM:SS` or `H:MM:SS` for longer texts

---

## File Handling

### Supported Formats

1. **Plain Text (`.txt`)**
   - Direct reading, UTF-8 encoding assumed
   - Fallback to system encoding if UTF-8 fails

2. **Markdown (`.md`)**
   - Strip all formatting (headers, bold, italic, links, etc.)
   - Preserve paragraph structure
   - Remove code blocks

3. **EPUB (`.epub`)** *(DRM-free only)*
   - Extract text content from all chapters
   - Strip HTML tags
   - Preserve paragraph structure
   - Handle chapter boundaries as extended pauses
   - **DRM Detection:** Check for encryption.xml in EPUB container
   - **DRM-protected files are not supported** (see Error Handling)

### File Loading

- **File Dialog:** Native OS file picker via Tkinter
- **Command Line:** `python -m speed_reading [filepath]`
- **Drag & Drop:** Optional enhancement if time permits

### Recent Files

- Store last 10 opened files
- Display in dropdown menu
- Persist across sessions

---

## Progress Persistence

### Saved Data (per file)

```json
{
  "file_path": "/path/to/book.txt",
  "file_hash": "sha256...",
  "word_index": 127,
  "total_words": 892,
  "last_opened": "2026-01-19T14:30:00Z"
}
```

### Storage Location

- **macOS:** `~/.config/speed_reading/progress.json`
- **Windows:** `%APPDATA%/speed_reading/progress.json`
- **Linux:** `~/.config/speed_reading/progress.json`

### Resume Behavior

- On file open, check for saved progress
- Prompt user: "Resume from word 127?" or "Start from beginning"

---

## Settings

### Configurable Options

| Setting | Range | Default |
|---------|-------|---------|
| WPM | 100-800 | 300 |
| Paragraph pause (seconds) | 0.25-3.0 | 1.0 |
| Font size (px) | 24-96 | 48 |
| ORP highlight color | Any hex | `#ff3333` |
| Word skip amount | 1-20 | 5 |

### Settings Storage

- **Location:** Same config directory as progress
- **File:** `settings.json`
- **Format:**

```json
{
  "wpm": 300,
  "paragraph_pause": 1.0,
  "font_size": 48,
  "orp_color": "#ff3333",
  "word_skip": 5,
  "recent_files": [
    "/path/to/file1.txt",
    "/path/to/file2.epub"
  ]
}
```

### In-App Settings

- Sliders for WPM and paragraph pause (real-time adjustment)
- Settings button opens modal with all options
- Changes persist immediately to config file

---

## Text Processing Pipeline

### 1. File Loading
```
Read file → Detect format → Parse/strip formatting → Raw text
```

### 2. Tokenization
```
Raw text → Split into paragraphs → Split into sentences → Split into words
```

### 3. Data Structure
```python
@dataclass
class Word:
    text: str
    orp_index: int
    paragraph_end: bool
    sentence_end: bool

@dataclass
class Document:
    words: list[Word]
    total_words: int
    file_path: str
    file_hash: str
```

### 4. Sentence Detection

- End markers: `.` `!` `?`
- Handle abbreviations: `Mr.` `Dr.` `etc.` (don't split)
- Handle ellipsis: `...` (don't split mid-ellipsis)

### 5. Paragraph Detection

- Double newline: `\n\n`
- Multiple blank lines collapsed to single paragraph break

### 6. EPUB DRM Detection

EPUB files are ZIP archives. DRM-protected EPUBs contain an `encryption.xml` file in the `META-INF` directory that specifies encrypted content.

**Detection Algorithm:**
```python
def has_drm(epub_path: str) -> bool:
    """Check if EPUB file contains DRM encryption."""
    with zipfile.ZipFile(epub_path, 'r') as zf:
        if 'META-INF/encryption.xml' in zf.namelist():
            encryption_content = zf.read('META-INF/encryption.xml').decode('utf-8')
            # Check for Adobe DRM or other encryption schemes
            drm_indicators = [
                'http://ns.adobe.com/adept',
                'http://www.w3.org/2001/04/xmlenc',
                'EncryptedData',
            ]
            return any(indicator in encryption_content for indicator in drm_indicators)
    return False
```

**Note:** Some EPUBs have `encryption.xml` for font obfuscation only (not DRM). The detection should look for actual content encryption indicators, not just the presence of the file.

---

## Module Structure

```
speed_reading/
├── __init__.py
├── __main__.py          # Entry point
├── app.py               # Main application class
├── gui/
│   ├── __init__.py
│   ├── main_window.py   # Main Tkinter window
│   ├── display.py       # ORP word display widget
│   ├── controls.py      # Playback controls
│   └── settings.py      # Settings dialog
├── core/
│   ├── __init__.py
│   ├── reader.py        # Reading engine / timing
│   ├── orp.py           # ORP calculation
│   └── tokenizer.py     # Text processing
├── io/
│   ├── __init__.py
│   ├── file_loader.py   # File format handling
│   ├── config.py        # Settings management
│   └── progress.py      # Progress persistence
└── utils/
    ├── __init__.py
    └── constants.py     # Colors, defaults, etc.
```

---

## Error Handling

### File Errors
- File not found: Display error dialog, return to file selection
- Encoding error: Try alternative encodings, warn user if content may be corrupted
- EPUB parse error: Display specific error, suggest alternative format
- **EPUB DRM detected:** Display error dialog with message:
  > "This EPUB file is DRM-protected and cannot be opened. DRM (Digital Rights Management) encryption prevents third-party applications from reading the content. Please use a DRM-free version of this file, or export from your ebook provider if they allow it."

### Runtime Errors
- Empty file: Display message, disable playback
- Invalid settings: Reset to defaults, notify user

---

## Future Enhancements (Out of Scope)

These are not part of the initial implementation but noted for potential future work:

- Light mode theme toggle
- PDF support
- URL/webpage support
- Practice mode with comprehension quizzes
- Statistics tracking (words read per session, streak days)
- Multiple highlight color themes
- Text-to-speech integration
- Cloud sync for progress

---

## Dependencies

```toml
[project]
dependencies = [
    "ebooklib",        # EPUB parsing
]

[project.optional-dependencies]
dev = [
    "pytest",
    "mypy",
]
```

Note: Tkinter is included with Python standard library.

---

## Launch Commands

```bash
# Run with file dialog
uv run python -m speed_reading

# Run with specific file
uv run python -m speed_reading /path/to/book.txt

# Run with EPUB
uv run python -m speed_reading /path/to/book.epub
```
