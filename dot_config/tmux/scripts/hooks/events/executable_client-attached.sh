#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
client_tty="${1:-}"

start_bg() {
  "$@" >/dev/null 2>&1 &
}

start_bg "$repo_root/scripts/session/session_created.sh"
start_bg "$repo_root/scripts/auto_ipad_mode.sh" attached "$client_tty"
