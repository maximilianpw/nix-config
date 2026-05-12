-- Window Rules (Lua syntax)
-- =========================

-- Suppress maximize requests from all apps
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Fix XWayland drag issues
hl.window_rule({
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
})

-- Float common dialogs/utilities
hl.window_rule({ match = { class = "^(pavucontrol)$" }, float = true })
hl.window_rule({ match = { class = "^(Protonvpn|protonvpn)$" }, float = true })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" }, float = true })
hl.window_rule({ match = { class = "^(Blueman-manager)$" }, float = true })
hl.window_rule({ match = { class = "^(org\\.gnome\\.Calculator|gnome-calculator)$" }, float = true })
hl.window_rule({ match = { title = "^(File Operation Progress)$" }, float = true })
hl.window_rule({ match = { title = "^(Open File|Save File|Authentication Required)$" }, float = true })
hl.window_rule({ match = { class = "^(qt5ct|lxqt-policykit|polkit-gnome-authentication-agent-1)$" }, float = true })

-- Size rules
hl.window_rule({ match = { class = "^(Postman)$" }, size = "1200 800" })
hl.window_rule({ match = { class = "^(org\\.gnome\\.Nautilus)$" }, size = "800 600" })

-- Nautilus properties dialog
hl.window_rule({
	match = {
		class = "^(org\\.gnome\\.Nautilus)$",
		title = "^(.*Properties.*)$",
	},
	float = true,
})

-- Center floated windows
hl.window_rule({ match = { float = true }, center = true })

-- Layer rules
hl.layer_rule({ match = { namespace = "waybar" }, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "waybar" }, no_anim = true })

-- Workspace assignments
hl.window_rule({ match = { class = "^(com\\.mitchellh\\.ghostty)$" }, workspace = "1" })
hl.window_rule({ match = { class = "^(firefox)$" }, workspace = "2" })

hl.workspace_rule({ workspace = "1", layout = "master" })
hl.workspace_rule({ workspace = "3", layout = "master" })
