#!/usr/bin/env zsh

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux/things"
COUNTS_FILE="$CACHE_DIR/today_counts"
TITLE_FILE="$CACHE_DIR/today_title"
TITLES_FILE="$CACHE_DIR/today_titles"
STATE_FILE="$CACHE_DIR/today_state"
LOCK_DIR="$CACHE_DIR/.refresh.lock"
REFRESH_SCRIPT="$HOME/.config/tmux/scripts/status/things_today_cache.sh"
REFRESH_SEC="${TMUX_THINGS_REFRESH_SEC:-60}"
LOCK_STALE_SEC="${TMUX_THINGS_LOCK_STALE_SEC:-300}"
MAX_CHARS="${SKETCHYBAR_THINGS_MAX_CHARS:-25}"
ROTATE_SEC="${SKETCHYBAR_THINGS_ROTATE_SEC:-30}"
if [[ ! "$ROTATE_SEC" =~ ^[0-9]+$ ]] || (( ROTATE_SEC <= 0 )); then
  ROTATE_SEC=30
fi
if [[ ! "$LOCK_STALE_SEC" =~ ^[0-9]+$ ]] || (( LOCK_STALE_SEC <= 0 )); then
  LOCK_STALE_SEC=300
fi

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

label_from_counts() {
  local raw open_count done_count

  if [[ ! -f "$COUNTS_FILE" ]]; then
    printf '...'
    return 0
  fi

  raw="$(<"$COUNTS_FILE")"
  open_count="${raw%%,*}"
  done_count="${raw#*,}"

  if [[ "$open_count" =~ ^[0-9]+$ ]] && [[ "$done_count" =~ ^[0-9]+$ ]]; then
    if (( open_count == 0 && done_count == 0 )); then
      printf 'ALL DONE'
    elif (( open_count > 0 )); then
      printf '%s' "$open_count"
    else
      printf 'ALL DONE'
    fi
  else
    printf 'THINGS ERR'
  fi
}

SHOULD_REFRESH=0

state=""
[[ -f "$STATE_FILE" ]] && state="$(<"$STATE_FILE")"

if [[ "$state" == "error" ]]; then
  LABEL="THINGS ERR"
  SHOULD_REFRESH=1
elif [[ -f "$TITLES_FILE" ]] && [[ -n "$(<"$TITLES_FILE")" ]]; then
  TITLES=()
  while IFS= read -r line; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
    TITLES+=("$line")
  done < "$TITLES_FILE"

  if (( ${#TITLES[@]} > 0 )); then
    INDEX=$(( (($(date +%s) / ROTATE_SEC) % ${#TITLES[@]}) + 1 ))
    TITLE="${TITLES[$INDEX]}"
    LABEL="$(truncate_title "$TITLE" "$MAX_CHARS")"
    if (( INDEX == ${#TITLES[@]} )); then
      SHOULD_REFRESH=1
    fi
    if [[ -z "${LABEL//[[:space:]]/}" ]]; then
      LABEL="$(label_from_counts)"
    fi
  else
    LABEL="$(label_from_counts)"
    SHOULD_REFRESH=1
  fi
elif [[ -f "$TITLE_FILE" ]] && [[ -n "$(<"$TITLE_FILE")" ]]; then
  TITLE="$(<"$TITLE_FILE")"
  LABEL="$(truncate_title "$TITLE" "$MAX_CHARS")"
  SHOULD_REFRESH=1
  if [[ -z "${LABEL//[[:space:]]/}" ]]; then
    LABEL="$(label_from_counts)"
  fi
elif [[ -f "$COUNTS_FILE" ]]; then
  LABEL="$(label_from_counts)"
  SHOULD_REFRESH=1
else
  LABEL="..."
  SHOULD_REFRESH=1
fi

if [[ -z "${LABEL//[[:space:]]/}" ]]; then
  LABEL="..."
fi

sketchybar --set "$NAME" label="$LABEL"

if (( SHOULD_REFRESH == 1 )); then
  refresh_if_needed
fi
