# Nova Tweaks

Safe, EAC-friendly Fortnite performance suite. Native app on Windows and macOS, built by Kyle Bonebrake.

## How the Windows app works

`NovaTweaks.exe` is a real native Windows application. It opens a dark, maximized WinForms window that hosts
**Microsoft Edge WebView2** and renders the Nova Tweaks UI directly inside the app.

- **No localhost, no browser, no web server.** Nothing is served over HTTP and no external browser is opened.
- The WebView2 SDK (`Microsoft.Web.WebView2.Core.dll`, `Microsoft.Web.WebView2.WinForms.dll`,
  `WebView2Loader.dll`) is embedded in the app as Base64 and extracted to `%USERPROFILE%\NovaTweaks\webview2`
  on first run, so the download is a single self-contained `.exe`.
- The HTML UI is written to `%USERPROFILE%\NovaTweaks\webui\index.html` and loaded through a private
  virtual host (`https://nova.local`), which gives it a normal web origin (localStorage, reload, history).
- All `/api/*` calls are bridged from JavaScript to PowerShell with `postMessage` / `PostWebMessageAsString`.
  Tweaks, accounts, config and logs stay local on the machine.
- The only external requirement is the **WebView2 Evergreen Runtime**, which ships with Windows 11 and most
  Windows 10 PCs. If it is missing, the app installs it silently or shows a download link.

On macOS the same UI runs in the default browser from a loopback-only PowerShell HTTP listener.

## Data locations

| Platform | Folder |
| --- | --- |
| Windows | `%USERPROFILE%\NovaTweaks` |
| macOS | `~/.novatweaks` |

Both use `config.json`, `accounts.json`, `session.token` and `nova.log`.

## Build

The `.exe` is built automatically by GitHub Actions (`.github/workflows/build.yml`). Push to `main` for an
artifact, or push a `v*` tag to attach `NovaTweaks.exe` to a release.

Or build locally on Windows:

```powershell
Install-Module PS2EXE -Scope CurrentUser -Force
Invoke-PS2EXE `
  -InputFile "Nova_Tweaks_WebGUI.ps1" `
  -OutputFile "NovaTweaks.exe" `
  -Title "Nova Tweaks" `
  -Description "Nova Tweaks performance suite - by Kyle Bonebrake" `
  -Company "Nova Tweaks" `
  -Product "Nova Tweaks" `
  -Version "5.0.0.0" `
  -RequireAdmin `
  -NoConsole `
  -STA `
  -x64
```

`-STA` is required for WinForms and WebView2. Do not remove it.

## Project layout

- `Nova_Tweaks_WebGUI.ps1` — the whole app: tweak engine, account system, UI, WebView2 host, macOS server.
- `Nova Tweaks.app` — macOS app bundle.
- `Nova_Tweaks_WinForms_Ultimate.ps1` — older native WinForms UI, kept as a fallback reference.
- `.github/workflows/build.yml` — Windows build + release pipeline.
