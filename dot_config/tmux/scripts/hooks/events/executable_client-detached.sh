#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
client_tty="${1:-}"

"$repo_root/scripts/auto_ipad_mode.sh" detached "$client_tty" >/dev/null 2>&1 &
