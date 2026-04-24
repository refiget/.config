#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
event="${1:-}"
shift || true

case "$event" in
  bootstrap-sync|client-attached|client-detached|pane-focus-in|after-select-window|session-created|session-renamed|session-closed)
    exec "$script_dir/events/${event}.sh" "$@"
    ;;
  *)
    exit 0
    ;;
esac
