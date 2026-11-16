{inputs, ...}: {
  imports = [inputs.rex.homeManagerModules.default];

  # Rex Beta.app runs Joyce's server; this adds its CLI, terminfo and ssh guard.
  programs.rex.enable = true;
}
