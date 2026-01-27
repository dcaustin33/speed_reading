from speed_reading.gui.main_window import MainWindow


def run(filepath: str | None = None):
    """Run the speed reading application."""
    app = MainWindow(initial_file=filepath)
    app.run()
