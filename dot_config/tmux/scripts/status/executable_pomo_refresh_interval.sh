#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/tmux_runtime.sh
source "$script_dir/../lib/tmux_runtime.sh"

# Set tmux status-interval dynamically:
# - 1s while a pomodoro is active (@pomo_until_epoch in the future)
# - otherwise 2s (calmer + less churn)

active_interval=${TMUX_POMO_ACTIVE_INTERVAL:-1}
idle_interval=${TMUX_POMO_IDLE_INTERVAL:-2}

now=$(date +%s)
until=$(tmux show -gqv '@pomo_until_epoch' 2>/dev/null || true)

interval="$idle_interval"
if [[ -n "${until:-}" && "$until" =~ ^[0-9]+$ ]]; then
  if (( now < until )); then
    interval="$active_interval"
  fi
fi

tmux set -g status-interval "$interval" >/dev/null 2>&1 || true
