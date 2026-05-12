-- Environment Variables
-- =====================

-- Wayland-friendly envs (already set OZONE via NixOS)
hl.env("GDK_SCALE", "1.6")
hl.env("GDK_DPI_SCALE", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("XCURSOR_THEME", "Vanilla-DMZ")
hl.env("XCURSOR_SIZE", "128")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
