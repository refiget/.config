#!/usr/bin/env bash

set -u

STATE_FILE="/tmp/opencode_provider_state.json"
BALANCE_CACHE_FILE="/tmp/n1n_balance.json"
DAILY_CACHE_FILE="/tmp/n1n_daily_usage.json"
LOCK_DIR="/tmp/n1n_balance.lock"
LOCK_STALE_SECONDS="${LOCK_STALE_SECONDS:-30}"
CACHE_TTL="${CACHE_TTL:-0}"
SIGNAL_HANDLER="${HOME}/.config/opencode/hooks/opencode-signal.sh"
TARGET_PROVIDERS=("n1n_relay")
TARGET_MODELS=("claude-sonnet-4-6" "claude-haiku-4-5")

event="${OPENCODE_EVENT:-}"
provider="${OPENCODE_PROVIDER:-${PROVIDER:-${OPENCODE_PROVIDER_ID:-${PROVIDER_ID:-}}}}"
model="${OPENCODE_MODEL:-${OPENCODE_MODEL_ID:-${MODEL:-${MODEL_ID:-}}}}"
session_id="${OPENCODE_SESSION_ID:-${SESSION_ID:-}}"

is_event() {
  case "${1:-}" in
    idle|active|model-change) return 0 ;;
    *) return 1 ;;
  esac
}

shell_quote() {
  local value="${1:-}"
  printf "'%s'" "${value//\'/\'\\\'\'}"
}

lookup_display() {
  case "$1" in
    claude-sonnet-4-6) printf '%s\n' "Claude Sonnet 4.6" ;;
    claude-haiku-4-5) printf '%s\n' "Claude Haiku 4.5" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

fetch_usage_raw() {
  [ -n "${N1N_RELAY_API_KEY:-}" ] || return 1
  command -v curl >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1

  curl -s --max-time 8 "https://api.n1n.ai/v1/dashboard/billing/usage" \
    -H "Authorization: Bearer ${N1N_RELAY_API_KEY}" 2>/dev/null \
    | jq -r '.total_usage // empty' 2>/dev/null \
    | head -n 1
}

read_cached_usage() {
  cached_usage=""
  cached_timestamp=""
  [ -r "$BALANCE_CACHE_FILE" ] || return 1

  command -v jq >/dev/null 2>&1 || return 1
  cached_usage="$(jq -r '.usage // empty' "$BALANCE_CACHE_FILE" 2>/dev/null | head -n 1)"
  cached_timestamp="$(jq -r '.timestamp // empty' "$BALANCE_CACHE_FILE" 2>/dev/null | head -n 1)"
  [[ "${cached_usage:-}" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
  [[ "${cached_timestamp:-}" =~ ^[0-9]+$ ]] || cached_timestamp=0
  return 0
}

cache_is_fresh() {
  local now age
  [[ "${cached_timestamp:-}" =~ ^[0-9]+$ ]] || return 1
  now="$(date +%s)"
  age=$((now - cached_timestamp))
  [ "$age" -ge 0 ] || return 1
  [ "$age" -lt "$CACHE_TTL" ]
}

get_mtime() {
  local path="$1"
  stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null
}

acquire_lock() {
  local now mtime age
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    return 0
  fi

  now="$(date +%s)"
  mtime="$(get_mtime "$LOCK_DIR" || printf '0')"
  case "$mtime" in
    ''|*[!0-9]*) mtime=0 ;;
  esac
  age=$((now - mtime))
  if [ "$age" -gt "$LOCK_STALE_SECONDS" ]; then
    rm -rf "$LOCK_DIR" 2>/dev/null || true
    mkdir "$LOCK_DIR" 2>/dev/null && return 0
  fi
  return 1
}

release_lock() {
  rm -rf "$LOCK_DIR" 2>/dev/null || true
}

write_usage_cache() {
  local usage="${1:-}"
  local tmp_file
  local now
  tmp_file="$(mktemp "${BALANCE_CACHE_FILE}.XXXXXX")" || return 0
  now="$(date +%s)"
  if [[ "${usage:-}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf '{"timestamp":%s,"usage":%s}\n' "$now" "$usage" > "$tmp_file" 2>/dev/null || {
      rm -f "$tmp_file"
      return 0
    }
  else
    printf '{"timestamp":%s}\n' "$now" > "$tmp_file" 2>/dev/null || {
      rm -f "$tmp_file"
      return 0
    }
  fi
  mv "$tmp_file" "$BALANCE_CACHE_FILE" 2>/dev/null || rm -f "$tmp_file"
}

read_daily_cache() {
  daily_date=""
  daily_start_usage=""
  daily_last_usage=""
  daily_spent=""
  daily_count=""
  [ -r "$DAILY_CACHE_FILE" ] || return 1

  command -v jq >/dev/null 2>&1 || return 1
  daily_date="$(jq -r '.date // empty' "$DAILY_CACHE_FILE" 2>/dev/null | head -n 1)"
  daily_start_usage="$(jq -r '.start_usage // empty' "$DAILY_CACHE_FILE" 2>/dev/null | head -n 1)"
  daily_last_usage="$(jq -r '.last_usage // empty' "$DAILY_CACHE_FILE" 2>/dev/null | head -n 1)"
  daily_spent="$(jq -r '.spent_today // empty' "$DAILY_CACHE_FILE" 2>/dev/null | head -n 1)"
  daily_count="$(jq -r '.count // empty' "$DAILY_CACHE_FILE" 2>/dev/null | head -n 1)"

  [[ "${daily_date:-}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 1
  [[ "${daily_start_usage:-}" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
  [[ "${daily_last_usage:-}" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
  [[ "${daily_spent:-}" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
  [[ "${daily_count:-}" =~ ^[0-9]+$ ]] || return 1
  return 0
}

write_daily_cache() {
  local current_usage="${1:-}"
  local today now tmp_file delta
  local start_usage last_usage spent_today count
  today="$(date +%F)"
  now="$(date +%s)"
  tmp_file="$(mktemp "${DAILY_CACHE_FILE}.XXXXXX")" || return 0

  if read_daily_cache && [ "$daily_date" = "$today" ]; then
    start_usage="$daily_start_usage"
    last_usage="$daily_last_usage"
    spent_today="$daily_spent"
    count="$daily_count"
  else
    start_usage="$current_usage"
    last_usage="$current_usage"
    spent_today="0"
    count="0"
  fi

  delta="$(awk -v cur="$current_usage" -v last="$last_usage" 'BEGIN { d=cur-last; if (d>0) printf "%.10f", d; else printf "0" }' 2>/dev/null)"
  if awk -v d="$delta" 'BEGIN { exit !(d>0) }' 2>/dev/null; then
    spent_today="$(awk -v s="$spent_today" -v d="$delta" 'BEGIN { printf "%.10f", s+d }' 2>/dev/null)"
    count=$((count + 1))
  fi
  last_usage="$current_usage"

  printf '{"date":"%s","start_usage":%s,"last_usage":%s,"spent_today":%s,"count":%s,"timestamp":%s}\n' \
    "$today" "$start_usage" "$last_usage" "$spent_today" "$count" "$now" > "$tmp_file" 2>/dev/null || {
    rm -f "$tmp_file"
    return 0
  }
  mv "$tmp_file" "$DAILY_CACHE_FILE" 2>/dev/null || rm -f "$tmp_file"
}

resolve_from_logs() {
  local sid="$1"
  [ -n "$sid" ] || return 1
  command -v rg >/dev/null 2>&1 || return 1
  command -v awk >/dev/null 2>&1 || return 1

  local line
  line="$(rg --no-filename "service=llm .*providerID=n1n_relay .*session\\.id=${sid}" "${HOME}/.local/share/opencode/log/"*.log 2>/dev/null | tail -n 1)"
  if [ -z "$line" ]; then
    line="$(rg --no-filename "service=llm .*session\\.id=${sid}" "${HOME}/.local/share/opencode/log/"*.log 2>/dev/null | tail -n 1)"
  fi
  [ -n "$line" ] || return 1

  if [ -z "${provider:-}" ]; then
    provider="$(printf '%s\n' "$line" | awk '{for (i=1; i<=NF; i++) if ($i ~ /^providerID=/) {sub(/^providerID=/,"",$i); print $i; exit}}')"
  fi
  if [ -z "${model:-}" ]; then
    model="$(printf '%s\n' "$line" | awk '{for (i=1; i<=NF; i++) if ($i ~ /^modelID=/) {sub(/^modelID=/,"",$i); print $i; exit}}')"
  fi
}

write_state() {
  local usage="${1:-}"
  local tmp_file
  local now
  tmp_file="$(mktemp "${STATE_FILE}.XXXXXX")" || return 0
  now="$(date +%s)"
  if [[ "${usage:-}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf '{"event":"%s","provider":"%s","model":"%s","display":"%s","usage":%s,"timestamp":%s}\n' \
      "$event" "$provider" "$model" "$display" "$usage" "$now" > "$tmp_file" 2>/dev/null || {
      rm -f "$tmp_file"
      return 0
    }
  else
    printf '{"event":"%s","provider":"%s","model":"%s","display":"%s","timestamp":%s}\n' \
      "$event" "$provider" "$model" "$display" "$now" > "$tmp_file" 2>/dev/null || {
      rm -f "$tmp_file"
      return 0
    }
  fi

  mv "$tmp_file" "$STATE_FILE" 2>/dev/null || rm -f "$tmp_file"
}

if is_event "${1:-}"; then
  event="$1"
  shift
  if [ $# -ge 3 ]; then
    provider="${provider:-$1}"
    model="${model:-$2}"
    session_id="${session_id:-$3}"
  elif [ $# -eq 2 ]; then
    provider="${provider:-$1}"
    model="${model:-$2}"
    if [ -z "${session_id:-}" ] && [[ "${model:-}" == ses_* ]]; then
      session_id="$model"
      model=""
    fi
  elif [ $# -ge 1 ]; then
    if [ -z "${session_id:-}" ] && [[ "${1:-}" == ses_* ]]; then
      session_id="$1"
    else
      model="${model:-$1}"
    fi
  fi
else
  model="${model:-${1:-}}"
  event="${event:-${2:-active}}"
  provider="${provider:-${3:-}}"
  session_id="${session_id:-${4:-}}"
fi

[ -n "${event:-}" ] || event="active"

if [ -z "${provider:-}" ] && [[ "$model" == */* ]]; then
  provider="${model%%/*}"
  model="${model#*/}"
fi

if [ -z "${provider:-}" ] || [ -z "${model:-}" ]; then
  resolve_from_logs "${session_id:-}" || true
fi

[ -n "${provider:-}" ] || exit 0
[ -n "${model:-}" ] || exit 0

target_provider=""
for candidate in "${TARGET_PROVIDERS[@]}"; do
  if [ "$provider" = "$candidate" ]; then
    target_provider="$candidate"
    break
  fi
done

[ -n "$target_provider" ] || exit 0

matched_model=""
for candidate in "${TARGET_MODELS[@]}"; do
  if [[ "$model" == "$candidate"* ]]; then
    matched_model="$candidate"
    break
  fi
done

[ -n "$matched_model" ] || exit 0

display="$(lookup_display "$matched_model")"
[ -n "${display:-}" ] || display="$model"

if [ "$event" = "idle" ]; then
  if [ "${CACHE_TTL:-0}" -gt 0 ] && read_cached_usage && cache_is_fresh; then
    write_daily_cache "$cached_usage"
    write_state "$cached_usage"
  elif acquire_lock; then
    usage_raw="$(fetch_usage_raw 2>/dev/null || true)"
    if [ -n "${usage_raw:-}" ]; then
      write_usage_cache "$usage_raw"
      write_daily_cache "$usage_raw"
      write_state "$usage_raw"
    elif read_cached_usage; then
      write_daily_cache "$cached_usage"
      write_state "$cached_usage"
    else
      write_state
    fi
    release_lock
  else
    if read_cached_usage; then
      write_daily_cache "$cached_usage"
      write_state "$cached_usage"
    else
      write_state
    fi
  fi
else
  write_state
fi

handler_command="$(shell_quote "$SIGNAL_HANDLER") $(shell_quote "$event") $(shell_quote "$provider") $(shell_quote "$model") $(shell_quote "$display")"
tmux run-shell -b "$handler_command" 2>/dev/null || true
tmux refresh-client -S 2>/dev/null || true
