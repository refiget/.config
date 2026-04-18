#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
pane_path="${1:-}"

"$repo_root/scripts/check_and_run_on_activate.sh" "$pane_path"
