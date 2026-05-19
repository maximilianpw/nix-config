-- Window Rules (Lua syntax)
-- =========================

local hypr = require("lib")

-- Suppress maximize requests from all apps
hypr.window_rules({
	{
		name = "suppress-maximize-events",
		match = { class = ".*" },
		suppress_event = "maximize",
	},

	-- Fix XWayland drag issues
	{
		name = "fix-xwayland-drags",
		match = {
			class = "^$",
			title = "^$",
			xwayland = true,
			float = true,
			fullscreen = false,
			pin = false,
		},
		no_focus = true,
	},
})

-- Float common dialogs/utilities
hypr.window_rules({
	{ match = { class = "^(pavucontrol)$" }, float = true },
	{ match = { class = "^(Protonvpn|protonvpn)$" }, float = true },
	{ match = { class = "^(nm-connection-editor)$" }, float = true },
	{ match = { class = "^(Blueman-manager)$" }, float = true },
	{ match = { class = "^(org\\.gnome\\.Calculator|gnome-calculator)$" }, float = true },
	{ match = { title = "^(File Operation Progress)$" }, float = true },
	{ match = { title = "^(Open File|Save File|Authentication Required)$" }, float = true },
	{ match = { class = "^(qt5ct|lxqt-policykit|polkit-gnome-authentication-agent-1)$" }, float = true },
})

-- Size rules
hypr.window_rules({
	{ match = { class = "^(Postman)$" }, size = "1200 800" },
	{ match = { class = "^(org\\.gnome\\.Nautilus)$" }, size = "800 600" },
})

-- Prevent idle/DPMS while watching video, gaming, or presenting fullscreen
hypr.window_rules({
	{ match = { fullscreen = true }, idle_inhibit = "fullscreen" },
	{ match = { class = "^(mpv|vlc)$" }, idle_inhibit = "focus" },
	{ match = { content = "video" }, idle_inhibit = "focus" },
	{ match = { content = "game" }, idle_inhibit = "fullscreen" },
})

-- Nautilus properties dialog
hypr.window_rules({
	{
		match = {
			class = "^(org\\.gnome\\.Nautilus)$",
			title = "^(.*Properties.*)$",
		},
		float = true,
	},

	-- Center floated windows
	{ match = { float = true }, center = true },
})

-- Layer rules
hypr.layer_rules({
	{ match = { namespace = "waybar" }, blur = true, ignore_alpha = 0.2 },
	{ match = { namespace = "waybar" }, no_anim = true },
	{ match = { namespace = "rofi" }, blur = true, ignore_alpha = 0.2, dim_around = true },
	{ match = { namespace = "swaync.*" }, blur = true, ignore_alpha = 0.1 },
	{ match = { namespace = "wlogout" }, blur = true, dim_around = true },
})

-- Workspace assignments
hypr.window_rules({
	{ match = { class = "^(com\\.mitchellh\\.ghostty)$" }, workspace = "1" },
	{ match = { class = "^(firefox)$" }, workspace = "2" },
})

hypr.workspace_rules({
	{ workspace = "1", default_name = "term", persistent = true },
	{ workspace = "2", default_name = "web", persistent = true },
	{ workspace = "3", persistent = true, layout = "master" },
	{ workspace = "4", persistent = true },
	{ workspace = "5", persistent = true },
	-- Keep the normal outer gap for single-window workspaces so there is
	-- visible separation between tiled windows and the top Waybar layer.
	{ workspace = "f[1]s[false]", gaps_out = 0, gaps_in = 0 },
})

-- Smart gaps: remove borders when a workspace only has one tiled window,
-- while preserving the global decoration rounding.
hypr.window_rules({
	{ match = { float = false, workspace = "w[tv1]s[false]" }, border_size = 0 },
	{ match = { float = false, workspace = "f[1]s[false]" }, border_size = 0 },
})
