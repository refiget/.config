#!/usr/bin/env bash
set -euo pipefail

cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/tmux"
cache_dir="$cache_root/things"
counts_file="$cache_dir/today_counts"
state_file="$cache_dir/today_state"
error_file="$cache_dir/today_error.log"
lock_dir="$cache_dir/.refresh.lock"
list_name="${TMUX_THINGS_LIST_NAME:-Today}"

mkdir -p "$cache_dir"

if ! mkdir "$lock_dir" 2>/dev/null; then
  exit 0
fi

cleanup() {
  rmdir "$lock_dir" 2>/dev/null || true
}
trap cleanup EXIT

tmp_counts=$(mktemp "$cache_dir/.today_counts.XXXXXX")
tmp_error=$(mktemp "$cache_dir/.today_error.XXXXXX")

fetch_counts() {
  local candidate="${1:-}"
  osascript >"$tmp_counts" 2>"$tmp_error" <<APPLESCRIPT
using terms from application "Things3"
  tell application "Things3"
    set itemList to to dos of list "$candidate"
    set openCount to 0
    set doneCount to 0
    repeat with t in itemList
      if status of t is completed then
        set doneCount to doneCount + 1
      else if status of t is open then
        set openCount to openCount + 1
      end if
    end repeat
  end tell
end using terms from

return (openCount as text) & "," & (doneCount as text)
APPLESCRIPT
}

success=0
for candidate in "$list_name" "Today" "今天"; do
  [[ -z "$candidate" ]] && continue
  if fetch_counts "$candidate"; then
    success=1
    break
  fi
done

if (( success == 1 )); then
  perl -0pi -e 's/\r/\n/g; s/\n+\z/\n/; s/[[:cntrl:]&&[^\n\t]]//g' "$tmp_counts"
  mv "$tmp_counts" "$counts_file"
  : >"$error_file"
  printf 'ok\n' >"$state_file"
  rm -f "$tmp_error"
else
  mv "$tmp_error" "$error_file"
  rm -f "$tmp_counts"
  printf 'error\n' >"$state_file"
  exit 1
fi
