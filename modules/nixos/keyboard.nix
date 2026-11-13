# Colemak everywhere: the console and the XKB data Wayland compositors read.
_: {
  console.keyMap = "colemak";
  services.xserver.xkb = {
    layout = "us";
    variant = "colemak";
  };
}
