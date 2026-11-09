#!/bin/bash
# Nova Tweaks - combined Windows catalog preview (Fortnite + Minecraft)
# Opens the real localhost UI with both Windows catalogs in one session.
# This only previews the Windows UI on macOS; no Windows system changes are made.
set -e
cd "$(dirname "$0")" || exit 1

export NOVA_WINDOWS_PREVIEW=1
export NOVA_SKIP_ADMIN=1
unset NOVA_FIXED_GAME
unset NOVA_APP_VARIANT
unset NOVA_STDIO_BRIDGE
unset NOVA_NOOPEN

PWSH=""
for c in pwsh /opt/homebrew/bin/pwsh /usr/local/bin/pwsh; do
  if command -v "$c" >/dev/null 2>&1; then PWSH="$c"; break; fi
done
if [ -z "$PWSH" ]; then
  echo "PowerShell 7 (pwsh) is required."
  echo "Install it with: brew install --cask powershell"
  read -r -p "Press Enter to close..."
  exit 1
fi

echo "Nova Tweaks - combined Windows preview"
echo "Fortnite + Minecraft catalogs in one localhost session."
echo "Close this Terminal window to stop the server."
echo
exec "$PWSH" -NoProfile -ExecutionPolicy Bypass -File "shared/Nova_Tweaks_WebGUI.ps1"
