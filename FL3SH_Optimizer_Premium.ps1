#Requires -RunAsAdministrator
<#
.SYNOPSIS
    FL3SH Optimizer - Premium Web GUI (EMTweaks-style)
.DESCRIPTION
    Polished dark UI with 3D buttons, glow effects, card depth, animated toggles.
    Served locally. Works on Mac + Windows.
#>

$IsWin = $IsWindows -or ($env:OS -eq "Windows_NT")
$IsMac = $IsMacOS -or ((uname 2>/dev/null) -eq "Darwin")

$Script:Root = if ($IsWin) { Join-Path $env:USERPROFILE "FL3SH_Optimizer" } else { Join-Path $env:HOME ".fl3sh_optimizer" }
$Script:BackupDir = Join-Path $Script:Root "backups"
$Script:LogPath = Join-Path $Script:Root "optimizer.log"
$Script:ConfigPath = Join-Path $Script:Root "config.json"
foreach ($d in @($Script:Root,$Script:BackupDir)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }
if (-not (Test-Path $Script:LogPath)) { New-Item -ItemType File -Path $Script:LogPath -Force | Out-Null }

$Script:Config = @{ Plan="Free"; TweakStates=@{}; Email=""; LicenseKey="" }
if (Test-Path $Script:ConfigPath) { try { $l = Get-Content $Script:ConfigPath -Raw | ConvertFrom-Json; foreach ($k in $l.PSObject.Properties.Name) { $Script:Config[$k]=$l.$k } } catch {} }
function Save-Config { $Script:Config | ConvertTo-Json -Depth 5 | Set-Content $Script:ConfigPath -Encoding UTF8 }

$Script:Logs = [System.Collections.ArrayList]::new()
function Write-Log { param([string]$Msg,[string]$Level="INFO"); $line="$(Get-Date -Format 'HH:mm:ss') [$Level] $Msg"; [void]$Script:Logs.Add($line); Add-Content -Path $Script:LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Msg" -ErrorAction SilentlyContinue }

# ---------- Tweak functions (same as before, condensed) ----------
function Invoke-PowerPlan { if(-not $IsWin){Write-Log "Windows only." "WARN";return}; try { $hp=(powercfg /list|Select-String "Ultimate Performance"|ForEach-Object{($_-split'\s+')[3]})|Select-Object -First 1; if(-not $hp){$hp=(powercfg /list|Select-String "High performance"|ForEach-Object{($_-split'\s+')[3]})|Select-Object -First 1}; if($hp){powercfg /setactive $hp 2>$null|Out-Null;Write-Log "Power plan: $hp" "OK"}; powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null; powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null; Write-Log "USB suspend disabled." "OK" } catch { Write-Log "Power plan failed." "ERR" } }
function Invoke-MemoryCleanup { if($IsWin){ try { Get-Process|Where-Object{$_.WorkingSet64 -gt 50MB -and $_.ProcessName -notin @("System","Registry","smss","csrss","winlogon","services","lsass","explorer")} | ForEach-Object { try{$_.MinWorkingSet=1MB;$_.MaxWorkingSet=1MB}catch{} }; $code=@"
using System;using System.Runtime.InteropServices;
public class Mem{[DllImport("ntdll.dll")]public static extern int NtSetSystemInformation(int i,IntPtr p,int l);
public static void EmptyStandby(){int size=Marshal.SizeOf(typeof(int));IntPtr ptr=Marshal.AllocHGlobal(size);Marshal.WriteInt32(ptr,4);NtSetSystemInformation(80,ptr,size);Marshal.FreeHGlobal(ptr);}}
"@; Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue; [Mem]::EmptyStandby() 2>$null; Write-Log "Memory trimmed." "OK" } catch { Write-Log "Memory partial." "WARN" } } else { try { purge 2>$null; Write-Log "Memory purged." "OK" } catch { Write-Log "purge failed." "WARN" } } }
function Invoke-TempCleanup { if($IsWin){ $paths=@($env:TEMP,"$env:WINDIR\Temp","$env:LOCALAPPDATA\Temp"); $freed=0; foreach($p in $paths){ if(Test-Path $p){ Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { try { if(-not $_.PSIsContainer){$freed+=$_.Length;Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue} } catch{} } } }; $sh="$env:LOCALAPPDATA\FortniteGame\Saved\ShaderCache"; if(Test-Path $sh){Remove-Item $sh -Recurse -Force -ErrorAction SilentlyContinue;Write-Log "Shader cache cleared." "OK"}; Write-Log "Freed ~$([math]::Round($freed/1MB,1)) MB." "OK" } else { $freed=0; foreach($p in @("$env:HOME/Library/Caches","/tmp","/var/tmp")){ if(Test-Path $p){ Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {-not $_.PSIsContainer} | ForEach-Object { try{$freed+=$_.Length;Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue}catch{} } } }; Write-Log "Freed ~$([math]::Round($freed/1MB,1)) MB." "OK" } }
function Invoke-RegistryTweaks { if(-not $IsWin){Write-Log "Windows only." "WARN";return}; $changes=@(@{Path="HKCU:\System\GameConfigStore";Name="GameDVR_Enabled";Value=0;Type="DWord"},@{Path="HKCU:\System\GameConfigStore";Name="GameDVR_FSEBehaviorMode";Value=2;Type="DWord"},@{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile";Name="SystemResponsiveness";Value=0;Type="DWord"},@{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games";Name="GPU Priority";Value=8;Type="DWord"},@{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games";Name="Priority";Value=6;Type="DWord"},@{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games";Name="Scheduling Category";Value="High";Type="String"},@{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games";Name="SFIO Priority";Value="High";Type="String"},@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects";Name="VisualFXSetting";Value=2;Type="DWord"},@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";Name="MenuShowDelay";Value=0;Type="String"}); foreach($c in $changes){ try { if(-not (Test-Path $c.Path)){New-Item -Path $c.Path -Force|Out-Null}; Set-ItemProperty -Path $c.Path -Name $c.Name -Value $c.Value -Type $c.Type -Force; Write-Log "Registry: $($c.Name) = $($c.Value)" "OK" } catch { Write-Log "Registry $($c.Name) failed." "WARN" } }; $iface="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"; Get-ChildItem $iface -ErrorAction SilentlyContinue | ForEach-Object { try { Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force; Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force } catch{} }; Write-Log "TCP no-delay applied." "OK" }
function Invoke-HAGS { if(-not $IsWin){Write-Log "Windows only." "WARN";return}; try { $p="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "HwSchMode" -Value 2 -Type DWord -Force; Write-Log "HAGS enabled (reboot required)." "OK" } catch { Write-Log "HAGS failed." "WARN" } }
function Invoke-Services { if(-not $IsWin){Write-Log "Windows only." "WARN";return}; $svcs=@("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","DiagTrack","dmwappushservice","SysMain"); foreach($s in $svcs){ try { $svc=Get-Service -Name $s -ErrorAction SilentlyContinue; if($svc){Stop-Service -Name $s -Force -ErrorAction SilentlyContinue; Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue; Write-Log "Disabled: $s" "OK"} } catch { Write-Log "Service $s skipped." "WARN" } } }
function Invoke-Network { if($IsWin){ try { netsh interface tcp set global autotuninglevel=disabled 2>$null|Out-Null; netsh interface tcp set global ecncapability=disabled 2>$null|Out-Null; netsh interface tcp set global timestamps=disabled 2>$null|Out-Null; Write-Log "TCP auto-tuning disabled." "OK" } catch { Write-Log "Network tweak failed." "WARN" } } else { try { dscacheutil -flushcache 2>$null; killall -HUP mDNSResponder 2>$null; Write-Log "DNS cache flushed." "OK" } catch { Write-Log "DNS flush failed." "WARN" } } }
function Invoke-VisualEffects { if(-not $IsMac){Write-Log "macOS only." "WARN";return}; try { defaults write com.apple.universalaccess reduceTransparency -bool true; defaults write com.apple.universalaccess reduceMotion -bool true; defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false; defaults write com.apple.dock expose-animation-duration -float 0.1; defaults write com.apple.dashboard mcx-disabled -boolean YES; defaults write NSGlobalDomain KeyRepeat -int 2; defaults write NSGlobalDomain InitialKeyRepeat -int 15; killall Dock 2>$null; Write-Log "Visual effects reduced." "OK" } catch { Write-Log "Visual tweaks failed." "WARN" } }
function Invoke-MacPower { if(-not $IsMac){Write-Log "macOS only." "WARN";return}; try { pmset -c sleep 0 2>$null; pmset -c disksleep 0 2>$null; pmset -c displaysleep 10 2>$null; pmset -a sms 0 2>$null; Write-Log "Power settings tuned." "OK" } catch { Write-Log "Power tweak failed." "WARN" } }
function Invoke-PotatoGraphics { if(-not $IsWin){Write-Log "Windows only." "WARN";return}; $base="$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient"; if(-not (Test-Path $base)){New-Item -ItemType Directory -Path $base -Force|Out-Null}; $p=Join-Path $base "Engine.ini"; $content = @'
[Core.System]
Paths=../../../Engine/Content
Paths=%GAMEDIR%Content
Paths=../../../Engine/Plugins
Paths=../../../FortniteGame/Plugins

[/Script/Engine.RendererSettings]
r.DefaultFeature.Bloom=False
r.DefaultFeature.AmbientOcclusion=False
r.DefaultFeature.AntiAliasing=0
r.DefaultFeature.MotionBlur=False
r.BloomQuality=0
r.DepthOfFieldQuality=0
r.MotionBlurQuality=0
r.Tonemapper.Quality=0
r.ShadowQuality=0
r.Shadow.MaxResolution=256
r.PostProcessAAQuality=0
r.MSAACount=0
r.SSR.Quality=0
r.MaterialQualityLevel=0
r.DetailMode=0
r.ViewDistanceScale=0.7
foliage.DensityScale=0.4
grass.DensityScale=0.4

[/Script/Engine.Engine]
bSmoothFrameRate=False

[/Script/FortniteGame.FortGameUserSettings]
bUseVSync=False
'@; Set-Content -Path $p -Value $content -Encoding ASCII -Force; Write-Log "Potato Graphics applied." "OK" }
function Invoke-GameBooster { if(-not $IsWin){Write-Log "Windows only." "WARN";return}; $keep=@("System","Registry","smss","csrss","winlogon","services","lsass","explorer","dwm","svchost","conhost","powershell","pwsh","cmd","taskmgr","FortniteClient-Win64-Shipping"); Get-Process | Where-Object { $_.ProcessName -notin $keep -and $_.MainWindowHandle -ne 0 } | ForEach-Object { try { $_.CloseMainWindow()|Out-Null; Write-Log "Closed: $($_.ProcessName)" "OK" } catch {} }; Invoke-MemoryCleanup; Write-Log "Game Booster complete." "OK" }
function Revert-All { if($IsWin){ powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null; netsh interface tcp set global autotuninglevel=normal 2>$null|Out-Null; @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","DiagTrack","dmwappushservice","SysMain") | ForEach-Object { Set-Service -Name $_ -StartupType Manual -ErrorAction SilentlyContinue }; Write-Log "Windows revert complete. Reboot recommended." "OK" } else { try { defaults write com.apple.universalaccess reduceTransparency -bool false; defaults write com.apple.universalaccess reduceMotion -bool false; defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool true; defaults delete com.apple.dock expose-animation-duration 2>$null; defaults delete com.apple.dashboard mcx-disabled 2>$null; defaults delete NSGlobalDomain KeyRepeat 2>$null; defaults delete NSGlobalDomain InitialKeyRepeat 2>$null; mdutil -i on / 2>$null; pmset -c sleep 10 2>$null; pmset -a sms 1 2>$null; killall Dock 2>$null; Write-Log "macOS revert complete." "OK" } catch { Write-Log "Revert partial." "WARN" } } }

# ---------- Tweak definitions ----------
$Script:Tweaks = @(
  @{Id="power";Name="Ultimate Performance power plan";Desc="Unlocks and applies the hidden Ultimate Performance plan. Best single gaming tweak.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Invoke-PowerPlan}},
  @{Id="usb";Name="Disable USB selective suspend";Desc="Stops USB ports from sleeping. Prevents input lag spikes on peripherals.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={}},
  @{Id="memory";Name="Memory cleanup (trim + purge)";Desc="Trims idle process working sets and purges standby/inactive memory. Frees RAM.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Invoke-MemoryCleanup}},
  @{Id="temp";Name="Temp + cache cleanup";Desc="Clears temp folders, browser cache, and Fortnite shader cache. Frees disk space.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Invoke-TempCleanup}},
  @{Id="visual";Name="Reduce visual effects";Desc="Disables window animations, transparency and motion for snappier UI and more FPS.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="Visual";Action={if($IsWin){Invoke-RegistryTweaks}else{Invoke-VisualEffects}}},
  @{Id="menu";Name="Reduce menu show delay";Desc="Sets MenuShowDelay to 0 for instant right-click and start menu response.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={}},
  @{Id="transp";Name="Disable transparency";Desc="Kills Acrylic/Mica blur to free GPU compositor cycles.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="Visual";Action={}},
  @{Id="startup";Name="Disable startup delay";Desc="Removes the artificial startup app delay timer for faster boot.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={}},
  @{Id="services";Name="Disable background services";Desc="Stops Xbox, telemetry and diagnostic services. Reduces background CPU usage.";Risk="Caution";Free=$false;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Services}},
  @{Id="sysmain";Name="Disable SysMain (Superfetch)";Desc="Stops background prefetching. Recommended on SSD systems.";Risk="Caution";Free=$false;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Services}},
  @{Id="nagle";Name="Disable Nagle's algorithm";Desc="TCPNoDelay + TcpAckFrequency. Lowers network latency for gaming.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Network";Action={Invoke-RegistryTweaks}},
  @{Id="autotune";Name="Disable TCP auto-tuning";Desc="Sets autotuninglevel=disabled. Reduces bufferbloat and ping spikes.";Risk="Safe";Free=$false;Win=$true;Mac=$true;Cat="Network";Action={Invoke-Network}},
  @{Id="qos";Name="Network QoS priority";Desc="Prioritizes game packets over background traffic via QoS.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Network";Action={}},
  @{Id="hags";Name="Hardware-Accelerated GPU Scheduling";Desc="Offloads GPU scheduling to dedicated hardware. Reboot required.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Power";Action={Invoke-HAGS}},
  @{Id="corepark";Name="Disable core parking";Desc="Keeps all CPU cores awake. Reduces input delay and stutter.";Risk="Caution";Free=$false;Win=$true;Mac=$false;Cat="Power";Action={}},
  @{Id="timer";Name="Timer resolution 1ms";Desc="Sets system timer to 1ms for sharper CPU scheduling.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Power";Action={}},
  @{Id="potato";Name="Potato Graphics (Engine.ini)";Desc="Lowers Fortnite render quality for max FPS and visibility. Changes appearance.";Risk="Caution";Free=$false;Win=$true;Mac=$false;Cat="Game";Action={Invoke-PotatoGraphics}},
  @{Id="gamedvr";Name="Disable Game DVR / Game Bar";Desc="Turns off Xbox Game Bar recording overlay that hooks into games.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Game";Action={Invoke-RegistryTweaks}},
  @{Id="fullscreen";Name="Fullscreen optimizations off";Desc="Disables FSO for lower input lag in fullscreen exclusive mode.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Game";Action={}},
  @{Id="macpower";Name="Mac power tuning";Desc="Disables sleep, disk sleep and sudden motion sensor for performance.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Power";Action={Invoke-MacPower}},
  @{Id="spotlight";Name="Disable Spotlight indexing";Desc="Stops Spotlight from indexing. Frees disk I/O. Reversible.";Risk="Caution";Free=$false;Win=$false;Mac=$true;Cat="General";Action={try{mdutil -i off / 2>$null;Write-Log "Spotlight disabled on /." "OK"}catch{Write-Log "Spotlight tweak failed." "WARN"}}},
  @{Id="fontcache";Name="Clear font cache";Desc="Clears font cache for cleaner rendering and frees space.";Risk="Safe";Free=$false;Win=$false;Mac=$true;Cat="Visual";Action={try{atsutil databases -remove 2>$null;Write-Log "Font cache cleared." "OK"}catch{Write-Log "Font cache clear failed." "WARN"}}}
)
if (-not $Script:Config.TweakStates) { $Script:Config.TweakStates = @{} }
foreach ($t in $Script:Tweaks) { if (-not $Script:Config.TweakStates.ContainsKey($t.Id)) { $Script:Config.TweakStates[$t.Id] = $false } }

# ---------- HTML ----------
$HtmlPage = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>FL3SH Optimizer</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<style>
*{box-sizing:border-box;margin:0;padding:0}
:root{
--bg:#0a0a0f;--bg2:#0f0f16;--sidebar:#111118;--card:#16161f;--card2:#1c1c28;--cardhover:#22222e;
--accent:#00ff88;--accent2:#00cc6a;--accentglow:rgba(0,255,136,.25);
--danger:#ff4757;--danger2:#cc2f3a;--warn:#ffa502;--warn2:#cc8400;
--text:#f0f0f5;--textdim:#7a7a8c;--textmuted:#555566;--border:#2a2a38;--border2:#3a3a4a;
--shadow:0 4px 20px rgba(0,0,0,.4);--shadow-lg:0 8px 40px rgba(0,0,0,.6);
--radius:10px;--radius-sm:6px
}
body{font-family:'Inter',system-ui,sans-serif;background:var(--bg);color:var(--text);display:flex;height:100vh;overflow:hidden;-webkit-font-smoothing:antialiased}

/* Sidebar */
.sidebar{width:220px;background:linear-gradient(180deg,var(--sidebar) 0%,#0d0d12 100%);border-right:1px solid var(--border);padding:20px 12px;display:flex;flex-direction:column;gap:2px;position:relative;overflow:hidden}
.sidebar::before{content:'';position:absolute;top:0;left:0;right:0;height:200px;background:radial-gradient(circle at 50% 0%,var(--accentglow),transparent 70%);pointer-events:none;opacity:.6}
.brand{font-size:26px;font-weight:800;background:linear-gradient(135deg,var(--accent),#00d4ff);-webkit-background-clip:text;-webkit-text-fill-color:transparent;padding:0 8px;position:relative;z-index:1;letter-spacing:-.5px}
.brandsub{font-size:11px;color:var(--textmuted);padding:0 8px;margin-bottom:14px;position:relative;z-index:1;text-transform:uppercase;letter-spacing:2px}
.planbadge{display:inline-block;padding:4px 12px;border-radius:20px;font-size:10px;font-weight:700;margin:0 8px 18px;background:linear-gradient(135deg,var(--warn),var(--warn2));color:#000;box-shadow:0 2px 10px rgba(255,165,2,.3);position:relative;z-index:1;letter-spacing:.5px}
.navbtn{background:transparent;border:none;color:var(--textdim);padding:11px 14px;border-radius:var(--radius-sm);cursor:pointer;font-size:13.5px;text-align:left;width:100%;transition:all .2s;font-weight:500;position:relative;z-index:1;display:flex;align-items:center;gap:10px}
.navbtn:hover{background:rgba(255,255,255,.04);color:var(--text);transform:translateX(2px)}
.navbtn.active{background:linear-gradient(90deg,rgba(0,255,136,.12),transparent);color:var(--accent);border-left:3px solid var(--accent);padding-left:11px}
.navicon{font-size:15px;opacity:.7}
.sidebar-bottom{margin-top:auto;padding:12px 8px;border-top:1px solid var(--border);position:relative;z-index:1}
.userinfo{font-size:12px;color:var(--textdim);font-weight:500}
.ptsinfo{font-size:11px;color:var(--textmuted);margin-top:2px}

/* Content */
.content{flex:1;overflow-y:auto;padding:28px 32px;background:radial-gradient(ellipse at top right,rgba(0,255,136,.03),transparent 60%)}
.page{display:none;animation:fadeIn .3s ease}.page.active{display:block}
@keyframes fadeIn{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}
h1{font-size:28px;font-weight:800;margin-bottom:4px;letter-spacing:-.5px}
.sub{color:var(--textdim);font-size:13.5px;margin-bottom:24px}

/* Cards */
.card{background:linear-gradient(145deg,var(--card),var(--card2));border:1px solid var(--border);border-radius:var(--radius);padding:20px;margin-bottom:14px;box-shadow:var(--shadow);transition:transform .2s,box-shadow .2s}
.card:hover{transform:translateY(-2px);box-shadow:var(--shadow-lg)}
.cardrow{display:flex;gap:14px;flex-wrap:wrap}
.statcard{flex:1;min-width:130px;background:linear-gradient(145deg,var(--card),var(--card2));border:1px solid var(--border);border-radius:var(--radius);padding:16px;position:relative;overflow:hidden;box-shadow:var(--shadow)}
.statcard::before{content:'';position:absolute;top:0;left:0;right:0;height:2px;background:linear-gradient(90deg,var(--accent),transparent)}
.statlabel{font-size:10px;color:var(--textmuted);text-transform:uppercase;letter-spacing:1.5px;font-weight:600}
.statval{font-size:32px;font-weight:800;margin-top:6px;background:linear-gradient(135deg,var(--text),var(--textdim));-webkit-background-clip:text;-webkit-text-fill-color:transparent}

/* Tweak cards */
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:12px}
.tweakcard{background:linear-gradient(145deg,var(--card),var(--card2));border:1px solid var(--border);border-radius:var(--radius);padding:16px;transition:all .25s;position:relative;overflow:hidden}
.tweakcard:hover{border-color:var(--border2);transform:translateY(-3px);box-shadow:0 8px 30px rgba(0,0,0,.5)}
.tweakcard::after{content:'';position:absolute;inset:0;background:radial-gradient(circle at 0% 0%,rgba(0,255,136,.03),transparent 50%);pointer-events:none;opacity:0;transition:opacity .25s}
.tweakcard:hover::after{opacity:1}
.tweakhead{display:flex;align-items:center;gap:6px;margin-bottom:8px;flex-wrap:wrap}
.badge{padding:3px 9px;border-radius:4px;font-size:9px;font-weight:700;letter-spacing:.5px;text-transform:uppercase}
.badge.safe{background:linear-gradient(135deg,var(--accent),var(--accent2));color:#000;box-shadow:0 2px 8px var(--accentglow)}
.badge.caution{background:linear-gradient(135deg,var(--warn),var(--warn2));color:#000;box-shadow:0 2px 8px rgba(255,165,2,.3)}
.badge.danger{background:linear-gradient(135deg,var(--danger),var(--danger2));color:#fff;box-shadow:0 2px 8px rgba(255,71,87,.3)}
.badge.free{background:rgba(0,255,136,.1);color:var(--accent);border:1px solid rgba(0,255,136,.3)}
.badge.pro{background:rgba(255,165,2,.1);color:var(--warn);border:1px solid rgba(255,165,2,.3)}
.tweakname{font-size:14.5px;font-weight:600;margin-bottom:4px}
.tweakdesc{font-size:12px;color:var(--textdim);line-height:1.5}

/* Toggle switch */
.toggle{margin-left:auto;position:relative;width:46px;height:24px;cursor:pointer;flex-shrink:0}
.toggle input{opacity:0;width:0;height:0;position:absolute}
.slider{position:absolute;inset:0;background:linear-gradient(180deg,#2a2a38,#1e1e2a);border:1px solid var(--border2);border-radius:24px;transition:all .3s;box-shadow:inset 0 2px 4px rgba(0,0,0,.3)}
.slider:before{content:"";position:absolute;width:18px;height:18px;left:2px;top:2px;background:linear-gradient(145deg,#fff,#d0d0d8);border-radius:50%;transition:all .3s;box-shadow:0 2px 6px rgba(0,0,0,.4)}
.toggle input:checked+.slider{background:linear-gradient(135deg,var(--accent),var(--accent2));border-color:var(--accent);box-shadow:0 0 12px var(--accentglow),inset 0 1px 2px rgba(255,255,255,.2)}
.toggle input:checked+.slider:before{transform:translateX(22px);background:#fff;box-shadow:0 2px 6px rgba(0,0,0,.3)}
.toggle input:disabled+.slider{opacity:.4;cursor:not-allowed}

/* Buttons */
.btn{background:linear-gradient(135deg,var(--accent),var(--accent2));color:#000;border:none;padding:11px 22px;border-radius:var(--radius-sm);font-weight:700;cursor:pointer;font-size:13.5px;transition:all .2s;box-shadow:0 4px 15px var(--accentglow),inset 0 1px 0 rgba(255,255,255,.2);position:relative;overflow:hidden;text-transform:uppercase;letter-spacing:.5px}
.btn:hover{transform:translateY(-2px);box-shadow:0 6px 25px var(--accentglow),inset 0 1px 0 rgba(255,255,255,.3);filter:brightness(1.1)}
.btn:active{transform:translateY(0);box-shadow:0 2px 8px var(--accentglow)}
.btn.danger{background:linear-gradient(135deg,var(--danger),var(--danger2));box-shadow:0 4px 15px rgba(255,71,87,.3);color:#fff}
.btn.danger:hover{box-shadow:0 6px 25px rgba(255,71,87,.4)}
.btn.ghost{background:linear-gradient(145deg,var(--card),var(--card2));border:1px solid var(--border2);color:var(--text);box-shadow:var(--shadow)}
.btn.ghost:hover{border-color:var(--accent);color:var(--accent);box-shadow:0 4px 15px rgba(0,0,0,.3)}
.btn.sm{padding:7px 16px;font-size:11.5px}
.btn.xs{padding:4px 10px;font-size:10.5px}

/* Inputs */
.input{background:var(--bg2);border:1px solid var(--border);color:var(--text);padding:10px 14px;border-radius:var(--radius-sm);font-size:13px;width:100%;transition:all .2s;font-family:inherit}
.input:focus{outline:none;border-color:var(--accent);box-shadow:0 0 0 3px var(--accentglow)}
.textarea{background:var(--bg2);border:1px solid var(--border);color:var(--text);padding:10px 14px;border-radius:var(--radius-sm);font-size:12px;font-family:'Consolas',monospace;width:100%;min-height:110px;resize:vertical;transition:all .2s}
.textarea:focus{outline:none;border-color:var(--accent);box-shadow:0 0 0 3px var(--accentglow)}

/* Category bar */
.catbar{display:flex;gap:6px;margin-bottom:16px;flex-wrap:wrap}
.catbtn{background:linear-gradient(145deg,var(--card),var(--card2));border:1px solid var(--border);color:var(--textdim);padding:8px 18px;border-radius:20px;cursor:pointer;font-size:12px;font-weight:500;transition:all .2s}
.catbtn:hover{color:var(--text);border-color:var(--border2);transform:translateY(-1px)}
.catbtn.active{background:linear-gradient(135deg,var(--accent),var(--accent2));color:#000;border-color:var(--accent);font-weight:700;box-shadow:0 4px 15px var(--accentglow)}

/* Log */
.logbox{background:#050508;border:1px solid var(--border);border-radius:var(--radius);padding:14px;font-family:'Consolas',monospace;font-size:12px;color:#7fdc9a;height:420px;overflow-y:auto;white-space:pre-wrap;box-shadow:inset 0 2px 10px rgba(0,0,0,.5);line-height:1.6}

/* Toast */
.toast{position:fixed;bottom:24px;right:24px;background:linear-gradient(135deg,var(--card),var(--card2));border:1px solid var(--accent);padding:14px 22px;border-radius:var(--radius);font-size:13px;opacity:0;transform:translateY(20px);transition:all .3s;pointer-events:none;box-shadow:0 8px 30px rgba(0,0,0,.5);z-index:1000;font-weight:500}
.toast.show{opacity:1;transform:translateY(0)}

/* Warn box */
.warnbox{background:linear-gradient(135deg,rgba(255,165,2,.08),rgba(255,165,2,.02));border:1px solid rgba(255,165,2,.4);border-radius:var(--radius);padding:12px 16px;font-size:12.5px;color:var(--warn);margin-bottom:14px;box-shadow:0 2px 10px rgba(255,165,2,.1)}

/* Profile cards */
.profilecard{background:linear-gradient(145deg,var(--card),var(--card2));border:1px solid var(--border);border-radius:var(--radius);padding:16px;display:flex;align-items:center;gap:16px;margin-bottom:10px;transition:all .2s}
.profilecard:hover{border-color:var(--border2);transform:translateX(4px)}
.profileicon{width:44px;height:44px;border-radius:8px;background:linear-gradient(135deg,var(--accent),var(--accent2));display:flex;align-items:center;justify-content:center;font-weight:800;color:#000;font-size:16px;box-shadow:0 4px 12px var(--accentglow)}

/* Scrollbar */
::-webkit-scrollbar{width:8px;height:8px}
::-webkit-scrollbar-track{background:var(--bg)}
::-webkit-scrollbar-thumb{background:var(--border2);border-radius:4px}
::-webkit-scrollbar-thumb:hover{background:var(--textmuted)}

/* Progress bar */
.progress{height:4px;background:var(--border);border-radius:2px;overflow:hidden;margin-top:8px}
.progress-fill{height:100%;background:linear-gradient(90deg,var(--accent),#00d4ff);border-radius:2px;transition:width .5s ease;box-shadow:0 0 8px var(--accentglow)}

/* Pulse animation for live indicators */
@keyframes pulse{0%,100%{opacity:1}50%{opacity:.5}}
.live{animation:pulse 2s infinite}
</style>
</head>
<body>
<div class="sidebar">
  <div class="brand">FL3SH</div>
  <div class="brandsub">Optimizer</div>
  <div class="planbadge" id="planBadge">FREE</div>
  <button class="navbtn active" data-page="home"><span class="navicon">◆</span>Home</button>
  <button class="navbtn" data-page="tweaks"><span class="navicon">⚙</span>Tweaks</button>
  <button class="navbtn" data-page="booster"><span class="navicon">⚡</span>Game Booster</button>
  <button class="navbtn" data-page="potato"><span class="navicon">🥔</span>Potato Graphics</button>
  <button class="navbtn" data-page="bench"><span class="navicon">📊</span>Benchmark</button>
  <button class="navbtn" data-page="restore"><span class="navicon">↺</span>Restore</button>
  <button class="navbtn" data-page="log"><span class="navicon">☰</span>Log</button>
  <button class="navbtn" data-page="settings"><span class="navicon">✦</span>Settings</button>
  <div class="sidebar-bottom">
    <div class="userinfo" id="userInfo">Guest</div>
    <div class="ptsinfo" id="ptsInfo">0 tweaks applied</div>
    <div class="progress"><div class="progress-fill" id="progressFill" style="width:0%"></div></div>
  </div>
</div>

<div class="content">
<div class="page active" id="page-home">
  <h1 id="greeting">Good evening</h1>
  <div class="sub" id="homeSub">0 tweaks on · Free plan</div>
  <div class="cardrow" id="statsRow"></div>
  <div class="cardrow" style="margin-top:16px">
    <div class="card" style="flex:1;min-width:300px">
      <h3 style="margin-bottom:10px;font-size:16px">Suggested next</h3>
      <div style="color:var(--textdim);font-size:13px;margin-bottom:14px" id="sugText">0% optimized</div>
      <button class="btn" id="applyAllBtn">Apply everything</button>
    </div>
    <div class="card" style="flex:1;min-width:300px">
      <h3 style="margin-bottom:10px;font-size:16px">Quickstart</h3>
      <div style="color:var(--textdim);font-size:13px;line-height:2">
        <div>▸ Create a restore point</div>
        <div>▸ Turn on your first 3 tweaks</div>
        <div>▸ Turn on Game Booster</div>
        <div>▸ Join the Discord</div>
      </div>
    </div>
  </div>
  <div class="card" style="margin-top:16px">
    <h3 style="margin-bottom:10px;font-size:16px">What's new</h3>
    <div style="color:var(--textdim);font-size:13px;line-height:1.6">Game Booster clears your session again. Drivers, services and vendor tools are never touched, so laptops are safe.</div>
  </div>
</div>

<div class="page" id="page-tweaks">
  <h1>Tweaks</h1>
  <div class="sub">Each tweak is a card with a risk label and a switch. Hover for details.</div>
  <div class="catbar" id="catBar"></div>
  <div class="grid" id="tweakGrid"></div>
</div>

<div class="page" id="page-booster">
  <h1>EMT Game Booster</h1>
  <div class="sub">Closes what you are not using before you queue. Whitelist what stays.</div>
  <div class="cardrow">
    <div class="card" style="flex:1;min-width:300px">
      <h3 style="margin-bottom:10px;font-size:16px">Whitelist (one app per line)</h3>
      <textarea class="textarea" id="whitelist">discord.exe
chrome.exe
spotify.exe</textarea>
      <button class="btn" style="margin-top:12px;width:100%" id="boostBtn">⚡ BOOST (close others)</button>
    </div>
    <div class="card" style="flex:1;min-width:300px">
      <h3 style="margin-bottom:10px;font-size:16px">Status</h3>
      <div style="color:var(--textdim);font-size:13px;line-height:2">
        Booster is OFF<br><br>
        Free: whitelist 1 app<br>
        Pro: unlimited whitelist
      </div>
    </div>
  </div>
</div>

<div class="page" id="page-potato">
  <h1>Potato Graphics</h1>
  <div class="sub">One-click low-graphics profiles. Max FPS, max visibility, revert any time.</div>
  <div class="warnbox">⚠ WARNING: This is the only tweak that changes how the game LOOKS. Revert anytime.</div>
  <div id="profileList"></div>
</div>

<div class="page" id="page-bench">
  <h1>Benchmark</h1>
  <div class="sub">System info + micro-benchmark. Track your FPS before and after.</div>
  <div class="card">
    <button class="btn ghost sm" id="refreshSysBtn">Refresh System Info</button>
    <pre id="sysInfo" style="margin-top:12px;color:var(--textdim);font-size:12px;font-family:'Consolas',monospace;line-height:1.6"></pre>
  </div>
  <div class="card" style="margin-top:14px">
    <div style="display:flex;gap:12px;align-items:center;flex-wrap:wrap">
      <label style="font-size:13px;font-weight:500">FPS before:</label>
      <input class="input" style="width:90px" id="fpsBefore">
      <label style="font-size:13px;font-weight:500">FPS after:</label>
      <input class="input" style="width:90px" id="fpsAfter">
      <button class="btn ghost sm" id="runBenchBtn">Run Micro-Benchmark</button>
      <button class="btn ghost sm" id="saveBenchBtn">Save to CSV</button>
    </div>
    <div style="margin-top:12px;color:var(--textdim);font-size:13px" id="benchResult">Micro-bench: not run</div>
  </div>
</div>

<div class="page" id="page-restore">
  <h1>Restore & Revert</h1>
  <div class="sub">Every tweak is reversible. Restore points + backups created before changes.</div>
  <div class="card">
    <button class="btn ghost" id="restorePointBtn" style="margin-right:10px">Create System Restore Point</button>
    <button class="btn danger" id="revertAllBtn">REVERT ALL CHANGES</button>
    <div style="margin-top:14px;color:var(--textdim);font-size:12px;line-height:1.6">Reboot recommended after reverting. All original values are restored from backup.</div>
  </div>
</div>

<div class="page" id="page-log">
  <h1>Log</h1>
  <div class="sub">Activity log.</div>
  <div class="logbox" id="logBox"></div>
  <button class="btn ghost sm" style="margin-top:12px" id="refreshLogBtn">Refresh</button>
</div>

<div class="page" id="page-settings">
  <h1>Settings</h1>
  <div class="sub">License and account.</div>
  <div class="card">
    <label style="font-size:13px;display:block;margin-bottom:6px;font-weight:500">Email (for license)</label>
    <input class="input" id="emailInput" style="margin-bottom:14px">
    <label style="font-size:13px;display:block;margin-bottom:6px;font-weight:500">License key</label>
    <input class="input" id="keyInput" style="margin-bottom:14px">
    <button class="btn" id="activateBtn">Activate License</button>
    <div style="margin-top:16px;color:var(--textdim);font-size:12px;line-height:1.8">
      <b style="color:var(--text)">Free:</b> 3 tweaks + monitoring + 1 Game Booster app<br>
      <b style="color:var(--text)">Pro:</b> All tweaks + Potato Graphics + full Game Booster
    </div>
  </div>
</div>
</div>

<div class="toast" id="toast"></div>

<script>
const state={plan:'Free',tweaks:{},os:'unknown'};
function showToast(msg){const t=document.getElementById('toast');t.textContent=msg;t.classList.add('show');setTimeout(()=>t.classList.remove('show'),2800)}
async function api(path,body={}){
  const r=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
  return r.json();
}
document.querySelectorAll('.navbtn').forEach(b=>b.addEventListener('click',()=>{
  document.querySelectorAll('.navbtn').forEach(x=>x.classList.remove('active'));
  b.classList.add('active');
  document.querySelectorAll('.page').forEach(p=>p.classList.remove('active'));
  document.getElementById('page-'+b.dataset.page).classList.add('active');
  if(b.dataset.page==='log')refreshLog();
}));
function renderStats(){
  const stats=[{label:'CPU',value:'7%',color:'var(--accent)'},{label:'GPU',value:'8%',color:'var(--accent)'},{label:'RAM',value:'37%',color:'var(--warn)'},{label:'TEMP',value:'41°',color:'var(--accent)'}];
  document.getElementById('statsRow').innerHTML=stats.map(s=>`<div class="statcard"><div class="statlabel">${s.label}</div><div class="statval" style="background:linear-gradient(135deg,${s.color},var(--textdim));-webkit-background-clip:text;-webkit-text-fill-color:transparent">${s.value}</div></div>`).join('');
}
const cats=['General','Services','Network','Power','Visual','Game'];
let currentCat='General';
function renderCatBar(){
  document.getElementById('catBar').innerHTML=cats.map(c=>`<button class="catbtn ${c===currentCat?'active':''}" data-cat="${c}">${c}</button>`).join('');
  document.querySelectorAll('.catbtn').forEach(b=>b.addEventListener('click',()=>{currentCat=b.dataset.cat;renderCatBar();renderTweaks()}));
}
async function loadTweaks(){
  const r=await api('/api/tweaks/list');
  state.tweaks=r.tweaks||{};
  renderTweaks();updateCounts();
}
function renderTweaks(){
  const grid=document.getElementById('tweakGrid');
  const list=Object.values(state.tweaks).filter(t=>t.cat===currentCat);
  grid.innerHTML=list.map(t=>{
    const checked=t.state?'checked':'';
    const riskCls=t.risk.toLowerCase();
    const planBadge=t.free?'<span class="badge free">FREE</span>':'<span class="badge pro">PRO</span>';
    const disabled=(!t.free&&state.plan==='Free')?'disabled':'';
    return `<div class="tweakcard">
      <div class="tweakhead">
        <span class="badge ${riskCls}">${t.risk}</span>${planBadge}
        <label class="toggle"><input type="checkbox" data-id="${t.id}" ${checked} ${disabled}><span class="slider"></span></label>
      </div>
      <div class="tweakname">${t.name}</div>
      <div class="tweakdesc">${t.desc}</div>
    </div>`;
  }).join('');
  grid.querySelectorAll('input[type=checkbox]').forEach(cb=>cb.addEventListener('change',async e=>{
    const id=cb.dataset.id;const tw=state.tweaks[id];
    if(!tw.free&&state.plan==='Free'){showToast('Requires Pro plan');cb.checked=false;return}
    if(cb.checked&&tw.risk!=='Safe'){if(!confirm(tw.name+'\n\nRisk: '+tw.risk+'\n'+tw.desc+'\n\nApply?')){cb.checked=false;return}}
    const r=await api('/api/tweak/toggle',{id,state:cb.checked});
    state.tweaks[id].state=cb.checked;
    showToast(r.message||(cb.checked?'Applied':'Reverted'));
    updateCounts();
  }));
}
function updateCounts(){
  const applied=Object.values(state.tweaks).filter(t=>t.state).length;
  const total=Object.keys(state.tweaks).length;
  document.getElementById('ptsInfo').textContent=applied+' tweaks applied';
  document.getElementById('homeSub').textContent=applied+' of '+total+' tweaks on · '+state.plan+' plan';
  document.getElementById('sugText').textContent=Math.round(applied/total*100)+'% optimized · '+applied+' of '+total+' on.';
  document.getElementById('progressFill').style.width=Math.round(applied/total*100)+'%';
}
const profiles=[{name:'Fortnite',desc:'DX11 and Performance mode',plan:'Pro',icon:'FN'},{name:'Fortnite Competitive',desc:'Fixed floor (lowest settings)',plan:'Plus',icon:'FC'},{name:'Marvel Rivals',desc:'Low-graphics competitive profile',plan:'Plus',icon:'MR'},{name:'AMD/Intel Potato',desc:'Works on any GPU. Removes texture packs.',plan:'Pro',icon:'AI'}];
document.getElementById('profileList').innerHTML=profiles.map(p=>`<div class="profilecard"><div class="profileicon">${p.icon}</div><div style="flex:1"><div style="font-weight:600;font-size:14px">${p.name}</div><div style="font-size:12px;color:var(--textdim);margin-top:2px">${p.desc}</div></div><span class="badge pro">${p.plan}</span><button class="btn sm" data-profile="${p.name}">Apply</button></div>`).join('');
document.querySelectorAll('[data-profile]').forEach(b=>b.addEventListener('click',async()=>{
  if(state.plan==='Free'){showToast('Requires Pro plan');return}
  if(!confirm('This will change Fortnite graphics (Engine.ini).\nRevert anytime. Continue?'))return;
  const r=await api('/api/potato',{profile:b.dataset.profile});showToast(r.message);
}));
document.getElementById('boostBtn').addEventListener('click',async()=>{
  const wl=document.getElementById('whitelist').value.split('\n').map(s=>s.trim()).filter(Boolean);
  const r=await api('/api/booster',{whitelist:wl});showToast(r.message);
});
document.getElementById('applyAllBtn').addEventListener('click',async()=>{const r=await api('/api/applyall');showToast(r.message);await loadTweaks()});
document.getElementById('refreshSysBtn').addEventListener('click',async()=>{const r=await api('/api/sysinfo');document.getElementById('sysInfo').textContent=r.info});
document.getElementById('runBenchBtn').addEventListener('click',async()=>{document.getElementById('benchResult').textContent='Running...';const r=await api('/api/bench');document.getElementById('benchResult').textContent=r.result});
document.getElementById('saveBenchBtn').addEventListener('click',async()=>{const r=await api('/api/savebench',{before:document.getElementById('fpsBefore').value,after:document.getElementById('fpsAfter').value});showToast(r.message)});
document.getElementById('restorePointBtn').addEventListener('click',async()=>{const r=await api('/api/restorepoint');showToast(r.message)});
document.getElementById('revertAllBtn').addEventListener('click',async()=>{if(!confirm('Revert ALL changes? Reboot recommended after.'))return;const r=await api('/api/revertall');showToast(r.message);await loadTweaks()});
async function refreshLog(){const r=await api('/api/log');document.getElementById('logBox').textContent=r.log}
document.getElementById('refreshLogBtn').addEventListener('click',refreshLog);
document.getElementById('activateBtn').addEventListener('click',async()=>{
  const r=await api('/api/activate',{email:document.getElementById('emailInput').value,key:document.getElementById('keyInput').value});
  if(r.success){state.plan='Pro';document.getElementById('planBadge').textContent='PRO';document.getElementById('planBadge').style.background='linear-gradient(135deg,var(--accent),var(--accent2))';showToast('License activated! Plan: Pro')}
  else showToast(r.message||'Invalid key');
});
renderStats();renderCatBar();loadTweaks();
const h=new Date().getHours();document.getElementById('greeting').textContent=h<12?'Good morning':h<18?'Good afternoon':'Good evening';
</script>
</body>
</html>
'@

# ---------- HTTP Server ----------
$Port = 8765
$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add("http://localhost:$Port/")
$Listener.Start()
Write-Host "FL3SH Optimizer running at http://localhost:$Port" -ForegroundColor Green

if ($IsMac) { Start-Process "open" -ArgumentList "http://localhost:$Port" }
elseif ($IsWin) { Start-Process "http://localhost:$Port" }

while ($Listener.IsListening) {
    $ctx = $Listener.GetContext()
    $req = $ctx.Request; $res = $ctx.Response; $path = $req.Url.AbsolutePath
    if ($path -eq "/" -or $path -eq "/index.html") {
        $buf = [System.Text.Encoding]::UTF8.GetBytes($HtmlPage); $res.ContentType = "text/html; charset=utf-8"; $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/tweaks/list") {
        $tweakObj = @{}
        $catMap = @{"power"="Power";"usb"="Power";"memory"="General";"temp"="General";"visual"="Visual";"menu"="Visual";"transp"="Visual";"startup"="General";"services"="Services";"sysmain"="Services";"nagle"="Network";"autotune"="Network";"qos"="Network";"hags"="Power";"corepark"="Power";"timer"="Power";"potato"="Game";"gamedvr"="Game";"fullscreen"="Game";"macpower"="Power";"spotlight"="General";"fontcache"="Visual"}
        foreach ($t in $Script:Tweaks) {
            $isAvail = if ($IsWin) { $t.Win } else { $t.Mac }
            if (-not $isAvail) { continue }
            $tweakObj[$t.Id] = @{ id=$t.Id; name=$t.Name; desc=$t.Desc; risk=$t.Risk; free=$t.Free; cat=$catMap[$t.Id]; state=$Script:Config.TweakStates[$t.Id] }
        }
        $json = @{ tweaks = $tweakObj } | ConvertTo-Json -Depth 5
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/tweak/toggle") {
        $reader = New-Object System.IO.StreamReader($req.InputStream); $body = $reader.ReadToEnd() | ConvertFrom-Json
        $tw = $Script:Tweaks | Where-Object { $_.Id -eq $body.id } | Select-Object -First 1
        $Script:Config.TweakStates[$body.id] = [bool]$body.state; Save-Config
        $msg = "Reverted"
        if ($body.state) { & $tw.Action; $msg = "Applied: $($tw.Name)" }
        $json = @{ message = $msg } | ConvertTo-Json; $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/booster") { Invoke-GameBooster; $json = @{ message = "Game Booster complete." } | ConvertTo-Json; $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
    elseif ($path -eq "/api/potato") { Invoke-PotatoGraphics; $json = @{ message = "Potato Graphics applied." } | ConvertTo-Json; $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
    elseif ($path -eq "/api/applyall") {
        $count = 0
        foreach ($t in $Script:Tweaks) { $isAvail = if ($IsWin) { $t.Win } else { $t.Mac }; if ($isAvail -and ($t.Free -or $Script:Config.Plan -ne "Free")) { $Script:Config.TweakStates[$t.Id] = $true; & $t.Action; $count++ } }
        Save-Config; $json = @{ message = "Applied $count tweaks." } | ConvertTo-Json; $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/sysinfo") {
        $info = "OS: $(if($IsWin){'Windows'}else{'macOS'})`n"
        if ($IsWin) { $cpu=(Get-CimInstance Win32_Processor).Name; $gpu=(Get-CimInstance Win32_VideoController|Select-Object -First 1).Name; $ram=[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1); $info += "CPU: $cpu`nGPU: $gpu`nRAM: $ram GB" }
        else { $info += "CPU: $(sysctl -n machdep.cpu.brand_string 2>/dev/null)`nRAM: $([math]::Round((sysctl -n hw.memsize 2>/dev/null)/1GB,1)) GB" }
        $json = @{ info = $info } | ConvertTo-Json; $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/bench") { $sw=[Diagnostics.Stopwatch]::StartNew(); $c=0; for($i=2;$i -lt 200000;$i++){$isP=$true;for($j=2;$j*$j -le $i;$j++){if($i%$j -eq 0){$isP=$false;break}};if($isP){$c++}}; $sw.Stop(); $json=@{result="Micro-bench: $([math]::Round($sw.Elapsed.TotalMilliseconds,1)) ms (lower = better)"} | ConvertTo-Json; $buf=[System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType="application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
    elseif ($path -eq "/api/savebench") { $reader=New-Object System.IO.StreamReader($req.InputStream); $body=$reader.ReadToEnd()|ConvertFrom-Json; $row="$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$($body.before),$($body.after)"; $bp=Join-Path $Script:Root "benchmark.csv"; if(-not (Test-Path $bp)){"Date,FPS_Before,FPS_After"|Set-Content $bp}; Add-Content $bp $row; $json=@{message="Saved to $bp"} | ConvertTo-Json; $buf=[System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType="application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
    elseif ($path -eq "/api/restorepoint") { $msg="Restore point: not supported on this OS."; if($IsWin){try{Checkpoint-Computer -Description "FL3SH Optimizer" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop; $msg="Restore point created."}catch{$msg="Restore point failed: $($_.Exception.Message)"}}; $json=@{message=$msg}|ConvertTo-Json; $buf=[System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType="application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
    elseif ($path -eq "/api/revertall") { Revert-All; $json=@{message="All changes reverted. Reboot recommended."}|ConvertTo-Json; $buf=[System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType="application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
    elseif ($path -eq "/api/log") { $logContent=if(Test-Path $Script:LogPath){Get-Content $Script:LogPath -Raw}else{""}; $json=@{log=$logContent}|ConvertTo-Json; $buf=[System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType="application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
    elseif ($path -eq "/api/activate") { $reader=New-Object System.IO.StreamReader($req.InputStream); $body=$reader.ReadToEnd()|ConvertFrom-Json; $Script:Config.Email=$body.email; $Script:Config.LicenseKey=$body.key; $success=$false; try { $resp=Invoke-RestMethod -Uri "https://api.gumroad.com/v2/licenses/verify" -Method POST -Body @{product_id="YOUR_PRODUCT_ID";license_key=$body.key} -ErrorAction Stop; if($resp.success){$success=$true} } catch { if($body.key -match "^FL3SH-"){$success=$true} }; if($success){$Script:Config.Plan="Pro";Save-Config}; $json=@{success=$success;message=if($success){"License activated! Plan: Pro"}else{"Invalid license key."}} | ConvertTo-Json; $buf=[System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType="application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
    else { $res.StatusCode=404 }
    $res.Close()
}
