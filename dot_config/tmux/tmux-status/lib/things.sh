#!/usr/bin/env bash

status_things_cache_root() {
  printf '%s' "${XDG_CACHE_HOME:-$HOME/.cache}/tmux/things"
}

status_things_counts_file() {
  printf '%s/today_counts' "$(status_things_cache_root)"
}

status_things_state_file() {
  printf '%s/today_state' "$(status_things_cache_root)"
}

status_things_lock_dir() {
  printf '%s/.refresh.lock' "$(status_things_cache_root)"
}

status_things_refresh_script() {
  local repo_root="${TMUX_STATUS_ROOT:-$HOME/.config/tmux}"
  printf '%s/scripts/status/things_today_cache.sh' "$repo_root"
}

status_escape_tmux_text() {
  local text="${1:-}"
  text=${text//$'\r'/ }
  text=${text//$'\n'/ }
  text=${text//$'\t'/ }
  text=${text//#/##}
  printf '%s' "$text"
}

status_things_refresh_if_needed() {
  local refresh_sec="${TMUX_THINGS_REFRESH_SEC:-60}"
  local counts_file state_file lock_dir refresh_script now age mtime

  counts_file=$(status_things_counts_file)
  state_file=$(status_things_state_file)
  lock_dir=$(status_things_lock_dir)
  refresh_script=$(status_things_refresh_script)
  now=$(date +%s)

  if [[ ! -x "$refresh_script" ]]; then
    return 0
  fi

  if [[ -f "$counts_file" ]]; then
    mtime=$(stat -f '%m' "$counts_file" 2>/dev/null || echo 0)
  elif [[ -f "$state_file" ]]; then
    mtime=$(stat -f '%m' "$state_file" 2>/dev/null || echo 0)
  else
    mtime=0
  fi
  age=$((now - mtime))

  if (( mtime == 0 )); then
    "$refresh_script" >/dev/null 2>&1 || true
    return 0
  fi

  if (( age < refresh_sec )) || [[ -d "$lock_dir" ]]; then
    return 0
  fi

  "$refresh_script" >/dev/null 2>&1 &
}

status_things_summary() {
  local counts_file raw open_count done_count

  counts_file=$(status_things_counts_file)
  if [[ ! -f "$counts_file" ]]; then
    return 1
  fi

  raw=$(<"$counts_file")
  open_count=${raw%%,*}
  done_count=${raw#*,}

  if [[ ! "$open_count" =~ ^[0-9]+$ ]] || [[ ! "$done_count" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  if (( open_count == 0 && done_count == 0 )); then
    printf 'Today ALL DONE'
    return 0
  fi

  printf 'Today %s  󰛲' "$open_count"
}

status_build_things_segment() {
  local width="${1:-}"
  local text state_file state

  if [[ "${TMUX_THINGS:-1}" != "1" ]]; then
    return 0
  fi

  if [[ -n "${width:-}" && "$width" =~ ^[0-9]+$ ]] && (( width < ${TMUX_THINGS_MIN_WIDTH:-130} )); then
    return 0
  fi

  status_things_refresh_if_needed

  if ! text=$(status_things_summary 2>/dev/null); then
    state_file=$(status_things_state_file)
    state=""
    [[ -f "$state_file" ]] && state=$(<"$state_file")
    if [[ "$state" == "error" ]]; then
      text="THINGS ERR"
    else
      text="ALL DONE"
    fi
  fi

  text=$(status_escape_tmux_text "$text")

  printf '#[bold,italics,fg=#f9e2af]󰓎 %s#[default]' "$text"
}
