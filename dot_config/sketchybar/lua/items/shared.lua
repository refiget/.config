return function(sbar, config, host)
  local item_config = config.hosts[host].items

  sbar.exec(config.scripts.load_left_items)

  sbar.add("item", "clock", {
    position = "right",
    background = item_config.clock.background,
    icon = item_config.clock.icon,
    update_freq = 10,
    script = config.scripts.clock,
  })
end
