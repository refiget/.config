#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
LAST_ACTIVE_FILE="/tmp/opencode_provider_last_active"
IDLE_THRESHOLD="${IDLE_THRESHOLD:-60}"
now="$(date +%s)"
last_active=0

if [ -f "$LAST_ACTIVE_FILE" ]; then
  last_active="$(cat "$LAST_ACTIVE_FILE" 2>/dev/null || printf '0')"
fi

case "$last_active" in
  ''|*[!0-9]*) last_active=0 ;;
esac

if [ "$last_active" -gt 0 ] && [ $((now - last_active)) -lt "$IDLE_THRESHOLD" ]; then
  exit 0
fi

exec "${SCRIPT_DIR}/provider-monitor.sh" idle "$@"
