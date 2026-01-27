import tkinter as tk
from tkinter import filedialog, messagebox
from pathlib import Path
from typing import Callable

from speed_reading.core.reader import Reader
from speed_reading.core.tokenizer import tokenize_text, Word, Document, ChapterMarker
from speed_reading.io.file_loader import load_file_with_chapters, DRMError, FileLoadError
from speed_reading.io.config import Config
from speed_reading.io.progress import ProgressManager
from speed_reading.gui.display import ORPDisplay
from speed_reading.gui.controls import PlaybackControls, SettingsSliders, ProgressBar
from speed_reading.gui.settings import SettingsDialog
from speed_reading.gui.search_dialog import SearchDialog
from speed_reading.utils.constants import (
    BG_COLOR,
    TEXT_COLOR,
    CONTROLS_BG,
    WINDOW_WIDTH,
    WINDOW_HEIGHT,
    WINDOW_MIN_WIDTH,
    WINDOW_MIN_HEIGHT,
    WPM_STEP,
)

# Enhanced colors
ACCENT_COLOR = "#4a90d9"
BUTTON_NORMAL = "#3a3a3a"
BUTTON_HOVER = "#4a4a4a"
SUBTLE_TEXT = "#888888"
SEPARATOR_COLOR = "#333333"


class TextButton(tk.Canvas):
    """Custom styled text button."""

    def __init__(
        self,
        parent,
        text: str,
        command: Callable[[], None] | None = None,
        width: int = 100,
        height: int = 36,
        **kwargs,
    ):
        super().__init__(
            parent,
            width=width,
            height=height,
            bg=CONTROLS_BG,
            highlightthickness=0,
            **kwargs,
        )

        self._command = command
        self._text = text
        self._width = width
        self._height = height
        self._is_hovered = False
        self._enabled = True

        self._draw()

        self.bind("<Enter>", self._on_enter)
        self.bind("<Leave>", self._on_leave)
        self.bind("<ButtonPress-1>", self._on_press)
        self.bind("<ButtonRelease-1>", self._on_release)

    def _draw(self):
        self.delete("all")
        if self._enabled:
            bg_color = BUTTON_HOVER if self._is_hovered else BUTTON_NORMAL
            fg_color = TEXT_COLOR if self._is_hovered else SUBTLE_TEXT
        else:
            bg_color = "#2a2a2a"
            fg_color = "#555555"

        # Draw rounded rectangle
        r = 6
        x0, y0 = 2, 2
        x1, y1 = self._width - 2, self._height - 2

        self.create_arc(x0, y0, x0 + 2 * r, y0 + 2 * r, start=90, extent=90, fill=bg_color, outline="")
        self.create_arc(x1 - 2 * r, y0, x1, y0 + 2 * r, start=0, extent=90, fill=bg_color, outline="")
        self.create_arc(x0, y1 - 2 * r, x0 + 2 * r, y1, start=180, extent=90, fill=bg_color, outline="")
        self.create_arc(x1 - 2 * r, y1 - 2 * r, x1, y1, start=270, extent=90, fill=bg_color, outline="")
        self.create_rectangle(x0 + r, y0, x1 - r, y1, fill=bg_color, outline="")
        self.create_rectangle(x0, y0 + r, x1, y1 - r, fill=bg_color, outline="")

        # Draw text
        self.create_text(
            self._width // 2,
            self._height // 2,
            text=self._text,
            font=("SF Pro Display", 12),
            fill=fg_color,
        )

    def _on_enter(self, event):
        if self._enabled:
            self._is_hovered = True
            self._draw()

    def _on_leave(self, event):
        self._is_hovered = False
        self._draw()

    def _on_press(self, event):
        pass

    def _on_release(self, event):
        if self._is_hovered and self._command and self._enabled:
            self._command()

    def set_enabled(self, enabled: bool):
        self._enabled = enabled
        self._draw()

    def set_text(self, text: str):
        self._text = text
        self._draw()


class MainWindow:
    """Main application window."""

    def __init__(self, initial_file: str | None = None):
        self.root = tk.Tk()
        self.root.title("Speed Reading")
        self.root.configure(bg=BG_COLOR)
        self.root.geometry(f"{WINDOW_WIDTH}x{WINDOW_HEIGHT}")
        self.root.minsize(WINDOW_MIN_WIDTH, WINDOW_MIN_HEIGHT)

        # Load config and progress
        self.config = Config.load()
        self.progress_manager = ProgressManager()

        # State
        self.reader: Reader | None = None
        self.document: Document | None = None
        self.current_file_path: str | None = None
        self.current_file_hash: str | None = None

        # Build UI
        self._create_widgets()
        self._bind_keys()

        # Load initial file if provided
        if initial_file:
            self.root.after(100, lambda: self._load_file(initial_file))

    def _create_separator(self, parent):
        """Create a subtle horizontal separator."""
        sep = tk.Canvas(parent, height=1, bg=CONTROLS_BG, highlightthickness=0)
        sep.pack(fill=tk.X, padx=30)
        sep.create_line(0, 0, 2000, 0, fill=SEPARATOR_COLOR)
        return sep

    def _create_widgets(self):
        # Main display area
        self.display = ORPDisplay(self.root)
        self.display.pack(fill=tk.BOTH, expand=True, padx=20, pady=(30, 20))
        self.display.set_font_size(self.config.font_size)
        self.display.set_orp_color(self.config.orp_color)

        # Controls container with dark background
        controls_container = tk.Frame(self.root, bg=CONTROLS_BG)
        controls_container.pack(fill=tk.X, side=tk.BOTTOM)

        # Top separator
        self._create_separator(controls_container)

        # Playback controls
        self.playback = PlaybackControls(
            controls_container,
            on_play_pause=self._toggle_playback,
            on_prev_para=self._prev_paragraph,
            on_prev_sent=self._prev_sentence,
            on_rewind=self._rewind,
            on_forward=self._forward,
            on_next_sent=self._next_sentence,
            on_next_para=self._next_paragraph,
        )
        self.playback.pack(fill=tk.X)

        # Settings sliders
        self.sliders = SettingsSliders(
            controls_container,
            on_wpm_change=self._on_wpm_change,
            on_pause_change=self._on_pause_change,
        )
        self.sliders.pack(fill=tk.X)
        self.sliders.set_wpm(self.config.wpm)
        self.sliders.set_pause(self.config.paragraph_pause)

        # Progress bar
        self.progress_bar = ProgressBar(controls_container)
        self.progress_bar.pack(fill=tk.X)

        # Separator before bottom buttons
        self._create_separator(controls_container)

        # Bottom buttons
        btn_frame = tk.Frame(controls_container, bg=CONTROLS_BG)
        btn_frame.pack(fill=tk.X, pady=12, padx=20)

        # Left side buttons
        left_btns = tk.Frame(btn_frame, bg=CONTROLS_BG)
        left_btns.pack(side=tk.LEFT)

        self.open_btn = TextButton(
            left_btns, "Open File", command=self._open_file_dialog, width=100
        )
        self.open_btn.pack(side=tk.LEFT, padx=(0, 8))

        self.settings_btn = TextButton(
            left_btns, "Settings", command=self._open_settings, width=90
        )
        self.settings_btn.pack(side=tk.LEFT, padx=(0, 8))

        # Chapters button (disabled until EPUB loaded)
        self.chapters_btn = TextButton(
            left_btns, "Chapters ▾", command=self._show_chapters_menu, width=110
        )
        self.chapters_btn.pack(side=tk.LEFT, padx=(0, 8))
        self.chapters_btn.set_enabled(False)

        # Find button (disabled until file loaded)
        self.find_btn = TextButton(
            left_btns, "Find", command=self._open_search, width=70
        )
        self.find_btn.pack(side=tk.LEFT)
        self.find_btn.set_enabled(False)

        # Create chapters menu
        self.chapters_menu = tk.Menu(
            self.root,
            tearoff=0,
            bg="#2a2a2a",
            fg=TEXT_COLOR,
            activebackground=ACCENT_COLOR,
            activeforeground="#ffffff",
            font=("SF Pro Display", 11),
            borderwidth=0,
        )

        # Right side - Recent files dropdown
        right_btns = tk.Frame(btn_frame, bg=CONTROLS_BG)
        right_btns.pack(side=tk.RIGHT)

        # Custom recent button that opens a menu
        self.recent_btn = TextButton(
            right_btns, "Recent ▾", command=self._show_recent_menu, width=100
        )
        self.recent_btn.pack(side=tk.RIGHT)

        # Create the recent menu (hidden by default)
        self.recent_menu = tk.Menu(
            self.root,
            tearoff=0,
            bg="#2a2a2a",
            fg=TEXT_COLOR,
            activebackground=ACCENT_COLOR,
            activeforeground="#ffffff",
            font=("SF Pro Display", 11),
            borderwidth=0,
        )
        self._update_recent_menu()

    def _show_chapters_menu(self):
        """Show the chapters menu."""
        if not self.document or not self.document.chapters:
            return
        x = self.chapters_btn.winfo_rootx()
        y = self.chapters_btn.winfo_rooty() - min(len(self.document.chapters), 15) * 24 - 5
        self.chapters_menu.post(x, y)

    def _update_chapters_menu(self):
        """Update the chapters menu with current document chapters."""
        self.chapters_menu.delete(0, tk.END)

        if not self.document or not self.document.chapters:
            self.chapters_btn.set_enabled(False)
            return

        self.chapters_btn.set_enabled(True)

        for chapter in self.document.chapters:
            # Add indentation for nested chapters
            indent = "    " * chapter.level
            label = f"{indent}{chapter.title}"
            # Truncate long titles
            if len(label) > 50:
                label = label[:47] + "..."

            self.chapters_menu.add_command(
                label=label,
                command=lambda idx=chapter.word_index: self._jump_to_chapter(idx),
            )

    def _jump_to_chapter(self, word_index: int):
        """Jump to a specific chapter by word index."""
        if self.reader:
            self.reader.go_to_word(word_index)
            self._update_progress()

    def _show_recent_menu(self):
        """Show the recent files menu below the button."""
        if not self.config.recent_files:
            return
        x = self.recent_btn.winfo_rootx()
        y = self.recent_btn.winfo_rooty() - len(self.config.recent_files) * 24 - 5
        self.recent_menu.post(x, y)

    def _bind_keys(self):
        self.root.bind("<space>", lambda e: self._toggle_playback())
        self.root.bind("<Left>", lambda e: self._rewind())
        self.root.bind("<Right>", lambda e: self._forward())
        self.root.bind("<Control-Left>", lambda e: self._prev_sentence())
        self.root.bind("<Control-Right>", lambda e: self._next_sentence())
        self.root.bind("<Shift-Left>", lambda e: self._prev_paragraph())
        self.root.bind("<Shift-Right>", lambda e: self._next_paragraph())
        self.root.bind("<Up>", lambda e: self._increase_wpm())
        self.root.bind("<Down>", lambda e: self._decrease_wpm())
        self.root.bind("<Control-o>", lambda e: self._open_file_dialog())
        self.root.bind("<r>", lambda e: self._restart())
        self.root.bind("<Escape>", lambda e: self._stop())
        self.root.bind("<q>", lambda e: self._quit())
        # Chapter navigation shortcuts
        self.root.bind("<bracketleft>", lambda e: self._prev_chapter())
        self.root.bind("<bracketright>", lambda e: self._next_chapter())
        # Search
        self.root.bind("<Control-f>", lambda e: self._open_search())

    def _prev_chapter(self):
        """Jump to previous chapter."""
        if not self.reader or not self.document or not self.document.chapters:
            return

        current_idx = self.reader.current_index
        # Find the chapter we're currently in or just passed
        prev_chapter_idx = 0
        for chapter in self.document.chapters:
            if chapter.word_index >= current_idx:
                break
            prev_chapter_idx = chapter.word_index

        # If we're at the start of current chapter, go to previous
        for i, chapter in enumerate(self.document.chapters):
            if chapter.word_index == current_idx and i > 0:
                prev_chapter_idx = self.document.chapters[i - 1].word_index
                break

        self.reader.go_to_word(prev_chapter_idx)
        self._update_progress()

    def _next_chapter(self):
        """Jump to next chapter."""
        if not self.reader or not self.document or not self.document.chapters:
            return

        current_idx = self.reader.current_index
        # Find the next chapter after current position
        for chapter in self.document.chapters:
            if chapter.word_index > current_idx:
                self.reader.go_to_word(chapter.word_index)
                self._update_progress()
                return

    def _update_recent_menu(self):
        self.recent_menu.delete(0, tk.END)
        for path in self.config.recent_files:
            name = Path(path).name
            self.recent_menu.add_command(
                label=name,
                command=lambda p=path: self._load_file(p),
            )

    def _open_file_dialog(self):
        filepath = filedialog.askopenfilename(
            title="Open File",
            filetypes=[
                ("Supported files", "*.txt *.md *.epub"),
                ("Text files", "*.txt"),
                ("Markdown files", "*.md"),
                ("EPUB files", "*.epub"),
                ("All files", "*.*"),
            ],
        )
        if filepath:
            self._load_file(filepath)

    def _load_file(self, filepath: str):
        try:
            loaded = load_file_with_chapters(filepath)
        except FileNotFoundError:
            messagebox.showerror("Error", f"File not found: {filepath}")
            return
        except DRMError as e:
            messagebox.showerror("DRM Protected", str(e))
            return
        except FileLoadError as e:
            messagebox.showerror("Error", str(e))
            return

        # Tokenize with chapter info
        self.document = tokenize_text(
            loaded.content, filepath, loaded.file_hash, loaded.chapters
        )
        self.current_file_path = filepath
        self.current_file_hash = loaded.file_hash

        if self.document.total_words == 0:
            messagebox.showwarning("Empty File", "The file contains no readable text.")
            return

        # Create reader
        self.reader = Reader(
            self.document,
            on_word=self._on_word,
            on_complete=self._on_complete,
        )
        self.reader.set_root(self.root)
        self.reader.wpm = self.config.wpm
        self.reader.paragraph_pause = self.config.paragraph_pause
        self.reader.word_skip = self.config.word_skip

        # Check for saved progress
        saved_index = self.progress_manager.get_progress(filepath, loaded.file_hash)
        if saved_index is not None and saved_index > 0:
            resume = messagebox.askyesno(
                "Resume Reading",
                f"Resume from word {saved_index + 1} of {self.document.total_words}?",
            )
            if resume:
                self.reader.go_to_word(saved_index)
            else:
                self.reader.go_to_word(0)
        else:
            self.reader.go_to_word(0)

        # Update UI
        self.root.title(f"Speed Reading - {Path(filepath).name}")
        self.config.add_recent_file(filepath)
        self._update_recent_menu()
        self._update_chapters_menu()
        self._update_progress()
        self.find_btn.set_enabled(True)

    def _on_word(self, word: Word, index: int):
        self.display.display_word(word)
        self._update_progress()

        # Save progress periodically (every 50 words)
        if index % 50 == 0 and self.current_file_path and self.current_file_hash:
            self.progress_manager.save_progress(
                self.current_file_path,
                self.current_file_hash,
                index,
                self.document.total_words,
            )

    def _on_complete(self):
        self.playback.set_playing(False)
        messagebox.showinfo("Complete", "You've finished reading!")

        # Clear saved progress
        if self.current_file_path:
            self.progress_manager.clear_progress(self.current_file_path)

    def _update_progress(self):
        if not self.reader:
            return

        self.progress_bar.set_progress(
            self.reader.progress,
            self.reader.current_index + 1,
            self.document.total_words,
            self.reader.time_remaining_seconds,
        )

    def _toggle_playback(self):
        if not self.reader:
            return
        self.reader.toggle()
        self.playback.set_playing(self.reader.is_playing)

    def _rewind(self):
        if self.reader:
            self.reader.skip_backward()

    def _forward(self):
        if self.reader:
            self.reader.skip_forward()

    def _prev_sentence(self):
        if self.reader:
            self.reader.prev_sentence()

    def _next_sentence(self):
        if self.reader:
            self.reader.next_sentence()

    def _prev_paragraph(self):
        if self.reader:
            self.reader.prev_paragraph()

    def _next_paragraph(self):
        if self.reader:
            self.reader.next_paragraph()

    def _increase_wpm(self):
        if self.reader:
            new_wpm = self.reader.wpm + WPM_STEP
            self.reader.wpm = new_wpm
            self.sliders.set_wpm(self.reader.wpm)
            self.config.wpm = self.reader.wpm
            self.config.save()

    def _decrease_wpm(self):
        if self.reader:
            new_wpm = self.reader.wpm - WPM_STEP
            self.reader.wpm = new_wpm
            self.sliders.set_wpm(self.reader.wpm)
            self.config.wpm = self.reader.wpm
            self.config.save()

    def _on_wpm_change(self, wpm: int):
        if self.reader:
            self.reader.wpm = wpm
        self.config.wpm = wpm
        self.config.save()
        self._update_progress()

    def _on_pause_change(self, pause: float):
        if self.reader:
            self.reader.paragraph_pause = pause
        self.config.paragraph_pause = pause
        self.config.save()

    def _restart(self):
        if self.reader:
            self.reader.stop()
            self.reader.go_to_word(0)
            self.playback.set_playing(False)

    def _stop(self):
        if self.reader:
            self.reader.pause()
            self.playback.set_playing(False)

    def _open_settings(self):
        SettingsDialog(self.root, self.config, on_save=self._on_settings_save)

    def _open_search(self):
        """Open the search dialog."""
        if not self.reader:
            return
        SearchDialog(
            self.root,
            on_select=self._on_search_select,
            search_fn=self.reader.find_phrase,
        )

    def _on_search_select(self, word_index: int):
        """Handle selection from search results."""
        if self.reader:
            self.reader.go_to_word(word_index)
            self._update_progress()

    def _on_settings_save(self, config: Config):
        self.display.set_font_size(config.font_size)
        self.display.set_orp_color(config.orp_color)
        if self.reader:
            self.reader.word_skip = config.word_skip

    def _quit(self):
        # Save progress before quitting
        if self.reader and self.current_file_path and self.current_file_hash:
            self.progress_manager.save_progress(
                self.current_file_path,
                self.current_file_hash,
                self.reader.current_index,
                self.document.total_words,
            )
        self.root.quit()

    def run(self):
        self.root.mainloop()
