{
  config,
  currentSystemUser,
  lib,
  ...
}: {
  users.users.${currentSystemUser} = {
    isNormalUser = true;
    description = lib.mkDefault "Maximilian PINDER-WHITE";
    home = "/home/${currentSystemUser}";
    shell = config.custom.shells.login;
    extraGroups = ["wheel"];
  };
}
