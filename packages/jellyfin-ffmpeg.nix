{
  ffmpeg_8-full,
  fetchFromGitHub,
}: let
  version = "8.1.2-4";
in
  (ffmpeg_8-full.override {
    # Set the version through override so the builder selects the FFmpeg 8 ABI.
    inherit version;
    source = fetchFromGitHub {
      owner = "jellyfin";
      repo = "jellyfin-ffmpeg";
      tag = "v${version}";
      hash = "sha256-+xUjwhVX/HyS/+Gmv8iQfUwHax7xjX3SSOjs34IDHHs=";
    };
  }).overrideAttrs (old: {
    pname = "jellyfin-ffmpeg";

    configureFlags =
      old.configureFlags
      ++ [
        "--extra-version=Jellyfin"
      ];

    # Jellyfin ships its transcoding changes as an unapplied Debian patch series.
    postPatch = ''
      while IFS= read -r patchFile; do
        patch -p1 < "debian/patches/$patchFile"
      done < debian/patches/series

      ${old.postPatch or ""}
    '';

    meta =
      old.meta
      // {
        changelog = "https://github.com/jellyfin/jellyfin-ffmpeg/releases/tag/v${version}";
        description = "${old.meta.description} (Jellyfin fork)";
        homepage = "https://github.com/jellyfin/jellyfin-ffmpeg";
      };
  })
