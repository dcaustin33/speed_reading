import json
from pathlib import Path
from dataclasses import dataclass, field, asdict

from speed_reading.utils.constants import (
    CONFIG_DIR,
    SETTINGS_FILE,
    WPM_DEFAULT,
    PAUSE_DEFAULT,
    FONT_SIZE_DEFAULT,
    ORP_COLOR,
    WORD_SKIP_DEFAULT,
    MAX_RECENT_FILES,
)


@dataclass
class Config:
    wpm: int = WPM_DEFAULT
    paragraph_pause: float = PAUSE_DEFAULT
    font_size: int = FONT_SIZE_DEFAULT
    orp_color: str = ORP_COLOR
    word_skip: int = WORD_SKIP_DEFAULT
    recent_files: list[str] = field(default_factory=list)

    @classmethod
    def load(cls) -> "Config":
        """Load config from file, or return defaults if not found."""
        if not SETTINGS_FILE.exists():
            return cls()

        try:
            data = json.loads(SETTINGS_FILE.read_text())
            return cls(
                wpm=data.get("wpm", WPM_DEFAULT),
                paragraph_pause=data.get("paragraph_pause", PAUSE_DEFAULT),
                font_size=data.get("font_size", FONT_SIZE_DEFAULT),
                orp_color=data.get("orp_color", ORP_COLOR),
                word_skip=data.get("word_skip", WORD_SKIP_DEFAULT),
                recent_files=data.get("recent_files", []),
            )
        except (json.JSONDecodeError, KeyError):
            return cls()

    def save(self):
        """Save config to file."""
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        SETTINGS_FILE.write_text(json.dumps(asdict(self), indent=2))

    def add_recent_file(self, file_path: str):
        """Add a file to recent files list."""
        # Remove if already exists
        if file_path in self.recent_files:
            self.recent_files.remove(file_path)

        # Add to front
        self.recent_files.insert(0, file_path)

        # Trim to max size
        self.recent_files = self.recent_files[:MAX_RECENT_FILES]

        self.save()
