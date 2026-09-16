{
  # Keep the media stack coupled through one stable import while each deployment
  # concern owns its host services, Tunarr, or downloader container settings.
  imports = [
    ./media/host-services.nix
    ./media/tunarr.nix
    ./media/qbittorrent.nix
    ./media/sabnzbd.nix
  ];
}
