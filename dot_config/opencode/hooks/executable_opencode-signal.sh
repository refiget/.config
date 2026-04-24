#!/usr/bin/env bash

DEFAULT_ITEM='$00.00'
EVENT="${1:-}"
PROVIDER="${2:-unknown}"
MODEL="${3:-unknown}"
DISPLAY="${4:-$MODEL}"
LOG_FILE="/tmp/opencode_tmux.log"

{
  printf '[%s] %s | %s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$EVENT" "$PROVIDER" "$MODEL"
} >> "$LOG_FILE" 2>/dev/null || true

tmux refresh-client -S 2>/dev/null || true
