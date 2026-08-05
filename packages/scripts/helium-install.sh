#!/usr/bin/env bash

: "${out:?out must be set by the Nix build environment}"
: "${NIX_CC:?NIX_CC must be set by the Nix build environment}"
: "${HELIUM_LIB_PATH:?HELIUM_LIB_PATH must be set}"

runHook preInstall

mkdir -p "$out" "$out/bin" "$out/opt"

cp -r opt/helium "$out/opt/helium"
cp -r usr/share "$out/share"

# Patch main binaries
patchelf \
  --set-interpreter "$(cat "$NIX_CC/nix-support/dynamic-linker")" \
  --set-rpath "$HELIUM_LIB_PATH" \
  "$out/opt/helium/helium"

patchelf \
  --set-interpreter "$(cat "$NIX_CC/nix-support/dynamic-linker")" \
  --set-rpath "$HELIUM_LIB_PATH" \
  "$out/opt/helium/helium_crashpad_handler"

# Patch shared libraries that need it
for lib in "$out/opt/helium/libEGL.so" "$out/opt/helium/libGLESv2.so"; do
  if [ -f "$lib" ]; then
    patchelf --set-rpath "$HELIUM_LIB_PATH" "$lib" || true
  fi
done

# Fix the upstream wrapper script to use the correct binary path
substituteInPlace "$out/opt/helium/helium-wrapper" \
  --replace-fail '$HERE/helium' "$out/opt/helium/helium"

# Create symlink for wrapGAppsHook to wrap (like Brave does)
ln -sf "$out/opt/helium/helium-wrapper" "$out/bin/helium"

# Fix .desktop file
substituteInPlace "$out/share/applications/helium.desktop" \
  --replace-fail 'Exec=helium' "Exec=$out/bin/helium" \
  --replace-fail 'Icon=helium' "Icon=$out/share/icons/hicolor/256x256/apps/helium.png"

# Copy icon to hicolor theme directory
mkdir -p "$out/share/icons/hicolor/256x256/apps"
if [ -f "$out/opt/helium/product_logo_256.png" ]; then
  cp "$out/opt/helium/product_logo_256.png" "$out/share/icons/hicolor/256x256/apps/helium.png"
elif [ -f "$out/opt/helium/product_logo.png" ]; then
  cp "$out/opt/helium/product_logo.png" "$out/share/icons/hicolor/256x256/apps/helium.png"
fi

runHook postInstall
