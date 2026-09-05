# Repo-local package registration. `systems` controls flake output exposure,
# not overlay availability; upstream tools remain outside this registry.
{
  helium = {
    source = ./helium.nix;
    systems = ["x86_64-linux"];
    update = true;
  };
  obsidian = {
    source = ./obsidian.nix;
    systems = ["x86_64-linux"];
    update = true;
  };
  cliproxyapi = {
    source = ./cliproxyapi.nix;
    systems = ["x86_64-linux"];
    update = true;
  };
  nextcloud-calendar = {
    source = ./nextcloud-calendar.nix;
    systems = ["x86_64-linux" "aarch64-darwin"];
    update = true;
  };
  tunarr = {
    source = ./tunarr.nix;
    systems = ["x86_64-linux"];
    update = true;
  };
}
