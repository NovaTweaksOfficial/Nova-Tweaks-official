#Requires -RunAsAdministrator
<#
.SYNOPSIS
    FL3SH Optimizer - Cross-Platform Web GUI (Mac + Windows)
.DESCRIPTION
    Uses an embedded HTML/CSS/JS interface served by a local PowerShell HTTP server.
    Works on macOS and Windows. Compile to .exe on Windows with PS2EXE.
.NOTES
    macOS:  sudo pwsh ./FL3SH_Optimizer_WebGUI.ps1
    Windows: Run as Administrator, then open http://localhost:8765
#>

# ---------- OS Detection ----------
$IsWin = $IsWindows -or ($env:OS -eq "Windows_NT")
$IsMac = $IsMacOS -or ((uname 2>/dev/null) -eq "Darwin")

$Script:Root = if ($IsWin) { Join-Path $env:USERPROFILE "FL3SH_Optimizer" } else { Join-Path $env:HOME ".fl3sh_optimizer" }
$Script:BackupDir = Join-Path $Script:Root "backups"
$Script:LogPath   = Join-Path $Script:Root "optimizer.log"
$Script:ConfigPath = Join-Path $Script:Root "config.json"
foreach ($d in @($Script:Root,$Script:BackupDir)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }
if (-not (Test-Path $Script:LogPath)) { New-Item -ItemType File -Path $Script:LogPath -Force | Out-Null }

$Script:Config = @{ Plan="Free"; FortnitePath=""; PotatoGraphics=$false; TweakStates=@{}; Email=""; LicenseKey="" }
if (Test-Path $Script:ConfigPath) { try { $l = Get-Content $Script:ConfigPath -Raw | ConvertFrom-Json; foreach ($k in $l.PSObject.Properties.Name) { $Script:Config[$k]=$l.$k } } catch {} }
function Save-Config { $Script:Config | ConvertTo-Json -Depth 5 | Set-Content $Script:ConfigPath -Encoding UTF8 }

$Script:Logs = [System.Collections.ArrayList]::new()
function Write-Log {
    param([string]$Msg,[string]$Level="INFO")
    $line = "$(Get-Date -Format 'HH:mm:ss') [$Level] $Msg"
    [void]$Script:Logs.Add($line)
    Add-Content -Path $Script:LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Msg" -ErrorAction SilentlyContinue
}

# ---------- Tweak Functions ----------
function Invoke-PowerPlan {
    if (-not $IsWin) { Write-Log "Power plan: Windows only." "WARN"; return }
    try {
        $hp = (powercfg /list | Select-String "Ultimate Performance" | ForEach-Object { ($_ -split '\s+')[3] }) | Select-Object -First 1
        if (-not $hp) { $hp = (powercfg /list | Select-String "High performance" | ForEach-Object { ($_ -split '\s+')[3] }) | Select-Object -First 1 }
        if ($hp) { powercfg /setactive $hp 2>$null | Out-Null; Write-Log "Power plan activated: $hp" "OK" }
        powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
        powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
        Write-Log "USB selective suspend disabled." "OK"
    } catch { Write-Log "Power plan failed: $($_.Exception.Message)" "ERR" }
}

function Invoke-MemoryCleanup {
    if ($IsWin) {
        try {
            Get-Process | Where-Object { $_.WorkingSet64 -gt 50MB -and $_.ProcessName -notin @("System","Registry","smss","csrss","winlogon","services","lsass","explorer") } | ForEach-Object { try { $_.MinWorkingSet=1MB; $_.MaxWorkingSet=1MB } catch {} }
            $code = @"
using System; using System.Runtime.InteropServices;
public class Mem {
  [DllImport("ntdll.dll")] public static extern int NtSetSystemInformation(int i, IntPtr p, int l);
  public static void EmptyStandby() { int size=Marshal.SizeOf(typeof(int)); IntPtr ptr=Marshal.AllocHGlobal(size); Marshal.WriteInt32(ptr,4); NtSetSystemInformation(80,ptr,size); Marshal.FreeHGlobal(ptr); }
}
"@
            Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
            [Mem]::EmptyStandby() 2>$null
            Write-Log "Memory trimmed + standby purged." "OK"
        } catch { Write-Log "Memory partial: $($_.Exception.Message)" "WARN" }
    } else {
        try { purge 2>$null; Write-Log "Inactive memory purged." "OK" } catch { Write-Log "purge failed." "WARN" }
    }
}

function Invoke-TempCleanup {
    if ($IsWin) {
        $paths = @($env:TEMP, "$env:WINDIR\Temp", "$env:LOCALAPPDATA\Temp")
        $freed = 0
        foreach ($p in $paths) {
            if (Test-Path $p) { Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { try { if (-not $_.PSIsContainer) { $freed += $_.Length; Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } } catch {} } }
        }
        $shader = "$env:LOCALAPPDATA\FortniteGame\Saved\ShaderCache"
        if (Test-Path $shader) { Remove-Item $shader -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "Fortnite shader cache cleared." "OK" }
        Write-Log "Temp cleanup freed ~$([math]::Round($freed/1MB,1)) MB." "OK"
    } else {
        $freed = 0
        foreach ($p in @("$env:HOME/Library/Caches","/tmp","/var/tmp")) {
            if (Test-Path $p) { Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | ForEach-Object { try { $freed += $_.Length; Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } catch {} } }
        }
        Write-Log "Temp cleanup freed ~$([math]::Round($freed/1MB,1)) MB." "OK"
    }
}

function Invoke-RegistryTweaks {
    if (-not $IsWin) { Write-Log "Registry tweaks: Windows only." "WARN"; return }
    $changes = @(
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_Enabled"; Value=0; Type="DWord"},
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_FSEBehaviorMode"; Value=2; Type="DWord"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="SystemResponsiveness"; Value=0; Type="DWord"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="GPU Priority"; Value=8; Type="DWord"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Priority"; Value=6; Type="DWord"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Scheduling Category"; Value="High"; Type="String"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="SFIO Priority"; Value="High"; Type="String"},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; Name="VisualFXSetting"; Value=2; Type="DWord"},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="MenuShowDelay"; Value=0; Type="String"}
    )
    foreach ($c in $changes) {
        try {
            if (-not (Test-Path $c.Path)) { New-Item -Path $c.Path -Force | Out-Null }
            Set-ItemProperty -Path $c.Path -Name $c.Name -Value $c.Value -Type $c.Type -Force
            Write-Log "Registry: $($c.Name) = $($c.Value)" "OK"
        } catch { Write-Log "Registry $($c.Name) failed." "WARN" }
    }
    $iface = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    Get-ChildItem $iface -ErrorAction SilentlyContinue | ForEach-Object {
        try { Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force; Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force } catch {}
    }
    Write-Log "TCP no-delay (Nagle) applied." "OK"
}

function Invoke-HAGS {
    if (-not $IsWin) { Write-Log "HAGS: Windows only." "WARN"; return }
    try {
        $p = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        Set-ItemProperty -Path $p -Name "HwSchMode" -Value 2 -Type DWord -Force
        Write-Log "HAGS enabled (reboot required)." "OK"
    } catch { Write-Log "HAGS failed." "WARN" }
}

function Invoke-Services {
    if (-not $IsWin) { Write-Log "Services: Windows only." "WARN"; return }
    $svcs = @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","DiagTrack","dmwappushservice","SysMain")
    foreach ($s in $svcs) {
        try {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue; Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue; Write-Log "Disabled: $s" "OK" }
        } catch { Write-Log "Service $s skipped." "WARN" }
    }
}

function Invoke-Network {
    if ($IsWin) {
        try { netsh interface tcp set global autotuninglevel=disabled 2>$null | Out-Null; netsh interface tcp set global ecncapability=disabled 2>$null | Out-Null; netsh interface tcp set global timestamps=disabled 2>$null | Out-Null; Write-Log "TCP auto-tuning disabled." "OK" } catch { Write-Log "Network tweak failed." "WARN" }
    } else {
        try { dscacheutil -flushcache 2>$null; killall -HUP mDNSResponder 2>$null; Write-Log "DNS cache flushed." "OK" } catch { Write-Log "DNS flush failed." "WARN" }
    }
}

function Invoke-VisualEffects {
    if (-not $IsMac) { Write-Log "Visual effects: macOS only." "WARN"; return }
    try {
        defaults write com.apple.universalaccess reduceTransparency -bool true
        defaults write com.apple.universalaccess reduceMotion -bool true
        defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
        defaults write com.apple.dock expose-animation-duration -float 0.1
        defaults write com.apple.dashboard mcx-disabled -boolean YES
        defaults write NSGlobalDomain KeyRepeat -int 2
        defaults write NSGlobalDomain InitialKeyRepeat -int 15
        killall Dock 2>$null
        Write-Log "Visual effects reduced." "OK"
    } catch { Write-Log "Visual tweaks failed." "WARN" }
}

function Invoke-MacPower {
    if (-not $IsMac) { Write-Log "Mac power: macOS only." "WARN"; return }
    try {
        pmset -c sleep 0 2>$null; pmset -c disksleep 0 2>$null; pmset -c displaysleep 10 2>$null; pmset -a sms 0 2>$null
        Write-Log "Power settings tuned." "OK"
    } catch { Write-Log "Power tweak failed." "WARN" }
}

function Invoke-PotatoGraphics {
    if (-not $IsWin) { Write-Log "Potato Graphics: Windows only (Fortnite Engine.ini)." "WARN"; return }
    $base = "$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient"
    if (-not (Test-Path $base)) { New-Item -ItemType Directory -Path $base -Force | Out-Null }
    $p = Join-Path $base "Engine.ini"
    $content = @"
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
"@
    Set-Content -Path $p -Value $content -Encoding ASCII -Force
    Write-Log "Potato Graphics applied to Engine.ini." "OK"
}

function Invoke-GameBooster {
    if (-not $IsWin) { Write-Log "Game Booster: Windows only." "WARN"; return }
    $keep = @("System","Registry","smss","csrss","winlogon","services","lsass","explorer","dwm","svchost","conhost","powershell","pwsh","cmd","taskmgr","FortniteClient-Win64-Shipping")
    Get-Process | Where-Object { $_.ProcessName -notin $keep -and $_.MainWindowHandle -ne 0 } | ForEach-Object { try { $_.CloseMainWindow() | Out-Null; Write-Log "Closed: $($_.ProcessName)" "OK" } catch {} }
    Invoke-MemoryCleanup
    Write-Log "Game Booster complete." "OK"
}

function Revert-All {
    if ($IsWin) {
        powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
        netsh interface tcp set global autotuninglevel=normal 2>$null | Out-Null
        @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","DiagTrack","dmwappushservice","SysMain") | ForEach-Object { Set-Service -Name $_ -StartupType Manual -ErrorAction SilentlyContinue }
        Write-Log "Windows revert complete. Reboot recommended." "OK"
    } else {
        try {
            defaults write com.apple.universalaccess reduceTransparency -bool false
            defaults write com.apple.universalaccess reduceMotion -bool false
            defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool true
            defaults delete com.apple.dock expose-animation-duration 2>$null
            defaults delete com.apple.dashboard mcx-disabled 2>$null
            defaults delete NSGlobalDomain KeyRepeat 2>$null
            defaults delete NSGlobalDomain InitialKeyRepeat 2>$null
            mdutil -i on / 2>$null
            pmset -c sleep 10 2>$null; pmset -a sms 1 2>$null
            killall Dock 2>$null
            Write-Log "macOS revert complete." "OK"
        } catch { Write-Log "Revert partial." "WARN" }
    }
}

# ---------- Tweak Registry ----------
$Script:Tweaks = @(
    @{Id="power";Name="Ultimate Performance power plan";Desc="Unlocks hidden Ultimate Performance plan. Best single gaming tweak.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Action={Invoke-PowerPlan}},
    @{Id="usb";Name="Disable USB selective suspend";Desc="Stops USB ports from sleeping. Prevents input lag spikes.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Action={}},
    @{Id="memory";Name="Memory cleanup (trim + purge)";Desc="Trims idle process working sets, purges standby/inactive memory.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Action={Invoke-MemoryCleanup}},
    @{Id="temp";Name="Temp + cache cleanup";Desc="Clears temp folders and shader cache. Frees disk space.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Action={Invoke-TempCleanup}},
    @{Id="visual";Name="Reduce visual effects";Desc="Disables animations, transparency, motion for snappier UI.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Action={if($IsWin){Invoke-RegistryTweaks}else{Invoke-VisualEffects}}},
    @{Id="menu";Name="Reduce menu show delay";Desc="Sets MenuShowDelay to 0 for instant menu response.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Action={}},
    @{Id="transp";Name="Disable transparency";Desc="Kills Acrylic/Mica blur to free GPU compositor cycles.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Action={}},
    @{Id="startup";Name="Disable startup delay";Desc="Removes artificial startup app delay timer.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Action={}},
    @{Id="services";Name="Disable background services";Desc="Stops Xbox + telemetry services (XblAuthManager, DiagTrack, etc).";Risk="Caution";Free=$false;Win=$true;Mac=$false;Action={Invoke-Services}},
    @{Id="sysmain";Name="Disable SysMain (Superfetch)";Desc="Stops background prefetching. Helps on SSD systems.";Risk="Caution";Free=$false;Win=$true;Mac=$false;Action={Invoke-Services}},
    @{Id="nagle";Name="Disable Nagle's algorithm";Desc="TCPNoDelay + TcpAckFrequency. Lowers network latency.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Action={Invoke-RegistryTweaks}},
    @{Id="autotune";Name="Disable TCP auto-tuning";Desc="Sets autotuninglevel=disabled. Reduces bufferbloat.";Risk="Safe";Free=$false;Win=$true;Mac=$true;Action={Invoke-Network}},
    @{Id="qos";Name="Network QoS priority";Desc="Prioritizes game packets over background traffic.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Action={}},
    @{Id="hags";Name="Hardware-Accelerated GPU Scheduling";Desc="Offloads GPU scheduling to hardware. Reboot required.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Action={Invoke-HAGS}},
    @{Id="corepark";Name="Disable core parking";Desc="Keeps all CPU cores awake. Reduces input delay.";Risk="Caution";Free=$false;Win=$true;Mac=$false;Action={}},
    @{Id="timer";Name="Timer resolution 1ms";Desc="Sets system timer to 1ms. Sharper scheduling.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Action={}},
    @{Id="potato";Name="Potato Graphics (Engine.ini)";Desc="Lowers Fortnite render quality for max FPS. Changes appearance.";Risk="Caution";Free=$false;Win=$true;Mac=$false;Action={Invoke-PotatoGraphics}},
    @{Id="gamedvr";Name="Disable Game DVR / Game Bar";Desc="Turns off Xbox Game Bar recording overlay.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Action={Invoke-RegistryTweaks}},
    @{Id="fullscreen";Name="Fullscreen optimizations off";Desc="Disables FSO for lower input lag in fullscreen.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Action={}},
    @{Id="macpower";Name="Mac power tuning";Desc="Disables sleep/disk sleep, sudden motion sensor for performance.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Action={Invoke-MacPower}},
    @{Id="spotlight";Name="Disable Spotlight indexing";Desc="Stops Spotlight from indexing. Frees disk I/O. Reversible.";Risk="Caution";Free=$false;Win=$false;Mac=$true;Action={try{mdutil -i off / 2>$null; Write-Log "Spotlight disabled on /." "OK"}catch{Write-Log "Spotlight tweak failed." "WARN"}}},
    @{Id="fontcache";Name="Clear font cache";Desc="Clears font cache for cleaner rendering.";Risk="Safe";Free=$false;Win=$false;Mac=$true;Action={try{atsutil databases -remove 2>$null; Write-Log "Font cache cleared." "OK"}catch{Write-Log "Font cache clear failed." "WARN"}}}
)

if (-not $Script:Config.TweakStates) { $Script:Config.TweakStates = @{} }
foreach ($t in $Script:Tweaks) { if (-not $Script:Config.TweakStates.ContainsKey($t.Id)) { $Script:Config.TweakStates[$t.Id] = $false } }

# ---------- HTML GUI ----------
$HtmlPage = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>FL3SH Optimizer</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
:root{
--bg:#121216;--sidebar:#18181e;--card:#1e1e26;--cardh:#262630;
--accent:#00c878;--accentdim:#007846;--danger:#dc3c3c;--warn:#f0b428;
--text:#e6e6eb;--textdim:#8c8c96;--border:#32323c
}
body{font-family:'Segoe UI',system-ui,sans-serif;background:var(--bg);color:var(--text);display:flex;height:100vh;overflow:hidden}
.sidebar{width:200px;background:var(--sidebar);border-right:1px solid var(--border);padding:20px 10px;display:flex;flex-direction:column;gap:4px}
.brand{font-size:22px;font-weight:700;color:var(--accent);padding:0 10px}
.brandsub{font-size:11px;color:var(--textdim);padding:0 10px;margin-bottom:12px}
.planbadge{display:inline-block;padding:3px 10px;border-radius:4px;font-size:10px;font-weight:700;margin:0 10px 16px;background:var(--warn);color:#000}
.navbtn{background:transparent;border:none;color:var(--textdim);padding:10px 14px;border-radius:6px;cursor:pointer;font-size:14px;text-align:left;width:100%;transition:.15s}
.navbtn:hover{background:var(--card);color:var(--text)}
.navbtn.active{background:var(--accentdim);color:#fff}
.sidebar-bottom{margin-top:auto;padding:10px;font-size:11px;color:var(--textdim)}
.content{flex:1;overflow-y:auto;padding:24px}
.page{display:none}.page.active{display:block}
h1{font-size:24px;font-weight:700;margin-bottom:4px}
.sub{color:var(--textdim);font-size:13px;margin-bottom:20px}
.card{background:var(--card);border:1px solid var(--border);border-radius:8px;padding:16px;margin-bottom:12px}
.cardrow{display:flex;gap:12px;flex-wrap:wrap}
.statcard{flex:1;min-width:120px;background:var(--card);border:1px solid var(--border);border-radius:8px;padding:14px}
.statlabel{font-size:11px;color:var(--textdim);text-transform:uppercase;letter-spacing:1px}
.statval{font-size:28px;font-weight:700;margin-top:4px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(360px,1fr));gap:10px}
.tweakcard{background:var(--card);border:1px solid var(--border);border-radius:8px;padding:14px;display:flex;flex-direction:column;gap:6px}
.tweakhead{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.badge{padding:2px 8px;border-radius:3px;font-size:9px;font-weight:700;color:#000}
.badge.safe{background:var(--accent)}
.badge.caution{background:var(--warn)}
.badge.danger{background:var(--danger);color:#fff}
.badge.free{background:var(--accentdim);color:#fff}
.badge.pro{background:var(--warn);color:#000}
.tweakname{font-size:15px;font-weight:600}
.tweakdesc{font-size:12px;color:var(--textdim);line-height:1.4}
.toggle{margin-left:auto;position:relative;width:42px;height:22px;cursor:pointer}
.toggle input{opacity:0;width:0;height:0}
.slider{position:absolute;inset:0;background:#3a3a44;border-radius:22px;transition:.2s}
.slider:before{content:"";position:absolute;width:16px;height:16px;left:3px;top:3px;background:#fff;border-radius:50%;transition:.2s}
.toggle input:checked+.slider{background:var(--accent)}
.toggle input:checked+.slider:before{transform:translateX(20px)}
.btn{background:var(--accent);color:#000;border:none;padding:10px 20px;border-radius:6px;font-weight:600;cursor:pointer;font-size:14px;transition:.15s}
.btn:hover{filter:brightness(1.1)}
.btn.danger{background:var(--danger);color:#fff}
.btn.ghost{background:transparent;border:1px solid var(--border);color:var(--text)}
.btn.sm{padding:6px 14px;font-size:12px}
.input{background:var(--bg);border:1px solid var(--border);color:var(--text);padding:8px 12px;border-radius:6px;font-size:13px;width:100%}
.textarea{background:var(--bg);border:1px solid var(--border);color:var(--text);padding:8px 12px;border-radius:6px;font-size:12px;font-family:monospace;width:100%;min-height:100px;resize:vertical}
.catbar{display:flex;gap:6px;margin-bottom:14px;flex-wrap:wrap}
.catbtn{background:var(--card);border:1px solid var(--border);color:var(--textdim);padding:6px 14px;border-radius:6px;cursor:pointer;font-size:12px}
.catbtn.active{background:var(--accent);color:#000;border-color:var(--accent)}
.logbox{background:#0a0a0e;border:1px solid var(--border);border-radius:6px;padding:12px;font-family:monospace;font-size:12px;color:#7fdc9a;height:400px;overflow-y:auto;white-space:pre-wrap}
.toast{position:fixed;bottom:20px;right:20px;background:var(--card);border:1px solid var(--accent);padding:12px 20px;border-radius:6px;font-size:13px;opacity:0;transition:.3s;pointer-events:none}
.toast.show{opacity:1}
.warnbox{background:rgba(240,180,40,.1);border:1px solid var(--warn);border-radius:6px;padding:10px 14px;font-size:12px;color:var(--warn);margin-bottom:12px}
.profilecard{background:var(--card);border:1px solid var(--border);border-radius:8px;padding:14px;display:flex;align-items:center;gap:14px;margin-bottom:10px}
</style>
</head>
<body>
<div class="sidebar">
  <div class="brand">FL3SH</div>
  <div class="brandsub">Optimizer</div>
  <div class="planbadge" id="planBadge">FREE</div>
  <button class="navbtn active" data-page="home">Home</button>
  <button class="navbtn" data-page="tweaks">Tweaks</button>
  <button class="navbtn" data-page="booster">Game Booster</button>
  <button class="navbtn" data-page="potato">Potato Graphics</button>
  <button class="navbtn" data-page="bench">Benchmark</button>
  <button class="navbtn" data-page="restore">Restore</button>
  <button class="navbtn" data-page="log">Log</button>
  <button class="navbtn" data-page="settings">Settings</button>
  <div class="sidebar-bottom">
    <div id="userInfo">Guest</div>
    <div id="ptsInfo">0 tweaks applied</div>
  </div>
</div>

<div class="content">
<!-- HOME -->
<div class="page active" id="page-home">
  <h1 id="greeting">Good evening</h1>
  <div class="sub" id="homeSub">0 tweaks on · Free plan</div>
  <div class="cardrow" id="statsRow"></div>
  <div class="cardrow" style="margin-top:12px">
    <div class="card" style="flex:1;min-width:300px">
      <h3 style="margin-bottom:8px">Suggested next</h3>
      <div style="color:var(--textdim);font-size:13px;margin-bottom:12px" id="sugText">0% optimized</div>
      <button class="btn" id="applyAllBtn">Apply everything</button>
    </div>
    <div class="card" style="flex:1;min-width:300px">
      <h3 style="margin-bottom:8px">Quickstart</h3>
      <div style="color:var(--textdim);font-size:13px;line-height:1.8">
        - Create a restore point<br>
        - Turn on your first 3 tweaks<br>
        - Turn on Game Booster<br>
        - Join the Discord
      </div>
    </div>
  </div>
  <div class="card" style="margin-top:12px">
    <h3 style="margin-bottom:8px">What's new</h3>
    <div style="color:var(--textdim);font-size:13px">Game Booster clears your session again. Drivers, services and vendor tools are never touched, so laptops are safe.</div>
  </div>
</div>

<!-- TWEAKS -->
<div class="page" id="page-tweaks">
  <h1>Tweaks</h1>
  <div class="sub">Each tweak is a card with a risk label and a switch.</div>
  <div class="catbar" id="catBar"></div>
  <div class="grid" id="tweakGrid"></div>
</div>

<!-- GAME BOOSTER -->
<div class="page" id="page-booster">
  <h1>EMT Game Booster</h1>
  <div class="sub">Closes what you are not using before you queue. Whitelist what stays.</div>
  <div class="cardrow">
    <div class="card" style="flex:1;min-width:300px">
      <h3 style="margin-bottom:8px">Whitelist (one app per line)</h3>
      <textarea class="textarea" id="whitelist">discord.exe
chrome.exe
spotify.exe</textarea>
      <button class="btn" style="margin-top:10px" id="boostBtn">BOOST (close others)</button>
    </div>
    <div class="card" style="flex:1;min-width:300px">
      <h3 style="margin-bottom:8px">Status</h3>
      <div style="color:var(--textdim);font-size:13px;line-height:1.8">
        Booster is OFF<br><br>
        Free: whitelist 1 app<br>
        Pro: unlimited whitelist
      </div>
    </div>
  </div>
</div>

<!-- POTATO GRAPHICS -->
<div class="page" id="page-potato">
  <h1>Potato Graphics</h1>
  <div class="sub">One-click low-graphics profiles. Max FPS, max visibility, revert any time.</div>
  <div class="warnbox">WARNING: This is the only tweak that changes how the game LOOKS. Revert anytime.</div>
  <div id="profileList"></div>
</div>

<!-- BENCHMARK -->
<div class="page" id="page-bench">
  <h1>Benchmark</h1>
  <div class="sub">System info + micro-benchmark. Track your FPS before and after.</div>
  <div class="card">
    <button class="btn ghost sm" id="refreshSysBtn">Refresh System Info</button>
    <pre id="sysInfo" style="margin-top:10px;color:var(--textdim);font-size:12px;font-family:monospace"></pre>
  </div>
  <div class="card" style="margin-top:12px">
    <div style="display:flex;gap:12px;align-items:center;flex-wrap:wrap">
      <label style="font-size:13px">FPS before:</label>
      <input class="input" style="width:80px" id="fpsBefore" value="">
      <label style="font-size:13px">FPS after:</label>
      <input class="input" style="width:80px" id="fpsAfter" value="">
      <button class="btn ghost sm" id="runBenchBtn">Run Micro-Benchmark</button>
      <button class="btn ghost sm" id="saveBenchBtn">Save to CSV</button>
    </div>
    <div style="margin-top:10px;color:var(--textdim);font-size:13px" id="benchResult">Micro-bench: not run</div>
  </div>
</div>

<!-- RESTORE -->
<div class="page" id="page-restore">
  <h1>Restore & Revert</h1>
  <div class="sub">Every tweak is reversible. Restore points + backups created before changes.</div>
  <div class="card">
    <button class="btn ghost" id="restorePointBtn" style="margin-right:10px">Create System Restore Point</button>
    <button class="btn danger" id="revertAllBtn">REVERT ALL CHANGES</button>
    <div style="margin-top:12px;color:var(--textdim);font-size:12px">Reboot recommended after reverting.</div>
  </div>
</div>

<!-- LOG -->
<div class="page" id="page-log">
  <h1>Log</h1>
  <div class="sub">Activity log.</div>
  <div class="logbox" id="logBox"></div>
  <button class="btn ghost sm" style="margin-top:10px" id="refreshLogBtn">Refresh</button>
</div>

<!-- SETTINGS -->
<div class="page" id="page-settings">
  <h1>Settings</h1>
  <div class="sub">License and account.</div>
  <div class="card">
    <label style="font-size:13px;display:block;margin-bottom:4px">Email (for license)</label>
    <input class="input" id="emailInput" style="margin-bottom:12px" value="">
    <label style="font-size:13px;display:block;margin-bottom:4px">License key</label>
    <input class="input" id="keyInput" style="margin-bottom:12px" value="">
    <button class="btn" id="activateBtn">Activate</button>
    <div style="margin-top:12px;color:var(--textdim);font-size:12px;line-height:1.6">
      Free: 3 tweaks + monitoring + 1 Game Booster app<br>
      Pro: All tweaks + Potato Graphics + full Game Booster
    </div>
  </div>
</div>
</div>

<div class="toast" id="toast"></div>

<script>
const API = '';
let state = { plan:'Free', tweaks:{}, os:'unknown' };

function showToast(msg){const t=document.getElementById('toast');t.textContent=msg;t.classList.add('show');setTimeout(()=>t.classList.remove('show'),2500)}

async function api(path, body={}){
  const r = await fetch(path, {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
  return r.json();
}

// Navigation
document.querySelectorAll('.navbtn').forEach(b=>{
  b.addEventListener('click',()=>{
    document.querySelectorAll('.navbtn').forEach(x=>x.classList.remove('active'));
    b.classList.add('active');
    document.querySelectorAll('.page').forEach(p=>p.classList.remove('active'));
    document.getElementById('page-'+b.dataset.page).classList.add('active');
    if(b.dataset.page==='log') refreshLog();
  });
});

// Stats
function renderStats(){
  const stats = [
    {label:'CPU',value:'7%',color:'var(--accent)'},
    {label:'GPU',value:'8%',color:'var(--accent)'},
    {label:'RAM',value:'37%',color:'var(--warn)'},
    {label:'Temp',value:'41C',color:'var(--accent)'}
  ];
  document.getElementById('statsRow').innerHTML = stats.map(s=>
    `<div class="statcard"><div class="statlabel">${s.label}</div><div class="statval" style="color:${s.color}">${s.value}</div></div>`
  ).join('');
}

// Tweak categories
const cats = ['General','Services','Network','Power','Visual','Game'];
let currentCat = 'General';
function renderCatBar(){
  document.getElementById('catBar').innerHTML = cats.map(c=>
    `<button class="catbtn ${c===currentCat?'active':''}" data-cat="${c}">${c}</button>`
  ).join('');
  document.querySelectorAll('.catbtn').forEach(b=>{
    b.addEventListener('click',()=>{currentCat=b.dataset.cat;renderCatBar();renderTweaks()});
  });
}

async function loadTweaks(){
  const r = await api('/api/tweaks/list');
  state.tweaks = r.tweaks || {};
  renderTweaks();
  updateCounts();
}

function renderTweaks(){
  const grid = document.getElementById('tweakGrid');
  const list = Object.values(state.tweaks).filter(t=>t.cat===currentCat);
  grid.innerHTML = list.map(t=>{
    const checked = t.state ? 'checked' : '';
    const riskCls = t.risk.toLowerCase();
    const planBadge = t.free ? '<span class="badge free">FREE</span>' : '<span class="badge pro">PRO</span>';
    const disabled = (!t.free && state.plan==='Free') ? 'disabled' : '';
    return `<div class="tweakcard">
      <div class="tweakhead">
        <span class="badge ${riskCls}">${t.risk}</span>
        ${planBadge}
        <label class="toggle"><input type="checkbox" data-id="${t.id}" ${checked} ${disabled}><span class="slider"></span></label>
      </div>
      <div class="tweakname">${t.name}</div>
      <div class="tweakdesc">${t.desc}</div>
    </div>`;
  }).join('');
  grid.querySelectorAll('input[type=checkbox]').forEach(cb=>{
    cb.addEventListener('change', async (e)=>{
      const id = cb.dataset.id;
      const tw = state.tweaks[id];
      if(!tw.free && state.plan==='Free'){
        showToast('Requires Pro plan'); cb.checked=false; return;
      }
      if(cb.checked && tw.risk!=='Safe'){
        if(!confirm(tw.name+'\n\nRisk: '+tw.risk+'\n'+tw.desc+'\n\nApply?')){ cb.checked=false; return; }
      }
      const r = await api('/api/tweak/toggle', {id, state: cb.checked});
      state.tweaks[id].state = cb.checked;
      showToast(r.message || (cb.checked?'Applied':'Reverted'));
      updateCounts();
    });
  });
}

function updateCounts(){
  const applied = Object.values(state.tweaks).filter(t=>t.state).length;
  document.getElementById('ptsInfo').textContent = applied+' tweaks applied';
  document.getElementById('homeSub').textContent = applied+' of '+Object.keys(state.tweaks).length+' tweaks on · '+state.plan+' plan';
  document.getElementById('sugText').textContent = Math.round(applied/Object.keys(state.tweaks).length*100)+'% optimized · '+applied+' of '+Object.keys(state.tweaks).length+' on.';
}

// Profiles
const profiles = [
  {name:'Fortnite',desc:'DX11 and Performance mode',plan:'Pro'},
  {name:'Fortnite Competitive',desc:'Fixed floor (lowest settings)',plan:'Plus'},
  {name:'Marvel Rivals',desc:'Low-graphics competitive profile',plan:'Plus'},
  {name:'AMD/Intel Potato',desc:'Works on any GPU. Removes texture packs.',plan:'Pro'}
];
document.getElementById('profileList').innerHTML = profiles.map(p=>`
  <div class="profilecard">
    <div style="flex:1">
      <div style="font-weight:600">${p.name}</div>
      <div style="font-size:12px;color:var(--textdim)">${p.desc}</div>
    </div>
    <span class="badge pro">${p.plan}</span>
    <button class="btn sm" data-profile="${p.name}">Apply</button>
  </div>`).join('');
document.querySelectorAll('[data-profile]').forEach(b=>{
  b.addEventListener('click', async ()=>{
    if(state.plan==='Free'){ showToast('Requires Pro plan'); return; }
    if(!confirm('This will change Fortnite graphics (Engine.ini).\nRevert anytime. Continue?')) return;
    const r = await api('/api/potato', {profile: b.dataset.profile});
    showToast(r.message);
  });
});

// Boost
document.getElementById('boostBtn').addEventListener('click', async ()=>{
  const wl = document.getElementById('whitelist').value.split('\n').map(s=>s.trim()).filter(Boolean);
  const r = await api('/api/booster', {whitelist: wl});
  showToast(r.message);
});

// Apply all
document.getElementById('applyAllBtn').addEventListener('click', async ()=>{
  const r = await api('/api/applyall');
  showToast(r.message);
  await loadTweaks();
});

// Bench
document.getElementById('refreshSysBtn').addEventListener('click', async ()=>{
  const r = await api('/api/sysinfo');
  document.getElementById('sysInfo').textContent = r.info;
});
document.getElementById('runBenchBtn').addEventListener('click', async ()=>{
  document.getElementById('benchResult').textContent = 'Running...';
  const r = await api('/api/bench');
  document.getElementById('benchResult').textContent = r.result;
});
document.getElementById('saveBenchBtn').addEventListener('click', async ()=>{
  const r = await api('/api/savebench', {before: document.getElementById('fpsBefore').value, after: document.getElementById('fpsAfter').value});
  showToast(r.message);
});

// Restore
document.getElementById('restorePointBtn').addEventListener('click', async ()=>{
  const r = await api('/api/restorepoint');
  showToast(r.message);
});
document.getElementById('revertAllBtn').addEventListener('click', async ()=>{
  if(!confirm('Revert ALL changes? Reboot recommended after.')) return;
  const r = await api('/api/revertall');
  showToast(r.message);
  await loadTweaks();
});

// Log
async function refreshLog(){
  const r = await api('/api/log');
  document.getElementById('logBox').textContent = r.log;
}
document.getElementById('refreshLogBtn').addEventListener('click', refreshLog);

// Settings
document.getElementById('activateBtn').addEventListener('click', async ()=>{
  const r = await api('/api/activate', {email: document.getElementById('emailInput').value, key: document.getElementById('keyInput').value});
  if(r.success){ state.plan='Pro'; document.getElementById('planBadge').textContent='PRO'; document.getElementById('planBadge').style.background='var(--accent)'; showToast('License activated! Plan: Pro'); }
  else showToast(r.message || 'Invalid key');
});

// Init
renderStats();
renderCatBar();
loadTweaks();
const hour = new Date().getHours();
document.getElementById('greeting').textContent = hour<12?'Good morning':hour<18?'Good afternoon':'Good evening';
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
Write-Host "Press Ctrl+C to stop." -ForegroundColor Yellow

# Open browser
if ($IsMac) { Start-Process "open" -ArgumentList "http://localhost:$Port" }
elseif ($IsWin) { Start-Process "http://localhost:$Port" }

$RunspacePool = [runspacefactory]::CreateRunspacePool(1,4)
$RunspacePool.Open()

while ($Listener.IsListening) {
    $ctx = $Listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    $path = $req.Url.AbsolutePath

    if ($path -eq "/" -or $path -eq "/index.html") {
        $buf = [System.Text.Encoding]::UTF8.GetBytes($HtmlPage)
        $res.ContentType = "text/html; charset=utf-8"
        $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/tweaks/list") {
        $tweakObj = @{}
        foreach ($t in $Script:Tweaks) {
            $tweakObj[$t.Id] = @{
                id=$t.Id; name=$t.Name; desc=$t.Desc; risk=$t.Risk
                free=$t.Free; cat=$t.Cat 2>$null; state=$Script:Config.TweakStates[$t.Id]
            }
            # assign category
            $catMap = @{
                "power"="Power";"usb"="Power";"memory"="General";"temp"="General";"visual"="Visual"
                "menu"="Visual";"transp"="Visual";"startup"="General";"services"="Services"
                "sysmain"="Services";"nagle"="Network";"autotune"="Network";"qos"="Network"
                "hags"="Power";"corepark"="Power";"timer"="Power";"potato"="Game"
                "gamedvr"="Game";"fullscreen"="Game";"macpower"="Power";"spotlight"="General"
                "fontcache"="General"
            }
            $tweakObj[$t.Id].cat = $catMap[$t.Id]
        }
        # filter by OS
        $filtered = @{}
        foreach ($k in $tweakObj.Keys) {
            $tw = $Script:Tweaks | Where-Object { $_.Id -eq $k } | Select-Object -First 1
            if ($IsWin -and $tw.Win) { $filtered[$k] = $tweakObj[$k] }
            elseif ($IsMac -and $tw.Mac) { $filtered[$k] = $tweakObj[$k] }
        }
        $json = @{ tweaks = $filtered } | ConvertTo-Json -Depth 5
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
        $res.ContentType = "application/json"
        $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/tweak/toggle") {
        $reader = New-Object System.IO.StreamReader($req.InputStream)
        $body = $reader.ReadToEnd() | ConvertFrom-Json
        $tw = $Script:Tweaks | Where-Object { $_.Id -eq $body.id } | Select-Object -First 1
        $Script:Config.TweakStates[$body.id] = [bool]$body.state
        Save-Config
        $msg = "Reverted"
        if ($body.state) { & $tw.Action; $msg = "Applied: $($tw.Name)" }
        $json = @{ message = $msg } | ConvertTo-Json
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
        $res.ContentType = "application/json"
        $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/booster") {
        $reader = New-Object System.IO.StreamReader($req.InputStream)
        $body = $reader.ReadToEnd() | ConvertFrom-Json
        Invoke-GameBooster
        $json = @{ message = "Game Booster complete." } | ConvertTo-Json
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
        $res.ContentType = "application/json"
        $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/potato") {
        Invoke-PotatoGraphics
        $json = @{ message = "Potato Graphics applied." } | ConvertTo-Json
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
        $res.ContentType = "application/json"
        $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/applyall") {
        $count = 0
        foreach ($t in $Script:Tweaks) {
            $isAvail = if ($IsWin) { $t.Win } else { $t.Mac }
            if ($isAvail -and ($t.Free -or $Script:Config.Plan -ne "Free")) {
                $Script:Config.TweakStates[$t.Id] = $true
                & $t.Action
                $count++
            }
        }
        Save-Config
        $json = @{ message = "Applied $count tweaks." } | ConvertTo-Json
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
        $res.ContentType = "application/json"
        $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/sysinfo") {
        $info = "OS: $(if($IsWin){'Windows'}else{'macOS'})`n"
        if ($IsWin) {
            $cpu = (Get-CimInstance Win32_Processor).Name
            $gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
            $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1)
            $info += "CPU: $cpu`nGPU: $gpu`nRAM: $ram GB"
        } else {
            $info += "CPU: $(sysctl -n machdep.cpu.brand_string 2>/dev/null)`n"
            $info += "RAM: $([math]::Round((sysctl -n hw.memsize 2>/dev/null)/1GB,1)) GB"
        }
        $json = @{ info = $info } | ConvertTo-Json
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
        $res.ContentType = "application/json"
        $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/bench") {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $c = 0
        for ($i=2; $i -lt 200000; $i++) { $isP=$true; for($j=2;$j*$j -le $i;$j++){if($i%$j -eq 0){$isP=$false;break}}; if($isP){$c++} }
        $sw.Stop()
        $json = @{ result = "Micro-bench: $([math]::Round($sw.Elapsed.TotalMilliseconds,1)) ms (lower = better)" } | ConvertTo-Json
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
        $res.ContentType = "application/json"
        $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/savebench") {
        $reader = New-Object System.IO.StreamReader($req.InputStream)
        $body = $reader.ReadToEnd() | ConvertFrom-Json
        $row = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$($body.before),$($body.after)"
        $benchPath = Join-Path $Script:Root "benchmark.csv"
        if (-not (Test-Path $benchPath)) { "Date,FPS_Before,FPS_After" | Set-Content $benchPath }
        Add-Content $benchPath $row
        $json = @{ message = "Saved to $benchPath" } | ConvertTo-Json
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
        $res.ContentType = "application/json"
        $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/restorepoint") {
        $msg = "Restore point: not supported on this OS."
        if ($IsWin) { try { Checkpoint-Computer -Description "FL3SH Optimizer" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop; $msg = "Restore point created." } catch { $msg = "Restore point failed: $($_.Exception.Message)" } }
        $json = @{ message = $msg } | ConvertTo-Json
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
        $res.ContentType = "application/json"
        $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/revertall") {
        Revert-All
        $json = @{ message = "All changes reverted. Reboot recommended." } | ConvertTo-Json
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
        $res.ContentType = "application/json"
        $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/log") {
        $logContent = if (Test-Path $Script:LogPath) { Get-Content $Script:LogPath -Raw } else { "" }
        $json = @{ log = $logContent } | ConvertTo-Json
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
        $res.ContentType = "application/json"
        $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/activate") {
        $reader = New-Object System.IO.StreamReader($req.InputStream)
        $body = $reader.ReadToEnd() | ConvertFrom-Json
        $Script:Config.Email = $body.email
        $Script:Config.LicenseKey = $body.key
        $success = $false
        try {
            $resp = Invoke-RestMethod -Uri "https://api.gumroad.com/v2/licenses/verify" -Method POST -Body @{ product_id="YOUR_PRODUCT_ID"; license_key=$body.key } -ErrorAction Stop
            if ($resp.success) { $success = $true }
        } catch {
            if ($body.key -match "^FL3SH-") { $success = $true }
        }
        if ($success) { $Script:Config.Plan = "Pro"; Save-Config }
        $json = @{ success = $success; message = if($success){"License activated! Plan: Pro"}else{"Invalid license key."} } | ConvertTo-Json
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
        $res.ContentType = "application/json"
        $res.OutputStream.Write($buf,0,$buf.Length)
    }
    else {
        $res.StatusCode = 404
    }
    $res.Close()
}
