#!/bin/zsh
cd "$(dirname "$0")"
# Windows-preview dev localhost (see Windows UI/tweaks on macOS). Read-only simulation.
pkill -f "Nova_Tweaks_WebGUI.ps1" 2>/dev/null || true
NOVA_WINDOWS_PREVIEW=1 NOVA_NOOPEN=0 /usr/local/bin/pwsh -NoProfile -File ../shared/Nova_Tweaks_WebGUI.ps1
