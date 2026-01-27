import tkinter as tk
from typing import Callable

from speed_reading.utils.constants import (
    BG_COLOR,
    TEXT_COLOR,
    CONTROLS_BG,
    PROGRESS_FILLED,
    PROGRESS_EMPTY,
    WPM_MIN,
    WPM_MAX,
    WPM_DEFAULT,
    PAUSE_MIN,
    PAUSE_MAX,
    PAUSE_DEFAULT,
    ORP_COLOR,
)

# Enhanced color palette
ACCENT_COLOR = "#4a90d9"
ACCENT_HOVER = "#5aa0e9"
BUTTON_NORMAL = "#3a3a3a"
BUTTON_HOVER = "#4a4a4a"
BUTTON_ACTIVE = "#2a2a2a"
SUBTLE_TEXT = "#888888"


class IconButton(tk.Canvas):
    """Custom styled button with icon."""

    def __init__(
        self,
        parent,
        icon: str,
        command: Callable[[], None] | None = None,
        size: int = 44,
        is_primary: bool = False,
        **kwargs,
    ):
        super().__init__(
            parent,
            width=size,
            height=size,
            bg=CONTROLS_BG,
            highlightthickness=0,
            **kwargs,
        )

        self._command = command
        self._size = size
        self._icon = icon
        self._is_primary = is_primary
        self._is_hovered = False
        self._is_pressed = False

        self._draw()

        self.bind("<Enter>", self._on_enter)
        self.bind("<Leave>", self._on_leave)
        self.bind("<ButtonPress-1>", self._on_press)
        self.bind("<ButtonRelease-1>", self._on_release)

    def _get_colors(self):
        if self._is_primary:
            if self._is_pressed:
                return ACCENT_COLOR, "#ffffff"
            elif self._is_hovered:
                return ACCENT_HOVER, "#ffffff"
            else:
                return ACCENT_COLOR, "#ffffff"
        else:
            if self._is_pressed:
                return BUTTON_ACTIVE, TEXT_COLOR
            elif self._is_hovered:
                return BUTTON_HOVER, TEXT_COLOR
            else:
                return BUTTON_NORMAL, SUBTLE_TEXT

    def _draw(self):
        self.delete("all")
        bg_color, fg_color = self._get_colors()

        # Draw rounded rectangle
        r = 8
        x0, y0 = 2, 2
        x1, y1 = self._size - 2, self._size - 2

        # Create rounded rectangle using arcs and rectangles
        self.create_arc(x0, y0, x0 + 2 * r, y0 + 2 * r, start=90, extent=90, fill=bg_color, outline="")
        self.create_arc(x1 - 2 * r, y0, x1, y0 + 2 * r, start=0, extent=90, fill=bg_color, outline="")
        self.create_arc(x0, y1 - 2 * r, x0 + 2 * r, y1, start=180, extent=90, fill=bg_color, outline="")
        self.create_arc(x1 - 2 * r, y1 - 2 * r, x1, y1, start=270, extent=90, fill=bg_color, outline="")
        self.create_rectangle(x0 + r, y0, x1 - r, y1, fill=bg_color, outline="")
        self.create_rectangle(x0, y0 + r, x1, y1 - r, fill=bg_color, outline="")

        # Draw icon
        self.create_text(
            self._size // 2,
            self._size // 2,
            text=self._icon,
            font=("Arial", 16),
            fill=fg_color,
        )

    def _on_enter(self, event):
        self._is_hovered = True
        self._draw()

    def _on_leave(self, event):
        self._is_hovered = False
        self._is_pressed = False
        self._draw()

    def _on_press(self, event):
        self._is_pressed = True
        self._draw()

    def _on_release(self, event):
        self._is_pressed = False
        self._draw()
        if self._is_hovered and self._command:
            self._command()

    def set_icon(self, icon: str):
        self._icon = icon
        self._draw()


class ModernSlider(tk.Canvas):
    """Custom styled slider."""

    def __init__(
        self,
        parent,
        min_val: float,
        max_val: float,
        initial: float,
        on_change: Callable[[float], None] | None = None,
        width: int = 160,
        height: int = 36,
        resolution: float = 1.0,
        label: str = "",
        unit: str = "",
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

        self._min = min_val
        self._max = max_val
        self._value = initial
        self._on_change = on_change
        self._resolution = resolution
        self._label = label
        self._unit = unit
        self._width = width
        self._height = height
        self._dragging = False

        self._track_y = height - 10
        self._track_start = 10
        self._track_end = width - 10

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
        # Apply resolution
        if self._resolution >= 1:
            value = round(value / self._resolution) * self._resolution
        else:
            decimals = len(str(self._resolution).split(".")[-1])
            value = round(value / self._resolution) * self._resolution
            value = round(value, decimals)
        return max(self._min, min(self._max, value))

    def _draw(self):
        self.delete("all")

        # Draw label and value
        if self._label:
            self.create_text(
                self._track_start,
                8,
                text=self._label,
                font=("SF Pro Display", 11),
                fill=SUBTLE_TEXT,
                anchor="w",
            )

        # Format value display
        if self._resolution >= 1:
            val_text = f"{int(self._value)}{self._unit}"
        else:
            val_text = f"{self._value:.2f}{self._unit}"

        self.create_text(
            self._track_end,
            8,
            text=val_text,
            font=("SF Pro Display", 11, "bold"),
            fill=TEXT_COLOR,
            anchor="e",
        )

        # Draw track background
        self.create_line(
            self._track_start,
            self._track_y,
            self._track_end,
            self._track_y,
            fill=PROGRESS_EMPTY,
            width=4,
            capstyle="round",
        )

        # Draw filled track
        thumb_x = self._value_to_x(self._value)
        self.create_line(
            self._track_start,
            self._track_y,
            thumb_x,
            self._track_y,
            fill=ACCENT_COLOR,
            width=4,
            capstyle="round",
        )

        # Draw thumb
        self.create_oval(
            thumb_x - 7,
            self._track_y - 7,
            thumb_x + 7,
            self._track_y + 7,
            fill=TEXT_COLOR,
            outline="",
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


class PlaybackControls(tk.Frame):
    """Widget containing playback control buttons."""

    def __init__(
        self,
        parent,
        on_play_pause: Callable[[], None] | None = None,
        on_prev_para: Callable[[], None] | None = None,
        on_prev_sent: Callable[[], None] | None = None,
        on_rewind: Callable[[], None] | None = None,
        on_forward: Callable[[], None] | None = None,
        on_next_sent: Callable[[], None] | None = None,
        on_next_para: Callable[[], None] | None = None,
        **kwargs,
    ):
        super().__init__(parent, bg=CONTROLS_BG, **kwargs)

        self._on_play_pause = on_play_pause
        self._is_playing = False

        # Create centered button container
        btn_frame = tk.Frame(self, bg=CONTROLS_BG)
        btn_frame.pack(pady=15)

        # Button definitions: (icon, callback, is_primary)
        buttons = [
            ("⏮", on_prev_para, False),
            ("⏪", on_prev_sent, False),
            ("◂", on_rewind, False),
            ("▶", self._handle_play_pause, True),  # Play button - primary
            ("▸", on_forward, False),
            ("⏩", on_next_sent, False),
            ("⏭", on_next_para, False),
        ]

        self._buttons = []
        for i, (icon, cmd, is_primary) in enumerate(buttons):
            size = 56 if is_primary else 44
            btn = IconButton(btn_frame, icon, cmd, size=size, is_primary=is_primary)
            btn.pack(side=tk.LEFT, padx=4 if not is_primary else 12)
            self._buttons.append(btn)

        # Store play button reference for updating icon
        self._play_btn = self._buttons[3]

    def _handle_play_pause(self):
        if self._on_play_pause:
            self._on_play_pause()

    def set_playing(self, playing: bool):
        """Update the play/pause button state."""
        self._is_playing = playing
        self._play_btn.set_icon("⏸" if playing else "▶")


class SettingsSliders(tk.Frame):
    """Widget containing WPM and pause sliders."""

    def __init__(
        self,
        parent,
        on_wpm_change: Callable[[int], None] | None = None,
        on_pause_change: Callable[[float], None] | None = None,
        **kwargs,
    ):
        super().__init__(parent, bg=CONTROLS_BG, **kwargs)

        self._on_wpm_change = on_wpm_change
        self._on_pause_change = on_pause_change

        # Center container
        container = tk.Frame(self, bg=CONTROLS_BG)
        container.pack(pady=10)

        # WPM slider
        self.wpm_slider = ModernSlider(
            container,
            min_val=WPM_MIN,
            max_val=WPM_MAX,
            initial=WPM_DEFAULT,
            on_change=self._on_wpm_slider,
            width=200,
            label="WPM",
            unit="",
            resolution=25,
        )
        self.wpm_slider.pack(side=tk.LEFT, padx=30)

        # Pause slider
        self.pause_slider = ModernSlider(
            container,
            min_val=PAUSE_MIN,
            max_val=PAUSE_MAX,
            initial=PAUSE_DEFAULT,
            on_change=self._on_pause_slider,
            width=180,
            label="Pause",
            unit="s",
            resolution=0.25,
        )
        self.pause_slider.pack(side=tk.LEFT, padx=30)

    def _on_wpm_slider(self, value):
        if self._on_wpm_change:
            self._on_wpm_change(int(value))

    def _on_pause_slider(self, value):
        if self._on_pause_change:
            self._on_pause_change(float(value))

    def set_wpm(self, wpm: int):
        self.wpm_slider.set_value(wpm)

    def set_pause(self, pause: float):
        self.pause_slider.set_value(pause)


class ProgressBar(tk.Frame):
    """Widget showing reading progress and statistics."""

    def __init__(self, parent, **kwargs):
        super().__init__(parent, bg=CONTROLS_BG, **kwargs)

        # Progress canvas with rounded corners
        self.canvas = tk.Canvas(
            self,
            bg=CONTROLS_BG,
            highlightthickness=0,
            height=12,
        )
        self.canvas.pack(fill=tk.X, padx=40, pady=(15, 8))

        # Stats in a nicer format
        stats_frame = tk.Frame(self, bg=CONTROLS_BG)
        stats_frame.pack(pady=(0, 10))

        self.word_label = tk.Label(
            stats_frame,
            text="Word 0 of 0",
            bg=CONTROLS_BG,
            fg=TEXT_COLOR,
            font=("SF Pro Display", 12),
        )
        self.word_label.pack(side=tk.LEFT, padx=20)

        self.time_label = tk.Label(
            stats_frame,
            text="0:00 remaining",
            bg=CONTROLS_BG,
            fg=SUBTLE_TEXT,
            font=("SF Pro Display", 12),
        )
        self.time_label.pack(side=tk.LEFT, padx=20)

        self.canvas.bind("<Configure>", self._on_resize)
        self._progress = 0.0
        self._draw_progress()

    def _on_resize(self, event):
        self._draw_progress()

    def _draw_progress(self):
        self.canvas.delete("all")
        width = self.canvas.winfo_width()
        height = self.canvas.winfo_height()

        if width <= 1:
            return

        r = 4  # Corner radius
        y0, y1 = 2, height - 2

        # Background track with rounded ends
        self.canvas.create_line(
            r + 2, height // 2, width - r - 2, height // 2,
            fill=PROGRESS_EMPTY,
            width=height - 4,
            capstyle="round",
        )

        # Filled portion
        filled_width = max(0, (width - 4) * self._progress)
        if filled_width > r * 2:
            self.canvas.create_line(
                r + 2, height // 2, r + filled_width, height // 2,
                fill=ACCENT_COLOR,
                width=height - 4,
                capstyle="round",
            )

    def set_progress(self, progress: float, current: int, total: int, time_remaining: float):
        """Update progress display."""
        self._progress = max(0.0, min(1.0, progress))
        self._draw_progress()

        # Format stats
        self.word_label.config(text=f"Word {current} of {total}")

        # Format time remaining
        minutes = int(time_remaining // 60)
        seconds = int(time_remaining % 60)
        if minutes >= 60:
            hours = minutes // 60
            minutes = minutes % 60
            time_str = f"{hours}:{minutes:02d}:{seconds:02d}"
        else:
            time_str = f"{minutes}:{seconds:02d}"

        self.time_label.config(text=f"{time_str} remaining")
