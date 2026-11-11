{lib, ...}: {
  imports = [
    ./actual.nix
    ./atuin.nix
    ./backup
    ./cloudflared.nix
    ./cliproxyapi.nix
    ./container-hygiene
    ./executor.nix
    ./forgejo.nix
    ./home-assistant
    ./homepage
    ./immich.nix
    ./leerr.nix
    ./media-mcp.nix
    ./media
    ./miniflux
    ./monitoring
    ./nextcloud
    ./paperless.nix
    ./portfolio-tracker.nix
    ./storage.nix
    ./syncthing.nix
    ./tailscale-serve
    ./uptime-kuma
    ./vaultwarden.nix
  ];

  # Homelab services connect through /run/postgresql. Do not occupy the common
  # TCP port so local dev stacks can bind 5432 themselves.
  services.postgresql.settings.listen_addresses = lib.mkForce "";
}
