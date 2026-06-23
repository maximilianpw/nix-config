-- Startup Applications
-- ====================

local hypr = require("lib")

hl.on("hyprland.start", function()
	hypr.exec_once({
		"waybar",
		"wl-paste --watch cliphist store",
		-- hyprpaper 0.8.4 (nixpkgs 26.05) ignores the `wallpaper=` line in
		-- hyprpaper.conf at startup ("Monitor … has no target"), so apply it
		-- over IPC once the daemon is up. The `preload=` line still works.
		"hyprpaper & (for i in $(seq 1 40); do hyprctl hyprpaper wallpaper ',/home/maxpw/nix-config/users/maxpw/wallpapers/futuristic-journey-simon-stalenhag-wide.jpg' && break; sleep 0.5; done)",
		"1password --silent",
		"gammastep",
		"hypridle",
		"swaync",
		"blueman-applet",
		"nm-applet --indicator",
	})
end)
