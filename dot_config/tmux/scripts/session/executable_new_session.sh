#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"
# shellcheck source=../lib/tmux_runtime.sh
source "$script_dir/../lib/tmux_runtime.sh"

session_id=$(tmux new-session -d -P -F '#{session_id}' 2>/dev/null || true)
if [[ -z "${session_id:-}" ]]; then
  exit 0
fi

python3 "$repo_root/scripts/session_manager.py" ensure

tmux switch-client -t "$session_id"
