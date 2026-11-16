{
  currentSystemUser,
  isLinuxDesktop,
  lib,
  ...
}: {
  # The op CLI is useful headless too; only the GUI is desktop-gated.
  programs._1password.enable = true;
  programs._1password-gui = lib.mkIf isLinuxDesktop {
    enable = true;
    polkitPolicyOwners = [currentSystemUser];
  };

  environment = {
    sessionVariables = lib.mkIf (!isLinuxDesktop) {
      # Headless hosts cannot use 1Password desktop-app authentication.
      # Force `op signin` to use the manually configured account instead.
      OP_BIOMETRIC_UNLOCK_ENABLED = "false";
    };

    etc = lib.optionalAttrs isLinuxDesktop {
      # Allow Helium (Chromium fork) to talk to the 1Password desktop app via
      # native messaging. 1Password verifies browsers against a built-in list
      # plus this file; it must be owned by root with mode 0755 or it's ignored.
      "1password/custom_allowed_browsers" = {
        text = ''
          helium
          .helium-wrapped
        '';
        mode = "0755";
      };
    };
  };
}
