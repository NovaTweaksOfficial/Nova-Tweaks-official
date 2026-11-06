# Nova Tweaks

Safe, EAC-friendly Fortnite performance suite. Native app on Windows and macOS, built by Kyle Bonebrake.

**375 working tweaks** across General, Input, Network, Power, Visual, Services, Game, Storage, Firmware and
Privacy. Every tweak in the shipped build changes the system — there are no log-only placeholders — and each
one has a risk label, an OS badge (Windows/macOS/Both) and a one-click switch. 315 apply on Windows and 65 on
macOS (5 are cross-platform); the app includes all 375 and the Windows/Mac tabs show every one.
`tools/Check-Tweaks.ps1` enforces this in CI.

v5.3 expands the catalog from 156 to 375 tweaks. New coverage includes per-service Windows toggles, DNS
providers, Teredo/ISATAP/6to4 and NIC tuning, CPU idle and wake controls, update/shader/crash cleanup, VBS and
Hyper-V boot options, deeper privacy controls, and a large macOS set covering pointer acceleration, key repeat,
scroll behavior, Dock/Finder animations, Power Nap, GPU switching, local snapshots, LaunchServices, analytics,
advertising, and more. Every entry still performs a real registry, service, power, network, or macOS
`defaults` change.

v5.2 added a Windows **Drag Macro** (capture start/end, adjustable swipe duration, hold time, repeat and loop)
and a **BIOS / UEFI** page that detects firmware, memory speed, XMP/EXPO, Secure Boot, boot mode, VBS/HVCI and
TPM. Nova Tweaks never flashes or silently edits firmware; it reports what is set, gives UEFI guidance, and can
restart straight into firmware settings. The utility pages now live in a top toolbar under a vibrant red sweep
outline, and the Storage, Firmware and Privacy categories cover DNS, power, services, telemetry, privacy and
firmware-adjacent OS settings.

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
  -Version "5.3.0.0" `
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
