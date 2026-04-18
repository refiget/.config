#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/tmux_runtime.sh
source "$script_dir/lib/tmux_runtime.sh"

read_clipboard() {
  if command -v pbpaste >/dev/null 2>&1; then
    env LANG="${LANG:-en_US.UTF-8}" LC_CTYPE="${LC_CTYPE:-en_US.UTF-8}" pbpaste
    return 0
  fi
  if command -v wl-paste >/dev/null 2>&1; then
    wl-paste --no-newline 2>/dev/null || wl-paste
    return 0
  fi
  if command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -o 2>/dev/null || true
    return 0
  fi
  if command -v xsel >/dev/null 2>&1; then
    xsel -o --clipboard 2>/dev/null || true
    return 0
  fi
  if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command Get-Clipboard 2>/dev/null || true
    return 0
  fi
  return 1
}

content=$(read_clipboard || true)
if [[ -z "${content:-}" ]]; then
  exit 0
fi


tmux set-buffer -- "$content"
tmux paste-buffer -p -d

