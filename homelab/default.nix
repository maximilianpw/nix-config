{lib, ...}: {
  imports = [
    ./cloudflared.nix
    ./container-hygiene.nix
    ./executor.nix
    ./home-assistant.nix
    ./homepage.nix
    ./immich.nix
    ./media.nix
    ./miniflux.nix
    ./monitoring.nix
    ./nextcloud.nix
    ./paperless.nix
    ./storage.nix
    ./syncthing.nix
    ./tailscale-serve.nix
    ./uptime-kuma.nix
    ./vaultwarden.nix
  ];

  # Homelab services connect through /run/postgresql. Do not occupy the common
  # TCP port so local dev stacks can bind 5432 themselves.
  services.postgresql.settings.listen_addresses = lib.mkForce "";
}
