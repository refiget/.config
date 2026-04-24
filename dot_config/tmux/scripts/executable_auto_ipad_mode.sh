#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/tmux_runtime.sh
source "$script_dir/lib/tmux_runtime.sh"

# Auto-toggle iPad (low-flicker) tmux bar mode based on SSH tmux clients.
# Single-iPad-friendly behavior:
# - when an SSH tmux client attaches -> enable iPad mode (off)
# - when last SSH tmux client detaches -> restore normal mode (on)

event="${1:-}"
client_tty="${2:-}"
ipad_script="${HOME}/dotfiles/scripts/tmux_ipad_mode.sh"

have() {
  command -v "$1" >/dev/null 2>&1
}

# On macOS, `who` includes remote host in parentheses for SSH sessions.
# Example: "mac ttys012 Apr 2 04:35 (127.0.0.1)"
is_ssh_tty_via_who() {
  local tty="${1:-}" short
  [[ -n "$tty" ]] || return 1
  short="${tty#/dev/}"

  # shellcheck disable=SC2016
  who | awk -v t="$short" '$2==t && $0 ~ /\(.*\)$/ {found=1} END{exit found?0:1}'
}

# Fallback: check process ancestry for sshd
is_ssh_tty_via_ps() {
  local tty="${1:-}"
  [[ -n "$tty" ]] || return 1

  local pids pid cur ppid comm
  pids=$(ps -t "${tty#/dev/}" -o pid= 2>/dev/null | tr -s ' ' '\n' | sed '/^$/d' || true)
  [[ -n "$pids" ]] || return 1

  for pid in $pids; do
    cur="$pid"
    while [[ -n "$cur" && "$cur" != "0" ]]; do
      comm=$(ps -p "$cur" -o comm= 2>/dev/null | awk '{print $1}' || true)
      if [[ "$comm" == "sshd" ]]; then
        return 0
      fi
      ppid=$(ps -p "$cur" -o ppid= 2>/dev/null | tr -d ' ' || true)
      [[ -n "$ppid" ]] || break
      cur="$ppid"
    done
  done
  return 1
}

is_ssh_tty() {
  local tty="${1:-}"
  is_ssh_tty_via_who "$tty" || is_ssh_tty_via_ps "$tty"
}

has_any_ssh_client() {
  local tty
  while IFS= read -r tty; do
    [[ -n "$tty" ]] || continue
    if is_ssh_tty "$tty"; then
      return 0
    fi
  done < <(tmux list-clients -F '#{client_tty}' 2>/dev/null || true)
  return 1
}

run_ipad_mode() {
  local mode="$1"
  [[ -x "$ipad_script" ]] || return 0
  "$ipad_script" "$mode" >/dev/null 2>&1 || true
}

if ! have tmux; then
  exit 0
fi

case "$event" in
  attached)
    if is_ssh_tty "$client_tty"; then
      run_ipad_mode off
    fi
    ;;
  detached)
    if has_any_ssh_client; then
      :
    else
      run_ipad_mode on
    fi
    ;;
  *)
    ;;
esac

exit 0
