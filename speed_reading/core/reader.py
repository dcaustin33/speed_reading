from typing import Callable

from speed_reading.core.tokenizer import Document, Word
from speed_reading.utils.constants import WPM_DEFAULT, PAUSE_DEFAULT, WORD_SKIP_DEFAULT


class Reader:
    """Reading engine that manages playback of a document."""

    def __init__(
        self,
        document: Document,
        on_word: Callable[[Word, int], None] | None = None,
        on_complete: Callable[[], None] | None = None,
    ):
        self.document = document
        self.on_word = on_word
        self.on_complete = on_complete

        self._current_index = 0
        self._wpm = WPM_DEFAULT
        self._paragraph_pause = PAUSE_DEFAULT
        self._word_skip = WORD_SKIP_DEFAULT
        self._playing = False
        self._timer_id: str | None = None
        self._root = None  # Tkinter root for timer scheduling

    @property
    def current_index(self) -> int:
        return self._current_index

    @current_index.setter
    def current_index(self, value: int):
        self._current_index = max(0, min(value, self.document.total_words - 1))

    @property
    def wpm(self) -> int:
        return self._wpm

    @wpm.setter
    def wpm(self, value: int):
        self._wpm = max(100, min(800, value))

    @property
    def paragraph_pause(self) -> float:
        return self._paragraph_pause

    @paragraph_pause.setter
    def paragraph_pause(self, value: float):
        self._paragraph_pause = max(0.25, min(3.0, value))

    @property
    def word_skip(self) -> int:
        return self._word_skip

    @word_skip.setter
    def word_skip(self, value: int):
        self._word_skip = max(1, min(20, value))

    @property
    def is_playing(self) -> bool:
        return self._playing

    @property
    def current_word(self) -> Word | None:
        if 0 <= self._current_index < self.document.total_words:
            return self.document.words[self._current_index]
        return None

    @property
    def progress(self) -> float:
        """Return progress as a fraction from 0 to 1."""
        if self.document.total_words == 0:
            return 0.0
        return self._current_index / self.document.total_words

    @property
    def time_remaining_seconds(self) -> float:
        """Estimate remaining time based on current WPM."""
        remaining_words = self.document.total_words - self._current_index
        return (remaining_words / self._wpm) * 60

    def _word_delay_ms(self) -> int:
        """Calculate delay between words in milliseconds."""
        return int(60000 / self._wpm)

    def _schedule_next(self):
        """Schedule the next word display."""
        if not self._playing or self._root is None:
            return

        word = self.current_word
        if word is None:
            self.stop()
            if self.on_complete:
                self.on_complete()
            return

        # Notify callback
        if self.on_word:
            self.on_word(word, self._current_index)

        # Calculate delay
        delay = self._word_delay_ms()
        if word.paragraph_end:
            delay += int(self._paragraph_pause * 1000)

        # Move to next word
        self._current_index += 1

        # Check if we're done
        if self._current_index >= self.document.total_words:
            self._playing = False
            if self.on_complete:
                self.on_complete()
            return

        # Schedule next
        self._timer_id = self._root.after(delay, self._schedule_next)

    def set_root(self, root):
        """Set the Tkinter root for timer scheduling."""
        self._root = root

    def play(self):
        """Start or resume playback."""
        if self._playing or self._root is None:
            return
        if self._current_index >= self.document.total_words:
            self._current_index = 0
        self._playing = True
        self._schedule_next()

    def pause(self):
        """Pause playback."""
        self._playing = False
        if self._timer_id and self._root:
            self._root.after_cancel(self._timer_id)
            self._timer_id = None

    def stop(self):
        """Stop playback and reset to beginning."""
        self.pause()
        self._current_index = 0

    def toggle(self):
        """Toggle between play and pause."""
        if self._playing:
            self.pause()
        else:
            self.play()

    def skip_words(self, count: int):
        """Skip forward by count words (use negative to rewind)."""
        self.current_index = self._current_index + count
        if self.on_word and self.current_word:
            self.on_word(self.current_word, self._current_index)

    def skip_forward(self):
        """Skip forward by word_skip words."""
        self.skip_words(self._word_skip)

    def skip_backward(self):
        """Skip backward by word_skip words."""
        self.skip_words(-self._word_skip)

    def next_sentence(self):
        """Jump to the start of the next sentence."""
        for i in range(self._current_index, self.document.total_words):
            if self.document.words[i].sentence_end and i + 1 < self.document.total_words:
                self.current_index = i + 1
                if self.on_word and self.current_word:
                    self.on_word(self.current_word, self._current_index)
                return
        # If no next sentence found, go to end
        self.current_index = self.document.total_words - 1

    def prev_sentence(self):
        """Jump to the start of the current or previous sentence."""
        # First, find start of current sentence
        current_start = self._current_index
        for i in range(self._current_index - 1, -1, -1):
            if self.document.words[i].sentence_end:
                current_start = i + 1
                break
        else:
            current_start = 0

        # If we're already at start of sentence, go to previous
        if current_start == self._current_index and self._current_index > 0:
            for i in range(current_start - 2, -1, -1):
                if self.document.words[i].sentence_end:
                    self.current_index = i + 1
                    if self.on_word and self.current_word:
                        self.on_word(self.current_word, self._current_index)
                    return
            self.current_index = 0
        else:
            self.current_index = current_start

        if self.on_word and self.current_word:
            self.on_word(self.current_word, self._current_index)

    def next_paragraph(self):
        """Jump to the start of the next paragraph."""
        for i in range(self._current_index, self.document.total_words):
            if self.document.words[i].paragraph_end and i + 1 < self.document.total_words:
                self.current_index = i + 1
                if self.on_word and self.current_word:
                    self.on_word(self.current_word, self._current_index)
                return
        self.current_index = self.document.total_words - 1

    def prev_paragraph(self):
        """Jump to the start of the current or previous paragraph."""
        # Find start of current paragraph
        current_start = self._current_index
        for i in range(self._current_index - 1, -1, -1):
            if self.document.words[i].paragraph_end:
                current_start = i + 1
                break
        else:
            current_start = 0

        # If we're already at start of paragraph, go to previous
        if current_start == self._current_index and self._current_index > 0:
            for i in range(current_start - 2, -1, -1):
                if self.document.words[i].paragraph_end:
                    self.current_index = i + 1
                    if self.on_word and self.current_word:
                        self.on_word(self.current_word, self._current_index)
                    return
            self.current_index = 0
        else:
            self.current_index = current_start

        if self.on_word and self.current_word:
            self.on_word(self.current_word, self._current_index)

    def go_to_word(self, index: int):
        """Jump to a specific word index."""
        self.current_index = index
        if self.on_word and self.current_word:
            self.on_word(self.current_word, self._current_index)
