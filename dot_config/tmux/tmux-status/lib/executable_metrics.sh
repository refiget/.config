#!/usr/bin/env bash

status_build_rainbarf_segment() {
  local width="${1:-}"
  local segment_fg="${2:-#6c7086}"

  local rainbarf_toggle="${TMUX_RAINBARF:-1}"
  local rainbarf_min_width="${TMUX_RAINBARF_MIN_WIDTH:-120}"
  local rainbarf_width="${TMUX_RAINBARF_WIDTH:-18}"

  case "$rainbarf_toggle" in
    0|false|FALSE|off|OFF|no|NO)
      rainbarf_toggle="0"
      ;;
    *)
      rainbarf_toggle="1"
      ;;
  esac

  if [[ "$rainbarf_toggle" != "1" ]] || ! command -v rainbarf >/dev/null 2>&1; then
    return 0
  fi

  local show_rainbarf=1
  if [[ -n "${width:-}" && "$width" =~ ^[0-9]+$ ]] && (( width < rainbarf_min_width )); then
    show_rainbarf=0
  fi
  if (( show_rainbarf != 1 )); then
    return 0
  fi

  local cpu_busy alpha prev_ema cpu_ema metric_fg rainbarf_output
  cpu_busy=$(top -l 1 -n 0 2>/dev/null | awk -F'[:,% ]+' '/CPU usage/ {print $3; exit}')
  if [[ ! "$cpu_busy" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    cpu_busy="0"
  fi

  alpha="${TMUX_RAINBARF_SMOOTHING:-0.30}"
  prev_ema=$(tmux show -gqv '@cpu_ema' 2>/dev/null || true)
  if [[ ! "$prev_ema" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    prev_ema="$cpu_busy"
  fi
  cpu_ema=$(awk -v a="$alpha" -v c="$cpu_busy" -v p="$prev_ema" 'BEGIN {printf "%.2f", (a*c)+((1-a)*p)}')
  tmux set -gq @cpu_ema "$cpu_ema"

  metric_fg="$segment_fg"
  if awk "BEGIN {exit !($cpu_ema >= 90)}"; then
    metric_fg="#f38ba8"
  elif awk "BEGIN {exit !($cpu_ema >= 75)}"; then
    metric_fg="#fab387"
  elif awk "BEGIN {exit !($cpu_ema >= 60)}"; then
    metric_fg="#f9e2af"
  elif awk "BEGIN {exit !($cpu_ema >= 45)}"; then
    metric_fg="#a6e3a1"
  elif awk "BEGIN {exit !($cpu_ema >= 30)}"; then
    metric_fg="#89dceb"
  else
    metric_fg="#6c7086"
  fi

  rainbarf_output=$(rainbarf --tmux --width "$rainbarf_width" --no-battery --no-remaining --no-bolt --no-rgb --fg colour244 2>/dev/null || true)
  rainbarf_output=${rainbarf_output//$'\n'/}
  if [[ -n "$rainbarf_output" ]]; then
    printf '#[fg=%s] %s #[default]' "$metric_fg" "$rainbarf_output"
  fi
}
