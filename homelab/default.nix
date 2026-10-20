{lib, ...}: {
  imports = [
    ./actual.nix
    ./atuin.nix
    ./backup.nix
    ./cloudflared.nix
    ./cliproxyapi.nix
    ./container-hygiene.nix
    ./executor.nix
    ./forgejo.nix
    ./home-assistant.nix
    ./homepage
    ./immich.nix
    ./leerr.nix
    ./media-mcp.nix
    ./media
    ./miniflux
    ./monitoring
    ./nextcloud.nix
    ./paperless.nix
    ./portfolio-tracker.nix
    ./storage.nix
    ./superlocal.nix
    ./syncthing.nix
    ./tailscale-serve.nix
    ./uptime-kuma.nix
    ./vaultwarden.nix
  ];

  # Homelab services connect through /run/postgresql. Do not occupy the common
  # TCP port so local dev stacks can bind 5432 themselves.
  services.postgresql.settings.listen_addresses = lib.mkForce "";
}
