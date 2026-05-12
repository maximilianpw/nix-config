-- Animations and Visual Effects
-- =============================

hl.config({
	animations = {
		enabled = true,
		workspace_wraparound = false,
	},

	decoration = {
		rounding = 6,
		active_opacity = 1.0,
		inactive_opacity = 0.95,

		dim_inactive = true,
		dim_strength = 0.15,

		blur = {
			enabled = true,
			size = 8,
			passes = 3,
			ignore_opacity = true,
		},

		glow = {
			enabled = true,
			range = 10,
			render_power = 3,
			color = "rgba(33ccffee)",
			color_inactive = "rgba(33ccff00)",
		},
	},
})

hl.curve("ease", { type = "bezier", points = { { 0.20, 0.10 }, { 0.10, 1.00 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "ease", style = "popin" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "ease", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "ease" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "ease" })
hl.animation({ leaf = "workspaces", enabled = false })
