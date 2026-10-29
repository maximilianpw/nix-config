# Rex

[Rex](https://www.superlogical.com/rex/docs/installation) comes from its
prebuilt flake on the `preview` channel (`inputs.rex`).

- **Kim** runs the NixOS login server (`machines/kim.nix`). It listens on
  Kim's tailnet addresses at port 7297, and only `tailscale0` has that port
  open. Rex identifies callers through Kim's tailscaled. The only account is
  `maxpw`, for the Tailscale login `maximilianpw@github`.
- **Joyce** runs the server in Rex Beta.app. Home Manager's `programs.rex`
  adds the CLI, the `xterm-rex` terminfo and the ssh guard.
- **CI** uses the inert stub in `tests/stubs/rex`. When the real module's
  options change, mirror them there.

## Package token

Until Rex's first release, `pkgs.superlogical.com` requires a testing-wave
token. Every machine that evaluates this flake needs the token in a netrc
file. The file is created by hand and is kept out of Git, sops and the Nix
store. The line is:

```text
machine pkgs.superlogical.com login rex password TOKEN
```

- **Joyce (Determinate Nix):** `/etc/determinate/rex.netrc`, mode `0600`
  root. `machines/joyce.nix` owns `/etc/determinate/config.json`, which lists
  that file under `additionalNetrcSources`. Determinate merges the token into
  `/nix/var/determinate/netrc`, and every local user can read that file.
- **Kim (NixOS):** `/etc/nix/netrc`, owned by root, group `wheel`, mode
  `0640`. Evaluation runs as `maxpw`, so the group must be able to read it.

On a new NixOS machine, create the netrc before the first evaluation:

```sh
read -rs token
printf 'machine pkgs.superlogical.com\nlogin rex\npassword %s\n' "$token" \
  | sudo install -m 0640 -o root -g wheel /dev/stdin /etc/nix/netrc
unset token
```

Without the netrc, any evaluation that includes `rex` fails with HTTP 401.

## Connecting

In Rex for Mac, choose **Add Remote Host…** and enter
`kim.liger-shilling.ts.net`. Plain HTTP on 7297 is expected; Tailscale
encrypts it. To check from the CLI on another tailnet machine (Kim refuses
connections from its own tailnet address):

```sh
rex -S kim.liger-shilling.ts.net ls
```

On Kim, `sudo journalctl -u rex-login-server` shows the login server's log.
Run `rex client ls` there to list the principals that are connected.
