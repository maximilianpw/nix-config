{
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

    # Native review plugins prefer the installer's usual path over PATH.
    file.".local/bin/plannotator".source = "${plannotator}/bin/plannotator";

    # Undo the old Inbox registration without replacing Codex's mutable
    # configuration or touching saved Plannotator messages and attachments.
    activation.removePlannotatorInboxCodex = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run ${lib.getExe pkgs.codex} mcp remove plannotator-inbox
    '';
  };
}
