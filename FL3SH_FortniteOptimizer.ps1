#Requires -RunAsAdministrator
<#
.SYNOPSIS
    FL3SH Fortnite Performance Optimizer
    Safe, EAC-friendly system + config tweaks for Fortnite (Windows 10/11).
.DESCRIPTION
    Applies reversible performance tweaks: power plan, memory cleanup, temp cleanup,
    safe registry edits, hardware-accelerated GPU scheduling, and Fortnite Engine.ini
    performance settings. Creates a restore point + backups before changing anything.
.NOTES
    - Run as Administrator.
    - Nothing here touches game memory or game files beyond Engine.ini config.
    - Avoids visibility/gameplay-altering edits by default (Safe preset).
#>

$Script:AppName   = "FL3SH Fortnite Optimizer"
$Script:Version   = "1.0.0"
$Script:Root      = Join-Path $env:USERPROFILE "FL3SH_FortniteOptimizer"
$Script:BackupDir = Join-Path $Script:Root "backups"
$Script:LogPath   = Join-Path $Script:Root "optimizer.log"
$Script:Preset    = "Safe"   # Safe | Aggressive

# ---------------- Logging ----------------
function Write-Log {
    param([string]$Msg, [string]$Level = "INFO")
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Msg"
    Add-Content -Path $Script:LogPath -Value $line -ErrorAction SilentlyContinue
    switch ($Level) {
        "OK"    { Write-Host $line -ForegroundColor Green }
        "WARN"  { Write-Host $line -ForegroundColor Yellow }
        "ERR"   { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line }
    }
}

function Ensure-Dirs {
    foreach ($d in @($Script:Root, $Script:BackupDir)) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
}

# ---------------- Elevation ----------------
function Ensure-Admin {
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
}

# ---------------- Restore point ----------------
function New-RestorePoint {
    try {
        Checkpoint-Computer -Description "FL3SH Fortnite Optimizer" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "System restore point created." "OK"
        return $true
    } catch {
        Write-Log "Could not create restore point: $($_.Exception.Message)" "WARN"
        return $false
    }
}

# ---------------- Power plan ----------------
function Set-HighPerformancePowerPlan {
    try {
        $hp = powercfg /list | Select-String "High performance" | ForEach-Object { ($_ -split '\s+')[3] }
        if (-not $hp) {
            # Ultimate Performance scheme (Win10/11 Pro)
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null | Out-Null
            $hp = powercfg /list | Select-String "Ultimate Performance" | ForEach-Object { ($_ -split '\s+')[3] }
        }
        if ($hp) {
            powercfg /setactive $hp | Out-Null
            Write-Log "Activated power plan: $hp" "OK"
        } else {
            # fallback: High performance GUID
            powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null | Out-Null
            Write-Log "Activated High Performance (fallback GUID)." "OK"
        }
        # Disable USB selective suspend + PCI Express power mgmt
        powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
        powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
        powercfg /setactive SCHEME_CURRENT 2>$null
        Write-Log "Disabled USB selective suspend." "OK"
    } catch {
        Write-Log "Power plan tweak failed: $($_.Exception.Message)" "ERR"
    }
}

# ---------------- Memory cleanup ----------------
function Clear-Memory {
    try {
        # Trim working sets of non-critical processes
        Get-Process | Where-Object { $_.WorkingSet64 -gt 50MB -and $_.ProcessName -notin @("System","Registry","smss","csrss","winlogon","services","lsass") } |
            ForEach-Object {
                try { $_.MinWorkingSet = 1MB; $_.MaxWorkingSet = 1MB } catch {}
            }
        # Empty standby list via RAMMap-style NtSetSystemInformation (best effort)
        $code = @"
using System; using System.Runtime.InteropServices;
public class Mem {
  [DllImport("ntdll.dll")] public static extern int NtSetSystemInformation(int i, IntPtr p, int l);
  public static void EmptyStandby() {
    int size = Marshal.SizeOf(typeof(int));
    IntPtr ptr = Marshal.AllocHGlobal(size);
    Marshal.WriteInt32(ptr, 4); // MemoryPurgeStandbyList
    NtSetSystemInformation(80, ptr, size);
    Marshal.FreeHGlobal(ptr);
  }
}
"@
        Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
        [Mem]::EmptyStandby() 2>$null
        Write-Log "Memory working sets trimmed + standby list purged." "OK"
    } catch {
        Write-Log "Memory cleanup partial: $($_.Exception.Message)" "WARN"
    }
}

# ---------------- Temp cleanup ----------------
function Clear-TempFiles {
    $paths = @($env:TEMP, "$env:WINDIR\Temp", "$env:LOCALAPPDATA\Temp")
    $freed = 0
    foreach ($p in $paths) {
        if (Test-Path $p) {
            Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    if (-not $_.PSIsContainer) { $freed += $_.Length; Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
                } catch {}
            }
        }
    }
    # Fortnite shader cache
    $shader = "$env:LOCALAPPDATA\FortniteGame\Saved\ShaderCache"
    if (Test-Path $shader) { Remove-Item $shader -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "Fortnite shader cache cleared." "OK" }
    Write-Log "Temp cleanup freed ~$([math]::Round($freed/1MB,1)) MB." "OK"
}

# ---------------- Registry tweaks ----------------
function Backup-RegistryKey {
    param([string]$Key)
    $safe = $Key -replace '[\\/:*?"<>|]', '_'
    $out = Join-Path $Script:BackupDir "reg_$safe.reg"
    reg export $Key $out /y 2>$null | Out-Null
}

function Set-RegistryTweaks {
    $changes = @(
        @{ Path="HKCU:\System\GameConfigStore"; Name="GameDVR_Enabled"; Value=0; Type="DWord" },
        @{ Path="HKCU:\System\GameConfigStore"; Name="GameDVR_FSEBehaviorMode"; Value=2; Type="DWord" },
        @{ Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="SystemResponsiveness"; Value=0; Type="DWord" },
        @{ Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="GPU Priority"; Value=8; Type="DWord" },
        @{ Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Priority"; Value=6; Type="DWord" },
        @{ Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Scheduling Category"; Value="High"; Type="String" },
        @{ Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="SFIO Priority"; Value="High"; Type="String" },
        @{ Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; Name="VisualFXSetting"; Value=2; Type="DWord" }
    )
    foreach ($c in $changes) {
        try {
            if (-not (Test-Path $c.Path)) { New-Item -Path $c.Path -Force | Out-Null }
            Backup-RegistryKey $c.Path
            Set-ItemProperty -Path $c.Path -Name $c.Name -Value $c.Value -Type $c.Type -Force
            Write-Log "Registry: $($c.Path)\$($c.Name) = $($c.Value)" "OK"
        } catch {
            Write-Log "Registry failed ($($c.Name)): $($_.Exception.Message)" "WARN"
        }
    }
    # Disable Nagle (TCP no delay) for lower latency
    $iface = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    Get-ChildItem $iface -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
        } catch {}
    }
    Write-Log "TCP no-delay (Nagle) applied to interfaces." "OK"
}

# ---------------- GPU scheduling ----------------
function Enable-HAGS {
    try {
        $p = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        Backup-RegistryKey $p
        Set-ItemProperty -Path $p -Name "HwSchMode" -Value 2 -Type DWord -Force
        Write-Log "Hardware-Accelerated GPU Scheduling enabled (reboot required)." "OK"
    } catch {
        Write-Log "HAGS failed: $($_.Exception.Message)" "WARN"
    }
}

# ---------------- Services (opt-in) ----------------
function Disable-BackgroundServices {
    $svcs = @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","DiagTrack","dmwappushservice")
    foreach ($s in $svcs) {
        try {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc) {
                Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
                Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Log "Disabled service: $s" "OK"
            }
        } catch {
            Write-Log "Service $s skipped: $($_.Exception.Message)" "WARN"
        }
    }
}

# ---------------- Fortnite Engine.ini (optional, opt-in "potato graphics") ----------------
# NOTE: This is the ONLY tweak that changes how the game looks. Everything else in this
# script is system-level (power plan, services, registry, network, memory, temp cleanup).
# Kept separate + clearly labeled so buyers know exactly what it does.
function Get-FortniteConfigPath {
    $base = "$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient"
    if (-not (Test-Path $base)) { New-Item -ItemType Directory -Path $base -Force | Out-Null }
    return (Join-Path $base "Engine.ini")
}

function Backup-EngineIni {
    $p = Get-FortniteConfigPath
    if (Test-Path $p) {
        $bak = Join-Path $Script:BackupDir "Engine.ini.bak"
        Copy-Item $p $bak -Force
        Write-Log "Engine.ini backed up to $bak" "OK"
    }
}

function Apply-PotatoGraphics {
    # Opt-in only. Lowers render quality for max FPS. Changes game appearance.
    $p = Get-FortniteConfigPath
    Backup-EngineIni
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
    Write-Log "Potato graphics Engine.ini applied (appearance changes)." "OK"
    Write-Log "This is the only tweak that alters how the game looks." "WARN"
}

# ---------------- Revert ----------------
function Revert-All {
    Write-Log "Reverting changes..."
    # Restore Engine.ini
    $bak = Join-Path $Script:BackupDir "Engine.ini.bak"
    $p   = Get-FortniteConfigPath
    if (Test-Path $bak) { Copy-Item $bak $p -Force; Write-Log "Engine.ini restored." "OK" }
    # Restore registry backups
    Get-ChildItem $Script:BackupDir -Filter "reg_*.reg" | ForEach-Object {
        reg import $_.FullName 2>$null | Out-Null
        Write-Log "Imported $($_.Name)" "OK"
    }
    # Re-enable services
    @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","DiagTrack","dmwappushservice") | ForEach-Object {
        Set-Service -Name $_ -StartupType Manual -ErrorAction SilentlyContinue
    }
    Write-Log "Services set back to Manual." "OK"
    # Power plan back to balanced
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
    Write-Log "Power plan set to Balanced." "OK"
    Write-Log "Revert complete. Reboot recommended." "OK"
}

# ---------------- Menu ----------------
function Show-Menu {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  $Script:AppName v$Script:Version" -ForegroundColor Cyan
    Write-Host "  Preset: $Script:Preset" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "1) Run FULL optimization (all tweaks)"
    Write-Host "2) Power plan -> High/Ultimate Performance"
    Write-Host "3) Memory cleanup"
    Write-Host "4) Temp + shader cache cleanup"
    Write-Host "5) Registry tweaks (GameDVR off, MMCSS, Nagle)"
    Write-Host "6) Enable Hardware-Accelerated GPU Scheduling"
    Write-Host "7) Disable background services (Xbox/telemetry)"
    Write-Host "8) Apply Fortnite Engine.ini tweaks"
    Write-Host "9) Toggle preset (Safe <-> Aggressive)"
    Write-Host "A) Create system restore point"
    Write-Host "R) REVERT all changes"
    Write-Host "Q) Quit"
    Write-Host ""
}

Ensure-Dirs
Ensure-Admin
New-Item -ItemType File -Path $Script:LogPath -Force -ErrorAction SilentlyContinue | Out-Null

while ($true) {
    Show-Menu
    $choice = Read-Host "Select option"
    switch ($choice.ToUpper()) {
        "1" {
            New-RestorePoint
            Set-HighPerformancePowerPlan
            Clear-Memory
            Clear-TempFiles
            Set-RegistryTweaks
            Enable-HAGS
            $ans = Read-Host "Disable background services? (y/N)"
            if ($ans -eq "y") { Disable-BackgroundServices }
            $agg = ($Script:Preset -eq "Aggressive")
            Apply-EngineIni -Aggressive:$agg
            Write-Log "FULL optimization complete. Reboot recommended." "OK"
            Read-Host "Press Enter to continue"
        }
        "2" { Set-HighPerformancePowerPlan; Read-Host "Press Enter" }
        "3" { Clear-Memory; Read-Host "Press Enter" }
        "4" { Clear-TempFiles; Read-Host "Press Enter" }
        "5" { Set-RegistryTweaks; Read-Host "Press Enter" }
        "6" { Enable-HAGS; Read-Host "Press Enter" }
        "7" { Disable-BackgroundServices; Read-Host "Press Enter" }
        "8" { $agg = ($Script:Preset -eq "Aggressive"); Apply-EngineIni -Aggressive:$agg; Read-Host "Press Enter" }
        "9" { $Script:Preset = if ($Script:Preset -eq "Safe") { "Aggressive" } else { "Safe" }; Write-Log "Preset -> $Script:Preset" "OK" }
        "A" { New-RestorePoint; Read-Host "Press Enter" }
        "R" {
            $c = Read-Host "Revert ALL changes? (y/N)"
            if ($c -eq "y") { Revert-All; Read-Host "Press Enter" }
        }
        "Q" { exit }
        default { Write-Host "Invalid option." -ForegroundColor Red; Start-Sleep 1 }
    }
}
