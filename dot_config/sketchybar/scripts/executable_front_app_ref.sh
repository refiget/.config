#!/usr/bin/env zsh

if [[ "$SENDER" != "front_app_switched" ]]; then
  exit 0
fi

sketchybar --set "$NAME" label="" icon.background.image="app.$INFO" \
  --set "$NAME" icon.background.image.scale=0.8
