#!/usr/bin/env bash
# Shared tmux runtime helpers.
# Source from scripts that need consistent socket/path selection.

TMUX_RUNTIME_PREFIX=()
if [[ -n "${TMUX_SOCKET_NAME:-}" ]]; then
  TMUX_RUNTIME_PREFIX=(-L "$TMUX_SOCKET_NAME")
elif [[ -n "${TMUX_SOCKET_PATH:-}" ]]; then
  TMUX_RUNTIME_PREFIX=(-S "$TMUX_SOCKET_PATH")
fi

# shellcheck disable=SC2317
_tmux_runtime_command() {
  command tmux "${TMUX_RUNTIME_PREFIX[@]}" "$@"
}

tmux() {
  _tmux_runtime_command "$@"
}

tmux_run() {
  tmux "$@"
}

tmux_capture() {
  tmux "$@"
}

tmux_current_target=()
if [[ -n "${TMUX_PANE:-}" ]]; then
  tmux_current_target=(-t "$TMUX_PANE")
fi

tmux_display_current() {
  tmux display-message "${tmux_current_target[@]}" -p "$1"
}

tmux_show_option_value() {
  tmux show-options -gqv "$1" 2>/dev/null || true
}

tmux_set_option_value() {
  tmux set-option -gq "$1" "$2"
}

tmux_show_environment_value() {
  local key="${1:-}"
  local line
  line=$(tmux show-environment "$key" 2>/dev/null || tmux show-environment -g "$key" 2>/dev/null || true)
  if [[ "$line" == "$key="* ]]; then
    printf '%s' "${line#*=}"
  fi
}

tmux_shell_prefix() {
  if [[ -n "${TMUX_SOCKET_NAME:-}" ]]; then
    printf 'tmux -L %q' "$TMUX_SOCKET_NAME"
  elif [[ -n "${TMUX_SOCKET_PATH:-}" ]]; then
    printf 'tmux -S %q' "$TMUX_SOCKET_PATH"
  else
    printf 'tmux'
  fi
}
