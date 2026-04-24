#!/usr/bin/env python3

import os
import re
import subprocess
import sys
import time
from typing import List, Dict, Optional, Tuple


def tmux_base_cmd() -> List[str]:
    cmd = ["tmux"]
    socket_name = os.environ.get("TMUX_SOCKET_NAME", "").strip()
    socket_path = os.environ.get("TMUX_SOCKET_PATH", "").strip()
    if socket_name:
        cmd.extend(["-L", socket_name])
    elif socket_path:
        cmd.extend(["-S", socket_path])
    return cmd


def run_tmux(args: List[str], check: bool = True, capture: bool = False) -> str:
    kwargs = {
        "check": check,
    }
    if capture:
        kwargs["stdout"] = subprocess.PIPE
        kwargs["text"] = True
    result = subprocess.run([*tmux_base_cmd(), *args], **kwargs)
    if capture:
        return result.stdout.rstrip("\n")
    return ""


DEFAULT_LABEL = "new"
NAME_SEP = "__"


def sanitize_label(label: str) -> str:
    label = label.strip()
    if not label:
        return DEFAULT_LABEL
    # Keep labels simple and separator-safe.
    label = label.replace(":", "-")
    label = label.replace(NAME_SEP, "-")
    return label


def cleanup_label(index: int, label: str) -> str:
    label = sanitize_label(label)
    # Remove repeated leading "<index><sep>" prefixes caused by earlier bugs.
    while True:
        match = re.match(rf"^{index}(?:__|[:_-])(.*)$", label)
        if not match:
            break
        label = match.group(1)
        if not label:
            return DEFAULT_LABEL
    return label or DEFAULT_LABEL


def parse_session_name(name: str) -> Tuple[Optional[int], str]:
    # Preferred canonical format: <index>__<label>
    match = re.match(r"^(\d+)__(.*)$", name)
    if match:
        index = int(match.group(1))
        label = match.group(2)
        if index <= 0:
            return None, sanitize_label(label)
        return index, cleanup_label(index, label)

    # Backward compatibility with legacy separators: 1_main / 2-new / 3:foo
    match = re.match(r"^(\d+)([:_-])(.*)$", name)
    if match:
        index = int(match.group(1))
        label = match.group(3)
        if index <= 0:
            return None, sanitize_label(label)
        return index, cleanup_label(index, label)

    if name.isdigit():
        index = int(name)
        if index <= 0:
            return None, DEFAULT_LABEL
        return index, DEFAULT_LABEL

    # Unindexed plain names become labels and get indexed during ensure().
    return None, sanitize_label(name)


def build_session_name(index: int, label: str) -> str:
    safe_label = sanitize_label(label)
    return f"{index}{NAME_SEP}{safe_label}"


def list_sessions() -> List[Dict[str, object]]:
    output = run_tmux([
        "list-sessions",
        "-F",
        "#{session_id}\t#{session_name}\t#{session_created}"
    ], capture=True)
    if not output:
        return []

    sessions = []
    for line in output.splitlines():
        session_id, name, created_str = line.split("\t")
        created = int(created_str)
        index, label = parse_session_name(name)
        sessions.append({
            "id": session_id,
            "name": name,
            "created": created,
            "index": index,
            "label": label,
        })
    return sessions


def normalize_sessions() -> List[Dict[str, object]]:
    sessions = list_sessions()
    indexed = []
    unindexed = []

    for session in sessions:
        label = session.get("label") or DEFAULT_LABEL
        session["label"] = label
        index = session["index"]
        if index is not None and index > 0:
            indexed.append(session)
        else:
            session["index"] = None
            unindexed.append(session)

    indexed.sort(key=lambda entry: entry["index"])
    unindexed.sort(key=lambda entry: entry["created"])

    ordered = indexed + unindexed
    for position, session in enumerate(ordered, start=1):
        session["index"] = position

    return ordered


def rename_session(session: Dict[str, object], new_name: str) -> None:
    run_tmux(["rename-session", "-t", session["id"], new_name], check=False)
    session["name"] = new_name


def apply_names(sessions: List[Dict[str, object]]) -> None:
    targets = {}
    for session in sessions:
        targets[session["id"]] = build_session_name(int(session["index"]), str(session["label"]))

    temp_prefix = f"__ren__{os.getpid()}_{int(time.time() * 1000)}_"
    temp_counter = 0

    for session in sessions:
        target = targets[session["id"]]
        if session["name"] != target:
            temp_name = f"{temp_prefix}{temp_counter}"
            temp_counter += 1
            rename_session(session, temp_name)

    for session in sessions:
        target = targets[session["id"]]
        if session["name"] != target:
            rename_session(session, target)


def current_target_args() -> List[str]:
    pane_id = os.environ.get("TMUX_PANE", "").strip()
    if pane_id:
        return ["-t", pane_id]
    return []


def current_session_id() -> str:
    return run_tmux(["display-message", *current_target_args(), "-p", "#{session_id}"], capture=True)


def current_window_id() -> str:
    return run_tmux(["display-message", *current_target_args(), "-p", "#{window_id}"], capture=True)


def command_switch(index_str: str) -> None:
    try:
        index = int(index_str)
    except ValueError:
        return
    if index < 1:
        return
    sessions = normalize_sessions()
    apply_names(sessions)
    target = next((session for session in sessions if session["index"] == index), None)
    if not target:
        return
    run_tmux(["switch-client", "-t", target["id"]], check=False)


def command_rename(label: str) -> None:
    # rename current session to a custom label (without number), then re-apply numbering
    current_id = current_session_id()
    if not current_id:
        return
    label = label.strip()
    if not label:
        label = DEFAULT_LABEL
    sessions = normalize_sessions()
    current = next((session for session in sessions if session["id"] == current_id), None)
    if not current:
        return
    current["label"] = label
    apply_names(sessions)


def command_move(direction: str) -> None:
    direction = direction.lower()
    sessions = normalize_sessions()
    current_id = current_session_id()
    indices = {session["id"]: idx for idx, session in enumerate(sessions)}
    if current_id not in indices:
        return
    pos = indices[current_id]
    if direction == "left" and pos > 0:
        sessions[pos - 1], sessions[pos] = sessions[pos], sessions[pos - 1]
    elif direction == "right" and pos < len(sessions) - 1:
        sessions[pos], sessions[pos + 1] = sessions[pos + 1], sessions[pos]
    else:
        return
    for position, session in enumerate(sessions, start=1):
        session["index"] = position
    apply_names(sessions)


def command_ensure() -> None:
    sessions = normalize_sessions()
    if sessions:
        apply_names(sessions)


def command_created() -> None:
    # Called after a session is created; ensure numbering stays contiguous.
    command_ensure()


def command_move_window_to_session(index_str: str) -> None:
    try:
        index = int(index_str)
    except ValueError:
        return
    if index < 1:
        return
    sessions = normalize_sessions()
    apply_names(sessions)
    target = next((session for session in sessions if session["index"] == index), None)
    if not target:
        return
    target_session_id = target["id"]
    run_tmux(["move-window", "-s", current_window_id(), "-t", f"{target_session_id}:"], check=False)
    run_tmux(["switch-client", "-t", target_session_id], check=False)


def command_clean() -> None:
    current_id = current_session_id()
    if not current_id:
        return

    sessions = normalize_sessions()
    current = next((session for session in sessions if session["id"] == current_id), None)
    if not current:
        return

    run_tmux(["set-option", "-gq", "@session_manager_suspended", "1"], check=False)
    try:
        for session in sessions:
            if session["id"] == current_id:
                continue
            run_tmux(["kill-session", "-t", session["id"]], check=False)

        current["index"] = 1
        current["label"] = cleanup_label(1, str(current.get("label") or DEFAULT_LABEL))
        rename_session(current, build_session_name(1, str(current["label"])))
    finally:
        run_tmux(["set-option", "-gu", "@session_manager_suspended"], check=False)

    run_tmux(["switch-client", "-t", current_id], check=False)


def main(argv: List[str]) -> None:
    if len(argv) < 2:
        return
    command = argv[1]
    if command == "switch" and len(argv) >= 3:
        command_switch(argv[2])
    elif command == "rename" and len(argv) >= 3:
        command_rename(argv[2])
    elif command == "move" and len(argv) >= 3:
        command_move(argv[2])
    elif command == "ensure":
        command_ensure()
    elif command == "created":
        command_created()
    elif command == "move-window-to" and len(argv) >= 3:
        command_move_window_to_session(argv[2])
    elif command == "clean":
        command_clean()


if __name__ == "__main__":
    main(sys.argv)
