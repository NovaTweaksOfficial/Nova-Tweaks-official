# Nova Tweaks

Safe, EAC-friendly Fortnite performance suite for Windows.

## Build

The `.exe` is built automatically via GitHub Actions. Push to `main` and download the artifact from the Actions tab.

Or build locally on Windows:
```powershell
Install-Module PS2EXE -Scope CurrentUser -Force
Invoke-PS2EXE -InputFile "NovaTweaks_WinForms_Red.ps1" -OutputFile "NovaTweaks.exe" -RequireAdmin -NoConsole -x64
```
