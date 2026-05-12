-- Startup Applications
-- ====================

local hypr = require("lib")

hl.on("hyprland.start", function()
	hypr.exec_once({
		"waybar",
		"wl-paste --watch cliphist store",
		"hyprpaper",
		"1password --silent",
		"gammastep",
		"hypridle",
		"swaync",
		"mullvad-gui --minimize-to-tray",
		"blueman-applet",
		"nm-applet --indicator",
	})
end)
