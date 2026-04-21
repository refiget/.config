#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/runtime.sh
source "$script_dir/lib/runtime.sh"
# shellcheck source=lib/segments.sh
source "$script_dir/lib/segments.sh"
# shellcheck source=lib/things.sh
source "$script_dir/lib/things.sh"

min_width=${TMUX_RIGHT_MIN_WIDTH:-90}
width=$(status_client_width)
if [[ -n "${width:-}" && "$width" =~ ^[0-9]+$ ]]; then
  if (( width < min_width )); then
    exit 0
  fi
fi

status_bg=$(status_bg_value)

subtext0="#a6adc8"

session_segment=$(status_build_session_segment "$width" "$subtext0" "$status_bg")
things_segment=$(status_build_things_segment "$width" "$status_bg")
time_segment=$(status_build_time_segment "$status_bg" "$subtext0")
date_segment=$(status_build_date_segment "$status_bg" "$subtext0")
right_cap=""

printf '%s%s%s%s%s' \
  "$session_segment" \
  "$things_segment" \
  "$time_segment" \
  "$date_segment" \
  "$right_cap"
