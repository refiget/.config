#!/usr/bin/env zsh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
SPACE_SCRIPT="$CONFIG_DIR/scripts/workspace_item.sh"
FRONT_APP_SCRIPT="$CONFIG_DIR/scripts/front_app_ref.sh"

SPACE_IDS=("${(@f)$(yabai -m query --spaces 2>/dev/null | jq -r '.[].index' 2>/dev/null)}")
SPACE_IDS=(${SPACE_IDS:#})
if (( ${#SPACE_IDS[@]} == 0 )); then
  SPACE_IDS=(1 2 3 4 5)
fi

for sid in "${SPACE_IDS[@]}"; do
  sketchybar --add item "space.$sid" left \
    --set "space.$sid" \
      drawing=on \
      background.color=0x44ffffff \
      background.corner_radius=5 \
      background.drawing=on \
      background.border_color=0xAAFFFFFF \
      background.border_width=0 \
      background.height=25 \
      icon="$sid" \
      icon.padding_left=10 \
      icon.shadow.distance=4 \
      icon.shadow.color=0xA0000000 \
      label.font="sketchybar-app-font:Regular:18.0" \
      label.padding_right=20 \
      label.padding_left=0 \
      label.y_offset=-1 \
      label.shadow.drawing=off \
      label.shadow.color=0xA0000000 \
      label.shadow.distance=4 \
      updates=on \
      update_freq=10 \
      click_script="yabai -m space --focus $sid" \
      script="$SPACE_SCRIPT $sid" \
    --subscribe "space.$sid" space_change space_windows_change system_woke mouse.clicked
done

sketchybar --add item things.app q \
  --set things.app \
    background.color=0x667dc4e4 \
    background.padding_right=-1 \
    icon.padding_left=3 \
    icon.padding_right=4 \
    icon.background.drawing=on \
    icon.background.image=app.Things \
    icon.background.image.scale=0.8 \
    label.drawing=off \
    click_script="open -a Things"

sketchybar --add item front_app left \
  --set front_app \
    label.font="JetBrainsMono Nerd Font:Black:18.0" \
    label.drawing=off \
    icon.background.drawing=on \
    display=active \
    script="$FRONT_APP_SCRIPT" \
  --subscribe front_app front_app_switched
