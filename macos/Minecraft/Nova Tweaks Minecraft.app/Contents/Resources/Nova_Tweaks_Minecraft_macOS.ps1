# Nova Tweaks (Minecraft) for macOS - separate app entrypoint.
# Same Nova Tweaks UI, Minecraft-only tweaks, no in-app game switch. Free/Pro/Ultimate.
$env:NOVA_FIXED_GAME = 'Minecraft'
$env:NOVA_APP_VARIANT = 'NovaTweaksMinecraft'
$env:NOVA_WINDOWS_PREVIEW = '' # native macOS view when run on Mac
& "$PSScriptRoot/Nova_Tweaks_WebGUI.ps1"
