# macOS only: Aikido Endpoint Protection inspects HTTPS through its own root CA.
# Nixpkgs' git verifies against the Nix CA bundle rather than the macOS
# keychain, so HTTPS fetches (such as Pi's git packages) fail with
# "self-signed certificate in certificate chain". Aikido's own git trust rule
# cannot write the global git config because Home Manager owns it, so point git
# at the bundle Aikido maintains: the public roots plus its proxy CA. If Aikido
# is uninstalled, the file disappears and HTTPS git fails until this module is
# removed.
{
  lib,
  isDarwin,
  ...
}: {
  programs.git.settings.http.sslCAInfo = lib.mkIf isDarwin "/Library/Application Support/AikidoSecurity/EndpointProtection/run/endpoint-protection-openssl-combined-ca.pem";
}
