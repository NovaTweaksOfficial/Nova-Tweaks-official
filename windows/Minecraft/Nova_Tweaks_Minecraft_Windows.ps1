# Nova Tweaks (Minecraft) for Windows - separate app entrypoint.
# Same Nova Tweaks UI, Minecraft-only tweaks, no in-app game switch. Free/Pro/Ultimate.
$env:NOVA_FIXED_GAME = 'Minecraft'
$env:NOVA_APP_VARIANT = 'NovaTweaksMinecraft'
& "$PSScriptRoot/../../shared/Nova_Tweaks_WebGUI.ps1"
