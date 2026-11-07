# Nova Tweaks (Fortnite) for Windows - separate app entrypoint.
# Same Nova Tweaks UI, Fortnite-only tweaks, no in-app game switch. Free/Pro/Ultimate.
$env:NOVA_FIXED_GAME = 'Fortnite'
$env:NOVA_APP_VARIANT = 'NovaTweaksFortnite'
& "$PSScriptRoot/../../shared/Nova_Tweaks_WebGUI.ps1"
