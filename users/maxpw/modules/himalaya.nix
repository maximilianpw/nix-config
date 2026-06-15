# Himalaya CLI email client for the Proton Mail account, talking to the local
# Proton Mail Bridge (127.0.0.1:1143 IMAP / :1025 SMTP, STARTTLS). Configured
# declaratively via Home Manager's `accounts.email` framework; enabling
# `programs.himalaya` installs the package and generates config.toml.
#
# Secret handling mirrors the borg backup passphrase: the Bridge password lives
# encrypted in secrets/secrets.yaml under sops, is decrypted at activation, and
# is read at runtime via `passwordCommand = "cat <path>"`. The decrypt path
# differs per platform:
#   - darwin: nix-darwin has no system sops, so we use sops-nix's home-manager
#     module (activates via a launchd agent) -> ~/.config/sops-nix/secrets/...
#   - NixOS:  reuse the existing *system* sops (modules/core/sops.nix), exactly
#     like borg -> /run/secrets/...
#
# Proton Bridge generates a DIFFERENT password per machine, so the Mac and
# main-pc use separate sops keys:
#   - darwin -> himalaya-work-password      (added via the HM sops module here)
#   - NixOS  -> himalaya-bridge-password    (declared in modules/core/sops.nix)
#
# Enabled on the Mac and the Linux desktop; skipped on WSL.
{
  isDarwin,
  isLinuxDesktop,
  inputs,
  config,
  lib,
  ...
}: let
  enableMail = isDarwin || isLinuxDesktop;

  # Path to the sops-decrypted Bridge password, per platform.
  passwordFile =
    if isDarwin
    then config.sops.secrets.himalaya-work-password.path
    else "/run/secrets/himalaya-bridge-password";
in {
  imports = lib.optionals isDarwin [
    inputs.sops-nix.homeManagerModules.sops
  ];

  config = lib.mkIf enableMail (lib.mkMerge [
    # darwin only: sops-nix home-manager module. Decrypts at activation using the
    # age key at ~/.config/sops/age/keys.txt (backed up in 1Password). On NixOS
    # the system sops module (modules/core/sops.nix) handles this instead.
    # optionalAttrs (not mkIf): the `sops` option only exists when the HM sops
    # module is imported, which is darwin-only above.
    (lib.optionalAttrs isDarwin {
      sops = {
        age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
        defaultSopsFile = ../../../secrets/secrets.yaml;
        secrets.himalaya-work-password = {};
      };
    })
    {
      programs.himalaya.enable = true;

      accounts.email.accounts.work = {
        primary = true;
        himalaya.enable = true;

        address = "mpinderwhite@proton.me";
        realName = "Maximilian Pinder-White";
        userName = "mpinderwhite@proton.me"; # Bridge IMAP/SMTP login

        # Borg-style secret: read the sops-decrypted Bridge password at runtime.
        # NOTE: this is the Proton *Bridge* password, not your Proton login.
        passwordCommand = "cat ${passwordFile}";

        # Proton Bridge listens on localhost with STARTTLS.
        imap = {
          host = "127.0.0.1";
          port = 1143;
          tls.useStartTls = true;
        };
        smtp = {
          host = "127.0.0.1";
          port = 1025;
          tls.useStartTls = true;
        };

        folders = {
          inbox = "INBOX";
          sent = "Sent";
          drafts = "Drafts";
          trash = "Trash";
        };
      };
    }
  ]);
}
