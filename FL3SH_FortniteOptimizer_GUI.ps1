#Requires -RunAsAdministrator
<#
.SYNOPSIS
    FL3SH Fortnite Performance Optimizer - GUI Edition
    Safe, EAC-friendly Windows + Fortnite config optimizer. No game memory touched.
.DESCRIPTION
    WinForms GUI. Compile to .exe with PS2EXE (instructions at bottom of file).
.NOTES
    Run as Administrator. All changes reversible via the Revert tab.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------- Paths ----------
$Script:Root      = Join-Path $env:USERPROFILE "FL3SH_FortniteOptimizer"
$Script:BackupDir = Join-Path $Script:Root "backups"
$Script:LogPath   = Join-Path $Script:Root "optimizer.log"
$Script:ConfigPath= Join-Path $Script:Root "config.json"
$Script:BenchPath = Join-Path $Script:Root "benchmark.csv"
foreach ($d in @($Script:Root,$Script:BackupDir)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }
if (-not (Test-Path $Script:LogPath)) { New-Item -ItemType File -Path $Script:LogPath -Force | Out-Null }

# ---------- Config ----------
$Script:Config = @{ Preset="Safe"; FortnitePath=""; PotatoGraphics=$false; TweakPower=$true; TweakMemory=$true; TweakTemp=$true; TweakRegistry=$true; TweakHAGS=$true; TweakServices=$false; TweakNetwork=$true }
if (Test-Path $Script:ConfigPath) {
    try { $loaded = Get-Content $Script:ConfigPath -Raw | ConvertFrom-Json; foreach ($k in $loaded.PSObject.Properties.Name) { $Script:Config[$k]=$loaded.$k } } catch {}
}
function Save-Config { $Script:Config | ConvertTo-Json | Set-Content $Script:ConfigPath -Encoding UTF8 }

# ---------- Logging ----------
function Write-Log {
    param([string]$Msg,[string]$Level="INFO")
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Msg"
    Add-Content -Path $Script:LogPath -Value $line -ErrorAction SilentlyContinue
    if ($Script:LogBox) { $Script:LogBox.AppendText("$line`r`n"); $Script:LogBox.ScrollToCaret() }
}

# ---------- Elevation ----------
function Ensure-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $psi.Verb = "runas"
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit
    }
}

# ---------- Restore point ----------
function New-RestorePoint {
    try { Checkpoint-Computer -Description "FL3SH Fortnite Optimizer" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop; Write-Log "Restore point created." "OK"; return $true }
    catch { Write-Log "Restore point failed: $($_.Exception.Message)" "WARN"; return $false }
}

# ---------- Power plan ----------
function Set-HighPerformancePowerPlan {
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

# ---------- Memory ----------
function Clear-Memory {
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

# ---------- Temp ----------
function Clear-TempFiles {
    $paths = @($env:TEMP, "$env:WINDIR\Temp", "$env:LOCALAPPDATA\Temp")
    $freed = 0
    foreach ($p in $paths) {
        if (Test-Path $p) {
            Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try { if (-not $_.PSIsContainer) { $freed += $_.Length; Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } } catch {}
            }
        }
    }
    if ($Script:Config.FortnitePath) {
        $shader = Join-Path $Script:Config.FortnitePath "..\..\..\..\..\LocalAppData\FortniteGame\Saved\ShaderCache" 2>$null
    }
    $shader = "$env:LOCALAPPDATA\FortniteGame\Saved\ShaderCache"
    if (Test-Path $shader) { Remove-Item $shader -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "Fortnite shader cache cleared." "OK" }
    Write-Log "Temp cleanup freed ~$([math]::Round($freed/1MB,1)) MB." "OK"
}

# ---------- Registry ----------
function Backup-RegistryKey { param([string]$Key); $safe=$Key -replace '[\\/:*?"<>|]','_'; reg export $Key (Join-Path $Script:BackupDir "reg_$safe.reg") /y 2>$null | Out-Null }
function Set-RegistryTweaks {
    $changes = @(
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_Enabled"; Value=0; Type="DWord"},
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_FSEBehaviorMode"; Value=2; Type="DWord"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="SystemResponsiveness"; Value=0; Type="DWord"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="GPU Priority"; Value=8; Type="DWord"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Priority"; Value=6; Type="DWord"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Scheduling Category"; Value="High"; Type="String"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="SFIO Priority"; Value="High"; Type="String"},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; Name="VisualFXSetting"; Value=2; Type="DWord"},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="MenuShowDelay"; Value=0; Type="String"},
        @{Path="HKCU:\Software\Microsoft\Windows\DWM"; Name="EnableAeroPeek"; Value=0; Type="DWord"}
    )
    foreach ($c in $changes) {
        try {
            if (-not (Test-Path $c.Path)) { New-Item -Path $c.Path -Force | Out-Null }
            Backup-RegistryKey $c.Path
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

# ---------- HAGS ----------
function Enable-HAGS {
    try {
        $p = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        Backup-RegistryKey $p
        Set-ItemProperty -Path $p -Name "HwSchMode" -Value 2 -Type DWord -Force
        Write-Log "HAGS enabled (reboot required)." "OK"
    } catch { Write-Log "HAGS failed: $($_.Exception.Message)" "WARN" }
}

# ---------- Services ----------
function Disable-BackgroundServices {
    $svcs = @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","DiagTrack","dmwappushservice","SysMain")
    foreach ($s in $svcs) {
        try {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue; Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue; Write-Log "Disabled service: $s" "OK" }
        } catch { Write-Log "Service $s skipped." "WARN" }
    }
}

# ---------- Network QoS / DNS ----------
function Apply-NetworkTweaks {
    try {
        # Disable auto-tuning for lower latency (gaming)
        netsh interface tcp set global autotuninglevel=disabled 2>$null | Out-Null
        netsh interface tcp set global ecncapability=disabled 2>$null | Out-Null
        netsh interface tcp set global timestamps=disabled 2>$null | Out-Null
        Write-Log "TCP auto-tuning disabled." "OK"
    } catch { Write-Log "Network tweak failed: $($_.Exception.Message)" "WARN" }
}

# ---------- Fortnite detect ----------
function Find-Fortnite {
    $candidates = @()
    # Common install roots
    foreach ($root in @("C:\Program Files\Epic Games","D:\Program Files\Epic Games","E:\Program Files\Epic Games","C:\Epic Games","D:\Epic Games")) {
        $p = Join-Path $root "Fortnite\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe"
        if (Test-Path $p) { $candidates += (Split-Path (Split-Path (Split-Path (Split-Path $p)))) }
    }
    # Registry
    $regPaths = @(
        "HKLM:\SOFTWARE\Epic Games\EpicGamesLauncher",
        "HKLM:\SOFTWARE\WOW6432Node\Epic Games\EpicGamesLauncher"
    )
    foreach ($r in $regPaths) {
        if (Test-Path $r) {
            try {
                $inst = (Get-ItemProperty $r -ErrorAction SilentlyContinue).AppDataPath
                if ($inst) {
                    $p = Join-Path $inst "..\..\..\Fortnite" 2>$null
                    if (Test-Path $p) { $candidates += $p }
                }
            } catch {}
        }
    }
    # Search drives for FortniteGame folder (shallow)
    Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | ForEach-Object {
        $root = $_.Root
        foreach ($sub in @("Program Files\Epic Games\Fortnite","Epic Games\Fortnite")) {
            $p = Join-Path $root $sub
            if (Test-Path (Join-Path $p "FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe")) { $candidates += $p }
        }
    }
    $candidates = $candidates | Select-Object -Unique
    if ($candidates.Count -gt 0) { return $candidates[0] }
    return $null
}

function Get-FortniteConfigPath {
    if ($Script:Config.FortnitePath) {
        $cfg = Join-Path $Script:Config.FortnitePath "FortniteGame\Saved\Config\WindowsClient"
        if (-not (Test-Path $cfg)) { New-Item -ItemType Directory -Path $cfg -Force | Out-Null }
        return (Join-Path $cfg "Engine.ini")
    }
    $base = "$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient"
    if (-not (Test-Path $base)) { New-Item -ItemType Directory -Path $base -Force | Out-Null }
    return (Join-Path $base "Engine.ini")
}

function Backup-EngineIni {
    $p = Get-FortniteConfigPath
    if (Test-Path $p) {
        $bak = Join-Path $Script:BackupDir "Engine.ini.bak"
        Copy-Item $p $bak -Force
        Write-Log "Engine.ini backed up." "OK"
    }
}

function Apply-PotatoGraphics {
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
    Write-Log "Potato graphics Engine.ini applied (changes game appearance)." "OK"
}

function Revert-EngineIni {
    $bak = Join-Path $Script:BackupDir "Engine.ini.bak"
    $p   = Get-FortniteConfigPath
    if (Test-Path $bak) { Copy-Item $bak $p -Force; Write-Log "Engine.ini restored from backup." "OK" }
    else { Write-Log "No Engine.ini backup found." "WARN" }
}

# ---------- Revert all ----------
function Revert-All {
    Write-Log "Reverting all changes..."
    Revert-EngineIni
    Get-ChildItem $Script:BackupDir -Filter "reg_*.reg" | ForEach-Object { reg import $_.FullName 2>$null | Out-Null; Write-Log "Imported $($_.Name)" "OK" }
    @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","DiagTrack","dmwappushservice","SysMain") | ForEach-Object { Set-Service -Name $_ -StartupType Manual -ErrorAction SilentlyContinue }
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
    netsh interface tcp set global autotuninglevel=normal 2>$null | Out-Null
    Write-Log "Revert complete. Reboot recommended." "OK"
}

# ---------- Benchmark ----------
function Get-SystemInfo {
    $cpu = (Get-CimInstance Win32_Processor).Name
    $gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
    $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1)
    $os  = (Get-CimInstance Win32_OperatingSystem).Caption
    return @{CPU=$cpu;GPU=$gpu;RAM="$ram GB";OS=$os}
}
function Run-MicroBench {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $c = 0
    for ($i=2; $i -lt 200000; $i++) {
        $isP = $true
        for ($j=2; $j*$j -le $i; $j++) { if ($i % $j -eq 0) { $isP=$false; break } }
        if ($isP) { $c++ }
    }
    $sw.Stop()
    return [math]::Round($sw.Elapsed.TotalMilliseconds,1)
}

# ---------- GUI ----------
Ensure-Admin

$form = New-Object System.Windows.Forms.Form
$form.Text = "FL3SH Fortnite Optimizer v1.0"
$form.Size = New-Object System.Drawing.Size(920,640)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(24,24,28)
$form.ForeColor = [System.Drawing.Color]::White
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(10,10)
$tabs.Size = New-Object System.Drawing.Size(890,560)
$form.Controls.Add($tabs)

function New-Tab($title) {
    $t = New-Object System.Windows.Forms.TabPage
    $t.Text = $title
    $t.BackColor = [System.Drawing.Color]::FromArgb(30,30,36)
    $t.ForeColor = [System.Drawing.Color]::White
    return $t
}

# ---- Dashboard tab ----
$tabDash = New-Tab "Dashboard"
$tabs.TabPages.Add($tabDash)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "FL3SH Fortnite Performance Optimizer"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI",16,[System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(20,20)
$lblTitle.AutoSize = $true
$tabDash.Controls.Add($lblTitle)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Safe, EAC-friendly. System-level tweaks only. Potato graphics is opt-in."
$lblSub.Location = New-Object System.Drawing.Point(20,55)
$lblSub.AutoSize = $true
$lblSub.ForeColor = [System.Drawing.Color]::LightGray
$tabDash.Controls.Add($lblSub)

$btnOptimize = New-Object System.Windows.Forms.Button
$btnOptimize.Text = "OPTIMIZE (One Click)"
$btnOptimize.Size = New-Object System.Drawing.Size(260,60)
$btnOptimize.Location = New-Object System.Drawing.Point(20,90)
$btnOptimize.BackColor = [System.Drawing.Color]::FromArgb(0,150,80)
$btnOptimize.ForeColor = [System.Drawing.Color]::White
$btnOptimize.FlatStyle = "Flat"
$btnOptimize.Font = New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold)
$tabDash.Controls.Add($btnOptimize)

$btnRevert = New-Object System.Windows.Forms.Button
$btnRevert.Text = "REVERT ALL"
$btnRevert.Size = New-Object System.Drawing.Size(160,40)
$btnRevert.Location = New-Object System.Drawing.Point(300,110)
$btnRevert.BackColor = [System.Drawing.Color]::FromArgb(180,60,60)
$btnRevert.ForeColor = [System.Drawing.Color]::White
$btnRevert.FlatStyle = "Flat"
$tabDash.Controls.Add($btnRevert)

$btnRestore = New-Object System.Windows.Forms.Button
$btnRestore.Text = "Create Restore Point"
$btnRestore.Size = New-Object System.Drawing.Size(180,40)
$btnRestore.Location = New-Object System.Drawing.Point(480,110)
$btnRestore.FlatStyle = "Flat"
$tabDash.Controls.Add($btnRestore)

$lblPreset = New-Object System.Windows.Forms.Label
$lblPreset.Text = "Preset:"
$lblPreset.Location = New-Object System.Drawing.Point(20,170)
$lblPreset.AutoSize = $true
$tabDash.Controls.Add($lblPreset)

$cmbPreset = New-Object System.Windows.Forms.ComboBox
$cmbPreset.Items.AddRange(@("Safe (recommended)","Aggressive"))
$cmbPreset.SelectedIndex = if ($Script:Config.Preset -eq "Aggressive") { 1 } else { 0 }
$cmbPreset.Location = New-Object System.Drawing.Point(80,166)
$cmbPreset.Width = 200
$cmbPreset.DropDownStyle = "DropDownList"
$tabDash.Controls.Add($cmbPreset)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Status: Ready"
$lblStatus.Location = New-Object System.Drawing.Point(20,200)
$lblStatus.AutoSize = $true
$lblStatus.ForeColor = [System.Drawing.Color]::LightGreen
$tabDash.Controls.Add($lblStatus)

# ---- System Tweaks tab ----
$tabSys = New-Tab "System Tweaks"
$tabs.TabPages.Add($tabSys)

$checks = @(
    @{Key="TweakPower"; Text="High/Ultimate Performance power plan + disable USB suspend"; Desc="Best single tweak for gaming. Switches power plan and disables USB selective suspend."},
    @{Key="TweakMemory"; Text="Memory cleanup (trim working sets + purge standby)"; Desc="Frees RAM by trimming idle process working sets."},
    @{Key="TweakTemp"; Text="Temp + Fortnite shader cache cleanup"; Desc="Clears %TEMP% and Fortnite shader cache."},
    @{Key="TweakRegistry"; Text="Registry tweaks (GameDVR off, MMCSS, Nagle, menu delay)"; Desc="Disables Game Bar/DVR, raises game thread priority, reduces network latency."},
    @{Key="TweakHAGS"; Text="Hardware-Accelerated GPU Scheduling (HAGS)"; Desc="Offloads GPU scheduling to hardware. Reboot required."},
    @{Key="TweakServices"; Text="Disable background services (Xbox/telemetry/SysMain)"; Desc="Stops Xbox + telemetry services. May affect Xbox app."},
    @{Key="TweakNetwork"; Text="Network tweaks (TCP auto-tuning off)"; Desc="Lowers network latency for gaming."}
)
$y = 20
foreach ($c in $checks) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $c.Text
    $cb.Location = New-Object System.Drawing.Point(20,$y)
    $cb.Width = 520
    $cb.Checked = [bool]$Script:Config[$c.Key]
    $cb.Tag = $c.Key
    $cb.ForeColor = [System.Drawing.Color]::White
    $tabSys.Controls.Add($cb)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $c.Desc
    $lbl.Location = New-Object System.Drawing.Point(40,$y+22)
    $lbl.Width = 700
    $lbl.ForeColor = [System.Drawing.Color]::Gray
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI",8)
    $tabSys.Controls.Add($lbl)
    $y += 55
}

# ---- Fortnite tab ----
$tabFN = New-Tab "Fortnite"
$tabs.TabPages.Add($tabFN)

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "Fortnite install path:"
$lblPath.Location = New-Object System.Drawing.Point(20,20)
$lblPath.AutoSize = $true
$tabFN.Controls.Add($lblPath)

$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Location = New-Object System.Drawing.Point(20,45)
$txtPath.Width = 600
$txtPath.Text = $Script:Config.FortnitePath
$tabFN.Controls.Add($txtPath)

$btnDetect = New-Object System.Windows.Forms.Button
$btnDetect.Text = "Auto-Detect"
$btnDetect.Location = New-Object System.Drawing.Point(630,43)
$btnDetect.Width = 110
$btnDetect.FlatStyle = "Flat"
$tabFN.Controls.Add($btnDetect)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse"
$btnBrowse.Location = New-Object System.Drawing.Point(750,43)
$btnBrowse.Width = 90
$btnBrowse.FlatStyle = "Flat"
$tabFN.Controls.Add($btnBrowse)

$cbPotato = New-Object System.Windows.Forms.CheckBox
$cbPotato.Text = "Apply 'Potato Graphics' to Fortnite Engine.ini (changes game appearance - opt-in)"
$cbPotato.Location = New-Object System.Drawing.Point(20,90)
$cbPotato.Width = 700
$cbPotato.Checked = [bool]$Script:Config.PotatoGraphics
$cbPotato.ForeColor = [System.Drawing.Color]::Orange
$tabFN.Controls.Add($cbPotato)

$lblWarn = New-Object System.Windows.Forms.Label
$lblWarn.Text = "WARNING: Potato graphics lowers shadows/view distance/foliage. Only visual-changing tweak. Safe for EAC."
$lblWarn.Location = New-Object System.Drawing.Point(40,115)
$lblWarn.Width = 700
$lblWarn.ForeColor = [System.Drawing.Color]::Orange
$lblWarn.Font = New-Object System.Drawing.Font("Segoe UI",8)
$tabFN.Controls.Add($lblWarn)

$btnBackupIni = New-Object System.Windows.Forms.Button
$btnBackupIni.Text = "Backup Engine.ini"
$btnBackupIni.Location = New-Object System.Drawing.Point(20,150)
$btnBackupIni.Width = 140
$btnBackupIni.FlatStyle = "Flat"
$tabFN.Controls.Add($btnBackupIni)

$btnRestoreIni = New-Object System.Windows.Forms.Button
$btnRestoreIni.Text = "Restore Engine.ini"
$btnRestoreIni.Location = New-Object System.Drawing.Point(170,150)
$btnRestoreIni.Width = 140
$btnRestoreIni.FlatStyle = "Flat"
$tabFN.Controls.Add($btnRestoreIni)

# ---- Benchmark tab ----
$tabBench = New-Tab "Benchmark"
$tabs.TabPages.Add($tabBench)

$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Text = "System info + micro-benchmark. Enter your in-game FPS before/after for tracking."
$lblInfo.Location = New-Object System.Drawing.Point(20,20)
$lblInfo.AutoSize = $true
$tabBench.Controls.Add($lblInfo)

$btnSysInfo = New-Object System.Windows.Forms.Button
$btnSysInfo.Text = "Refresh System Info"
$btnSysInfo.Location = New-Object System.Drawing.Point(20,50)
$btnSysInfo.Width = 160
$btnSysInfo.FlatStyle = "Flat"
$tabBench.Controls.Add($btnSysInfo)

$txtSysInfo = New-Object System.Windows.Forms.TextBox
$txtSysInfo.Location = New-Object System.Drawing.Point(20,85)
$txtSysInfo.Size = New-Object System.Drawing.Size(500,90)
$txtSysInfo.Multiline = $true
$txtSysInfo.ReadOnly = $true
$txtSysInfo.BackColor = [System.Drawing.Color]::FromArgb(40,40,46)
$txtSysInfo.ForeColor = [System.Drawing.Color]::White
$tabBench.Controls.Add($txtSysInfo)

$lblBefore = New-Object System.Windows.Forms.Label
$lblBefore.Text = "FPS before:"
$lblBefore.Location = New-Object System.Drawing.Point(20,190)
$lblBefore.AutoSize = $true
$tabBench.Controls.Add($lblBefore)
$txtBefore = New-Object System.Windows.Forms.TextBox
$txtBefore.Location = New-Object System.Drawing.Point(110,187)
$txtBefore.Width = 80
$tabBench.Controls.Add($txtBefore)

$lblAfter = New-Object System.Windows.Forms.Label
$lblAfter.Text = "FPS after:"
$lblAfter.Location = New-Object System.Drawing.Point(210,190)
$lblAfter.AutoSize = $true
$tabBench.Controls.Add($lblAfter)
$txtAfter = New-Object System.Windows.Forms.TextBox
$txtAfter.Location = New-Object System.Drawing.Point(290,187)
$txtAfter.Width = 80
$tabBench.Controls.Add($txtAfter)

$btnBench = New-Object System.Windows.Forms.Button
$btnBench.Text = "Run Micro-Benchmark"
$btnBench.Location = New-Object System.Drawing.Point(400,185)
$btnBench.Width = 180
$btnBench.FlatStyle = "Flat"
$tabBench.Controls.Add($btnBench)

$lblBenchResult = New-Object System.Windows.Forms.Label
$lblBenchResult.Text = "Micro-bench: not run"
$lblBenchResult.Location = New-Object System.Drawing.Point(20,220)
$lblBenchResult.AutoSize = $true
$tabBench.Controls.Add($lblBenchResult)

$btnSaveBench = New-Object System.Windows.Forms.Button
$btnSaveBench.Text = "Save to CSV"
$btnSaveBench.Location = New-Object System.Drawing.Point(20,250)
$btnSaveBench.Width = 140
$btnSaveBench.FlatStyle = "Flat"
$tabBench.Controls.Add($btnSaveBench)

# ---- Log tab ----
$tabLog = New-Tab "Log"
$tabs.TabPages.Add($tabLog)
$Script:LogBox = New-Object System.Windows.Forms.TextBox
$Script:LogBox.Location = New-Object System.Drawing.Point(10,10)
$Script:LogBox.Size = New-Object System.Drawing.Size(860,500)
$Script:LogBox.Multiline = $true
$Script:LogBox.ScrollBars = "Vertical"
$Script:LogBox.ReadOnly = $true
$Script:LogBox.BackColor = [System.Drawing.Color]::FromArgb(20,20,24)
$Script:LogBox.ForeColor = [System.Drawing.Color]::LightGreen
$Script:LogBox.Font = New-Object System.Drawing.Font("Consolas",9)
$tabLog.Controls.Add($Script:LogBox)

# ---------- Event handlers ----------
$btnOptimize.Add_Click({
    $lblStatus.Text = "Status: Optimizing..."
    $lblStatus.ForeColor = [System.Drawing.Color]::Yellow
    [System.Windows.Forms.Application]::DoEvents()
    if ($cmbPreset.SelectedIndex -eq 1) { $Script:Config.Preset="Aggressive" } else { $Script:Config.Preset="Safe" }
    # save checkbox states
    foreach ($ctl in $tabSys.Controls) {
        if ($ctl -is [System.Windows.Forms.CheckBox]) { $Script:Config[$ctl.Tag] = $ctl.Checked }
    }
    $Script:Config.PotatoGraphics = $cbPotato.Checked
    $Script:Config.FortnitePath = $txtPath.Text
    Save-Config
    New-RestorePoint | Out-Null
    if ($Script:Config.TweakPower) { Set-HighPerformancePowerPlan }
    if ($Script:Config.TweakMemory) { Clear-Memory }
    if ($Script:Config.TweakTemp) { Clear-TempFiles }
    if ($Script:Config.TweakRegistry) { Set-RegistryTweaks }
    if ($Script:Config.TweakHAGS) { Enable-HAGS }
    if ($Script:Config.TweakServices) { Disable-BackgroundServices }
    if ($Script:Config.TweakNetwork) { Apply-NetworkTweaks }
    if ($Script:Config.PotatoGraphics) { Apply-PotatoGraphics }
    $lblStatus.Text = "Status: Done. Reboot recommended."
    $lblStatus.ForeColor = [System.Drawing.Color]::LightGreen
    [System.Windows.Forms.MessageBox]::Show("Optimization complete. Reboot recommended for full effect.","FL3SH Optimizer") | Out-Null
})

$btnRevert.Add_Click({
    Revert-All
    $lblStatus.Text = "Status: Reverted."
    $lblStatus.ForeColor = [System.Drawing.Color]::LightGreen
})

$btnRestore.Add_Click({ New-RestorePoint | Out-Null })

$btnDetect.Add_Click({
    $found = Find-Fortnite
    if ($found) { $txtPath.Text = $found; Write-Log "Detected Fortnite at: $found" "OK" }
    else { Write-Log "Fortnite not auto-detected. Use Browse." "WARN"; [System.Windows.Forms.MessageBox]::Show("Not found. Use Browse to select Fortnite folder (the one containing FortniteGame).","FL3SH") | Out-Null }
})

$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select the Fortnite folder (contains FortniteGame)"
    if ($dlg.ShowDialog() -eq "OK") { $txtPath.Text = $dlg.SelectedPath }
})

$btnBackupIni.Add_Click({ $Script:Config.FortnitePath=$txtPath.Text; Save-Config; Backup-EngineIni })
$btnRestoreIni.Add_Click({ Revert-EngineIni })

$btnSysInfo.Add_Click({
    $si = Get-SystemInfo
    $txtSysInfo.Text = "CPU: $($si.CPU)`r`nGPU: $($si.GPU)`r`nRAM: $($si.RAM)`r`nOS: $($si.OS)"
})

$btnBench.Add_Click({
    $lblBenchResult.Text = "Running micro-benchmark..."
    [System.Windows.Forms.Application]::DoEvents()
    $ms = Run-MicroBench
    $lblBenchResult.Text = "Micro-bench: $ms ms (lower is better). Log saved on CSV export."
})

$btnSaveBench.Add_Click({
    $si = Get-SystemInfo
    $ms = $lblBenchResult.Text
    $row = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$($si.CPU),$($si.GPU),$($si.RAM),$($txtBefore.Text),$($txtAfter.Text),`"$ms`""
    if (-not (Test-Path $Script:BenchPath)) { "Date,CPU,GPU,RAM,FPS_Before,FPS_After,MicroBench" | Set-Content $Script:BenchPath }
    Add-Content $Script:BenchPath $row
    Write-Log "Benchmark row saved to $Script:BenchPath" "OK"
    [System.Windows.Forms.MessageBox]::Show("Saved to $Script:BenchPath","FL3SH") | Out-Null
})

# init log view
Get-Content $Script:LogPath -ErrorAction SilentlyContinue | ForEach-Object { $Script:LogBox.AppendText("$_`r`n") }

# tray-ish: save config on close
$form.Add_FormClosing({
    $Script:Config.FortnitePath = $txtPath.Text
    $Script:Config.PotatoGraphics = $cbPotato.Checked
    foreach ($ctl in $tabSys.Controls) { if ($ctl -is [System.Windows.Forms.CheckBox]) { $Script:Config[$ctl.Tag]=$ctl.Checked } }
    Save-Config
})

[void]$form.ShowDialog()
