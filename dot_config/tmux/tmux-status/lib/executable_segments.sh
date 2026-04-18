#!/usr/bin/env bash

status_build_session_segment() {
  local width="${1:-}"
  local subtext0="${2:-#a6adc8}"

  local show_session=1
  local session_min_width="${TMUX_SESSION_RIGHT_MIN_WIDTH:-105}"
  if [[ -n "${width:-}" && "$width" =~ ^[0-9]+$ ]] && (( width < session_min_width )); then
    show_session=0
  fi
  if (( show_session != 1 )); then
    return 0
  fi

  local current_session_name session_name_clean session_idx
  current_session_name=$(tmux display-message -p '#{session_name}' 2>/dev/null || true)
  session_name_clean="$current_session_name"
  session_idx=""

  if [[ "$current_session_name" =~ ^([0-9]+)__(.*)$ ]]; then
    session_idx="${BASH_REMATCH[1]}"
    session_name_clean="${BASH_REMATCH[2]}"
  elif [[ "$current_session_name" =~ ^([0-9]+)[:_-](.*)$ ]]; then
    session_idx="${BASH_REMATCH[1]}"
    session_name_clean="${BASH_REMATCH[2]}"
  fi
  session_name_clean=${session_name_clean:-$current_session_name}

  local session_icons_csv session_icon display_idx arr_index mapped_icon
  session_icons_csv="${TMUX_SESSION_ICONS:-}"
  session_icon="1"
  display_idx="1"

  if [[ -n "$session_idx" && "$session_idx" =~ ^[0-9]+$ ]]; then
    display_idx="$session_idx"
  fi

  if [[ -n "$session_icons_csv" ]]; then
    local -a session_icons_arr
    IFS=',' read -r -a session_icons_arr <<< "$session_icons_csv"
    arr_index=0
    if [[ -n "$session_idx" && "$session_idx" =~ ^[0-9]+$ ]] && (( session_idx >= 1 )); then
      arr_index=$((session_idx - 1))
    fi
    if (( arr_index < ${#session_icons_arr[@]} )); then
      mapped_icon="${session_icons_arr[$arr_index]}"
      if [[ -n "$mapped_icon" ]]; then
        session_icon="$mapped_icon"
      else
        session_icon="$display_idx"
      fi
    else
      session_icon="$display_idx"
    fi
  else
    session_icon="$display_idx"
  fi

  local session_fg session_bg max_slen
  session_fg=$(status_option_or '@session_label_fg' "$subtext0")
  session_bg=$(status_option_or '@session_label_bg' '')

  max_slen=${TMUX_SESSION_RIGHT_MAXLEN:-12}
  if (( ${#session_name_clean} > max_slen )); then
    session_name_clean="${session_name_clean:0:max_slen-1}…"
  fi

  if [[ -n "$session_bg" ]]; then
    printf '#[fg=%s,bg=%s] %s %s #[default]' "$session_fg" "$session_bg" "$session_icon" "$session_name_clean"
  else
    printf '#[fg=%s] %s %s #[default]' "$session_fg" "$session_icon" "$session_name_clean"
  fi
}

status_build_time_segment() {
  local status_bg="${1:-default}"
  local fallback_fg="${2:-#a6adc8}"
  local time_value time_fg time_bg

  time_value=$(date +"${TMUX_TIME_ONLY_FMT:-%H:%M}")
  time_fg=$(status_option_or '@time_fg' "$fallback_fg")
  time_bg=$(status_option_or '@time_bg' "$status_bg")
  printf '#[fg=%s,bg=%s] %s #[default]' "$time_fg" "$time_bg" "$time_value"
}

status_build_date_segment() {
  local status_bg="${1:-default}"
  local fallback_fg="${2:-#a6adc8}"
  local date_value date_fg date_bg

  date_value=$(date +"${TMUX_DATE_ONLY_FMT:-%m-%d}")
  date_fg=$(status_option_or '@date_fg' "$fallback_fg")
  date_bg=$(status_option_or '@date_bg' "$status_bg")
  printf '#[fg=%s,bg=%s] %s #[default]' "$date_fg" "$date_bg" "$date_value"
}
