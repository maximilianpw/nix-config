{lib, ...}: {
  imports = [
    ./buzz.nix
    ./cloudflared.nix
    ./home-assistant.nix
    ./homepage.nix
    ./miniflux.nix
    ./nextcloud.nix
    ./paperless.nix
    ./storage.nix
    ./syncthing.nix
    ./tailscale-serve.nix
    ./uptime-kuma.nix
  ];

  # Homelab services connect through /run/postgresql. Do not occupy the common
  # TCP port so local dev stacks can bind 5432 themselves.
  services.postgresql.settings.listen_addresses = lib.mkForce "";
}
