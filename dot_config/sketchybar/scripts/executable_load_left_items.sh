#!/usr/bin/env zsh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
SPACE_SCRIPT="$CONFIG_DIR/scripts/workspace_item.sh"
THINGS_LEFT_STATS_SCRIPT="$CONFIG_DIR/scripts/things_left_stats.sh"

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

sketchybar --add item things_left_inbox q \
  --set things_left_inbox \
    background.drawing=off \
    icon="󰚇" \
    icon.color=0xff1aadf8 \
    icon.font="JetBrainsMono Nerd Font:Bold:18.0" \
    icon.padding_left=8 \
    icon.padding_right=4 \
    label="--" \
    label.color=0xffffffff \
    label.font="JetBrainsMono Nerd Font:Bold:16.0" \
    label.padding_left=0 \
    label.padding_right=6

sketchybar --add item things_left_stack q \
  --set things_left_stack \
    background.drawing=off \
    icon="" \
    icon.color=0xff38a89d \
    icon.font="JetBrainsMono Nerd Font:Bold:18.0" \
    icon.padding_left=0 \
    icon.padding_right=4 \
    label="--" \
    label.color=0xffffffff \
    label.font="JetBrainsMono Nerd Font:Bold:16.0" \
    label.padding_left=0 \
    label.padding_right=6

sketchybar --add item things_left_star q \
  --set things_left_star \
    background.drawing=off \
    icon="" \
    icon.color=0xffffd700 \
    icon.font="JetBrainsMono Nerd Font:Bold:18.0" \
    icon.padding_left=0 \
    icon.padding_right=4 \
    label="--" \
    label.color=0xffffffff \
    label.font="JetBrainsMono Nerd Font:Bold:16.0" \
    label.padding_left=0 \
    label.padding_right=8

sketchybar --add bracket things_left_stats_bracket things_left_inbox things_left_star things_left_stack \
  --set things_left_stats_bracket \
    background.drawing=on \
    background.color=0x33494d64 \
    background.corner_radius=6 \
    background.height=24

sketchybar --add item things_left_app q \
  --set things_left_app \
    background.color=0x667dc4e4 \
    background.padding_right=2 \
    icon.padding_left=3 \
    icon.padding_right=4 \
    icon.background.drawing=on \
    icon.background.image=app.com.culturedcode.ThingsMac \
    icon.background.image.scale=0.8 \
    label.drawing=off \
    click_script="open -a Things"

sketchybar --move things_left_stack after things_left_app
sketchybar --move things_left_star after things_left_stack
sketchybar --move things_left_inbox after things_left_star

sketchybar --add item things_left_stats_updater q \
  --set things_left_stats_updater \
    drawing=off \
    script="$THINGS_LEFT_STATS_SCRIPT" \
    update_freq=15 \
    updates=on \
  --subscribe things_left_stats_updater system_woke

"$THINGS_LEFT_STATS_SCRIPT" >/dev/null 2>&1 || true
