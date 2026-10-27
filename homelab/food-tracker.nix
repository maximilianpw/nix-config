{
  inputs,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit (homelab.endpoints) food-tracker;
  web = pkgs.callPackage ../packages/food-tracker.nix {src = inputs.food-tracker-src;};
in {
  # The journal has no server state. Serve the compiled SPA, never Vite dev or
  # a public Cloudflare origin. Tailscale owns HTTPS and tailnet authorization.
  services.nginx = {
    enable = true;
    virtualHosts.${food-tracker.host} = {
      listen = [
        {
          addr = "127.0.0.1";
          inherit (food-tracker) port;
        }
      ];
      root = web;
      locations = {
        "/".tryFiles = "$uri $uri/ /index.html";
        "= /index.html".extraConfig = "add_header Cache-Control \"no-cache\";";
        "= /sw.js" = {
          tryFiles = "$uri =404";
          extraConfig = "add_header Cache-Control \"no-cache\";";
        };
        "= /manifest.webmanifest" = {
          tryFiles = "$uri =404";
          extraConfig = ''
            default_type application/manifest+json;
            add_header Cache-Control "no-cache";
          '';
        };
        "/assets/".extraConfig = "add_header Cache-Control \"public, max-age=31536000, immutable\";";
      };
    };
  };
}
