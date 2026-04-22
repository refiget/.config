#!/usr/bin/env zsh

CURRENT_SOURCE="$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources 2>/dev/null)"

if echo "$CURRENT_SOURCE" | grep -q 'KeyboardLayout Name = ABC'; then
  LABEL="A"
elif echo "$CURRENT_SOURCE" | grep -q 'com.apple.inputmethod.SCIM.Shuangpin'; then
  LABEL="中"
elif echo "$CURRENT_SOURCE" | grep -q 'com.apple.inputmethod.SCIM'; then
  LABEL="中"
else
  LABEL="A"
fi

sketchybar --set "$NAME" label="$LABEL"
