{
  stdenvNoCC,
  nodejs,
  pnpm_12,
  pnpmConfigHook,
  fetchPnpmDeps,
  src,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "food-tracker-web";
  version = "f9d598de";
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
    hash = "sha256-ko09PBLND4ADV2gSEH2H++m9k08Lxnl52S0Cm94phzc=";
  };
  buildPhase = ''
    runHook preBuild
    pnpm --filter @food-tracker/web build
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    test -s apps/web/dist/client/index.html
    mkdir -p "$out"
    cp -r apps/web/dist/client/. "$out/"
    runHook postInstall
  '';
  meta.description = "Foodlog browser-local food journal";
})
