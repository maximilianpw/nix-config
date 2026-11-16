{
  config,
  homeFiles,
  lib,
  pkgs,
  ...
}: let
  # Keep plan/code reviews, but prevent native plugins or the CLI from
  # registering Inbox tools, reconnecting agents, or publishing the Inbox.
  inboxEnvironment = {
    PLANNOTATOR_INBOX_CONNECT = "0";
    PLANNOTATOR_INBOX_NOTES = "0";
    PLANNOTATOR_INBOX_TAILSCALE = "0";
    PLANNOTATOR_INBOX_TOOL = "0";
  };
  plannotator = pkgs.symlinkJoin {
    name = "plannotator-configured-${pkgs.plannotator.version}";
    paths = [pkgs.plannotator];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram "$out/bin/plannotator" ${lib.concatStringsSep " " (lib.mapAttrsToList (name: value: "--set ${name} ${lib.escapeShellArg value}") inboxEnvironment)}
    '';
  };
in {
  home = {
    packages = [plannotator];
    sessionVariables = inboxEnvironment;

    file = {
      # Native review plugins prefer the installer's usual path over PATH.
      ".local/bin/plannotator".source = "${plannotator}/bin/plannotator";
      # Plannotator rewrites its config, so it links to the checkout, not the
      # store; `git diff` shows the app's changes for review.
      ".plannotator/config.json".source = homeFiles.mkRepoSource config.home.homeDirectory "users/maxpw/files/editable/.plannotator/config.json";
    };

    # Undo the old Inbox registration without replacing Codex's mutable
    # configuration or touching saved Plannotator messages and attachments.
    activation.removePlannotatorInboxCodex = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run ${lib.getExe pkgs.codex} mcp remove plannotator-inbox
    '';
  };
}
