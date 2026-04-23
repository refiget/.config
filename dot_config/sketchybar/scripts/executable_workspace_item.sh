#!/usr/bin/env zsh

SID="$1"
ICON_MAP_SCRIPT="${CONFIG_DIR:-$HOME/.config/sketchybar}/scripts/icon_map_fn.sh"

if [[ "$SENDER" == "mouse.clicked" ]]; then
  yabai -m space --focus "$SID" >/dev/null 2>&1
fi

FOCUSED_SPACE=""
if [[ "$SENDER" == "space_change" && -n "$INFO" ]]; then
  FOCUSED_SPACE="$(echo "$INFO" | jq -r 'if type == "object" then (.["display-1"] // .[keys[0]]) else empty end' 2>/dev/null)"
fi
if [[ -z "$FOCUSED_SPACE" ]]; then
  FOCUSED_SPACE="$(yabai -m query --spaces --space 2>/dev/null | jq -r '.index // empty' 2>/dev/null)"
fi

if [[ "$FOCUSED_SPACE" == "$SID" ]]; then
  BG_COLOR="0x88FF00FF"
  BORDER_WIDTH="2"
  SHADOW="on"
else
  BG_COLOR="0x44FFFFFF"
  BORDER_WIDTH="0"
  SHADOW="off"
fi

ICON_STRIP=" "
WINDOW_APPS=""
if [[ "$SENDER" == "space_windows_change" && -n "$INFO" ]]; then
  CHANGED_SPACE="$(echo "$INFO" | jq -r '.space // empty' 2>/dev/null)"
  if [[ "$CHANGED_SPACE" == "$SID" ]]; then
    WINDOW_APPS="$(echo "$INFO" | jq -r '.apps | keys[]?' 2>/dev/null)"
  fi
fi
if [[ -z "$WINDOW_APPS" ]]; then
  WINDOW_APPS="$(yabai -m query --windows --space "$SID" 2>/dev/null | jq -r 'map(select(."is-minimized" == false)) | .[].app' 2>/dev/null | awk '!a[$0]++')"
fi

if [[ -n "$WINDOW_APPS" && -x "$ICON_MAP_SCRIPT" ]]; then
  while IFS= read -r APP; do
    [[ -z "$APP" ]] && continue
    ICON_STRIP+=" $("$ICON_MAP_SCRIPT" "$APP")"
  done <<< "$WINDOW_APPS"
else
  ICON_STRIP=""
fi

sketchybar --animate sin 5 --set "$NAME" \
  background.color="$BG_COLOR" \
  background.border_width="$BORDER_WIDTH" \
  label="$ICON_STRIP" \
  label.shadow.drawing="$SHADOW" \
  icon.shadow.drawing="$SHADOW" \
  drawing=on
