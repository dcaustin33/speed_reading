# Theme colors (dark mode)
BG_COLOR = "#1a1a1a"
TEXT_COLOR = "#e0e0e0"
ORP_COLOR = "#ff3333"
CONTROLS_BG = "#2d2d2d"
PROGRESS_FILLED = "#4a90d9"
PROGRESS_EMPTY = "#404040"
BUTTON_BG = "#3d3d3d"
BUTTON_HOVER = "#4d4d4d"

# WPM settings
WPM_MIN = 100
WPM_MAX = 800
WPM_DEFAULT = 300
WPM_STEP = 25

# Paragraph pause settings (seconds)
PAUSE_MIN = 0.25
PAUSE_MAX = 3.0
PAUSE_DEFAULT = 1.0

# Font settings
FONT_FAMILY = "Courier"
FONT_SIZE_MIN = 24
FONT_SIZE_MAX = 96
FONT_SIZE_DEFAULT = 48

# Navigation
WORD_SKIP_DEFAULT = 5

# Window dimensions
WINDOW_WIDTH = 800
WINDOW_HEIGHT = 500
WINDOW_MIN_WIDTH = 600
WINDOW_MIN_HEIGHT = 400

# Config paths
import platform
from pathlib import Path

def get_config_dir() -> Path:
    if platform.system() == "Windows":
        base = Path.home() / "AppData" / "Roaming"
    else:
        base = Path.home() / ".config"
    return base / "speed_reading"

CONFIG_DIR = get_config_dir()
SETTINGS_FILE = CONFIG_DIR / "settings.json"
PROGRESS_FILE = CONFIG_DIR / "progress.json"

# Recent files
MAX_RECENT_FILES = 10

# ORP position lookup table
ORP_POSITIONS = {
    1: 0,
    2: 1, 3: 1, 4: 1, 5: 1,
    6: 2, 7: 2, 8: 2, 9: 2,
    10: 3, 11: 3, 12: 3, 13: 3,
}
ORP_DEFAULT_POSITION = 4  # For words 14+ characters
