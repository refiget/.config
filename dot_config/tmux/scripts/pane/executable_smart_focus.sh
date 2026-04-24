#!/usr/bin/env bash
set -euo pipefail

direction="${1:-}"

case "$direction" in
  left)
    tmux_flag="-L"
    yabai_dir="west"
    ;;
  down)
    tmux_flag="-D"
    yabai_dir="south"
    ;;
  up)
    tmux_flag="-U"
    yabai_dir="north"
    ;;
  right)
    tmux_flag="-R"
    yabai_dir="east"
    ;;
  *)
    tmux display-message "smart_focus: invalid direction '$direction'"
    exit 0
    ;;
esac

pane_before="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
tmux select-pane "$tmux_flag" 2>/dev/null || true
pane_after="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"

if [ -n "$pane_before" ] && [ "$pane_before" != "$pane_after" ]; then
  exit 0
fi

yabai_bin="$(command -v yabai 2>/dev/null || true)"
if [ -n "$yabai_bin" ] && [ -x "$yabai_bin" ]; then
  "$yabai_bin" -m window --focus "$yabai_dir" >/dev/null 2>&1 || true
fi
