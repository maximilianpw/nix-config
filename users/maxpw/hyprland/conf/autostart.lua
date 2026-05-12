-- Startup Applications
-- ====================

hl.on("hyprland.start", function()
	hl.exec_cmd("waybar")
	hl.exec_cmd("wl-paste --watch cliphist store")
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("1password --silent")
	hl.exec_cmd("gammastep")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("swaync")
	hl.exec_cmd("mullvad-gui --minimize-to-tray")
	hl.exec_cmd("blueman-applet")
	hl.exec_cmd("nm-applet --indicator")
end)
