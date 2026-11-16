# Himalaya CLI email client for the Proton Mail account, talking to the local
# Proton Mail Bridge (127.0.0.1:1143 IMAP / :1025 SMTP, STARTTLS). Configured
# declaratively via Home Manager's `accounts.email` framework; enabling
# `programs.himalaya` installs the package and generates config.toml.
#
# Proton Bridge generates a different password per machine, so each platform
# has its own sops secret, read at runtime via `passwordCommand`:
#   - darwin: himalaya-work-password, decrypted by the Home Manager sops module
#   - NixOS:  himalaya-bridge-password, a system secret under /run/secrets
#
# Imported by the Mac and Linux desktop profiles only.
{
  isDarwin,
  config,
  pkgs,
  lib,
  ...
}: let
  passwordFile =
    if isDarwin
    then config.sops.secrets.himalaya-work-password.path
    else "/run/secrets/himalaya-bridge-password";

  bridgeCertFile = "${config.xdg.configHome}/himalaya/proton-bridge-cert.pem";
in {
  config = lib.mkMerge [
    {sops.secrets.himalaya-work-password = lib.mkIf isDarwin {};}
    {
      home.activation.exportProtonBridgeCert = lib.hm.dag.entryAfter ["writeBoundary"] ''
        cert_file="${bridgeCertFile}"
        cert_dir="$(dirname "$cert_file")"
        mkdir -p "$cert_dir"

        if ${pkgs.coreutils}/bin/timeout 2 ${pkgs.bash}/bin/bash -c "</dev/tcp/127.0.0.1/1143" 2>/dev/null; then
          ${pkgs.openssl}/bin/openssl s_client -starttls imap -connect 127.0.0.1:1143 -showcerts </dev/null 2>/dev/null \
            | ${pkgs.openssl}/bin/openssl x509 -outform PEM > "$cert_file"
        elif [ ! -s "$cert_file" ]; then
          echo "Proton Mail Bridge is not listening on 127.0.0.1:1143; cannot export certificate for himalaya." >&2
        fi
      '';

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

        himalaya.settings = {
          backend.encryption.cert = bridgeCertFile;
          message.send.backend.encryption.cert = bridgeCertFile;
        };

        folders = {
          inbox = "INBOX";
          sent = "Sent";
          drafts = "Drafts";
          trash = "Trash";
        };
      };
    }
  ];
}
