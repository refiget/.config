#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/tmux_runtime.sh
source "$script_dir/../lib/tmux_runtime.sh"

# Determine theme color from tmux environments with fallback
# Prefer session env, then global env; if unset, default differs by OS:
# 普通模式浅绿，插入模式紫色
# Catppuccin Mocha: lavender-ish base (less grey)
default_base="#b4befe"

theme_line=$(tmux show-environment TMUX_THEME_COLOR 2>/dev/null || true)
if [[ "$theme_line" == TMUX_THEME_COLOR=* ]]; then
  base_theme="${theme_line#TMUX_THEME_COLOR=}"
else
  theme_line=$(tmux show-environment -g TMUX_THEME_COLOR 2>/dev/null || true)
  if [[ "$theme_line" == TMUX_THEME_COLOR=* ]]; then
    base_theme="${theme_line#TMUX_THEME_COLOR=}"
  else
    base_theme="$default_base"
  fi
fi

is_valid_color() {
  local value="${1:-}"
  [[ -z "$value" ]] && return 1
  if [[ "$value" == "default" ]]; then
    return 0
  fi
  if [[ "$value" =~ ^colour[0-9]{1,3}$ ]]; then
    return 0
  fi
  if [[ "$value" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
    return 0
  fi
  return 1
}

if ! is_valid_color "$base_theme"; then
  base_theme="$default_base"
fi

# Theme preset (optional): allows per-scheme accents without splitting configs
preset_line=$(tmux show-environment TMUX_THEME_PRESET 2>/dev/null || tmux show-environment -g TMUX_THEME_PRESET 2>/dev/null || true)
TMUX_THEME_PRESET=""
if [[ "$preset_line" == TMUX_THEME_PRESET=* ]]; then
  TMUX_THEME_PRESET="${preset_line#TMUX_THEME_PRESET=}"
fi

if [[ "$TMUX_THEME_PRESET" == "catppuccin" ]]; then
  default_base="#a6e3a1"   # green
  insert_theme="#cba6f7"   # mauve
else
  # Insert accent: mauve
insert_theme="#cba6f7"   # purple
fi

# Mode-aware theme for active border / top labels
tmux_mode="normal"
mode_line=$(tmux show-environment TMUX_MODE 2>/dev/null || tmux show-environment -g TMUX_MODE 2>/dev/null || true)
if [[ "$mode_line" == TMUX_MODE=* ]]; then
  tmux_mode="${mode_line#TMUX_MODE=}"
fi

if [[ "$tmux_mode" == "insert" ]]; then
  theme="$insert_theme"   # insert -> purple
else
  theme="$base_theme"     # normal -> base (env or default)
fi

# Cache as a user option and apply to border style
tmux set -g @theme_color "$theme"
tmux set -g pane-active-border-style "fg=$theme"

exit 0
