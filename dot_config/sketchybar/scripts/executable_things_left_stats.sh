#!/usr/bin/env zsh

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux/things"
COUNTS_FILE="${THINGS_LEFT_COUNTS_FILE:-$CACHE_DIR/left_counts}"
STATE_FILE="$CACHE_DIR/today_state"
LOCK_DIR="$CACHE_DIR/.refresh.lock"
REFRESH_SCRIPT="${THINGS_REFRESH_SCRIPT:-$HOME/.config/tmux/scripts/status/things_today_cache.sh}"
REFRESH_SEC="${TMUX_THINGS_REFRESH_SEC:-60}"
LOCK_STALE_SEC="${TMUX_THINGS_LOCK_STALE_SEC:-300}"

# Fallback defaults for static mode or early startup before the first sync.
DEFAULT_INBOX="${THINGS_LEFT_INBOX_DEFAULT:-0}"
DEFAULT_TODAY="${THINGS_LEFT_TODAY_DEFAULT:-0}"
DEFAULT_SOMEDAY="${THINGS_LEFT_SOMEDAY_DEFAULT:-0}"

normalize_count() {
  local value="${1:-}"
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    printf '%s' "$value"
  else
    printf '0'
  fi
}

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

  if (( mtime == 0 || age >= REFRESH_SEC )); then
    "$REFRESH_SCRIPT" >/dev/null 2>&1 &
  fi
}

refresh_if_needed

inbox="${THINGS_INBOX_COUNT:-}"
today="${THINGS_TODAY_COUNT:-${THINGS_STAR_COUNT:-}}"
someday="${THINGS_SOMEDAY_COUNT:-${THINGS_STACK_COUNT:-}}"

# Interface 1: env vars
if [[ -n "$inbox" || -n "$today" || -n "$someday" ]]; then
  inbox="$(normalize_count "${inbox:-$DEFAULT_INBOX}")"
  today="$(normalize_count "${today:-$DEFAULT_TODAY}")"
  someday="$(normalize_count "${someday:-$DEFAULT_SOMEDAY}")"
else
  # Interface 2: cache file with CSV format: inbox,today,someday
  if [[ -f "$COUNTS_FILE" ]]; then
    raw="$(<"$COUNTS_FILE")"
    raw="${raw//$'\n'/}"
    raw="${raw//$'\r'/}"
    raw="${raw//[[:space:]]/}"
    if [[ "$raw" =~ ^[0-9]+,[0-9]+,[0-9]+$ ]]; then
      inbox="$(normalize_count "${raw%%,*}")"
      rest="${raw#*,}"
      today="$(normalize_count "${rest%%,*}")"
      someday="$(normalize_count "${rest#*,}")"
    else
      inbox="$(normalize_count "$DEFAULT_INBOX")"
      today="$(normalize_count "$DEFAULT_TODAY")"
      someday="$(normalize_count "$DEFAULT_SOMEDAY")"
    fi
  else
    inbox="$(normalize_count "$DEFAULT_INBOX")"
    today="$(normalize_count "$DEFAULT_TODAY")"
    someday="$(normalize_count "$DEFAULT_SOMEDAY")"
  fi
fi

sketchybar --set things_left_inbox label="$inbox" \
  --set things_left_star label="$today" \
  --set things_left_stack label="$someday"
