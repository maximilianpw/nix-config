-- Key Bindings
-- ============

local hypr = require("lib")
local mod = hypr.mod
local hyper = hypr.hyper
local dsp = hl.dsp

-- Window management
hypr.combo_binds(mod, {
	{ "Return", dsp.exec_cmd("ghostty") },
	{ "Q", dsp.window.close() },
	{ "F", dsp.window.fullscreen({ action = "toggle" }) },
	{ "D", dsp.window.float({ action = "toggle" }) },
	{ "S", dsp.layout("togglesplit") },
	{ "SHIFT + S", dsp.window.pseudo() },
})

-- Navigation and window movement
for _, direction in ipairs({
	{ key = "H", value = "l" },
	{ key = "J", value = "d" },
	{ key = "K", value = "u" },
	{ key = "L", value = "r" },
}) do
	hypr.bind_combo(mod, direction.key, dsp.focus({ direction = direction.value }))
	hypr.bind_combo(mod .. " + CTRL", direction.key, dsp.window.move({ direction = direction.value }))
end

-- Master flow (great on WS 1 & 3)
hypr.combo_binds(mod, {
	{ "SHIFT + Return", dsp.layout("swapwithmaster") },
	{ "Semicolon", dsp.layout("cyclenext") },
	{ "Apostrophe", dsp.layout("cycleprev") },
})

-- Master orientation + size on-the-fly
hypr.combo_binds(mod, {
	{ "G", dsp.layout("orientationnext") },
	{ "Equal", dsp.layout("mfact +0.05") },
	{ "Minus", dsp.layout("mfact -0.05") },
})

-- Workspace navigation
hypr.combo_binds(mod, {
	{ "BACKSPACE", dsp.focus({ workspace = "previous" }) },
	{ "SHIFT + BACKSPACE", dsp.window.move({ workspace = "previous" }) },
})

-- Next/Prev with wrap
hypr.combo_binds(mod .. " + CTRL", {
	{ "Right", dsp.focus({ workspace = "e+1" }) },
	{ "Left", dsp.focus({ workspace = "e-1" }) },
})

-- Move focused window to next/prev workspace (wrap)
hypr.combo_binds(mod .. " + CTRL + SHIFT", {
	{ "Right", dsp.window.move({ workspace = "e+1" }) },
	{ "Left", dsp.window.move({ workspace = "e-1" }) },
})

-- Tab through windows
hypr.combo_binds(mod, {
	{ "Tab", dsp.window.cycle_next({}) },
	{ "SHIFT + Tab", dsp.window.cycle_next({ prev = true }) },
})

-- Opacity toggles
hypr.exec_combo_binds(mod, {
	{ "O", "hyprctl keyword decoration:active_opacity 0.9 && hyprctl keyword decoration:inactive_opacity 0.8" },
	{ "SHIFT + O", "hyprctl keyword decoration:active_opacity 1.0 && hyprctl keyword decoration:inactive_opacity 0.95" },
})

-- Workspaces
for i = 1, 9 do
	hypr.bind_combo(mod, tostring(i), dsp.focus({ workspace = i }))
	hypr.bind_combo(mod .. " + SHIFT", tostring(i), dsp.window.move({ workspace = i }))
end

-- Mouse bindings
hypr.combo_binds(mod, {
	{ "mouse:272", dsp.window.drag(), { mouse = true } },
	{ "mouse:273", dsp.window.resize(), { mouse = true } },
	{ "mouse_down", dsp.focus({ workspace = "e+1" }) },
	{ "mouse_up", dsp.focus({ workspace = "e-1" }) },
})

-- Applications
hypr.exec_combo_binds(mod, {
	{ "SPACE", "rofi -show drun -show-icons" },
	{ "E", "nautilus" },
	{ "SHIFT + E", "ghostty -e yazi" },
})

-- Hyper key = Caps Lock held (tap = Escape, via keyd).
hypr.exec_combo_binds(hyper, {
	{ "1", "focus-or-launch helium helium" },
	{ "3", "focus-or-launch com.mitchellh.ghostty ghostty" },
	{ "5", "focus-or-launch discord discord" },
	{ "p", "focus-or-launch _1password-gui 1password-gui" },
})

-- Send current window to special (scratchpad) and show/hide it
hypr.combo_binds(mod, {
	{ "Y", dsp.window.move({ workspace = "special", follow = false }) },
	{ "SHIFT + Y", dsp.workspace.toggle_special("") },
})

-- Utilities
hypr.exec_combo_binds(mod, {
	{ "V", [[cliphist list | rofi -dmenu -p "clipboard" | cliphist decode | wl-copy]] },
	{ "SHIFT + V", "cliphist wipe" },
	{ "ESCAPE", "wlogout" },
})

-- Screenshots
hypr.exec_combo_binds(mod, {
	{ "P", [[mkdir -p ~/Pictures && grim -g "$(slurp)" ~/Pictures/shot-$(date +'%F_%T').png]] },
	{ "SHIFT + P", [[grim -g "$(slurp)" - | wl-copy]] },
	{ "CTRL + P", "grim - | wl-copy" },
})

-- Media Keys
-- ==========

-- Volume control
hypr.binds({
	{ "XF86AudioRaiseVolume", dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true } },
	{ "XF86AudioLowerVolume", dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true } },
	{ "XF86AudioMute", dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true } },
	{ "XF86AudioMicMute", dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true } },
})

-- Media playback control
hypr.binds({
	{ "XF86AudioPlay", dsp.exec_cmd("playerctl play-pause"), { locked = true } },
	{ "XF86AudioPause", dsp.exec_cmd("playerctl play-pause"), { locked = true } },
	{ "XF86AudioNext", dsp.exec_cmd("playerctl next"), { locked = true } },
	{ "XF86AudioPrev", dsp.exec_cmd("playerctl previous"), { locked = true } },
})

-- Brightness control (requires brightnessctl)
hypr.binds({
	{ "XF86MonBrightnessUp", dsp.exec_cmd("brightnessctl set 5%+"), { repeating = true } },
	{ "XF86MonBrightnessDown", dsp.exec_cmd("brightnessctl set 5%-"), { repeating = true } },
})

-- Resize Mode
-- ===========

hypr.bind_combo(mod, "R", dsp.submap("resize"))
hl.define_submap("resize", function()
	hypr.binds({
		{ "H", dsp.window.resize({ x = -20, y = 0, relative = true }), { repeating = true } },
		{ "L", dsp.window.resize({ x = 20, y = 0, relative = true }), { repeating = true } },
		{ "K", dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true } },
		{ "J", dsp.window.resize({ x = 0, y = 20, relative = true }), { repeating = true } },
		{ "escape", dsp.submap("reset") },
		{ "q", dsp.submap("reset") },
		{ hypr.combo(mod, "R"), dsp.submap("reset") },
		{ "Return", dsp.submap("reset") },
	})
end)
