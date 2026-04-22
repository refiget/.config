local home = os.getenv("HOME")
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar")

package.path = table.concat({
  config_dir .. "/?.lua",
  config_dir .. "/lua/?.lua",
  config_dir .. "/lua/?/init.lua",
  config_dir .. "/lua/?.lua",
  package.path,
}, ";")

package.cpath = table.concat({
  home .. "/.local/share/sketchybar_lua/?.so",
  package.cpath,
}, ";")

local ok, sbar = pcall(require, "sketchybar")
if not ok then
  io.stderr:write("failed to load SbarLua: " .. tostring(sbar) .. "\n")
  os.exit(1)
end

local detect_host = require("lua.detect_host")
local config = require("lua.config")
local add_shared_items = require("lua.items.shared")
local add_laptop_items = require("lua.items.laptop")
local add_desktop_items = require("lua.items.desktop")

local host = detect_host()
local host_config = config.hosts[host]

sbar.bar(host_config.bar)
sbar.default(host_config.default)

add_shared_items(sbar, config, host)

if host == "laptop" then
  add_laptop_items(sbar, config)
else
  add_desktop_items(sbar, config)
end

sbar.exec("sketchybar --update")
sbar.trigger("space_change")
