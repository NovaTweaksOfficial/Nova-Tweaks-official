# Nova Tweaks — Release & Testing Checklist

This checklist covers the current Nova Tweaks project state (shared core, Windows Fortnite, Windows Minecraft, macOS Minecraft native app, storefront/docs).

## Before any public release
- [ ] **Rotate secrets** in `shared/Nova_Tweaks_WebGUI.ps1` (`$Script:GiftSecret`, `$Script:LicenseSecret`) and keep them identical in `shared/tools/New-NovaKey.ps1`. Do not ship default placeholder secrets.
- [ ] **Tweak validation passes:** `pwsh -NoProfile -File ./shared/tools/Check-Tweaks.ps1` (AST parse + implemented actions; review missing-Off info).
- [ ] **AST parse:** `pwsh -NoProfile -Command '$e=$null;$t=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path ./shared/Nova_Tweaks_WebGUI.ps1),[ref]$t,[ref]$e)|Out-Null; if($e){$e|%{throw $_.Message}} else {"AST OK"}'`
- [ ] **No Marvel Rivals tweaks** and no destructive anti-cheat/core game file deletion in Fortnite potato flows.
- [ ] **Storefront config:** review `docs/config.js` / `docs/app.js` (checkout URLs, download links, support/contact, product status).

## Windows Fortnite (must test on real Windows 10/11 + Fortnite)
- [ ] App launches, branding shows **Nova Tweaks (Fortnite)**, login/tier UI works.
- [ ] Navigation (sidebar + topbar + page IDs) works; Ping Optimizer, Potato Graphics, Crosshair, Game/FPS Booster, All Tweaks render.
- [ ] **Potato Graphics** writes `%LOCALAPPDATA%\FortniteGame\Saved\Config\WindowsClient\Engine.ini`, creates backup `Engine.ini.nova-backup`, and **Off/restore** works. Verify Fortnite honors settings on current build (Epic may change cvars).
- [ ] **Fortnite high-performance GPU** sets Windows graphics preference; **Off** removes preference.
- [ ] **Fortnite high process priority** works when Fortnite is running; **Off** restores Normal.
- [ ] **Disable Fullscreen Optimizations** applies expected GameConfigStore/GameDVR values.
- [ ] **Clear Fortnite shader cache/logs/crash reports** only removes intended folders.
- [ ] FPS Booster applies only supported, reversible-safe system changes; confirm no fake/log-only behavior.
- [ ] Registry/service/power tweaks behave as intended; test **revert/restore point** flow and document reboot requirements.
- [ ] Test as standard user vs elevated/admin where required.

## Windows Minecraft (must test on real Windows)
- [ ] Branding shows **Nova Tweaks (Minecraft)**.
- [ ] Minecraft file paths/options/JVM tweaks work for installed launcher profiles; backups created and restores work.
- [ ] GPU/priority/Game Bar/fullscreen optimization tweaks behave as intended.
- [ ] Log/cache cleanup does not touch worlds/resource packs/shader packs beyond stated scope.

## macOS Minecraft (native app)
- [ ] Open `macos/Minecraft/Nova Tweaks Minecraft.app`; requires `pwsh` (`/usr/local/bin/pwsh` or bundled runtime when added).
- [ ] WKWebView loads UI, branding correct, login works, **Sign Out** returns to login overlay (no stuck/broken reload).
- [ ] `webkit.messageHandlers.nova` stdio bridge works (`/api/*` calls resolve). Debug: `~/.novatweaks/native-bridge.log`.
- [ ] Minecraft macOS tweaks (options/JVM/cache paths) work and restores/backups behave correctly.
- [ ] After shared PS1 changes: resync `macos/Minecraft/Nova Tweaks Minecraft.app/Contents/Resources/Nova_Tweaks_WebGUI.ps1` and rebuild `docs/downloads/Nova-Tweaks-Minecraft-macOS.zip`.
- [x] Bundle PowerShell 7 into the `.app` with `macos/Minecraft/Build-MacOS-App.command` (runtime-only copy, no `ref`/XML docs).
- [ ] Test the bundled app on a clean Mac with no PowerShell/Homebrew installed.
- [ ] **Code sign + notarize** the macOS app and zip.

## Macro
- [x] Drag macro (start/end capture, hold, repeat, loop) on Windows and macOS.
- [x] Auto clicker (button, randomized interval, hold, repeat/loop) on Windows and macOS.
- [x] macOS loop stop verified end-to-end (start → Running → Stop → Stopped).
- [ ] Verify Windows drag/clicker behavior and stop on a real Windows machine.
- [ ] Confirm Accessibility permission flow on a clean Mac.

## SellAuth / fulfillment
- [ ] Pro/Ultimate products have Nova key serial stock (`pwsh ./shared/tools/New-NovaKey.ps1 -Type Pro|Ultimate -Count N`) uploaded separately.
- [ ] Automatic delivery enabled; payment gateway connected and verified (test card/real flow as appropriate).
- [ ] End-to-end test: purchase → receive key → redeem in app → plan activates.
- [ ] Confirm key format/secrets match the app build.

## CI / distribution
- [x] Build separate Windows executables in CI (`NovaTweaks-Fortnite-Windows.exe`, `NovaTweaks-Minecraft-Windows.exe`, plus combined `NovaTweaks.exe`).
- [x] Point `docs/config.js` Windows download URLs at the per-product release assets.
- [ ] Push a `v*` tag and confirm all three assets attach to the GitHub release.
- [ ] Verify GitHub Pages deploy from `main`/`docs`.

## Safety notes
- Never implement tweaks that delete/modify **Easy Anti-Cheat, BattlEye, or core Fortnite/engine binaries**.
- Prefer **backups + reversible** config/registry changes; clearly warn on risky/caution tweaks.
- Treat downloaded third-party “optimizer” executables as untrusted unless source/signature/reputation are verified.
