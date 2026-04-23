#!/usr/bin/env python3
"""Sync Things data into simple cache files for SketchyBar/tmux consumers.

This script intentionally reads the local Things database via `things.py`
instead of AppleScript. The database schema is stable enough for reads, and
the library avoids the localization issues we hit with built-in list names.

Cache contract:
  - today_counts: "<open_count>,<done_count>"
  - today_title: first today title
  - today_titles: newline-separated today titles
  - left_counts: "<inbox_count>,<today_count>,<someday_count>"
  - today_state: "ok" or "error"
  - today_error.log: error details when sync fails
"""

from __future__ import annotations

import os
import pathlib
import tempfile
import traceback

import things


CACHE_DIR = pathlib.Path(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
) / "tmux" / "things"

COUNTS_FILE = CACHE_DIR / "today_counts"
TITLE_FILE = CACHE_DIR / "today_title"
TITLES_FILE = CACHE_DIR / "today_titles"
LEFT_COUNTS_FILE = CACHE_DIR / "left_counts"
STATE_FILE = CACHE_DIR / "today_state"
ERROR_FILE = CACHE_DIR / "today_error.log"


def valid_todos(items: list[dict]) -> list[dict]:
    """Keep only concrete to-dos with a non-empty title.

    `things.today()` may include synthetic/placeholder rows with `type=None`
    and empty titles. Those are not useful for bar display or counts.
    """

    result: list[dict] = []
    for item in items:
        title = (item.get("title") or "").strip()
        if item.get("type") != "to-do":
            continue
        if not title:
            continue
        result.append(item)
    return result


def atomic_write(path: pathlib.Path, content: str) -> None:
    """Write a cache file atomically to avoid partial reads."""

    fd, tmp_path = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(content)
        os.replace(tmp_path, path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except FileNotFoundError:
            pass
        raise


def main() -> int:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

    try:
        database = things.Database()

        today_items = valid_todos(things.today(status="incomplete", database=database))
        inbox_items = valid_todos(things.inbox(status="incomplete", database=database))
        someday_items = valid_todos(
            things.someday(status="incomplete", database=database)
        )

        today_titles = [item["title"].strip() for item in today_items]
        first_title = today_titles[0] if today_titles else ""

        atomic_write(COUNTS_FILE, f"{len(today_items)},0\n")
        atomic_write(TITLE_FILE, f"{first_title}\n" if first_title else "")
        atomic_write(
            TITLES_FILE,
            "".join(f"{title}\n" for title in today_titles),
        )
        atomic_write(
            LEFT_COUNTS_FILE,
            f"{len(inbox_items)},{len(today_items)},{len(someday_items)}\n",
        )
        atomic_write(STATE_FILE, "ok\n")
        atomic_write(ERROR_FILE, "")
        return 0
    except Exception:
        atomic_write(STATE_FILE, "error\n")
        atomic_write(ERROR_FILE, traceback.format_exc())
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
