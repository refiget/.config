#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../../.." && pwd)"
# shellcheck source=../../lib/tmux_runtime.sh
source "$repo_root/scripts/lib/tmux_runtime.sh"

"$repo_root/scripts/session/session_created.sh" >/dev/null 2>&1 &
tmux refresh-client -S >/dev/null 2>&1 &
