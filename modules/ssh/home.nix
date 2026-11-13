{
  config,
  hostRecord,
  isDarwin,
  isLinuxDesktop,
  isWSL,
  lib,
  ...
}: let
  githubAuthenticationKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSE4irNaEh8R1RxL0/839aKlA9KgdKIZl/uKgGCvMzs GitHub Authentication Key";
  # Darwin authenticates through the 1Password agent; headless NixOS through
  # the sops key modules/ssh/nixos.nix declares. WSL and the desktop use neither.
  useSopsGithubSshKey = !isDarwin && !isLinuxDesktop && !isWSL;
in {
  home = {
    activation.ensureOnePasswordAgentSymlink = lib.mkIf isDarwin (lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      agent_dir="${config.home.homeDirectory}/.1password"
      agent_target="${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

      mkdir -p "$agent_dir"
      ln -sfn "$agent_target" "$agent_dir/agent.sock"
    '');

    file = lib.mkIf isDarwin {
      ".ssh/github-authentication_ed25519.pub".text = githubAuthenticationKey + "\n";
      ".ssh/fleet_1password_ed25519.pub".text = hostRecord.client.key + "\n";
    };

    sessionVariables = lib.mkIf isDarwin {
      # See: https://github.com/NixOS/nixpkgs/issues/390751
      DISPLAY = "nixpkgs-390751";
      SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";
    };
  };

  programs.ssh = {
    enable = true;
    # Keep SSH defaults explicit as Home Manager changes its implicit defaults.
    enableDefaultConfig = false;
    includes = lib.optionals isDarwin ["~/.orbstack/ssh/config"];
    settings = lib.mkMerge [
      (lib.mkIf isDarwin {
        "github.com" = {
          HostName = "github.com";
          User = "git";
          IdentityAgent = "%d/.1password/agent.sock";
          IdentityFile = "~/.ssh/github-authentication_ed25519.pub";
          IdentitiesOnly = "yes";
          AddKeysToAgent = "no";
        };
      })
      (lib.mkIf useSopsGithubSshKey {
        "github.com" = {
          HostName = "github.com";
          User = "git";
          IdentityFile = "/run/secrets/github-ssh-private-key";
          IdentitiesOnly = "yes";
          AddKeysToAgent = "no";
        };
      })
    ];
  };
}
