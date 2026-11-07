# Nova Tweaks

Safe, EAC-friendly Fortnite and Minecraft performance suite for Windows. Native Windows app, built by Kyle Bonebrake.
**Version 1** is the permanent app line — no more version bumps.

**383 working tweaks** across General, Input, Network, Power, Visual, Services, Game, Storage, Firmware and
Privacy. Every tweak in the shipped build changes the system — there are no log-only placeholders — and each
one has a risk label, an OS badge and a one-click switch. 324 apply on Windows, including 9 dedicated
Minecraft tweaks; the app includes all 383 and filters the catalog by game profile.
`tools/Check-Tweaks.ps1` enforces this in CI.

The catalog covers per-service Windows toggles, DNS providers, Teredo/ISATAP/6to4 and NIC tuning, CPU idle and
wake controls, update/shader/crash cleanup, VBS and Hyper-V boot options, deeper privacy controls, and a
dedicated Minecraft set covering options.txt performance values, mipmaps, fullscreen, high-performance GPU,
fullscreen optimizations, process priority, log cleanup, Game Bar capture and G1GC JVM arguments. Every entry
performs a real registry, service, power, network or game-config change, and every change has a restore action.

The app also includes a Windows **Drag Macro** (capture start/end, adjustable swipe duration, hold time, repeat
and loop), an **FPS Booster** that applies Game Mode, capture-off, scheduling priority, game GPU preference,
power-plan and memory changes, and a **live network panel** that samples real ICMP pings and shows average ping,
jitter, packet loss and a rolling chart. **Badges and daily streaks** are computed from real account activity —
sign-in streaks, distinct tweaks applied, network tweaks, clean sweeps, gifts and plan tier. A **BIOS / UEFI**
page detects firmware, memory speed, XMP/EXPO, Secure Boot, boot mode,
VBS/HVCI and TPM. Nova Tweaks never flashes or silently edits firmware; it reports what is set, gives UEFI
guidance, and can restart straight into firmware settings. Utility pages live in a top toolbar under a vibrant
red sweep outline, and tweak cards are grouped by plain-language subcategory inside each tab.

**Settings → Game profile** switches between Fortnite Tweaks and Minecraft Tweaks. The choice persists in
`config.json` as `Game`, plays a short welcome animation, then loads the shared Windows catalog plus the
tweaks for that game. Fortnite-only tweaks are hidden in Minecraft mode and Minecraft-only tweaks are hidden
in Fortnite mode.

## Plans and accounts

| Plan | Price | What unlocks |
| --- | --- | --- |
| **Free** | $0 | 30 hand-picked core tweaks, Windows restore point, Classic crosshair, undo/restore |
| **Pro** | $5.99/mo | Most of the catalog: ping stabilizer, input-delay work, network/power sets, all 8 crosshairs, drag macro |
| **Ultimate** | $12.99/mo | All 383 tweaks, including Potato Graphics, Minecraft G1GC JVM arguments, advanced service toggles and firmware guidance |

Paid plans are 30-day periods. Accounts, balance and plans live locally in `accounts.json`; there is no
backend. Users can redeem signed giveaway codes for balance and spend that balance on Pro or Ultimate in
**Settings → Account**. A website purchase produces a license key that the user pastes into the app; keys are
validated offline with HMAC. Storefront: <https://NovaTweaksOfficial.github.io/fl3sh-optimizer/>.

Issue codes with:

```powershell
pwsh ./tools/New-NovaKey.ps1 -Type Gift -Amount 15
pwsh ./tools/New-NovaKey.ps1 -Type Pro -Count 5
pwsh ./tools/New-NovaKey.ps1 -Type Ultimate -Count 1
```

Keep `-GiftSecret` / `-LicenseSecret` in sync with `Nova_Tweaks_WebGUI.ps1`. This model is offline: the
secret ships inside the app, so it stops casual sharing, not a determined reverse-engineer. Real cross-device
subscriptions would need a backend.

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

The local `http://localhost:8765` PowerShell listener still exists only as a development preview for editing
the UI on non-Windows machines. It is not shipped and is not part of the Windows app.

## Data locations

The Windows app stores `config.json`, `accounts.json`, `session.token` and `nova.log` in
`%USERPROFILE%\NovaTweaks`.

Minecraft tweaks edit `%APPDATA%\.minecraft\options.txt`, keep per-key originals in
`nova-options-backup.json`, and back up `launcher_profiles.json` before writing JVM arguments.

## Build

The `.exe` is built automatically by GitHub Actions (`.github/workflows/build.yml`). Push to `main` for an
artifact, or push a `v*` tag to attach release assets (update the workflow to build separate Fortnite/Minecraft entrypoints if desired).

Or build locally on Windows (separate apps):

```powershell
Install-Module PS2EXE -Scope CurrentUser -Force
Invoke-PS2EXE -InputFile "windows/Fortnite/Nova_Tweaks_Fortnite_Windows.ps1" -OutputFile "NovaTweaks-Fortnite.exe" -Title "Nova Tweaks (Fortnite)" -Product "Nova Tweaks" -Version "1.0.0.0" -RequireAdmin -NoConsole -STA -x64
Invoke-PS2EXE -InputFile "windows/Minecraft/Nova_Tweaks_Minecraft_Windows.ps1" -OutputFile "NovaTweaks-Minecraft.exe" -Title "Nova Tweaks (Minecraft)" -Product "Nova Tweaks" -Version "1.0.0.0" -RequireAdmin -NoConsole -STA -x64
```

`-STA` is required for WinForms and WebView2. Do not remove it.

## Project layout (organized)

- `shared/Nova_Tweaks_WebGUI.ps1` — core app engine: tweaks, accounts/tiers, game profiles, UI, WebView2 host, stdio bridge.
- `shared/tools/Check-Tweaks.ps1` — CI guard that every catalog entry has a real action.
- `shared/tools/New-NovaKey.ps1` — issue gift codes and Pro/Ultimate license keys.
- `windows/Fortnite/` — `Nova_Tweaks_Fortnite_Windows.ps1` (separate Windows app entrypoint).
- `windows/Minecraft/` — `Nova_Tweaks_Minecraft_Windows.ps1` (separate Windows app entrypoint).
- `macos/Minecraft/` — `Nova_Tweaks_Minecraft_macOS.ps1`, `Nova Tweaks Minecraft.app` (native WKWebView + stdio bridge, no localhost), `native/` (Swift source/binary).
- `dev/` — localhost/preview launchers (`Start-Localhost*`).
- `docs/` — static storefront (GitHub Pages): supported games, downloads, pricing, checkout modal, FAQ.
- `archive/` — older reference variants.
- `.github/workflows/build.yml` — Windows CI build pipeline.
