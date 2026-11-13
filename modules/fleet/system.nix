{
  currentSystemUser,
  hostInventory,
  isDarwin,
  lib,
  ...
}: let
  enrolledClients = lib.filterAttrs (_: host: host.client != null) hostInventory;
  authorizedKey = host: ''from="${lib.concatStringsSep "," host.client.tailscaleIps}" ${host.client.key}'';
  authorizedKeys = lib.mapAttrsToList (_: authorizedKey) enrolledClients;
  tailnetUsers = [
    "${currentSystemUser}@100.64.0.0/10"
    "${currentSystemUser}@fd7a:115c:a1e0::/48"
  ];
in {
  users.users.${currentSystemUser}.openssh.authorizedKeys.keys = authorizedKeys;

  services.openssh =
    {enable = true;}
    // lib.optionalAttrs isDarwin {
      extraConfig = ''
        PasswordAuthentication no
        KbdInteractiveAuthentication no
        PermitRootLogin no
        AuthenticationMethods publickey
        AllowUsers ${lib.concatStringsSep " " tailnetUsers}
      '';
    }
    // lib.optionalAttrs (!isDarwin) {
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        AuthenticationMethods = "publickey";
        AllowUsers = tailnetUsers;
      };
    };
}
