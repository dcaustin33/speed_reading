# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Speed Reading is a Python Tkinter GUI application that displays text one word at a time using ORP (Optimal Recognition Point) highlighting. The ORP technique highlights a specific letter in each word where the eye naturally focuses, enabling faster reading speeds.

**Python 3.13+ required.** Package management via `uv`.

## Commands

```bash
# Activate virtual environment
source .venv/bin/activate

# Add dependencies
uv add <package>

# Add dev dependencies
uv add --dev <package>

# Run tests
uv run pytest

# Run the application (NOTE: __main__.py doesn't exist yet)
uv run python -m speed_reading
```

## Project Structure

```
speed_reading/
├── core/                    # Core reading engine
│   ├── orp.py              # ORP position calculation (lookup table based on word length)
│   ├── tokenizer.py        # Text → Document/Word objects with sentence/paragraph detection
│   └── reader.py           # Playback engine (play/pause/skip) using Tkinter timers
│
├── io/                      # File and configuration handling
│   ├── file_loader.py      # Loads .txt, .md, .epub files; DRM detection for EPUB
│   ├── config.py           # User settings persistence (WPM, font size, colors, recent files)
│   └── progress.py         # Reading progress tracking per file (word index, hash-based)
│
├── gui/                     # Tkinter GUI components
│   ├── display.py          # ORPDisplay widget - renders word with highlighted ORP letter
│   ├── controls.py         # PlaybackControls, SettingsSliders, ProgressBar widgets
│   └── settings.py         # SettingsDialog for font size, ORP color, word skip
│
└── utils/
    └── constants.py        # Theme colors, default values, window dimensions, ORP lookup table

tests/
├── test_orp.py             # ORP calculation tests
├── test_tokenizer.py       # Tokenization and sentence boundary tests
├── test_reader.py          # Reader navigation and playback tests
└── test_file_loader.py     # File loading and markdown stripping tests
```

## Key Components

### ORP (Optimal Recognition Point)
- Calculated in `core/orp.py` using a lookup table in `utils/constants.py`
- Position varies by word length: 1 char → index 0, 2-5 chars → index 1, 6-9 → index 2, etc.

### Tokenizer (`core/tokenizer.py`)
- Produces `Document` containing list of `Word` dataclasses
- Each `Word` has: `text`, `orp_index`, `paragraph_end`, `sentence_end`
- Handles abbreviations (Dr., Mr., etc.) to avoid false sentence breaks

### Reader (`core/reader.py`)
- Manages playback state: WPM (100-800), paragraph pause (0.25-3.0s), word skip amount
- Navigation: skip words, next/prev sentence, next/prev paragraph
- Requires Tkinter root for timer scheduling (`set_root()`)

### File Loading (`io/file_loader.py`)
- Supports: `.txt`, `.md` (strips markdown), `.epub` (extracts text, checks for DRM)
- Returns `(content, sha256_hash)` tuple for progress tracking

### Configuration
- Stored at `~/.config/speed_reading/` (Linux/macOS) or `%APPDATA%/speed_reading/` (Windows)
- `settings.json`: WPM, pause, font_size, orp_color, word_skip, recent_files
- `progress.json`: Per-file reading position keyed by file path and content hash

## Dependencies

- `ebooklib>=0.18` - EPUB parsing
- `pytest>=9.0.2` (dev) - Testing

## Incomplete/Missing

- `__main__.py` entry point (referenced in pyproject.toml but doesn't exist)
- Main application window that ties GUI components together

## Code Style

- Keep code clean, concise, and reusable
- Comments should provide insight, not explain what the code does
- Type hints used throughout (Python 3.10+ style: `list[X]`, `X | None`)
- Dataclasses for data structures (`Word`, `Document`, `Config`, `FileProgress`)
