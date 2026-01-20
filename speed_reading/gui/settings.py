import tkinter as tk
from tkinter import colorchooser
from typing import Callable

from speed_reading.io.config import Config
from speed_reading.utils.constants import (
    BG_COLOR,
    TEXT_COLOR,
    CONTROLS_BG,
    BUTTON_BG,
    FONT_SIZE_MIN,
    FONT_SIZE_MAX,
)


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
        self.geometry("350x300")
        self.resizable(False, False)
        self.transient(parent)
        self.grab_set()

        # Style options
        label_opts = {"bg": BG_COLOR, "fg": TEXT_COLOR, "font": ("Arial", 11)}
        frame_opts = {"bg": BG_COLOR, "padx": 20, "pady": 10}

        # Font size
        font_frame = tk.Frame(self, **frame_opts)
        font_frame.pack(fill=tk.X)

        tk.Label(font_frame, text="Font Size:", **label_opts).pack(side=tk.LEFT)

        self.font_size_var = tk.IntVar(value=config.font_size)
        self.font_slider = tk.Scale(
            font_frame,
            from_=FONT_SIZE_MIN,
            to=FONT_SIZE_MAX,
            orient=tk.HORIZONTAL,
            variable=self.font_size_var,
            bg=BG_COLOR,
            fg=TEXT_COLOR,
            highlightthickness=0,
            length=150,
        )
        self.font_slider.pack(side=tk.RIGHT)

        # ORP Color
        color_frame = tk.Frame(self, **frame_opts)
        color_frame.pack(fill=tk.X)

        tk.Label(color_frame, text="ORP Color:", **label_opts).pack(side=tk.LEFT)

        self.orp_color = config.orp_color
        self.color_btn = tk.Button(
            color_frame,
            text="     ",
            bg=self.orp_color,
            command=self._pick_color,
            width=5,
        )
        self.color_btn.pack(side=tk.RIGHT, padx=5)

        self.color_label = tk.Label(
            color_frame, text=self.orp_color, **label_opts
        )
        self.color_label.pack(side=tk.RIGHT)

        # Word skip amount
        skip_frame = tk.Frame(self, **frame_opts)
        skip_frame.pack(fill=tk.X)

        tk.Label(skip_frame, text="Word Skip:", **label_opts).pack(side=tk.LEFT)

        self.skip_var = tk.IntVar(value=config.word_skip)
        self.skip_slider = tk.Scale(
            skip_frame,
            from_=1,
            to=20,
            orient=tk.HORIZONTAL,
            variable=self.skip_var,
            bg=BG_COLOR,
            fg=TEXT_COLOR,
            highlightthickness=0,
            length=150,
        )
        self.skip_slider.pack(side=tk.RIGHT)

        # Buttons
        btn_frame = tk.Frame(self, bg=BG_COLOR, pady=20)
        btn_frame.pack(fill=tk.X)

        btn_opts = {
            "bg": BUTTON_BG,
            "fg": TEXT_COLOR,
            "activebackground": "#4d4d4d",
            "activeforeground": TEXT_COLOR,
            "relief": "flat",
            "padx": 20,
            "pady": 5,
        }

        tk.Button(
            btn_frame, text="Save", command=self._save, **btn_opts
        ).pack(side=tk.RIGHT, padx=20)

        tk.Button(
            btn_frame, text="Cancel", command=self.destroy, **btn_opts
        ).pack(side=tk.RIGHT)

    def _pick_color(self):
        color = colorchooser.askcolor(
            color=self.orp_color,
            title="Choose ORP Highlight Color",
        )
        if color[1]:
            self.orp_color = color[1]
            self.color_btn.config(bg=self.orp_color)
            self.color_label.config(text=self.orp_color)

    def _save(self):
        self.config_data.font_size = self.font_size_var.get()
        self.config_data.orp_color = self.orp_color
        self.config_data.word_skip = self.skip_var.get()
        self.config_data.save()

        if self._on_save:
            self._on_save(self.config_data)

        self.destroy()
