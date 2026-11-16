{
  stdenvNoCC,
  runCommand,
  nodejs,
  pnpm_12,
  pnpmConfigHook,
  fetchPnpmDeps,
  src,
}:
# CI swaps the private source for tests/stubs/food-tracker; build a placeholder
# with the same layout so the service configuration still evaluates and builds.
if builtins.pathExists (src + "/CI_STUB")
then
  runCommand "food-tracker-ci-stub" {} ''
    mkdir -p "$out/client" "$out/server" "$out/migrations"
    printf '%s\n' '<!doctype html><title>CI fixture</title>' > "$out/client/index.html"
    printf '%s\n' 'process.exit(1)' > "$out/server/main.mjs"
  ''
else
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "food-tracker";
    # Follows the flake pin. After changing it, refresh the pnpmDeps hash below.
    version = src.shortRev;
    inherit src;

    nativeBuildInputs = [nodejs pnpm_12 pnpmConfigHook];
    # pnpm 12 stores its own package-manager lock in the first YAML document.
    # Nix provides pnpm; retain the application's unmodified dependency lock.
    postPatch = ''
      awk '/^---$/ {document++; next} document == 2 {print}' pnpm-lock.yaml > app-lock.yaml
      mv app-lock.yaml pnpm-lock.yaml
      substituteInPlace package.json --replace-fail '"packageManager": "pnpm@12.0.0",' ""
    '';
    pnpmDeps = fetchPnpmDeps {
      inherit (finalAttrs) pname src postPatch;
      pnpm = pnpm_12;
      fetcherVersion = 5;
      hash = "sha256-JMHzUhLSsTZXm3RP5hqBEjAYrWKJ4so9BMgeIdFFiZU=";
    };
    buildPhase = ''
      runHook preBuild
      pnpm --filter @food-tracker/web build
      pnpm build:server
      runHook postBuild
    '';
    # The server bundle inlines its dependencies; only Node is needed to run it.
    installPhase = ''
      runHook preInstall
      test -s apps/web/dist/client/index.html
      test -s dist/server/main.mjs
      mkdir -p "$out/server"
      cp -r apps/web/dist/client "$out/client"
      cp dist/server/main.mjs "$out/server/main.mjs"
      cp -r migrations "$out/migrations"
      runHook postInstall
    '';
    meta.description = "Foodlog kitchen and food journal: web app, API server and migrations";
  })
