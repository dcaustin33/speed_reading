import tkinter as tk
from typing import Callable

from speed_reading.utils.constants import BG_COLOR, TEXT_COLOR

ACCENT_COLOR = "#4a90d9"
BUTTON_NORMAL = "#3a3a3a"
BUTTON_HOVER = "#4a4a4a"
SUBTLE_TEXT = "#888888"
INPUT_BG = "#2a2a2a"


class SearchDialog(tk.Toplevel):
    """Search dialog for finding phrases in the document."""

    def __init__(
        self,
        parent,
        on_select: Callable[[int], None] | None = None,
        search_fn: Callable[[str], list[tuple[int, str]]] | None = None,
    ):
        super().__init__(parent)

        self.title("Find in Book")
        self._on_select = on_select
        self._search_fn = search_fn
        self._results: list[tuple[int, str]] = []

        # Window setup
        self.configure(bg=BG_COLOR)
        self.geometry("500x400")
        self.resizable(True, True)
        self.minsize(400, 300)
        self.transient(parent)
        self.grab_set()

        # Center on parent
        self.update_idletasks()
        x = parent.winfo_x() + (parent.winfo_width() - 500) // 2
        y = parent.winfo_y() + (parent.winfo_height() - 400) // 2
        self.geometry(f"+{x}+{y}")

        self._create_widgets()

        # Focus the entry
        self.entry.focus_set()

        # Bind escape to close
        self.bind("<Escape>", lambda e: self.destroy())

    def _create_widgets(self):
        # Title
        title = tk.Label(
            self,
            text="Find in Book",
            bg=BG_COLOR,
            fg=TEXT_COLOR,
            font=("SF Pro Display", 18, "bold"),
        )
        title.pack(pady=(20, 15))

        # Search input frame
        input_frame = tk.Frame(self, bg=BG_COLOR)
        input_frame.pack(fill=tk.X, padx=25, pady=(0, 10))

        # Entry
        self.entry = tk.Entry(
            input_frame,
            bg=INPUT_BG,
            fg=TEXT_COLOR,
            insertbackground=TEXT_COLOR,
            font=("SF Pro Display", 13),
            relief=tk.FLAT,
            highlightthickness=1,
            highlightbackground="#404040",
            highlightcolor=ACCENT_COLOR,
        )
        self.entry.pack(side=tk.LEFT, fill=tk.X, expand=True, ipady=8, padx=(0, 10))
        self.entry.bind("<Return>", lambda e: self._do_search())

        # Search button
        self.search_btn = tk.Canvas(
            input_frame, width=80, height=36, bg=BG_COLOR, highlightthickness=0
        )
        self.search_btn.pack(side=tk.RIGHT)
        self._draw_button(self.search_btn, "Search", ACCENT_COLOR, "#ffffff")
        self.search_btn.bind("<Button-1>", lambda e: self._do_search())
        self.search_btn.bind("<Enter>", lambda e: self._draw_button(self.search_btn, "Search", "#5aa0e9", "#ffffff"))
        self.search_btn.bind("<Leave>", lambda e: self._draw_button(self.search_btn, "Search", ACCENT_COLOR, "#ffffff"))

        # Status label
        self.status_label = tk.Label(
            self,
            text="Enter a phrase to search (case-sensitive)",
            bg=BG_COLOR,
            fg=SUBTLE_TEXT,
            font=("SF Pro Display", 11),
        )
        self.status_label.pack(anchor=tk.W, padx=25, pady=(0, 10))

        # Results frame with listbox and scrollbar
        results_frame = tk.Frame(self, bg=BG_COLOR)
        results_frame.pack(fill=tk.BOTH, expand=True, padx=25, pady=(0, 15))

        # Scrollbar
        scrollbar = tk.Scrollbar(results_frame, bg=BG_COLOR, troughcolor=INPUT_BG)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # Listbox for results
        self.listbox = tk.Listbox(
            results_frame,
            bg=INPUT_BG,
            fg=TEXT_COLOR,
            selectbackground=ACCENT_COLOR,
            selectforeground="#ffffff",
            font=("SF Pro Display", 11),
            relief=tk.FLAT,
            highlightthickness=1,
            highlightbackground="#404040",
            highlightcolor=ACCENT_COLOR,
            activestyle="none",
            yscrollcommand=scrollbar.set,
        )
        self.listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.config(command=self.listbox.yview)

        # Double-click to go
        self.listbox.bind("<Double-Button-1>", lambda e: self._go_to_selected())

        # Bottom buttons
        btn_frame = tk.Frame(self, bg=BG_COLOR)
        btn_frame.pack(fill=tk.X, padx=25, pady=(0, 20))

        # Close button
        close_btn = tk.Canvas(
            btn_frame, width=80, height=36, bg=BG_COLOR, highlightthickness=0
        )
        close_btn.pack(side=tk.LEFT)
        self._draw_button(close_btn, "Close", BUTTON_NORMAL)
        close_btn.bind("<Button-1>", lambda e: self.destroy())
        close_btn.bind("<Enter>", lambda e: self._draw_button(close_btn, "Close", BUTTON_HOVER))
        close_btn.bind("<Leave>", lambda e: self._draw_button(close_btn, "Close", BUTTON_NORMAL))

        # Go button
        self.go_btn = tk.Canvas(
            btn_frame, width=80, height=36, bg=BG_COLOR, highlightthickness=0
        )
        self.go_btn.pack(side=tk.RIGHT)
        self._draw_button(self.go_btn, "Go", BUTTON_NORMAL, SUBTLE_TEXT)

    def _draw_button(self, canvas, text: str, bg: str, fg: str = None):
        if fg is None:
            fg = TEXT_COLOR
        canvas.delete("all")
        w, h = int(canvas["width"]), int(canvas["height"])
        r = 6

        # Rounded rectangle
        canvas.create_arc(2, 2, 2 + 2*r, 2 + 2*r, start=90, extent=90, fill=bg, outline="")
        canvas.create_arc(w - 2 - 2*r, 2, w - 2, 2 + 2*r, start=0, extent=90, fill=bg, outline="")
        canvas.create_arc(2, h - 2 - 2*r, 2 + 2*r, h - 2, start=180, extent=90, fill=bg, outline="")
        canvas.create_arc(w - 2 - 2*r, h - 2 - 2*r, w - 2, h - 2, start=270, extent=90, fill=bg, outline="")
        canvas.create_rectangle(2 + r, 2, w - 2 - r, h - 2, fill=bg, outline="")
        canvas.create_rectangle(2, 2 + r, w - 2, h - 2 - r, fill=bg, outline="")

        canvas.create_text(w // 2, h // 2, text=text, font=("SF Pro Display", 12), fill=fg)

    def _do_search(self):
        phrase = self.entry.get().strip()
        if not phrase:
            self.status_label.config(text="Please enter a phrase to search")
            return

        if not self._search_fn:
            return

        self._results = self._search_fn(phrase)

        # Clear and populate listbox
        self.listbox.delete(0, tk.END)

        if not self._results:
            self.status_label.config(text="No matches found")
            self._draw_button(self.go_btn, "Go", BUTTON_NORMAL, SUBTLE_TEXT)
            return

        for i, (word_idx, context) in enumerate(self._results):
            self.listbox.insert(tk.END, f"{i + 1}. {context}")

        count = len(self._results)
        self.status_label.config(text=f"{count} match{'es' if count != 1 else ''} found")

        # Enable go button
        self._draw_button(self.go_btn, "Go", ACCENT_COLOR, "#ffffff")
        self.go_btn.bind("<Button-1>", lambda e: self._go_to_selected())
        self.go_btn.bind("<Enter>", lambda e: self._draw_button(self.go_btn, "Go", "#5aa0e9", "#ffffff"))
        self.go_btn.bind("<Leave>", lambda e: self._draw_button(self.go_btn, "Go", ACCENT_COLOR, "#ffffff"))

        # Select first result
        self.listbox.selection_set(0)

    def _go_to_selected(self):
        selection = self.listbox.curselection()
        if not selection or not self._results:
            return

        idx = selection[0]
        word_index = self._results[idx][0]

        if self._on_select:
            self._on_select(word_index)
            self.destroy()
