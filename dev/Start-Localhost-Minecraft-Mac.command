#!/bin/zsh
cd "$(dirname "$0")"
pkill -f "Nova_Tweaks_WebGUI.ps1" 2>/dev/null || true
NOVA_FIXED_GAME=Minecraft NOVA_APP_VARIANT=NovaTweaksMinecraft NOVA_NOOPEN=0 /usr/local/bin/pwsh -NoProfile -File ../shared/Nova_Tweaks_WebGUI.ps1
