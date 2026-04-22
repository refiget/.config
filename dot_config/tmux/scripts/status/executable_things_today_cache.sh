#!/usr/bin/env bash
set -euo pipefail

cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/tmux"
cache_dir="$cache_root/things"
counts_file="$cache_dir/today_counts"
title_file="$cache_dir/today_title"
titles_file="$cache_dir/today_titles"
state_file="$cache_dir/today_state"
error_file="$cache_dir/today_error.log"
lock_dir="$cache_dir/.refresh.lock"
list_name="${TMUX_THINGS_LIST_NAME:-Today}"
lock_stale_sec="${TMUX_THINGS_LOCK_STALE_SEC:-300}"

if [[ ! "$lock_stale_sec" =~ ^[0-9]+$ ]] || (( lock_stale_sec <= 0 )); then
  lock_stale_sec=300
fi

mkdir -p "$cache_dir"

if [[ -d "$lock_dir" ]]; then
  lock_mtime=$(stat -f '%m' "$lock_dir" 2>/dev/null || echo 0)
  now=$(date +%s)
  lock_age=$((now - lock_mtime))
  if (( lock_mtime == 0 )) || (( lock_age >= lock_stale_sec )); then
    rmdir "$lock_dir" 2>/dev/null || true
  fi
fi

if ! mkdir "$lock_dir" 2>/dev/null; then
  exit 0
fi

cleanup() {
  rmdir "$lock_dir" 2>/dev/null || true
}
trap cleanup EXIT

tmp_counts=$(mktemp "$cache_dir/.today_counts.XXXXXX")
tmp_title=$(mktemp "$cache_dir/.today_title.XXXXXX")
tmp_titles=$(mktemp "$cache_dir/.today_titles.XXXXXX")
tmp_error=$(mktemp "$cache_dir/.today_error.XXXXXX")

fetch_counts() {
  local candidate="${1:-}"
  THINGS_TMP_COUNTS="$tmp_counts" THINGS_TMP_TITLE="$tmp_title" THINGS_TMP_TITLES="$tmp_titles" osascript 2>"$tmp_error" <<APPLESCRIPT
set countsPath to system attribute "THINGS_TMP_COUNTS"
set titlePath to system attribute "THINGS_TMP_TITLE"
set titlesPath to system attribute "THINGS_TMP_TITLES"

using terms from application "Things3"
  tell application "Things3"
    set itemList to to dos of list "$candidate"
    set openCount to 0
    set doneCount to 0
    set firstTitle to ""
    set openTitles to {}
    repeat with t in itemList
      if status of t is completed then
        set doneCount to doneCount + 1
      else if status of t is open then
        set openCount to openCount + 1
        set end of openTitles to (name of t)
        if firstTitle is "" then
          set firstTitle to name of t
        end if
      end if
    end repeat
  end tell
end using terms from

do shell script "printf %s " & quoted form of ((openCount as text) & "," & (doneCount as text)) & " > " & quoted form of countsPath
do shell script "printf %s " & quoted form of firstTitle & " > " & quoted form of titlePath
set AppleScript's text item delimiters to linefeed
do shell script "printf %s " & quoted form of (openTitles as text) & " > " & quoted form of titlesPath
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
  perl -0pi -e 's/\r/\n/g; s/\n+\z/\n/; s/[[:cntrl:]&&[^\n\t]]//g' "$tmp_title"
  perl -0pi -e 's/\r/\n/g; s/\n+\z/\n/; s/[[:cntrl:]&&[^\n\t]]//g' "$tmp_titles"
  mv "$tmp_counts" "$counts_file"
  mv "$tmp_title" "$title_file"
  mv "$tmp_titles" "$titles_file"
  : >"$error_file"
  printf 'ok\n' >"$state_file"
  rm -f "$tmp_error"
else
  mv "$tmp_error" "$error_file"
  rm -f "$tmp_counts"
  rm -f "$tmp_title"
  rm -f "$tmp_titles"
  printf 'error\n' >"$state_file"
  exit 1
fi
