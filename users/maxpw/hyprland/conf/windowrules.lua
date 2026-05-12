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
	{ match = { namespace = "waybar" }, ignore_alpha = 0.2 },
	{ match = { namespace = "waybar" }, no_anim = true },
})

-- Workspace assignments
hypr.window_rules({
	{ match = { class = "^(com\\.mitchellh\\.ghostty)$" }, workspace = "1" },
	{ match = { class = "^(firefox)$" }, workspace = "2" },
})

hypr.workspace_rules({
	{ workspace = "1", layout = "master" },
	{ workspace = "3", layout = "master" },
})
