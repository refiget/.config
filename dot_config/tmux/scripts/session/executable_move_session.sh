#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"

direction="${1:-}"
if [[ -z "$direction" ]]; then
  exit 0
fi

python3 "$repo_root/scripts/session_manager.py" move "$direction"
