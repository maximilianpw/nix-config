{
  jellyfin-web,
  fetchFromGitHub,
  fetchNpmDeps,
  nodejs_24,
}:
# Pass the unmodified nixpkgs jellyfin-web when calling this from an overlay.
(jellyfin-web.override {nodejs_22 = nodejs_24;}).overrideAttrs (finalAttrs: old: {
  version = "12.0.0";

  # Jellyfin dropped the leading 10 and tags this release without the patch zero.
  src = fetchFromGitHub {
    owner = "jellyfin";
    repo = "jellyfin-web";
    tag = "v12.0";
    hash = "sha256-LwFjfG+OLgQDP7GqD4/wQhmym4N5QWe/qITQN+hxHh8=";
  };

  npmDepsHash = "sha256-1s9PWqakzZMiZokOqnKfwaj9s7yWm6e/xh4R5OmTNMc=";
  # The inherited dependency derivation still captures nixpkgs' original source.
  npmDeps = fetchNpmDeps {
    name = "jellyfin-web-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src postPatch;
    hash = finalAttrs.npmDepsHash;
  };

  meta =
    old.meta
    // {
      changelog = "https://github.com/jellyfin/jellyfin-web/releases/tag/${finalAttrs.src.tag}";
    };
})
