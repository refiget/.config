#!/usr/bin/env bash

status_memory_percent() {
  local memory_percent=""

  if command -v memory_pressure >/dev/null 2>&1; then
    memory_percent=$(memory_pressure 2>/dev/null | awk '
      /System-wide memory free percentage:/ {
        gsub(/%/, "", $5)
        if ($5 ~ /^[0-9]+$/) {
          printf "%d", 100 - $5
          exit
        }
      }')
  fi

  if [[ -z "$memory_percent" ]] && command -v vm_stat >/dev/null 2>&1; then
    memory_percent=$(vm_stat 2>/dev/null | awk '
      /page size of/ {gsub(/\./, "", $8); page_size=$8}
      /^Pages free:/ {gsub(/\./, "", $3); free=$3}
      /^Pages active:/ {gsub(/\./, "", $3); active=$3}
      /^Pages inactive:/ {gsub(/\./, "", $3); inactive=$3}
      /^Pages speculative:/ {gsub(/\./, "", $3); speculative=$3}
      /^Pages wired down:/ {gsub(/\./, "", $4); wired=$4}
      /^Pages occupied by compressor:/ {gsub(/\./, "", $5); compressed=$5}
      END {
        used = active + inactive + speculative + wired + compressed
        total = used + free
        if (total > 0) {
          printf "%d", (used * 100) / total
        }
      }')
  fi

  printf '%s' "${memory_percent:-0}"
}

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

  if [[ "$rainbarf_toggle" != "1" ]]; then
    return 0
  fi

  local show_rainbarf=1
  if [[ -n "${width:-}" && "$width" =~ ^[0-9]+$ ]] && (( width < rainbarf_min_width )); then
    show_rainbarf=0
  fi
  if (( show_rainbarf != 1 )); then
    return 0
  fi

  local cpu_busy alpha prev_ema cpu_ema metric_fg metric_bg cpu_text mem_text memory_percent
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

  metric_bg=$(tmux show -gqv '@tab_bg' 2>/dev/null || true)
  [[ -z "$metric_bg" ]] && metric_bg="default"

  memory_percent=$(status_memory_percent)
  if [[ ! "$memory_percent" =~ ^[0-9]+$ ]]; then
    memory_percent="0"
  fi

  cpu_text=$(printf '󰍛 %d%%' "${cpu_ema%.*}")
  mem_text=$(printf '󰘚 %d%%' "$memory_percent")
  printf ' #[fg=%s,bg=%s]#[fg=%s,bg=%s] %s  %s #[fg=%s,bg=%s]#[default]' \
    "$metric_bg" "default" \
    "$metric_fg" "$metric_bg" \
    "$cpu_text" "$mem_text" \
    "$metric_bg" "default"
}
