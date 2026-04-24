#!/usr/bin/env bash

set -u

REFRESH_EVERY="${REFRESH_EVERY:-600}"
STAMP_FILE="/tmp/n1n_billing_refresh_stamp"
LOCK_DIR="/tmp/n1n_billing_refresh.lock"
MONITOR="${HOME}/.config/opencode/hooks/provider-monitor.sh"

# Hardcoded target for periodic refresh. Keep consistent with provider-monitor allowlist.
TARGET_PROVIDER="n1n_relay"
TARGET_MODEL="claude-haiku-4-5"

now="$(date +%s)"
last=0

if [ -r "$STAMP_FILE" ]; then
  last="$(cat "$STAMP_FILE" 2>/dev/null || printf '0')"
fi

case "$last" in
  ''|*[!0-9]*) last=0 ;;
esac

if [ "$last" -gt 0 ] && [ $((now - last)) -lt "$REFRESH_EVERY" ]; then
  exit 0
fi

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap 'rm -rf "$LOCK_DIR" >/dev/null 2>&1 || true' EXIT

# Re-check after acquiring lock to avoid duplicate trigger under concurrent clients.
now="$(date +%s)"
last=0
if [ -r "$STAMP_FILE" ]; then
  last="$(cat "$STAMP_FILE" 2>/dev/null || printf '0')"
fi
case "$last" in
  ''|*[!0-9]*) last=0 ;;
esac
if [ "$last" -gt 0 ] && [ $((now - last)) -lt "$REFRESH_EVERY" ]; then
  exit 0
fi

if "$MONITOR" idle "$TARGET_PROVIDER" "$TARGET_MODEL" >/dev/null 2>&1; then
  now="$(date +%s)"
  printf '%s\n' "$now" > "$STAMP_FILE" 2>/dev/null || true
fi
