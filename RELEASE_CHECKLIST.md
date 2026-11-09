# Nova Tweaks — Release & Testing Checklist

This checklist covers the current Nova Tweaks project state (shared core, Windows Fortnite, Windows Minecraft, macOS Minecraft native app, storefront/docs).

## Before any public release
- [ ] **Rotate secrets** in `shared/Nova_Tweaks_WebGUI.ps1` (`$Script:GiftSecret`, `$Script:LicenseSecret`) and keep them identical in `shared/tools/New-NovaKey.ps1`. Do not ship default placeholder secrets.
- [ ] **Tweak validation passes:** `pwsh -NoProfile -File ./shared/tools/Check-Tweaks.ps1` (AST parse + implemented actions; review missing-Off info).
- [ ] **AST parse:** `pwsh -NoProfile -Command '$e=$null;$t=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path ./shared/Nova_Tweaks_WebGUI.ps1),[ref]$t,[ref]$e)|Out-Null; if($e){$e|%{throw $_.Message}} else {"AST OK"}'`
- [ ] **No Marvel Rivals anywhere** (no profile, tweak, category or copy) and no destructive anti-cheat/core game file deletion in Fortnite potato flows.
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
- [x] Pro/Ultimate products, key serial stock, and automatic delivery configured.
- [ ] Add payment cards / payment methods to the SellAuth account.
- [ ] End-to-end test: purchase → receive key → redeem in app → plan activates.
- [ ] Confirm key format/secrets match the app build.

## Staff roles / Dev Console (owner / dev / mod)
- [x] Role resolution (`owner`, `dev`, `mod`, `user`) and automatic plans: owner/dev = Ultimate, mod = Pro.
- [x] Server-side enforcement: only owners receive password fields; devs/mods never receive passwords or password hashes.
- [x] Devs/mods see owner/dev/mod accounts only as redacted `OWNER`/`DEV`/`MOD` rows and cannot moderate or manage them.
- [x] Only owners can edit `devs.json`, grant/revoke dev or mod, change plans, reset passwords or permanently ban.
- [x] Devs can only timeout, softban or clear regular accounts; mods can only timeout or clear regular accounts.
- [ ] Re-test the role UI and redaction in the packaged Windows exes on real Windows.
- [ ] Confirm a newly granted dev immediately shows Ultimate and a newly granted mod immediately shows Pro after refresh/login.

## CI / distribution
- [x] Build separate Windows executables in CI (`NovaTweaks-Fortnite-Windows.exe`, `NovaTweaks-Minecraft-Windows.exe`).
- [x] Point `docs/config.js` Windows download URLs at the per-product release assets.
- [x] Push a `v*` tag and confirm all three assets attach to the GitHub release (`v5.5.0` verified: two Windows exes + macOS zip).
- [ ] Verify GitHub Pages deploy from `main`/`docs`.

## Safety notes
- Never implement tweaks that delete/modify **Easy Anti-Cheat, BattlEye, or core Fortnite/engine binaries**.
- Prefer **backups + reversible** config/registry changes; clearly warn on risky/caution tweaks.
- Treat downloaded third-party “optimizer” executables as untrusted unless source/signature/reputation are verified.
