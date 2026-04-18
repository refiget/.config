#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/runtime.sh
source "$script_dir/lib/runtime.sh"
# shellcheck source=lib/segments.sh
source "$script_dir/lib/segments.sh"
# shellcheck source=lib/metrics.sh
source "$script_dir/lib/metrics.sh"

min_width=${TMUX_RIGHT_MIN_WIDTH:-90}
width=$(status_client_width)
if [[ -n "${width:-}" && "$width" =~ ^[0-9]+$ ]]; then
  if (( width < min_width )); then
    exit 0
  fi
fi

status_bg=$(status_bg_value)

# Palette (Catppuccin Mocha-ish)
text="#cdd6f4"
subtext0="#a6adc8"
overlay0="#6c7086"
peach="#fab387"

# Keep segments on the terminal background to avoid color blocks on transparent themes
segment_fg=$(status_option_or '@status_fg' "$overlay0")

session_segment=$(status_build_session_segment "$width" "$subtext0")
rainbarf_segment=$(status_build_rainbarf_segment "$width" "$segment_fg")
time_segment=$(status_build_time_segment "$status_bg" "$subtext0")
date_segment=$(status_build_date_segment "$status_bg" "$subtext0")
right_cap=""

printf '%s%s%s%s%s' \
  "$session_segment" \
  "$rainbarf_segment" \
  "$time_segment" \
  "$date_segment" \
  "$right_cap"
