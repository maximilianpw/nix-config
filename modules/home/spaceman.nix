{
  config,
  homeFiles,
  ...
}: {
  # Spaceman saves settings changed in its window back to this file, so it
  # links to the checkout, not the store.
  home.file."Library/Application Support/Spaceman/config.toml".source = homeFiles.mkRepoSource config.home.homeDirectory "users/maxpw/files/editable/Library/Application Support/Spaceman/config.toml";
}
