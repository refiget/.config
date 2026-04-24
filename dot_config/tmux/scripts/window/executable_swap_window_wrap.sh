#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/tmux_runtime.sh
source "$script_dir/../lib/tmux_runtime.sh"

direction="${1:-}"
if [[ "$direction" != "left" && "$direction" != "right" ]]; then
  exit 0
fi

read -r current_id current_index count <<<"$(tmux display-message -p "#{window_id} #{window_index} #{session_windows}")"
if [[ -z "${current_id:-}" || -z "${current_index:-}" || -z "${count:-}" ]]; then
  exit 0
fi

# (scratchpad removed)

target="$current_index"
if [[ "$direction" == "left" ]]; then
  target=$((current_index - 1))
else
  target=$((current_index + 1))
fi

if (( target < 1 )); then
  target="$count"
elif (( target > count )); then
  target=1
fi

tmux swap-window -t ":${target}"
tmux select-window -t "${current_id}"
