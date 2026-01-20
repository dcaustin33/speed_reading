import tkinter as tk
from tkinter import ttk
from typing import Callable

from speed_reading.utils.constants import (
    BG_COLOR,
    TEXT_COLOR,
    CONTROLS_BG,
    BUTTON_BG,
    PROGRESS_FILLED,
    PROGRESS_EMPTY,
    WPM_MIN,
    WPM_MAX,
    WPM_DEFAULT,
    PAUSE_MIN,
    PAUSE_MAX,
    PAUSE_DEFAULT,
)


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

        # Button style
        btn_opts = {
            "bg": BUTTON_BG,
            "fg": TEXT_COLOR,
            "activebackground": "#4d4d4d",
            "activeforeground": TEXT_COLOR,
            "relief": "flat",
            "padx": 10,
            "pady": 5,
            "font": ("Arial", 14),
        }

        # Create buttons frame
        btn_frame = tk.Frame(self, bg=CONTROLS_BG)
        btn_frame.pack(pady=10)

        # Previous paragraph
        self.btn_prev_para = tk.Button(
            btn_frame, text="⏮", command=on_prev_para, **btn_opts
        )
        self.btn_prev_para.pack(side=tk.LEFT, padx=2)

        # Previous sentence
        self.btn_prev_sent = tk.Button(
            btn_frame, text="⏪", command=on_prev_sent, **btn_opts
        )
        self.btn_prev_sent.pack(side=tk.LEFT, padx=2)

        # Rewind
        self.btn_rewind = tk.Button(
            btn_frame, text="◀", command=on_rewind, **btn_opts
        )
        self.btn_rewind.pack(side=tk.LEFT, padx=2)

        # Play/Pause
        self.btn_play = tk.Button(
            btn_frame, text="▶", command=self._handle_play_pause, width=4, **btn_opts
        )
        self.btn_play.pack(side=tk.LEFT, padx=10)

        # Forward
        self.btn_forward = tk.Button(
            btn_frame, text="▶", command=on_forward, **btn_opts
        )
        self.btn_forward.pack(side=tk.LEFT, padx=2)

        # Next sentence
        self.btn_next_sent = tk.Button(
            btn_frame, text="⏩", command=on_next_sent, **btn_opts
        )
        self.btn_next_sent.pack(side=tk.LEFT, padx=2)

        # Next paragraph
        self.btn_next_para = tk.Button(
            btn_frame, text="⏭", command=on_next_para, **btn_opts
        )
        self.btn_next_para.pack(side=tk.LEFT, padx=2)

    def _handle_play_pause(self):
        if self._on_play_pause:
            self._on_play_pause()

    def set_playing(self, playing: bool):
        """Update the play/pause button state."""
        self._is_playing = playing
        self.btn_play.config(text="⏸" if playing else "▶")


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

        # WPM slider
        wpm_frame = tk.Frame(self, bg=CONTROLS_BG)
        wpm_frame.pack(side=tk.LEFT, padx=20, pady=5)

        tk.Label(
            wpm_frame, text="WPM:", bg=CONTROLS_BG, fg=TEXT_COLOR, font=("Arial", 10)
        ).pack(side=tk.LEFT)

        self.wpm_var = tk.IntVar(value=WPM_DEFAULT)
        self.wpm_slider = tk.Scale(
            wpm_frame,
            from_=WPM_MIN,
            to=WPM_MAX,
            orient=tk.HORIZONTAL,
            variable=self.wpm_var,
            command=self._on_wpm_slider,
            bg=CONTROLS_BG,
            fg=TEXT_COLOR,
            highlightthickness=0,
            troughcolor=PROGRESS_EMPTY,
            length=150,
        )
        self.wpm_slider.pack(side=tk.LEFT, padx=5)

        # Pause slider
        pause_frame = tk.Frame(self, bg=CONTROLS_BG)
        pause_frame.pack(side=tk.LEFT, padx=20, pady=5)

        tk.Label(
            pause_frame, text="Pause:", bg=CONTROLS_BG, fg=TEXT_COLOR, font=("Arial", 10)
        ).pack(side=tk.LEFT)

        self.pause_var = tk.DoubleVar(value=PAUSE_DEFAULT)
        self.pause_slider = tk.Scale(
            pause_frame,
            from_=PAUSE_MIN,
            to=PAUSE_MAX,
            orient=tk.HORIZONTAL,
            variable=self.pause_var,
            command=self._on_pause_slider,
            bg=CONTROLS_BG,
            fg=TEXT_COLOR,
            highlightthickness=0,
            troughcolor=PROGRESS_EMPTY,
            length=100,
            resolution=0.25,
        )
        self.pause_slider.pack(side=tk.LEFT, padx=5)

        tk.Label(
            pause_frame, text="s", bg=CONTROLS_BG, fg=TEXT_COLOR, font=("Arial", 10)
        ).pack(side=tk.LEFT)

    def _on_wpm_slider(self, value):
        if self._on_wpm_change:
            self._on_wpm_change(int(float(value)))

    def _on_pause_slider(self, value):
        if self._on_pause_change:
            self._on_pause_change(float(value))

    def set_wpm(self, wpm: int):
        self.wpm_var.set(wpm)

    def set_pause(self, pause: float):
        self.pause_var.set(pause)


class ProgressBar(tk.Frame):
    """Widget showing reading progress and statistics."""

    def __init__(self, parent, **kwargs):
        super().__init__(parent, bg=CONTROLS_BG, **kwargs)

        # Progress canvas
        self.canvas = tk.Canvas(
            self,
            bg=CONTROLS_BG,
            highlightthickness=0,
            height=20,
        )
        self.canvas.pack(fill=tk.X, padx=10, pady=5)

        # Stats label
        self.stats_label = tk.Label(
            self,
            text="Word 0/0  |  0:00",
            bg=CONTROLS_BG,
            fg=TEXT_COLOR,
            font=("Arial", 10),
        )
        self.stats_label.pack(pady=2)

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

        # Background
        self.canvas.create_rectangle(
            5, 5, width - 5, height - 5, fill=PROGRESS_EMPTY, outline=""
        )

        # Filled portion
        filled_width = max(0, (width - 10) * self._progress)
        if filled_width > 0:
            self.canvas.create_rectangle(
                5, 5, 5 + filled_width, height - 5, fill=PROGRESS_FILLED, outline=""
            )

    def set_progress(self, progress: float, current: int, total: int, time_remaining: float):
        """Update progress display."""
        self._progress = max(0.0, min(1.0, progress))
        self._draw_progress()

        # Format time remaining
        minutes = int(time_remaining // 60)
        seconds = int(time_remaining % 60)
        if minutes >= 60:
            hours = minutes // 60
            minutes = minutes % 60
            time_str = f"{hours}:{minutes:02d}:{seconds:02d}"
        else:
            time_str = f"{minutes}:{seconds:02d}"

        self.stats_label.config(text=f"Word {current}/{total}  |  {time_str}")
