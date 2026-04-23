return function(sbar, config)
  sbar.add("item", "things_right_icon", {
    position = "e",
    background = {
      color = 0x667dc4e4,
      padding_left = 2,
    },
    icon = {
      color = 0xffffd700,
      string = "",
      font = "JetBrainsMono Nerd Font:Bold:18.0",
      padding_left = 3,
      padding_right = 4,
    },
    label = { drawing = false },
  })

  sbar.add("item", "things_right_today", {
    position = "e",
    background = {
      drawing = true,
      color = 0x66494d64,
      corner_radius = 5,
      padding_left = 5,
      padding_right = 0,
    },
    icon = {
      drawing = false,
      string = "",
      color = 0xfff9e2af,
      font = "JetBrainsMono Nerd Font:Bold:18.0",
      padding_left = 0,
      padding_right = 4,
    },
    label = {
      string = "Today · TODO标题…",
      color = 0xffffffff,
      font = "JetBrainsMono Nerd Font:Bold:18.0",
      padding_left = 0,
      padding_right = 6,
    },
    update_freq = 10,
    script = config.scripts.things_today,
  })

  sbar.exec("sketchybar --move things_left_app before things_right_icon")
  sbar.exec("sketchybar --move things_right_icon before things_right_today")

  sbar.add("item", "battery", {
    position = "right",
    label = { color = 0xffffffff },
    update_freq = 20,
    script = config.scripts.battery,
  })

  local input_source = sbar.add("item", "input_source", {
    position = "right",
    icon = {
      string = "󰗊",
      color = 0xff8aadf4,
    },
    label = { drawing = true, color = 0xffffffff },
    update_freq = 2,
    script = config.scripts.input_source,
  })

  input_source:subscribe("system_woke")
end
