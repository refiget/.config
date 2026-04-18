#!/usr/bin/env bash
set -euo pipefail

## iPad/remote friendly tmux mode (runtime-first, no dotfile mutation by default)
#
# off (default):
#   - runtime: TMUX_RAINBARF=0, status-right='', status-interval=60
#   - reload tmux config
# on:
#   - runtime: restore previous status-right/status-interval/rainbarf
#   - reload tmux config
#
# Usage:
#   tmux_ipad_mode.sh off      # enable low-flicker iPad mode
#   tmux_ipad_mode.sh on       # restore
#   tmux_ipad_mode.sh toggle
#   tmux_ipad_mode.sh status

cmd="${1:-off}"

CONF_FILE="${TMUX_THEME_CONF:-$HOME/.config/tmux/conf.d/08_toggle_theme.conf}"
TMUX_MAIN_CONF="${TMUX_MAIN_CONF:-$HOME/.config/tmux/tmux.conf}"

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not found" >&2
  exit 1
fi

if ! tmux info >/dev/null 2>&1; then
  echo "No tmux server/session detected. Start tmux first." >&2
  exit 1
fi

if [[ ! -f "$CONF_FILE" ]]; then
  echo "Config not found: $CONF_FILE" >&2
  exit 1
fi

key_prefix="@ipad_mode_prev"

# By default, NEVER write back to tracked dotfiles.
# Opt-in persistence: TMUX_IPAD_MODE_PERSIST=1 tmux_ipad_mode.sh <off|on|toggle>
persist_mode="${TMUX_IPAD_MODE_PERSIST:-0}"

set_persistent_rainbarf() {
  local target="$1"
  [[ "$persist_mode" == "1" ]] || return 0
  if rg -n '^set-environment -g TMUX_RAINBARF ' "$CONF_FILE" >/dev/null 2>&1; then
    sed -i '' -E "s|^set-environment -g TMUX_RAINBARF .*|set-environment -g TMUX_RAINBARF ${target}|" "$CONF_FILE"
  else
    printf '\nset-environment -g TMUX_RAINBARF %s\n' "$target" >> "$CONF_FILE"
  fi
}

reload_tmux_conf() {
  if [[ -f "$TMUX_MAIN_CONF" ]]; then
    tmux source-file "$TMUX_MAIN_CONF"
  else
    # fallback: apply minimal runtime refresh
    tmux refresh-client -S
  fi
}

show_status() {
  echo "conf_rainbarf=$(sed -n 's/^set-environment -g TMUX_RAINBARF //p' "$CONF_FILE" | tail -n1)"
  echo "persist_mode=$persist_mode"
  echo "status-interval=$(tmux show -gqv status-interval)"
  echo "status-right=$(tmux show -gqv status-right)"
  echo "TMUX_RAINBARF=$(tmux show-environment -g 2>/dev/null | sed -n 's/^TMUX_RAINBARF=//p')"
  echo "marker=$(tmux show -gqv @ipad_mode_enabled)"
}

enable_off_mode() {
  # save current values once for restore
  if [[ "$(tmux show -gqv @ipad_mode_enabled)" != "1" ]]; then
    tmux set -gq "${key_prefix}_status_interval" "$(tmux show -gqv status-interval)"
    tmux set -gq "${key_prefix}_status_right" "$(tmux show -gqv status-right)"
    tmux set -gq "${key_prefix}_rainbarf" "$(tmux show-environment -g 2>/dev/null | sed -n 's/^TMUX_RAINBARF=//p')"
  fi

  set_persistent_rainbarf 0
  tmux set-environment -g TMUX_RAINBARF 0
  tmux set -g status-interval 60
  tmux set -g status-right ""
  tmux set -gq @ipad_mode_enabled 1

  reload_tmux_conf
  tmux refresh-client -S
  echo "iPad mode ON: runtime TMUX_RAINBARF=0, status-right='', status-interval=60"
}

restore_on_mode() {
  local prev_interval prev_right prev_rainbarf
  prev_interval="$(tmux show -gqv "${key_prefix}_status_interval")"
  prev_right="$(tmux show -gqv "${key_prefix}_status_right")"
  prev_rainbarf="$(tmux show -gqv "${key_prefix}_rainbarf")"

  set_persistent_rainbarf 1

  [[ -n "$prev_interval" ]] && tmux set -g status-interval "$prev_interval" || tmux set -g status-interval 15
  tmux set -g status-right "${prev_right:-#(~/.config/tmux/tmux-status/right.sh)}"

  if [[ -n "$prev_rainbarf" ]]; then
    tmux set-environment -g TMUX_RAINBARF "$prev_rainbarf"
  else
    tmux set-environment -g TMUX_RAINBARF 1
  fi

  tmux set -gu "${key_prefix}_status_interval" || true
  tmux set -gu "${key_prefix}_status_right" || true
  tmux set -gu "${key_prefix}_rainbarf" || true
  tmux set -gu @ipad_mode_enabled || true

  reload_tmux_conf
  tmux refresh-client -S
  echo "iPad mode OFF: restored runtime bar/interval"
}

case "$cmd" in
  off)
    enable_off_mode
    ;;
  on)
    restore_on_mode
    ;;
  toggle)
    if [[ "$(tmux show -gqv @ipad_mode_enabled)" == "1" ]]; then
      restore_on_mode
    else
      enable_off_mode
    fi
    ;;
  status)
    show_status
    ;;
  *)
    echo "Usage: $0 {off|on|toggle|status}" >&2
    exit 2
    ;;
esac
