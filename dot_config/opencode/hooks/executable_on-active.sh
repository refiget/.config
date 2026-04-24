#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
OPENCODE_CACHE_DIR="${OPENCODE_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/opencode}"
LAST_ACTIVE_FILE="${OPENCODE_CACHE_DIR}/opencode_provider_last_active"

mkdir -p "$OPENCODE_CACHE_DIR" 2>/dev/null || true
date +%s > "$LAST_ACTIVE_FILE" 2>/dev/null || true
exec "${SCRIPT_DIR}/provider-monitor.sh" active "$@"
