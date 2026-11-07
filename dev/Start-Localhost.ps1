# Dev localhost launcher. Set NOVA_WINDOWS_PREVIEW=1 to preview Windows UI on macOS.
$env:NOVA_NOOPEN = '0'
if (-not $env:NOVA_WINDOWS_PREVIEW -and $env:OS -ne 'Windows_NT' -and $IsMacOS) { $env:NOVA_WINDOWS_PREVIEW = '1' }
& "$PSScriptRoot/../shared/Nova_Tweaks_WebGUI.ps1"
