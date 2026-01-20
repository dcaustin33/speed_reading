import json
from datetime import datetime
from pathlib import Path
from dataclasses import dataclass, asdict

from speed_reading.utils.constants import CONFIG_DIR, PROGRESS_FILE


@dataclass
class FileProgress:
    file_path: str
    file_hash: str
    word_index: int
    total_words: int
    last_opened: str


class ProgressManager:
    """Manages reading progress persistence."""

    def __init__(self):
        self._progress: dict[str, FileProgress] = {}
        self._load()

    def _load(self):
        """Load progress data from file."""
        if not PROGRESS_FILE.exists():
            return

        try:
            data = json.loads(PROGRESS_FILE.read_text())
            for file_path, entry in data.items():
                self._progress[file_path] = FileProgress(
                    file_path=entry["file_path"],
                    file_hash=entry["file_hash"],
                    word_index=entry["word_index"],
                    total_words=entry["total_words"],
                    last_opened=entry["last_opened"],
                )
        except (json.JSONDecodeError, KeyError):
            self._progress = {}

    def _save(self):
        """Save progress data to file."""
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        data = {path: asdict(progress) for path, progress in self._progress.items()}
        PROGRESS_FILE.write_text(json.dumps(data, indent=2))

    def get_progress(self, file_path: str, file_hash: str) -> int | None:
        """Get saved word index for a file.

        Returns None if no progress saved or if file hash doesn't match
        (indicating file has changed).
        """
        progress = self._progress.get(file_path)
        if progress is None:
            return None

        # Check if file has changed
        if progress.file_hash != file_hash:
            return None

        return progress.word_index

    def save_progress(
        self, file_path: str, file_hash: str, word_index: int, total_words: int
    ):
        """Save progress for a file."""
        self._progress[file_path] = FileProgress(
            file_path=file_path,
            file_hash=file_hash,
            word_index=word_index,
            total_words=total_words,
            last_opened=datetime.now().isoformat(),
        )
        self._save()

    def clear_progress(self, file_path: str):
        """Clear saved progress for a file."""
        if file_path in self._progress:
            del self._progress[file_path]
            self._save()
