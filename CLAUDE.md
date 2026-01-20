# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Speed Reading is a Python package (Python 3.13+) managed with uv.

## Commands

```bash
# Activate virtual environment
source .venv/bin/activate

# Add dependencies
uv add <package>

# Add dev dependencies
uv add --dev <package>

# Run the package
uv run python -m speed_reading
```

## Structure

```
speed_reading/          # Package directory
    __init__.py
```

## Code Style

- Keep code clean, concise, and reusable
- Comments should provide insight, not explain what the code does—assume readers can follow the logic
