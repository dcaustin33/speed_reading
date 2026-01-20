import tkinter as tk
from tkinter import font as tkfont

from speed_reading.core.tokenizer import Word
from speed_reading.utils.constants import (
    BG_COLOR,
    TEXT_COLOR,
    ORP_COLOR,
    FONT_FAMILY,
    FONT_SIZE_DEFAULT,
)


class ORPDisplay(tk.Frame):
    """Widget that displays a word with ORP highlighting."""

    def __init__(self, parent, **kwargs):
        super().__init__(parent, bg=BG_COLOR, **kwargs)

        self._font_size = FONT_SIZE_DEFAULT
        self._orp_color = ORP_COLOR
        self._current_word: Word | None = None

        # Create canvas for precise text positioning
        self.canvas = tk.Canvas(
            self,
            bg=BG_COLOR,
            highlightthickness=0,
            width=600,
            height=150,
        )
        self.canvas.pack(expand=True, fill=tk.BOTH)

        # Bind resize event
        self.canvas.bind("<Configure>", self._on_resize)

    def _get_font(self) -> tkfont.Font:
        return tkfont.Font(family=FONT_FAMILY, size=self._font_size)

    def _on_resize(self, event):
        if self._current_word:
            self.display_word(self._current_word)

    def display_word(self, word: Word):
        """Display a word with ORP highlighting."""
        self._current_word = word
        self.canvas.delete("all")

        if not word or not word.text:
            return

        text = word.text
        orp_idx = word.orp_index

        # Ensure ORP index is valid
        if orp_idx >= len(text):
            orp_idx = len(text) // 2

        font = self._get_font()
        canvas_width = self.canvas.winfo_width()
        canvas_height = self.canvas.winfo_height()

        # Calculate character widths for precise positioning
        char_widths = [font.measure(c) for c in text]
        total_width = sum(char_widths)

        # Calculate position to center the ORP character
        orp_char_center = sum(char_widths[:orp_idx]) + char_widths[orp_idx] / 2
        start_x = (canvas_width / 2) - orp_char_center

        y = canvas_height / 2

        # Draw each character
        current_x = start_x
        for i, char in enumerate(text):
            color = self._orp_color if i == orp_idx else TEXT_COLOR
            self.canvas.create_text(
                current_x,
                y,
                text=char,
                font=font,
                fill=color,
                anchor="w",
            )
            current_x += char_widths[i]

        # Draw ORP indicator line below the highlighted letter
        orp_x = start_x + sum(char_widths[:orp_idx]) + char_widths[orp_idx] / 2
        line_y = y + self._font_size // 2 + 5
        line_half_width = char_widths[orp_idx] // 2
        self.canvas.create_line(
            orp_x - line_half_width,
            line_y,
            orp_x + line_half_width,
            line_y,
            fill=self._orp_color,
            width=2,
        )

    def clear(self):
        """Clear the display."""
        self._current_word = None
        self.canvas.delete("all")

    def set_font_size(self, size: int):
        """Update the font size."""
        self._font_size = size
        if self._current_word:
            self.display_word(self._current_word)

    def set_orp_color(self, color: str):
        """Update the ORP highlight color."""
        self._orp_color = color
        if self._current_word:
            self.display_word(self._current_word)
