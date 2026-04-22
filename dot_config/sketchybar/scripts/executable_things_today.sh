#!/usr/bin/env zsh

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux/things"
COUNTS_FILE="$CACHE_DIR/today_counts"
TITLE_FILE="$CACHE_DIR/today_title"
TITLES_FILE="$CACHE_DIR/today_titles"
STATE_FILE="$CACHE_DIR/today_state"
LOCK_DIR="$CACHE_DIR/.refresh.lock"
REFRESH_SCRIPT="$HOME/.config/tmux/scripts/status/things_today_cache.sh"
REFRESH_SEC="${TMUX_THINGS_REFRESH_SEC:-60}"
MAX_CHARS="${SKETCHYBAR_THINGS_MAX_CHARS:-25}"
ROTATE_SEC="${SKETCHYBAR_THINGS_ROTATE_SEC:-30}"

refresh_if_needed() {
  local now mtime age

  if [[ ! -x "$REFRESH_SCRIPT" ]]; then
    return 0
  fi

  if [[ -f "$COUNTS_FILE" ]]; then
    mtime=$(stat -f '%m' "$COUNTS_FILE" 2>/dev/null || echo 0)
  elif [[ -f "$STATE_FILE" ]]; then
    mtime=$(stat -f '%m' "$STATE_FILE" 2>/dev/null || echo 0)
  else
    mtime=0
  fi

  now=$(date +%s)
  age=$((now - mtime))

  if (( mtime == 0 )); then
    "$REFRESH_SCRIPT" >/dev/null 2>&1 || true
    return 0
  fi

  if (( age < REFRESH_SEC )) || [[ -d "$LOCK_DIR" ]]; then
    return 0
  fi

  "$REFRESH_SCRIPT" >/dev/null 2>&1 &
}

truncate_title() {
  local text="${1:-}"
  local limit="${2:-24}"

  text="${text//$'\r'/ }"
  text="${text//$'\n'/ }"
  text="${text//$'\t'/ }"
  text="$(printf '%s' "$text" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"

  if [[ -z "$text" ]]; then
    printf ''
    return 0
  fi

  if (( ${#text} <= limit )); then
    printf '%s' "$text"
    return 0
  fi

  printf '%s...' "${text:0:$limit}"
}

refresh_if_needed

state=""
[[ -f "$STATE_FILE" ]] && state="$(<"$STATE_FILE")"

if [[ "$state" == "error" ]]; then
  LABEL="THINGS ERR"
elif [[ -f "$TITLES_FILE" ]] && [[ -n "$(<"$TITLES_FILE")" ]]; then
  TITLES=("${(@f)$(<"$TITLES_FILE")}")
  if (( ${#TITLES[@]} > 0 )); then
    INDEX=$(( ($(date +%s) / ROTATE_SEC) % ${#TITLES[@]} ))
    TITLE="${TITLES[$INDEX]}"
    LABEL="$(truncate_title "$TITLE" "$MAX_CHARS")"
  else
    LABEL="..."
  fi
elif [[ -f "$TITLE_FILE" ]] && [[ -n "$(<"$TITLE_FILE")" ]]; then
  TITLE="$(<"$TITLE_FILE")"
  LABEL="$(truncate_title "$TITLE" "$MAX_CHARS")"
elif [[ -f "$COUNTS_FILE" ]]; then
  RAW="$(<"$COUNTS_FILE")"
  OPEN_COUNT="${RAW%%,*}"
  DONE_COUNT="${RAW#*,}"

  if [[ "$OPEN_COUNT" =~ ^[0-9]+$ ]] && [[ "$DONE_COUNT" =~ ^[0-9]+$ ]]; then
    if (( OPEN_COUNT == 0 && DONE_COUNT == 0 )); then
      LABEL="ALL DONE"
    elif (( OPEN_COUNT > 0 )); then
      LABEL="$OPEN_COUNT"
    else
      LABEL="ALL DONE"
    fi
  else
    LABEL="THINGS ERR"
  fi
else
  LABEL="..."
fi

sketchybar --set "$NAME" label="$LABEL"
