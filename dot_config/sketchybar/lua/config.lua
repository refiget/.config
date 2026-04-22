local home = os.getenv("HOME")
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar")

local font_face = "JetBrainsMono Nerd Font"

return {
  config_dir = config_dir,
  scripts = {
    load_left_items = config_dir .. "/scripts/load_left_items.sh",
    clock = config_dir .. "/scripts/clock.sh",
    input_source = config_dir .. "/scripts/input_source.sh",
    things_today = config_dir .. "/scripts/things_today.sh",
    weather = config_dir .. "/scripts/weather.sh",
    battery = config_dir .. "/scripts/battery.sh",
  },
  icons = {
    apps = {
      ["Arc"] = { icon = "󰞍", padding_right = 5 },
      ["Calendar"] = { icon = "", padding_right = 3 },
      ["Code"] = { icon = "󰨞", padding_right = 4 },
      ["Discord"] = { icon = "", padding_right = 5 },
      ["FaceTime"] = { icon = "", padding_right = 5 },
      ["Finder"] = { icon = "󰀶", padding_right = 5 },
      ["Google Chrome"] = { icon = "", padding_right = 7 },
      ["IINA"] = { icon = "󰕼", padding_right = 4 },
      ["kitty"] = { icon = "󰄛", padding_right = 5 },
      ["Messages"] = { icon = "", padding_right = 5 },
      ["Notion"] = { icon = "󰎚", padding_right = 6 },
      ["Preview"] = { icon = "", padding_right = 3 },
      ["PS Remote Play"] = { icon = "", padding_right = 3 },
      ["Spotify"] = { icon = "", padding_right = 2 },
      ["TextEdit"] = { icon = "", padding_right = 4 },
      ["Transmission"] = { icon = "󰶘", padding_right = 3 },
      default = { icon = "", padding_right = 2 },
    },
  },
  hosts = {
    laptop = {
      bar = {
        height = 32,
        color = 0x00000000,
        margin = 0,
        sticky = "on",
        padding_left = 23,
        padding_right = 23,
        notch_width = 188,
        display = "main",
      },
      default = {
        background = {
          color = 0x66494d64,
          corner_radius = 5,
          padding_right = 5,
          height = 26,
        },
        icon = {
          font = font_face .. ":Medium:18.0",
          padding_left = 5,
          padding_right = 5,
        },
        label = {
          font = font_face .. ":Bold:18.0",
          color = 0xffcad3f5,
          y_offset = 0,
          padding_left = 0,
          padding_right = 5,
        },
      },
      items = {
        front_app = {
          icon = { y_offset = 1, color = 0xff24273a },
          separator = {
            background_padding_left = -3,
            font = font_face .. ":Bold:18.0",
          },
          name = {
            font = font_face .. ":Bold:18.0",
            color = nil,
            padding_left = nil,
          },
        },
        clock = {
          icon = { string = "󰃰", color = 0xffed8796 },
        },
      },
    },
    desktop = {
      bar = {
        height = 32,
        color = 0x66494d64,
        margin = 0,
        sticky = "on",
        padding_left = 0,
        padding_right = 0,
        notch_width = 188,
        display = "main",
      },
      default = {
        background = {
          height = 32,
        },
        icon = {
          color = 0xff24273a,
          font = font_face .. ":Medium:18.0",
          padding_left = 5,
          padding_right = 5,
        },
        label = {
          color = 0xff24273a,
          font = font_face .. ":Bold:18.0",
          y_offset = 1,
          padding_left = 0,
          padding_right = 5,
        },
      },
      items = {
        front_app = {
          icon = { y_offset = 1, color = nil },
          separator = {
            background_padding_left = 0,
            font = font_face .. ":Bold:18.0",
          },
          name = {
            font = font_face .. ":Bold:18.0",
            color = 0xffcad3f5,
            padding_left = 5,
          },
        },
        clock = {
          background = { color = 0xffed8796 },
          icon = { string = "󰃰" },
        },
      },
    },
  },
}
