#!/bin/bash
# Build the distributable Nova Tweaks Minecraft app for macOS.
# Syncs the shared engine, bundles PowerShell 7 into the .app, and rebuilds the storefront zip.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="$ROOT/macos/Minecraft/Nova Tweaks Minecraft.app"
RES="$APP/Contents/Resources"
PWSH_SRC="${PWSH_SRC:-/usr/local/microsoft/powershell/7}"
DEST="$RES/pwsh"
ZIP="$ROOT/docs/downloads/Nova-Tweaks-Minecraft-macOS.zip"

if [ ! -d "$APP" ]; then
  echo "App bundle not found: $APP"
  exit 1
fi

echo "Syncing shared engine..."
cp "$ROOT/shared/Nova_Tweaks_WebGUI.ps1" "$RES/Nova_Tweaks_WebGUI.ps1"

if [ -x "$DEST/pwsh" ]; then
  echo "Bundled pwsh already present: $("$DEST/pwsh" -NoProfile -Command '$PSVersionTable.PSVersion.ToString()')"
else
  if [ ! -x "$PWSH_SRC/pwsh" ]; then
    echo "PowerShell 7 not found at $PWSH_SRC"
    echo "Install it with: brew install --cask powershell"
    echo "Or point at an existing install: PWSH_SRC=/path/to/powershell/7 $0"
    exit 1
  fi
  echo "Bundling pwsh from $PWSH_SRC..."
  rm -rf "$DEST"
  mkdir -p "$DEST"
  cp -R "$PWSH_SRC/." "$DEST/"
  # Runtime-only: drop compiler reference assemblies and XML docs.
  rm -rf "$DEST/ref"
  rm -f "$DEST"/*.xml
fi

echo "Rebuilding zip..."
mkdir -p "$ROOT/docs/downloads"
rm -f "$ZIP"
cd "$ROOT/macos/Minecraft"
ditto -c -k --sequesterRsrc --keepParent "Nova Tweaks Minecraft.app" "$ZIP"
ls -lh "$ZIP"
echo "Done."
