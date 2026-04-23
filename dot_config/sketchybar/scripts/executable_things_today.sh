#!/usr/bin/env zsh

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux/things"
COUNTS_FILE="$CACHE_DIR/today_counts"
TITLE_FILE="$CACHE_DIR/today_title"
TITLES_FILE="$CACHE_DIR/today_titles"
STATE_FILE="$CACHE_DIR/today_state"
LOCK_DIR="$CACHE_DIR/.refresh.lock"
REFRESH_SCRIPT="$HOME/.config/tmux/scripts/status/things_today_cache.sh"

# The refresh script now populates these cache files via `things.py`.
REFRESH_SEC="${TMUX_THINGS_REFRESH_SEC:-60}"
LOCK_STALE_SEC="${TMUX_THINGS_LOCK_STALE_SEC:-300}"
MAX_CHARS="${SKETCHYBAR_THINGS_MAX_CHARS:-25}"
ROTATE_SEC="${SKETCHYBAR_THINGS_ROTATE_SEC:-30}"

# Validate numeric parameters
if [[ ! "$ROTATE_SEC" =~ ^[0-9]+$ ]] || (( ROTATE_SEC <= 0 )); then
  ROTATE_SEC=30
fi
if [[ ! "$LOCK_STALE_SEC" =~ ^[0-9]+$ ]] || (( LOCK_STALE_SEC <= 0 )); then
  LOCK_STALE_SEC=300
fi
if [[ ! "$REFRESH_SEC" =~ ^[0-9]+$ ]] || (( REFRESH_SEC <= 0 )); then
  REFRESH_SEC=60
fi
if [[ ! "$MAX_CHARS" =~ ^[0-9]+$ ]] || (( MAX_CHARS <= 0 )); then
  MAX_CHARS=25
fi

# Ensure cache directory exists
[[ -d "$CACHE_DIR" ]] || mkdir -p "$CACHE_DIR" 2>/dev/null || true

NOW=$(date +%s)

clear_stale_lock() {
  local now lock_mtime lock_age

  if [[ ! -d "$LOCK_DIR" ]]; then
    return 0
  fi

  lock_mtime=$(stat -f '%m' "$LOCK_DIR" 2>/dev/null || echo 0)
  now=$(date +%s)
  lock_age=$((now - lock_mtime))

  if (( lock_mtime == 0 )) || (( lock_age >= LOCK_STALE_SEC )); then
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}

refresh_if_needed() {
  local now mtime age

  if [[ ! -x "$REFRESH_SCRIPT" ]]; then
    return 0
  fi

  clear_stale_lock

  # If REFRESH_SCRIPT is already running, don't pile up concurrent refreshes
  if [[ -d "$LOCK_DIR" ]]; then
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
    "$REFRESH_SCRIPT" >/dev/null 2>&1 &
    return 0
  fi

  if (( age < REFRESH_SEC )); then
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
  text="${text//\"/\\\"}"
  text="$(printf '%s' "$text" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"

  if [[ -z "$text" ]]; then
    printf ''
    return 0
  fi

  if (( limit <= 0 )); then
    printf '...'
    return 0
  fi

  if (( ${#text} <= limit )); then
    printf '%s' "$text"
    return 0
  fi

  printf '%s...' "${text:0:$limit}"
}

# Pre-compute data file age to throttle refresh frequency
data_mtime=0
if [[ -f "$COUNTS_FILE" ]]; then
  data_mtime=$(stat -f '%m' "$COUNTS_FILE" 2>/dev/null || echo 0)
elif [[ -f "$STATE_FILE" ]]; then
  data_mtime=$(stat -f '%m' "$STATE_FILE" 2>/dev/null || echo 0)
fi
data_age=$(( NOW - data_mtime ))
(( data_age < 0 )) && data_age=0

SHOULD_REFRESH=0

state=""
if [[ -f "$STATE_FILE" ]]; then
  read -r state < "$STATE_FILE" 2>/dev/null || state=""
fi

if [[ "$state" == "error" ]]; then
  LABEL="THINGS ERR"
  SHOULD_REFRESH=1
elif [[ -f "$TITLES_FILE" ]] && [[ -s "$TITLES_FILE" ]]; then
  TITLES=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
    TITLES+=("$line")
  done < "$TITLES_FILE"

  if (( ${#TITLES[@]} > 0 )); then
    INDEX=$(( ((NOW / ROTATE_SEC) % ${#TITLES[@]}) + 1 ))
    TITLE="${TITLES[$INDEX]}"
    LABEL="$(truncate_title "$TITLE" "$MAX_CHARS")"
    if (( INDEX == ${#TITLES[@]} )) && (( data_mtime == 0 || data_age >= REFRESH_SEC )); then
      SHOULD_REFRESH=1
    fi
  else
    LABEL="ALL DONE !"
    SHOULD_REFRESH=1
  fi
elif [[ -f "$TITLE_FILE" ]] && [[ -s "$TITLE_FILE" ]]; then
  TITLE="$(<"$TITLE_FILE")"
  LABEL="$(truncate_title "$TITLE" "$MAX_CHARS")"
  SHOULD_REFRESH=1
elif [[ -f "$COUNTS_FILE" ]]; then
  LABEL="ALL DONE !"
  SHOULD_REFRESH=1
else
  LABEL="ALL DONE !"
  SHOULD_REFRESH=1
fi

if [[ -z "${LABEL//[[:space:]]/}" ]]; then
  LABEL="ALL DONE !"
fi

sketchybar --set "$NAME" label="$LABEL"

if (( SHOULD_REFRESH == 1 )); then
  refresh_if_needed
fi
