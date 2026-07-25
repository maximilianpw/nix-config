{
  config,
  currentSystemUserDir,
  lib,
  ...
}: let
  homeFiles = import ../../../lib/home-files.nix {
    inherit lib;
    mkOutOfStoreSymlink = config.lib.file.mkOutOfStoreSymlink;
  };
  skillsDir = ../agents/shared/skills;
  skillNames = builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsDir));
  destinations = [
    ".agents/skills"
    ".claude/skills"
    ".config/opencode/skills"
    ".config/agents/skills"
    ".grok/skills"
  ];
  skillLinks = lib.listToAttrs (lib.concatMap (destination:
    builtins.map (skillName: {
      name = "${destination}/${skillName}";
      value = {
        source = homeFiles.mkRepoSource config.home.homeDirectory "users/${currentSystemUserDir}/agents/shared/skills/${skillName}";
        force = true;
      };
    })
    skillNames)
  destinations);
in {
  home.file = skillLinks;
}
