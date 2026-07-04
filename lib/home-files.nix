{
  lib,
  mkOutOfStoreSymlink,
}: {
  mkHomeSource = homeDirectory: path:
    mkOutOfStoreSymlink "${homeDirectory}/${path}";

  mkRepoSource = homeDirectory: path:
    mkOutOfStoreSymlink "${homeDirectory}/nix-config/${path}";

  symlinkDir = {
    dir,
    outOfStoreDir,
    prefix,
    exclude ? [],
  }:
    lib.mapAttrs' (name: _: {
      name = "${prefix}/${name}";
      value = {source = mkOutOfStoreSymlink "${outOfStoreDir}/${name}";};
    }) (lib.filterAttrs (name: _: !(builtins.elem name exclude)) (builtins.readDir dir));
}
