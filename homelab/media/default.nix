{
  # Keep the media stack coupled through one stable import while each deployment
  # concern owns its host services, Tunarr, or downloader container settings.
  imports = [
    ./host-services.nix
    ./companions.nix
    ./tunarr.nix
    ./qbittorrent.nix
    ./sabnzbd.nix
  ];
}
