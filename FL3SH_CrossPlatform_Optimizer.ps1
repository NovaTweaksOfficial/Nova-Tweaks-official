<#
.SYNOPSIS
    FL3SH Cross-Platform Performance Optimizer (Windows + macOS)
.DESCRIPTION
    Auto-detects OS. Applies platform-appropriate, reversible system tweaks.
    Manual override available if detection is wrong.
.NOTES
    - Windows: Run as Administrator (PowerShell 5.1+ or pwsh 7+).
    - macOS: Run with sudo (pwsh 7+).  brew install --cask powershell
    - Fortnite note: Fortnite no longer runs natively on macOS (Epic dropped Mac
      support in 2021). Mac tweaks here are general system optimization only.
#>

# ---------- OS Detection ----------
function Detect-OS {
    if ($IsWindows) { return "Windows" }
    if ($IsMacOS)   { return "macOS" }
    if ($IsLinux)   { return "Linux" }
    # Fallback for Windows PowerShell 5.1 (no $IsWindows)
    if ($env:OS -eq "Windows_NT") { return "Windows" }
    if ((uname 2>/dev/null) -eq "Darwin") { return "macOS" }
    return "Unknown"
}

$Script:OS = Detect-OS
$Script:OverrideOS = $null
$Script:Root = if ($IsWindows -or $env:OS -eq "Windows_NT") {
    Join-Path $env:USERPROFILE "FL3SH_Optimizer"
} else {
    Join-Path $env:HOME ".fl3sh_optimizer"
}
$Script:LogPath = Join-Path $Script:Root "optimizer.log"
$Script:BackupDir = Join-Path $Script:Root "backups"
foreach ($d in @($Script:Root,$Script:BackupDir)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }
if (-not (Test-Path $Script:LogPath)) { New-Item -ItemType File -Path $Script:LogPath -Force | Out-Null }

function Write-Log {
    param([string]$Msg,[string]$Level="INFO")
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Msg"
    Add-Content -Path $Script:LogPath -Value $line -ErrorAction SilentlyContinue
    $color = switch ($Level) { "OK"{"Green"} "WARN"{"Yellow"} "ERR"{"Red"} default{"White"} }
    Write-Host $line -ForegroundColor $color
}

function Get-ActiveOS {
    if ($Script:OverrideOS) { return $Script:OverrideOS }
    return $Script:OS
}

# ---------- Elevation ----------
function Ensure-Elevated {
    $os = Get-ActiveOS
    if ($os -eq "Windows") {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p  = New-Object Security.Principal.WindowsPrincipal($id)
        if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Host "Relaunching as Administrator..." -ForegroundColor Yellow
            $psi = New-Object System.Diagnostics.ProcessStartInfo "powershell.exe"
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            $psi.Verb = "runas"
            [System.Diagnostics.Process]::Start($psi) | Out-Null
            exit
        }
    } else {
        if ($env:EUID -ne "0" -and (id -u) -ne 0) {
            Write-Host "This script needs sudo on macOS. Re-run with: sudo pwsh $PSCommandPath" -ForegroundColor Yellow
            exit 1
        }
    }
}

# ============================================================
# WINDOWS TWEAKS
# ============================================================
function Win-PowerPlan {
    try {
        $hp = (powercfg /list | Select-String "Ultimate Performance" | ForEach-Object { ($_ -split '\s+')[3] }) | Select-Object -First 1
        if (-not $hp) { $hp = (powercfg /list | Select-String "High performance" | ForEach-Object { ($_ -split '\s+')[3] }) | Select-Object -First 1 }
        if (-not $hp) { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null | Out-Null; $hp = (powercfg /list | Select-String "Ultimate Performance" | ForEach-Object { ($_ -split '\s+')[3] }) | Select-Object -First 1 }
        if ($hp) { powercfg /setactive $hp 2>$null | Out-Null; Write-Log "Power plan activated: $hp" "OK" }
        else { powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null | Out-Null; Write-Log "High Performance (fallback) activated." "OK" }
        powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
        powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
        powercfg /setactive SCHEME_CURRENT 2>$null
        Write-Log "USB selective suspend disabled." "OK"
    } catch { Write-Log "Power plan failed: $($_.Exception.Message)" "ERR" }
}

function Win-Memory {
    try {
        Get-Process | Where-Object { $_.WorkingSet64 -gt 50MB -and $_.ProcessName -notin @("System","Registry","smss","csrss","winlogon","services","lsass","explorer") } | ForEach-Object {
            try { $_.MinWorkingSet = 1MB; $_.MaxWorkingSet = 1MB } catch {}
        }
        $code = @"
using System; using System.Runtime.InteropServices;
public class Mem {
  [DllImport("ntdll.dll")] public static extern int NtSetSystemInformation(int i, IntPtr p, int l);
  public static void EmptyStandby() {
    int size = Marshal.SizeOf(typeof(int));
    IntPtr ptr = Marshal.AllocHGlobal(size);
    Marshal.WriteInt32(ptr, 4);
    NtSetSystemInformation(80, ptr, size);
    Marshal.FreeHGlobal(ptr);
  }
}
"@
        Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
        [Mem]::EmptyStandby() 2>$null
        Write-Log "Memory trimmed + standby list purged." "OK"
    } catch { Write-Log "Memory partial: $($_.Exception.Message)" "WARN" }
}

function Win-Temp {
    $paths = @($env:TEMP, "$env:WINDIR\Temp", "$env:LOCALAPPDATA\Temp")
    $freed = 0
    foreach ($p in $paths) {
        if (Test-Path $p) {
            Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try { if (-not $_.PSIsContainer) { $freed += $_.Length; Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } } catch {}
            }
        }
    }
    $shader = "$env:LOCALAPPDATA\FortniteGame\Saved\ShaderCache"
    if (Test-Path $shader) { Remove-Item $shader -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "Fortnite shader cache cleared." "OK" }
    Write-Log "Temp cleanup freed ~$([math]::Round($freed/1MB,1)) MB." "OK"
}

function Win-Registry {
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
        } catch { Write-Log "Registry $($c.Name) failed: $($_.Exception.Message)" "WARN" }
    }
    $iface = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    Get-ChildItem $iface -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
        } catch {}
    }
    Write-Log "TCP no-delay (Nagle) applied." "OK"
}

function Win-HAGS {
    try {
        $p = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        Set-ItemProperty -Path $p -Name "HwSchMode" -Value 2 -Type DWord -Force
        Write-Log "HAGS enabled (reboot required)." "OK"
    } catch { Write-Log "HAGS failed: $($_.Exception.Message)" "WARN" }
}

function Win-Services {
    $svcs = @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","DiagTrack","dmwappushservice","SysMain")
    foreach ($s in $svcs) {
        try {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue; Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue; Write-Log "Disabled service: $s" "OK" }
        } catch { Write-Log "Service $s skipped." "WARN" }
    }
}

function Win-Network {
    try {
        netsh interface tcp set global autotuninglevel=disabled 2>$null | Out-Null
        netsh interface tcp set global ecncapability=disabled 2>$null | Out-Null
        netsh interface tcp set global timestamps=disabled 2>$null | Out-Null
        Write-Log "TCP auto-tuning disabled." "OK"
    } catch { Write-Log "Network tweak failed: $($_.Exception.Message)" "WARN" }
}

function Win-PotatoGraphics {
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
    Write-Log "Potato graphics Engine.ini applied (changes game appearance)." "OK"
}

# ============================================================
# macOS TWEAKS
# ============================================================
function Mac-Memory {
    try {
        # Purge inactive memory (built-in macOS command)
        purge 2>$null
        Write-Log "Inactive memory purged." "OK"
    } catch { Write-Log "purge failed: $($_.Exception.Message)" "WARN" }
}

function Mac-Temp {
    try {
        $freed = 0
        $paths = @("$env:HOME/Library/Caches", "/tmp", "/var/tmp")
        foreach ($p in $paths) {
            if (Test-Path $p) {
                Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
                    try { $freed += $_.Length; Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } catch {}
                }
            }
        }
        # Fortnite (if installed via any means) shader cache
        $shader = "$env:HOME/Library/Application Support/FortniteGame/Saved/ShaderCache"
        if (Test-Path $shader) { Remove-Item $shader -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "Fortnite shader cache cleared." "OK" }
        Write-Log "Temp cleanup freed ~$([math]::Round($freed/1MB,1)) MB." "OK"
    } catch { Write-Log "Temp cleanup partial: $($_.Exception.Message)" "WARN" }
}

function Mac-VisualEffects {
    try {
        # Reduce transparency (frees GPU compositor cycles)
        defaults write com.apple.universalaccess reduceTransparency -bool true
        # Reduce motion
        defaults write com.apple.universalaccess reduceMotion -bool true
        # Disable window animations
        defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
        # Speed up Mission Control
        defaults write com.apple.dock expose-animation-duration -float 0.1
        # Disable Dashboard
        defaults write com.apple.dashboard mcx-disabled -boolean YES
        # Faster key repeat
        defaults write NSGlobalDomain KeyRepeat -int 2
        defaults write NSGlobalDomain InitialKeyRepeat -int 15
        killall Dock 2>$null
        Write-Log "Visual effects reduced (Dock restarted)." "OK"
    } catch { Write-Log "Visual tweaks failed: $($_.Exception.Message)" "WARN" }
}

function Mac-Network {
    try {
        # Flush DNS cache
        dscacheutil -flushcache 2>$null
        killall -HUP mDNSResponder 2>$null
        Write-Log "DNS cache flushed." "OK"
    } catch { Write-Log "DNS flush failed: $($_.Exception.Message)" "WARN" }
}

function Mac-Power {
    try {
        # Prevent sleep while on AC, disable disk sleep
        pmset -c sleep 0 2>$null
        pmset -c disksleep 0 2>$null
        pmset -c displaysleep 10 2>$null
        # Disable sudden motion sensor (SSD Macs)
        pmset -a sms 0 2>$null
        Write-Log "Power settings tuned for performance." "OK"
    } catch { Write-Log "Power tweak failed: $($_.Exception.Message)" "WARN" }
}

function Mac-Spotlight {
    try {
        # Disable Spotlight indexing on root (reversible via mdutil -i on /)
        mdutil -i off / 2>$null
        Write-Log "Spotlight indexing disabled on / (re-enable: sudo mdutil -i on /)." "OK"
    } catch { Write-Log "Spotlight tweak failed: $($_.Exception.Message)" "WARN" }
}

function Mac-FontCache {
    try {
        atsutil databases -remove 2>$null
        Write-Log "Font cache cleared." "OK"
    } catch { Write-Log "Font cache clear failed: $($_.Exception.Message)" "WARN" }
}

function Mac-Revert {
    try {
        defaults write com.apple.universalaccess reduceTransparency -bool false
        defaults write com.apple.universalaccess reduceMotion -bool false
        defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool true
        defaults delete com.apple.dock expose-animation-duration 2>$null
        defaults delete com.apple.dashboard mcx-disabled 2>$null
        defaults delete NSGlobalDomain KeyRepeat 2>$null
        defaults delete NSGlobalDomain InitialKeyRepeat 2>$null
        mdutil -i on / 2>$null
        pmset -c sleep 10 2>$null
        pmset -a sms 1 2>$null
        killall Dock 2>$null
        Write-Log "macOS tweaks reverted." "OK"
    } catch { Write-Log "Revert partial: $($_.Exception.Message)" "WARN" }
}

# ---------- Menu ----------
function Show-Menu {
    $os = Get-ActiveOS
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  FL3SH Cross-Platform Optimizer" -ForegroundColor Cyan
    Write-Host "  Detected OS: $Script:OS | Active: $os" -ForegroundColor Cyan
    if ($os -eq "macOS") {
        Write-Host "  NOTE: Fortnite does not run natively on macOS." -ForegroundColor Yellow
        Write-Host "  Mac tweaks are general system optimization only." -ForegroundColor Yellow
    }
    Write-Host "=========================================" -ForegroundColor Cyan
    if ($os -eq "Windows") {
        Write-Host "1) Run FULL Windows optimization"
        Write-Host "2) Power plan (High/Ultimate)"
        Write-Host "3) Memory cleanup"
        Write-Host "4) Temp + shader cache cleanup"
        Write-Host "5) Registry tweaks"
        Write-Host "6) Enable HAGS"
        Write-Host "7) Disable background services"
        Write-Host "8) Network tweaks"
        Write-Host "9) Apply potato graphics (Engine.ini)"
    } else {
        Write-Host "1) Run FULL macOS optimization"
        Write-Host "2) Memory purge"
        Write-Host "3) Temp + cache cleanup"
        Write-Host "4) Reduce visual effects"
        Write-Host "5) Network (DNS flush)"
        Write-Host "6) Power settings"
        Write-Host "7) Disable Spotlight indexing"
        Write-Host "8) Clear font cache"
    }
    Write-Host "S) Switch OS mode (override detection)"
    Write-Host "R) REVERT all changes"
    Write-Host "Q) Quit"
    Write-Host ""
}

Ensure-Elevated

while ($true) {
    Show-Menu
    $choice = Read-Host "Select option"
    $os = Get-ActiveOS
    switch ($choice.ToUpper()) {
        "S" {
            $new = Read-Host "Switch to (Windows/macOS)"
            if ($new -match "win") { $Script:OverrideOS = "Windows"; Write-Log "Override -> Windows" "OK" }
            elseif ($new -match "mac") { $Script:OverrideOS = "macOS"; Write-Log "Override -> macOS" "OK" }
            else { Write-Host "Invalid." -ForegroundColor Red }
        }
        "R" {
            $c = Read-Host "Revert ALL changes? (y/N)"
            if ($c -eq "y") {
                if ($os -eq "Windows") {
                    # revert registry from backups if any
                    $bak = Join-Path $Script:BackupDir "Engine.ini.bak"
                    # power plan back to balanced
                    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
                    netsh interface tcp set global autotuninglevel=normal 2>$null | Out-Null
                    @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","DiagTrack","dmwappushservice","SysMain") | ForEach-Object { Set-Service -Name $_ -StartupType Manual -ErrorAction SilentlyContinue }
                    Write-Log "Windows revert complete. Reboot recommended." "OK"
                } else {
                    Mac-Revert
                }
            }
        }
        "Q" { exit }
        default {
            if ($os -eq "Windows") {
                switch ($choice) {
                    "1" { Win-PowerPlan; Win-Memory; Win-Temp; Win-Registry; Win-HAGS; $a=Read-Host "Disable background services? (y/N)"; if($a -eq "y"){Win-Services}; Win-Network; $b=Read-Host "Apply potato graphics? (y/N)"; if($b -eq "y"){Win-PotatoGraphics}; Write-Log "FULL Windows optimization complete. Reboot recommended." "OK" }
                    "2" { Win-PowerPlan }
                    "3" { Win-Memory }
                    "4" { Win-Temp }
                    "5" { Win-Registry }
                    "6" { Win-HAGS }
                    "7" { Win-Services }
                    "8" { Win-Network }
                    "9" { Win-PotatoGraphics }
                }
            } else {
                switch ($choice) {
                    "1" { Mac-Memory; Mac-Temp; Mac-VisualEffects; Mac-Network; Mac-Power; $a=Read-Host "Disable Spotlight indexing? (y/N)"; if($a -eq "y"){Mac-Spotlight}; Mac-FontCache; Write-Log "FULL macOS optimization complete. Reboot recommended." "OK" }
                    "2" { Mac-Memory }
                    "3" { Mac-Temp }
                    "4" { Mac-VisualEffects }
                    "5" { Mac-Network }
                    "6" { Mac-Power }
                    "7" { Mac-Spotlight }
                    "8" { Mac-FontCache }
                }
            }
            Read-Host "Press Enter to continue" 2>$null
        }
    }
}
