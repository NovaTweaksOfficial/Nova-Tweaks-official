# FL3SH Optimizer

Safe, EAC-friendly Fortnite performance optimizer for Windows.

## Build

The `.exe` is built automatically via GitHub Actions. Push to `main` and download the artifact from the Actions tab.

Or build locally on Windows:
```powershell
Install-Module PS2EXE -Scope CurrentUser -Force
Invoke-PS2EXE -InputFile "FL3SH_Optimizer_WinForms_Red.ps1" -OutputFile "FL3SH_Optimizer.exe" -RequireAdmin -NoConsole -x64
```
