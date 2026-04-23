#!/usr/bin/env bash
set -euo pipefail

cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/tmux"
cache_dir="$cache_root/things"
lock_dir="$cache_dir/.refresh.lock"
lock_stale_sec="${TMUX_THINGS_LOCK_STALE_SEC:-300}"
venv_activate="${THINGS_VENV_ACTIVATE:-$HOME/venvs/nvim/bin/activate}"
python_bin="${THINGS_PYTHON_BIN:-$HOME/venvs/nvim/bin/python}"
sync_script="${THINGS_SYNC_SCRIPT:-$HOME/.config/sketchybar/scripts/things_sync.py}"

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

if [[ ! -x "$python_bin" ]]; then
  exit 1
fi

if [[ ! -f "$sync_script" ]]; then
  exit 1
fi

# Use the existing nvim virtualenv by default so Things reads share the
# same Python environment you already maintain for local tools.
if [[ -f "$venv_activate" ]]; then
  # shellcheck disable=SC1090
  source "$venv_activate"
  python_bin="${THINGS_PYTHON_BIN:-python}"
fi

"$python_bin" "$sync_script"
