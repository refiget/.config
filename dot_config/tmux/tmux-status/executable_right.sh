#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/runtime.sh
source "$script_dir/lib/runtime.sh"
# shellcheck source=lib/segments.sh
source "$script_dir/lib/segments.sh"
# shellcheck source=lib/things.sh
source "$script_dir/lib/things.sh"

REFRESH_SCRIPT="${HOME}/.config/opencode/hooks/billing-refresh.sh"
"$REFRESH_SCRIPT" >/dev/null 2>&1 &

width=$(status_client_width)

session_segment=$(status_build_session_segment "$width")
time_segment=$(status_build_time_segment)
billing_raw='$00.00'
opencode_cache_dir="${OPENCODE_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/opencode}"
mkdir -p "$opencode_cache_dir" >/dev/null 2>&1 || true
balance_cache="${opencode_cache_dir}/n1n_balance.json"
daily_cache="${opencode_cache_dir}/n1n_daily_usage.json"
daily_raw='-$0.00 [0]'
if command -v jq >/dev/null 2>&1 && [[ -r "$balance_cache" ]]; then
  usage_raw="$(jq -r '.usage // empty' "$balance_cache" 2>/dev/null | head -n 1)"
  if [[ -n "${usage_raw:-}" ]]; then
    usage_fmt="$(awk -v u="$usage_raw" 'BEGIN { printf "%.2f", u / 100 }' 2>/dev/null)"
    if [[ -n "${usage_fmt:-}" ]]; then
      billing_raw="\$${usage_fmt}"
    fi
  fi
fi
if command -v jq >/dev/null 2>&1 && [[ -r "$daily_cache" ]]; then
  daily_spent_raw="$(jq -r '.spent_today // empty' "$daily_cache" 2>/dev/null | head -n 1)"
  daily_count_raw="$(jq -r '.count // empty' "$daily_cache" 2>/dev/null | head -n 1)"
  if [[ -n "${daily_spent_raw:-}" ]]; then
    daily_spent_fmt="$(awk -v u="$daily_spent_raw" 'BEGIN { printf "%.2f", u / 100 }' 2>/dev/null)"
    if [[ -n "${daily_spent_fmt:-}" ]]; then
      daily_count_raw="${daily_count_raw:-0}"
      daily_raw="-\$${daily_spent_fmt} [${daily_count_raw}]"
    fi
  fi
fi
billing_segment="#[fg=#ffffff,bold,italics]${billing_raw}#[default]"
extra_segment="#[fg=#f2a6a6,bold,italics]${daily_raw}#[default]"
right_cap=""

printf '%s  %s  %s  %s%s' \
  "$session_segment" \
  "$billing_segment" \
  "$extra_segment" \
  "$time_segment" \
  "$right_cap"
