import tkinter as tk
from tkinter import colorchooser
from typing import Callable

from speed_reading.io.config import Config
from speed_reading.utils.constants import (
    BG_COLOR,
    TEXT_COLOR,
    CONTROLS_BG,
    FONT_SIZE_MIN,
    FONT_SIZE_MAX,
)

# Enhanced colors
ACCENT_COLOR = "#4a90d9"
BUTTON_NORMAL = "#3a3a3a"
BUTTON_HOVER = "#4a4a4a"
SUBTLE_TEXT = "#888888"
INPUT_BG = "#2a2a2a"


class ModernSlider(tk.Canvas):
    """Custom styled slider for settings."""

    def __init__(
        self,
        parent,
        min_val: float,
        max_val: float,
        initial: float,
        on_change: Callable[[float], None] | None = None,
        width: int = 200,
        resolution: float = 1.0,
        **kwargs,
    ):
        super().__init__(
            parent,
            width=width,
            height=24,
            bg=BG_COLOR,
            highlightthickness=0,
            **kwargs,
        )

        self._min = min_val
        self._max = max_val
        self._value = initial
        self._on_change = on_change
        self._resolution = resolution
        self._width = width
        self._dragging = False

        self._track_y = 12
        self._track_start = 8
        self._track_end = width - 8

        self._draw()

        self.bind("<ButtonPress-1>", self._on_press)
        self.bind("<B1-Motion>", self._on_drag)
        self.bind("<ButtonRelease-1>", self._on_release)

    def _value_to_x(self, value: float) -> float:
        ratio = (value - self._min) / (self._max - self._min)
        return self._track_start + ratio * (self._track_end - self._track_start)

    def _x_to_value(self, x: float) -> float:
        ratio = (x - self._track_start) / (self._track_end - self._track_start)
        ratio = max(0, min(1, ratio))
        value = self._min + ratio * (self._max - self._min)
        if self._resolution >= 1:
            value = round(value / self._resolution) * self._resolution
        return max(self._min, min(self._max, value))

    def _draw(self):
        self.delete("all")

        # Draw track background
        self.create_line(
            self._track_start, self._track_y,
            self._track_end, self._track_y,
            fill="#404040", width=4, capstyle="round",
        )

        # Draw filled track
        thumb_x = self._value_to_x(self._value)
        self.create_line(
            self._track_start, self._track_y,
            thumb_x, self._track_y,
            fill=ACCENT_COLOR, width=4, capstyle="round",
        )

        # Draw thumb
        self.create_oval(
            thumb_x - 6, self._track_y - 6,
            thumb_x + 6, self._track_y + 6,
            fill=TEXT_COLOR, outline="",
        )

    def _on_press(self, event):
        self._dragging = True
        self._update_value(event.x)

    def _on_drag(self, event):
        if self._dragging:
            self._update_value(event.x)

    def _on_release(self, event):
        self._dragging = False

    def _update_value(self, x: float):
        new_value = self._x_to_value(x)
        if new_value != self._value:
            self._value = new_value
            self._draw()
            if self._on_change:
                self._on_change(self._value)

    def set_value(self, value: float):
        self._value = max(self._min, min(self._max, value))
        self._draw()

    def get_value(self) -> float:
        return self._value


class SettingsDialog(tk.Toplevel):
    """Settings dialog window."""

    def __init__(
        self,
        parent,
        config: Config,
        on_save: Callable[[Config], None] | None = None,
    ):
        super().__init__(parent)

        self.title("Settings")
        self.config_data = config
        self._on_save = on_save

        # Window setup
        self.configure(bg=BG_COLOR)
        self.geometry("380x340")
        self.resizable(False, False)
        self.transient(parent)
        self.grab_set()

        # Center on parent
        self.update_idletasks()
        x = parent.winfo_x() + (parent.winfo_width() - 380) // 2
        y = parent.winfo_y() + (parent.winfo_height() - 340) // 2
        self.geometry(f"+{x}+{y}")

        self._create_widgets()

    def _create_widgets(self):
        # Title
        title = tk.Label(
            self,
            text="Settings",
            bg=BG_COLOR,
            fg=TEXT_COLOR,
            font=("SF Pro Display", 18, "bold"),
        )
        title.pack(pady=(25, 20))

        # Settings container
        container = tk.Frame(self, bg=BG_COLOR)
        container.pack(fill=tk.X, padx=30)

        # Font size
        self._create_setting_row(
            container,
            "Font Size",
            f"{self.config_data.font_size}px",
        )
        self.font_value_label = self._last_value_label

        self.font_slider = ModernSlider(
            container,
            min_val=FONT_SIZE_MIN,
            max_val=FONT_SIZE_MAX,
            initial=self.config_data.font_size,
            on_change=self._on_font_change,
            width=320,
        )
        self.font_slider.pack(pady=(0, 20))

        # ORP Color
        color_frame = tk.Frame(container, bg=BG_COLOR)
        color_frame.pack(fill=tk.X, pady=(0, 20))

        tk.Label(
            color_frame,
            text="ORP Color",
            bg=BG_COLOR,
            fg=SUBTLE_TEXT,
            font=("SF Pro Display", 12),
        ).pack(side=tk.LEFT)

        self.orp_color = self.config_data.orp_color

        # Color preview button
        self.color_frame = tk.Frame(color_frame, bg=BG_COLOR)
        self.color_frame.pack(side=tk.RIGHT)

        self.color_label = tk.Label(
            self.color_frame,
            text=self.orp_color,
            bg=BG_COLOR,
            fg=TEXT_COLOR,
            font=("SF Pro Display", 12),
        )
        self.color_label.pack(side=tk.LEFT, padx=(0, 10))

        self.color_preview = tk.Canvas(
            self.color_frame,
            width=32,
            height=24,
            bg=BG_COLOR,
            highlightthickness=0,
        )
        self.color_preview.pack(side=tk.LEFT)
        self._draw_color_preview()
        self.color_preview.bind("<Button-1>", lambda e: self._pick_color())

        # Word skip
        self._create_setting_row(
            container,
            "Word Skip",
            str(self.config_data.word_skip),
        )
        self.skip_value_label = self._last_value_label

        self.skip_slider = ModernSlider(
            container,
            min_val=1,
            max_val=20,
            initial=self.config_data.word_skip,
            on_change=self._on_skip_change,
            width=320,
        )
        self.skip_slider.pack(pady=(0, 20))

        # Buttons
        btn_frame = tk.Frame(self, bg=BG_COLOR)
        btn_frame.pack(fill=tk.X, pady=20, padx=30)

        # Cancel button
        cancel_btn = tk.Canvas(
            btn_frame, width=100, height=36, bg=BG_COLOR, highlightthickness=0
        )
        cancel_btn.pack(side=tk.LEFT)
        self._draw_button(cancel_btn, "Cancel", BUTTON_NORMAL)
        cancel_btn.bind("<Button-1>", lambda e: self.destroy())
        cancel_btn.bind("<Enter>", lambda e: self._draw_button(cancel_btn, "Cancel", BUTTON_HOVER))
        cancel_btn.bind("<Leave>", lambda e: self._draw_button(cancel_btn, "Cancel", BUTTON_NORMAL))

        # Save button
        save_btn = tk.Canvas(
            btn_frame, width=100, height=36, bg=BG_COLOR, highlightthickness=0
        )
        save_btn.pack(side=tk.RIGHT)
        self._draw_button(save_btn, "Save", ACCENT_COLOR, fg="#ffffff")
        save_btn.bind("<Button-1>", lambda e: self._save())
        save_btn.bind("<Enter>", lambda e: self._draw_button(save_btn, "Save", "#5aa0e9", fg="#ffffff"))
        save_btn.bind("<Leave>", lambda e: self._draw_button(save_btn, "Save", ACCENT_COLOR, fg="#ffffff"))

    def _create_setting_row(self, parent, label: str, value: str):
        frame = tk.Frame(parent, bg=BG_COLOR)
        frame.pack(fill=tk.X, pady=(0, 8))

        tk.Label(
            frame,
            text=label,
            bg=BG_COLOR,
            fg=SUBTLE_TEXT,
            font=("SF Pro Display", 12),
        ).pack(side=tk.LEFT)

        value_label = tk.Label(
            frame,
            text=value,
            bg=BG_COLOR,
            fg=TEXT_COLOR,
            font=("SF Pro Display", 12, "bold"),
        )
        value_label.pack(side=tk.RIGHT)
        self._last_value_label = value_label

    def _draw_button(self, canvas, text: str, bg: str, fg: str = None):
        if fg is None:
            fg = TEXT_COLOR
        canvas.delete("all")
        w, h = 100, 36
        r = 6

        # Rounded rectangle
        canvas.create_arc(2, 2, 2 + 2*r, 2 + 2*r, start=90, extent=90, fill=bg, outline="")
        canvas.create_arc(w - 2 - 2*r, 2, w - 2, 2 + 2*r, start=0, extent=90, fill=bg, outline="")
        canvas.create_arc(2, h - 2 - 2*r, 2 + 2*r, h - 2, start=180, extent=90, fill=bg, outline="")
        canvas.create_arc(w - 2 - 2*r, h - 2 - 2*r, w - 2, h - 2, start=270, extent=90, fill=bg, outline="")
        canvas.create_rectangle(2 + r, 2, w - 2 - r, h - 2, fill=bg, outline="")
        canvas.create_rectangle(2, 2 + r, w - 2, h - 2 - r, fill=bg, outline="")

        canvas.create_text(w // 2, h // 2, text=text, font=("SF Pro Display", 12), fill=fg)

    def _draw_color_preview(self):
        self.color_preview.delete("all")
        r = 4
        w, h = 32, 24

        # Rounded rectangle with color
        self.color_preview.create_arc(0, 0, 2*r, 2*r, start=90, extent=90, fill=self.orp_color, outline="")
        self.color_preview.create_arc(w - 2*r, 0, w, 2*r, start=0, extent=90, fill=self.orp_color, outline="")
        self.color_preview.create_arc(0, h - 2*r, 2*r, h, start=180, extent=90, fill=self.orp_color, outline="")
        self.color_preview.create_arc(w - 2*r, h - 2*r, w, h, start=270, extent=90, fill=self.orp_color, outline="")
        self.color_preview.create_rectangle(r, 0, w - r, h, fill=self.orp_color, outline="")
        self.color_preview.create_rectangle(0, r, w, h - r, fill=self.orp_color, outline="")

    def _on_font_change(self, value):
        self.font_value_label.config(text=f"{int(value)}px")

    def _on_skip_change(self, value):
        self.skip_value_label.config(text=str(int(value)))

    def _pick_color(self):
        color = colorchooser.askcolor(
            color=self.orp_color,
            title="Choose ORP Highlight Color",
        )
        if color[1]:
            self.orp_color = color[1]
            self.color_label.config(text=self.orp_color)
            self._draw_color_preview()

    def _save(self):
        self.config_data.font_size = int(self.font_slider.get_value())
        self.config_data.orp_color = self.orp_color
        self.config_data.word_skip = int(self.skip_slider.get_value())
        self.config_data.save()

        if self._on_save:
            self._on_save(self.config_data)

        self.destroy()
