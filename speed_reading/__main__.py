import sys
from speed_reading.app import run


def main():
    """Entry point for the speed reading application."""
    filepath = sys.argv[1] if len(sys.argv) > 1 else None
    run(filepath)


if __name__ == "__main__":
    main()
