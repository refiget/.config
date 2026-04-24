#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
LAST_ACTIVE_FILE="/tmp/opencode_provider_last_active"

date +%s > "$LAST_ACTIVE_FILE" 2>/dev/null || true
exec "${SCRIPT_DIR}/provider-monitor.sh" model-change "$@"
