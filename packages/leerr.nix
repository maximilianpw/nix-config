{
  lib,
  buildNpmPackage,
  nodejs_24,
  makeWrapper,
}:
buildNpmPackage {
  pname = "leerr";
  version = "0-unstable-2026-09-12-b4dc546f";
  # Production handoff plus setup, rose, auth, cache and search/artwork fixes.
  # Provenance and archive SHA256 are recorded in docs/leerr.md.
  src = ./leerr/source.tar.gz;
  sourceRoot = ".";
  nodejs = nodejs_24;
  npmDepsHash = "sha256-mSv7DuN+Z47fkMxfXUmFBnme9Y7cJdMlJNLx6KfRneI=";
  nativeBuildInputs = [makeWrapper];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    npm test
    npm run lint
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    npm prune --omit=dev --ignore-scripts
    # Some production dependencies ship their own test fixtures in npm tarballs.
    find node_modules -type d \( -name test -o -name tests -o -name __tests__ -o -name spec -o -name fixtures \) -prune -exec rm -rf {} +
    mkdir -p "$out/lib/leerr/server" "$out/bin"
    node --input-type=module -e '
      import fs from "node:fs";
      const { name, private: privatePackage, type, engines, dependencies, scripts } = JSON.parse(fs.readFileSync("package.json", "utf8"));
      fs.writeFileSync(process.argv[1], JSON.stringify({ name, private: privatePackage, type, engines, dependencies, scripts: { start: scripts.start, operator: scripts.operator } }, null, 2) + "\n");
    ' "$out/lib/leerr/package.json"
    cp -r node_modules dist "$out/lib/leerr/"
    # Install only real runtime modules: preview, fixtures and tests stay out.
    cp server/{main,app,config,store,upstream,worker,operator}.ts "$out/lib/leerr/server/"
    install -Dm644 web/src/fonts/LICENSE.txt "$out/share/licenses/leerr/Inter-OFL.txt"
    makeWrapper ${lib.getExe nodejs_24} "$out/bin/leerr" \
      --chdir "$out/lib/leerr" \
      --add-flags "--import tsx server/main.ts"
    runHook postInstall
  '';

  meta = {
    description = "Private music library and requests with per-user Jellyfin access";
    mainProgram = "leerr";
    platforms = ["x86_64-linux"];
  };
}
