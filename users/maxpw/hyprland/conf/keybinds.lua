-- Key Bindings
-- ============

-- Define modifier keys
local mod = "SUPER"

-- Hyper key = Caps Lock held (tap = Escape, via keyd)
-- Maps to Ctrl+Super+Alt+Shift simultaneously - no workspace conflicts.
local hyper = "SUPER + CTRL + ALT + SHIFT"

-- Window management
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("ghostty"))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mod .. " + D", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + S", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.pseudo())

-- Navigation
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "d" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "r" }))

-- Master flow (great on WS 1 & 3)
hl.bind(mod .. " + SHIFT + Return", hl.dsp.layout("swapwithmaster"))
hl.bind(mod .. " + Semicolon", hl.dsp.layout("cyclenext"))
hl.bind(mod .. " + Apostrophe", hl.dsp.layout("cycleprev"))

-- Master orientation + size on-the-fly
hl.bind(mod .. " + G", hl.dsp.layout("orientationnext"))
hl.bind(mod .. " + Equal", hl.dsp.layout("mfact +0.05"))
hl.bind(mod .. " + Minus", hl.dsp.layout("mfact -0.05"))

-- Back to previous workspace
hl.bind(mod .. " + BACKSPACE", hl.dsp.focus({ workspace = "previous" }))

-- Next/Prev with wrap
hl.bind(mod .. " + CTRL + Right", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + CTRL + Left", hl.dsp.focus({ workspace = "e-1" }))

-- Move focused window to next/prev workspace (wrap)
hl.bind(mod .. " + CTRL + SHIFT + Right", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mod .. " + CTRL + SHIFT + Left", hl.dsp.window.move({ workspace = "e-1" }))

-- Tab through windows
hl.bind(mod .. " + Tab", hl.dsp.window.cycle_next({}))
hl.bind(mod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ prev = true }))

-- Opacity toggles
hl.bind(
	mod .. " + O",
	hl.dsp.exec_cmd("hyprctl keyword decoration:active_opacity 0.9 && hyprctl keyword decoration:inactive_opacity 0.8")
)
hl.bind(
	mod .. " + SHIFT + O",
	hl.dsp.exec_cmd("hyprctl keyword decoration:active_opacity 1.0 && hyprctl keyword decoration:inactive_opacity 0.95")
)

-- Workspaces
for i = 1, 9 do
	hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
	hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Move windows within workspace
hl.bind(mod .. " + CTRL + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + CTRL + J", hl.dsp.window.move({ direction = "d" }))
hl.bind(mod .. " + CTRL + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + CTRL + L", hl.dsp.window.move({ direction = "r" }))

-- Mouse bindings
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Applications
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("rofi -show drun -show-icons"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("nautilus"))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("ghostty -e yazi"))

-- Hyper key app launchers (Caps Lock + 1-6)
-- Class names: run `hyprctl clients | grep class` to verify.
hl.bind(hyper .. " + 1", hl.dsp.exec_cmd("focus-or-launch helium helium"))
hl.bind(hyper .. " + 3", hl.dsp.exec_cmd("focus-or-launch com.mitchellh.ghostty ghostty"))
hl.bind(hyper .. " + 5", hl.dsp.exec_cmd("focus-or-launch discord discord"))
hl.bind(hyper .. " + p", hl.dsp.exec_cmd("focus-or-launch _1password-gui 1password-gui"))

-- Send current window to special (scratchpad) and show/hide it
hl.bind(mod .. " + Y", hl.dsp.window.move({ workspace = "special", follow = false }))
hl.bind(mod .. " + SHIFT + Y", hl.dsp.workspace.toggle_special(""))

-- Utilities
hl.bind(mod .. " + V", hl.dsp.exec_cmd([[cliphist list | rofi -dmenu -p "clipboard" | cliphist decode | wl-copy]]))

-- Screenshots
hl.bind(
	mod .. " + P",
	hl.dsp.exec_cmd([[mkdir -p ~/Pictures && grim -g "$(slurp)" ~/Pictures/shot-$(date +'%F_%T').png]])
)
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]]))
hl.bind(mod .. " + CTRL + P", hl.dsp.exec_cmd("grim - | wl-copy"))

-- Media Keys
-- ==========

-- Volume control
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

-- Media playback control
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Brightness control (requires brightnessctl)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { repeating = true })

-- Resize Mode
-- ===========

hl.bind(mod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
	hl.bind("H", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { repeating = true })
	hl.bind("L", hl.dsp.window.resize({ x = 20, y = 0, relative = true }), { repeating = true })
	hl.bind("K", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true })
	hl.bind("J", hl.dsp.window.resize({ x = 0, y = 20, relative = true }), { repeating = true })
	hl.bind("escape", hl.dsp.submap("reset"))
	hl.bind("q", hl.dsp.submap("reset"))
	hl.bind(mod .. " + R", hl.dsp.submap("reset"))
	hl.bind("Return", hl.dsp.submap("reset"))
end)
