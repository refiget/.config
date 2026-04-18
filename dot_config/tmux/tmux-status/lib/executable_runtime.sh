#!/usr/bin/env bash

status_lib_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
status_repo_root="$(cd -- "$status_lib_dir/../.." && pwd)"
# shellcheck source=../../scripts/lib/tmux_runtime.sh
source "$status_repo_root/scripts/lib/tmux_runtime.sh"

status_client_width() {
  local width
  width=$(tmux display-message -p '#{client_width}' 2>/dev/null || true)
  if [[ -z "${width:-}" || "$width" == "0" ]]; then
    width=$(tmux display-message -p '#{window_width}' 2>/dev/null || true)
  fi
  if [[ -z "${width:-}" || "$width" == "0" ]]; then
    width=${COLUMNS:-}
  fi
  printf '%s' "$width"
}

status_bg_value() {
  local value
  value=$(tmux show -gqv status-bg 2>/dev/null || true)
  [[ -z "$value" || "$value" == "default" ]] && value="default"
  printf '%s' "$value"
}

status_option_or() {
  local key="${1:-}"
  local fallback="${2:-}"
  local value
  value=$(tmux show -gqv "$key" 2>/dev/null || true)
  [[ -z "$value" ]] && value="$fallback"
  printf '%s' "$value"
}
