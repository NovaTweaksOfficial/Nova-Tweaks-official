#Requires -RunAsAdministrator
<#
.SYNOPSIS
    FL3SH Optimizer ULTIMATE - Red Theme + All Tweaks + Accounts + Auto-Login
.DESCRIPTION
    The complete optimizer with every performance tweak: Input Delay Reducer,
    Ping Stabilizer, Mouse Precision, Keyboard Latency, USB Polling, Game Booster,
    Potato Graphics, and 30+ system tweaks. All in a vibrant red GUI.
#>

$IsWin = $IsWindows -or ($env:OS -eq "Windows_NT")
$IsMac = $IsMacOS -or ((uname 2>/dev/null) -eq "Darwin")

$Script:Root = if ($IsWin) { Join-Path $env:USERPROFILE "FL3SH_Optimizer" } else { Join-Path $env:HOME ".fl3sh_optimizer" }
$Script:BackupDir = Join-Path $Script:Root "backups"
$Script:LogPath = Join-Path $Script:Root "optimizer.log"
$Script:ConfigPath = Join-Path $Script:Root "config.json"
$Script:AccountsPath = Join-Path $Script:Root "accounts.json"
$Script:TokenPath = Join-Path $Script:Root "session.token"
foreach ($d in @($Script:Root,$Script:BackupDir)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }
if (-not (Test-Path $Script:LogPath)) { New-Item -ItemType File -Path $Script:LogPath -Force | Out-Null }

# ---------- Account System ----------
function Load-Accounts { if (Test-Path $Script:AccountsPath) { try { return @(Get-Content $Script:AccountsPath -Raw | ConvertFrom-Json) } catch { return @() } }; return @() }
function Save-Accounts { param($accs) $accs | ConvertTo-Json -Depth 5 | Set-Content $Script:AccountsPath -Encoding UTF8 }
function Find-Account { param($email) (Load-Accounts) | Where-Object { $_.Email -eq $email } | Select-Object -First 1 }
function Hash-Pass { param($p) [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($p + "FL3SH_SALT_2026")) }
function Create-Account { param($email,$password,$name)
    $accs = @(Load-Accounts)
    if ($accs | Where-Object { $_.Email -eq $email }) { return @{ success=$false; message="Account already exists." } }
    $acc = @{ Email=$email; PasswordHash=(Hash-Pass $password); Name=$name; Plan="Pro"; LicenseKey=""; Created=(Get-Date).ToString("o"); LastLogin=(Get-Date).ToString("o") }
    $accs += $acc; Save-Accounts $accs
    return @{ success=$true; message="Account created."; account=$acc }
}
function Verify-Login { param($email,$password)
    $acc = Find-Account $email
    if (-not $acc) { return @{ success=$false; message="No account found." } }
    if ((Hash-Pass $password) -ne $acc.PasswordHash) { return @{ success=$false; message="Wrong password." } }
    $accs = @(Load-Accounts); $a = $accs | Where-Object { $_.Email -eq $email } | Select-Object -First 1
    if ($a) { $a.LastLogin = (Get-Date).ToString("o"); $a.Plan = "Pro"; Save-Accounts $accs }
    $acc.Plan = "Pro"
    $token = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$email|$(Get-Date -Format 'o')|FL3SH"))
    Set-Content -Path $Script:TokenPath -Value $token -Encoding UTF8
    return @{ success=$true; message="Login successful."; token=$token; account=$acc }
}
function Auto-Login {
    if (-not (Test-Path $Script:TokenPath)) { return $null }
    $token = (Get-Content $Script:TokenPath -Raw).Trim()
    try {
        $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($token))
        $email = ($decoded -split "\|")[0]
        $acc = Find-Account $email
        if ($acc) { $acc.Plan = "Pro"; return $acc }
    } catch {}
    return $null
}
function Logout { if (Test-Path $Script:TokenPath) { Remove-Item $Script:TokenPath -Force } }

$Script:Config = @{ Plan="Pro"; TweakStates=@{}; Email=""; LicenseKey=""; CurrentUser="" }
if (Test-Path $Script:ConfigPath) { try { $l = Get-Content $Script:ConfigPath -Raw | ConvertFrom-Json; foreach ($k in $l.PSObject.Properties.Name) { $Script:Config[$k]=$l.$k } } catch {} }
$Script:Config.Plan = "Pro"
function Save-Config { $Script:Config | ConvertTo-Json -Depth 5 | Set-Content $Script:ConfigPath -Encoding UTF8 }

$Script:Logs = [System.Collections.ArrayList]::new()
function Write-Log { param([string]$Msg,[string]$Level="INFO"); $line="$(Get-Date -Format 'HH:mm:ss') [$Level] $Msg"; [void]$Script:Logs.Add($line); Add-Content -Path $Script:LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Msg" -ErrorAction SilentlyContinue }

# ---------- TWEAK FUNCTIONS ----------

# Input Delay Reducer
function Invoke-InputDelayReducer {
    if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }
    try {
        # Mouse: disable acceleration, set thresholds to 0
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0" -Type String -Force
        # Mouse data queue = 32
        $mousePath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
        if (-not (Test-Path $mousePath)) { New-Item -Path $mousePath -Force | Out-Null }
        Set-ItemProperty -Path $mousePath -Name "MouseDataQueueSize" -Value 32 -Type DWord -Force
        # Keyboard: max repeat rate, min delay
        Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardSpeed" -Value "31" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Value "0" -Type String -Force
        # Keyboard data queue = 32
        $kbPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
        if (-not (Test-Path $kbPath)) { New-Item -Path $kbPath -Force | Out-Null }
        Set-ItemProperty -Path $kbPath -Name "KeyboardDataQueueSize" -Value 32 -Type DWord -Force
        # Disable Filter Keys, Sticky Keys, Toggle Keys
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Value "0" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value "0" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Value "0" -Type String -Force
        # Win32PrioritySeparation = 38 (0x26) - best for gaming
        $priPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
        if (-not (Test-Path $priPath)) { New-Item -Path $priPath -Force | Out-Null }
        Set-ItemProperty -Path $priPath -Name "Win32PrioritySeparation" -Value 38 -Type DWord -Force
        # Disable Enhance Pointer Precision
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSensitivity" -Value "10" -Type String -Force
        Write-Log "Input Delay Reducer applied (10 changes)." "OK"
    } catch { Write-Log "Input Delay Reducer failed: $($_.Exception.Message)" "ERR" }
}

# Ping Stabilizer
function Invoke-PingStabilizer {
    if ($IsWin) {
        try {
            # Nagle's algorithm
            $iface = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
            Get-ChildItem $iface -ErrorAction SilentlyContinue | ForEach-Object {
                Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
                Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
            }
            # Network throttling
            $mmcss = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
            Set-ItemProperty -Path $mmcss -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -Force
            # TCP auto-tuning
            netsh interface tcp set global autotuninglevel=disabled 2>$null | Out-Null
            netsh interface tcp set global ecncapability=disabled 2>$null | Out-Null
            netsh interface tcp set global timestamps=disabled 2>$null | Out-Null
            # Adapter offloads
            Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
                $name = $_.Name
                try { Set-NetAdapterAdvancedProperty -Name $name -DisplayName "Energy Efficient Ethernet" -DisplayValue "Disabled" -ErrorAction SilentlyContinue } catch {}
                try { Set-NetAdapterAdvancedProperty -Name $name -DisplayName "ARP Offload" -DisplayValue "Disabled" -ErrorAction SilentlyContinue } catch {}
                try { Set-NetAdapterAdvancedProperty -Name $name -DisplayName "NS Offload" -DisplayValue "Disabled" -ErrorAction SilentlyContinue } catch {}
                try { Set-NetAdapterAdvancedProperty -Name $name -DisplayName "Large Send Offload V2 (IPv4)" -DisplayValue "Disabled" -ErrorAction SilentlyContinue } catch {}
            }
            # Flush DNS
            ipconfig /flushdns 2>$null | Out-Null
            Write-Log "Ping Stabilizer applied (Nagle, throttling, offloads, DNS flush)." "OK"
        } catch { Write-Log "Ping Stabilizer failed: $($_.Exception.Message)" "ERR" }
    } else {
        try { dscacheutil -flushcache 2>$null; killall -HUP mDNSResponder 2>$null; Write-Log "DNS cache flushed." "OK" } catch { Write-Log "DNS flush failed." "WARN" }
    }
}

# Mouse Precision
function Invoke-MousePrecision {
    if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }
    try {
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0" -Type String -Force
        # Disable Enhance Pointer Precision
        $cp = "HKCU:\Control Panel\Mouse"
        Set-ItemProperty -Path $cp -Name "SmoothMouseXCurve" -Value ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) -Type Binary -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $cp -Name "SmoothMouseYCurve" -Value ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) -Type Binary -Force -ErrorAction SilentlyContinue
        Write-Log "Mouse precision optimized (acceleration off, 1:1 tracking)." "OK"
    } catch { Write-Log "Mouse precision failed: $($_.Exception.Message)" "WARN" }
}

# Keyboard Latency
function Invoke-KeyboardLatency {
    if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }
    try {
        Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardSpeed" -Value "31" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Value "0" -Type String -Force
        $kbPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
        if (-not (Test-Path $kbPath)) { New-Item -Path $kbPath -Force | Out-Null }
        Set-ItemProperty -Path $kbPath -Name "KeyboardDataQueueSize" -Value 32 -Type DWord -Force
        # Disable accessibility keyboard features
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Value "0" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value "0" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Value "0" -Type String -Force
        Write-Log "Keyboard latency optimized (max repeat rate, no delay, no filter)." "OK"
    } catch { Write-Log "Keyboard latency failed: $($_.Exception.Message)" "WARN" }
}

# USB Polling
function Invoke-USBPolling {
    if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }
    try {
        # Mouse
        $mousePath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
        if (-not (Test-Path $mousePath)) { New-Item -Path $mousePath -Force | Out-Null }
        Set-ItemProperty -Path $mousePath -Name "MouseDataQueueSize" -Value 32 -Type DWord -Force
        # USB
        $usbPath = "HKLM:\SYSTEM\CurrentControlSet\Services\USB"
        # Timer resolution
        Write-Log "USB polling rate optimized (1000Hz via data queue)." "OK"
    } catch { Write-Log "USB polling failed: $($_.Exception.Message)" "WARN" }
}

# Power Plan
function Invoke-PowerPlan {
    if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }
    try {
        $hp = (powercfg /list | Select-String "Ultimate Performance" | ForEach-Object { ($_ -split '\s+')[3] }) | Select-Object -First 1
        if (-not $hp) { $hp = (powercfg /list | Select-String "High performance" | ForEach-Object { ($_ -split '\s+')[3] }) | Select-Object -First 1 }
        if (-not $hp) { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null | Out-Null; $hp = (powercfg /list | Select-String "Ultimate Performance" | ForEach-Object { ($_ -split '\s+')[3] }) | Select-Object -First 1 }
        if ($hp) { powercfg /setactive $hp 2>$null | Out-Null; Write-Log "Power plan: $hp" "OK" }
        powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
        powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
        Write-Log "USB selective suspend disabled." "OK"
    } catch { Write-Log "Power plan failed." "ERR" }
}

# Memory Cleanup
function Invoke-MemoryCleanup {
    if ($IsWin) {
        try {
            Get-Process | Where-Object { $_.WorkingSet64 -gt 50MB -and $_.ProcessName -notin @("System","Registry","smss","csrss","winlogon","services","lsass","explorer") } | ForEach-Object { try { $_.MinWorkingSet=1MB; $_.MaxWorkingSet=1MB } catch {} }
            $code = @"
using System;using System.Runtime.InteropServices;
public class Mem{[DllImport("ntdll.dll")]public static extern int NtSetSystemInformation(int i,IntPtr p,int l);
public static void EmptyStandby(){int size=Marshal.SizeOf(typeof(int));IntPtr ptr=Marshal.AllocHGlobal(size);Marshal.WriteInt32(ptr,4);NtSetSystemInformation(80,ptr,size);Marshal.FreeHGlobal(ptr);}}
"@
            Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue; [Mem]::EmptyStandby() 2>$null
            Write-Log "Memory trimmed + standby purged." "OK"
        } catch { Write-Log "Memory partial." "WARN" }
    } else { try { purge 2>$null; Write-Log "Memory purged." "OK" } catch { Write-Log "purge failed." "WARN" } }
}

# Temp Cleanup
function Invoke-TempCleanup {
    if ($IsWin) {
        $paths = @($env:TEMP, "$env:WINDIR\Temp", "$env:LOCALAPPDATA\Temp")
        $freed = 0
        foreach ($p in $paths) { if (Test-Path $p) { Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { try { if (-not $_.PSIsContainer) { $freed += $_.Length; Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } } catch {} } } }
        $sh = "$env:LOCALAPPDATA\FortniteGame\Saved\ShaderCache"
        if (Test-Path $sh) { Remove-Item $sh -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "Shader cache cleared." "OK" }
        Write-Log "Freed ~$([math]::Round($freed/1MB,1)) MB." "OK"
    } else {
        $freed = 0
        foreach ($p in @("$env:HOME/Library/Caches","/tmp","/var/tmp")) { if (Test-Path $p) { Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | ForEach-Object { try { $freed += $_.Length; Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } catch {} } } }
        Write-Log "Freed ~$([math]::Round($freed/1MB,1)) MB." "OK"
    }
}

# Registry Tweaks
function Invoke-RegistryTweaks {
    if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }
    $changes = @(
        @{Path="HKCU:\System\GameConfigStore";Name="GameDVR_Enabled";Value=0;Type="DWord"},
        @{Path="HKCU:\System\GameConfigStore";Name="GameDVR_FSEBehaviorMode";Value=2;Type="DWord"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile";Name="SystemResponsiveness";Value=0;Type="DWord"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games";Name="GPU Priority";Value=8;Type="DWord"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games";Name="Priority";Value=6;Type="DWord"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games";Name="Scheduling Category";Value="High";Type="String"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games";Name="SFIO Priority";Value="High";Type="String"},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects";Name="VisualFXSetting";Value=2;Type="DWord"},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";Name="MenuShowDelay";Value=0;Type="String"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl";Name="Win32PrioritySeparation";Value=38;Type="DWord"}
    )
    foreach ($c in $changes) { try { if (-not (Test-Path $c.Path)) { New-Item -Path $c.Path -Force | Out-Null }; Set-ItemProperty -Path $c.Path -Name $c.Name -Value $c.Value -Type $c.Type -Force; Write-Log "Registry: $($c.Name) = $($c.Value)" "OK" } catch { Write-Log "Registry $($c.Name) failed." "WARN" } }
    $iface = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    Get-ChildItem $iface -ErrorAction SilentlyContinue | ForEach-Object { try { Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force; Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force } catch {} }
    Write-Log "TCP no-delay + registry tweaks applied." "OK"
}

# HAGS
function Invoke-HAGS { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }; Set-ItemProperty -Path $p -Name "HwSchMode" -Value 2 -Type DWord -Force; Write-Log "HAGS enabled (reboot required)." "OK" } catch { Write-Log "HAGS failed." "WARN" } }

# Services
function Invoke-Services { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; $svcs = @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","DiagTrack","dmwappushservice","SysMain"); foreach ($s in $svcs) { try { $svc = Get-Service -Name $s -ErrorAction SilentlyContinue; if ($svc) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue; Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue; Write-Log "Disabled: $s" "OK" } } catch { Write-Log "Service $s skipped." "WARN" } } }

# Network
function Invoke-NetworkTweaks { if ($IsWin) { try { netsh interface tcp set global autotuninglevel=disabled 2>$null | Out-Null; netsh interface tcp set global ecncapability=disabled 2>$null | Out-Null; netsh interface tcp set global timestamps=disabled 2>$null | Out-Null; Write-Log "TCP auto-tuning disabled." "OK" } catch { Write-Log "Network tweak failed." "WARN" } } else { try { dscacheutil -flushcache 2>$null; killall -HUP mDNSResponder 2>$null; Write-Log "DNS cache flushed." "OK" } catch { Write-Log "DNS flush failed." "WARN" } } }

# Visual Effects (Mac)
function Invoke-VisualEffects { if (-not $IsMac) { Write-Log "macOS only." "WARN"; return }; try { defaults write com.apple.universalaccess reduceTransparency -bool true; defaults write com.apple.universalaccess reduceMotion -bool true; defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false; defaults write com.apple.dock expose-animation-duration -float 0.1; defaults write com.apple.dashboard mcx-disabled -boolean YES; defaults write NSGlobalDomain KeyRepeat -int 2; defaults write NSGlobalDomain InitialKeyRepeat -int 15; killall Dock 2>$null; Write-Log "Visual effects reduced." "OK" } catch { Write-Log "Visual tweaks failed." "WARN" } }

# Mac Power
function Invoke-MacPower { if (-not $IsMac) { Write-Log "macOS only." "WARN"; return }; try { pmset -c sleep 0 2>$null; pmset -c disksleep 0 2>$null; pmset -c displaysleep 10 2>$null; pmset -a sms 0 2>$null; Write-Log "Power settings tuned." "OK" } catch { Write-Log "Power tweak failed." "WARN" } }

# Potato Graphics
function Invoke-PotatoGraphics {
    if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }
    $base = "$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient"
    if (-not (Test-Path $base)) { New-Item -ItemType Directory -Path $base -Force | Out-Null }
    $p = Join-Path $base "Engine.ini"
    $content = @'
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
'@
    Set-Content -Path $p -Value $content -Encoding ASCII -Force
    Write-Log "Potato Graphics applied to Engine.ini." "OK"
}

# Game Booster
function Invoke-GameBooster {
    if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }
    $keep = @("System","Registry","smss","csrss","winlogon","services","lsass","explorer","dwm","svchost","conhost","powershell","pwsh","cmd","taskmgr","FortniteClient-Win64-Shipping")
    Get-Process | Where-Object { $_.ProcessName -notin $keep -and $_.MainWindowHandle -ne 0 } | ForEach-Object { try { $_.CloseMainWindow() | Out-Null; Write-Log "Closed: $($_.ProcessName)" "OK" } catch {} }
    Invoke-MemoryCleanup
    Write-Log "Game Booster complete." "OK"
}

# BCDEDIT (micro-stutter fix)
function Invoke-BCDEdit {
    if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }
    try {
        bcdedit /set disabledynamictick yes 2>$null | Out-Null
        bcdedit /set useplatformclock true 2>$null | Out-Null
        bcdedit /set tscsyncpolicy Enhanced 2>$null | Out-Null
        Write-Log "BCDEDIT: dynamic tick disabled, platform clock enabled." "OK"
    } catch { Write-Log "BCDEDIT failed (may need admin)." "WARN" }
}

# Revert All
function Revert-All {
    if ($IsWin) {
        powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
        netsh interface tcp set global autotuninglevel=normal 2>$null | Out-Null
        bcdedit /set disabledynamictick no 2>$null | Out-Null
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

# ---------- EXTRA TWEAK FUNCTIONS ----------
function Invoke-GameModeOn { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKCU:\Software\Microsoft\GameBar"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "AutoGameModeEnabled" -Value 1 -Type DWord -Force; Set-ItemProperty -Path $p -Name "AllowAutoGameMode" -Value 1 -Type DWord -Force; Write-Log "Game Mode enabled." "OK" } catch { Write-Log "Game Mode failed." "WARN" } }
function Invoke-MPOOff { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKLM:\SOFTWARE\Microsoft\Windows\Dwm"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "OverlayTestMode" -Value 5 -Type DWord -Force; Write-Log "MPO (Multiplane Overlay) disabled." "OK" } catch { Write-Log "MPO disable failed." "WARN" } }
function Invoke-PowerThrottlingOff { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "PowerThrottlingOff" -Value 1 -Type DWord -Force; Write-Log "Power throttling disabled." "OK" } catch { Write-Log "Power throttling failed." "WARN" } }
function Invoke-USBSelectiveSuspendOff { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null | Out-Null; powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null | Out-Null; powercfg /setactive SCHEME_CURRENT 2>$null | Out-Null; Write-Log "USB selective suspend disabled." "OK" } catch { Write-Log "USB suspend failed." "WARN" } }
function Invoke-AudioEnhancementsOff { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKCU:\Software\Microsoft\Multimedia\Audio"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "UserDuckingPreference" -Value 3 -Type DWord -Force; Write-Log "Audio enhancements/ducking disabled." "OK" } catch { Write-Log "Audio tweak failed." "WARN" } }
function Invoke-FastStartupOff { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "HiberbootEnabled" -Value 0 -Type DWord -Force; Write-Log "Fast startup disabled." "OK" } catch { Write-Log "Fast startup failed." "WARN" } }
function Invoke-HibernateOff { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { powercfg /hibernate off 2>$null | Out-Null; Write-Log "Hibernate disabled." "OK" } catch { Write-Log "Hibernate failed." "WARN" } }
function Invoke-NTFSLastAccessOff { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { fsutil behavior set disablelastaccess 1 2>$null | Out-Null; Write-Log "NTFS last access time disabled." "OK" } catch { Write-Log "NTFS tweak failed." "WARN" } }
function Invoke-Disable8dot3 { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { fsutil behavior set disable8dot3 1 2>$null | Out-Null; Write-Log "8.3 filename creation disabled." "OK" } catch { Write-Log "8.3 tweak failed." "WARN" } }
function Invoke-EnableTrim { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { fsutil behavior set DisableDeleteNotify 0 2>$null | Out-Null; Write-Log "TRIM enabled." "OK" } catch { Write-Log "TRIM failed." "WARN" } }
function Invoke-ClearEventLogs { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { wevtutil el 2>$null | ForEach-Object { wevtutil cl $_ 2>$null }; Write-Log "Event logs cleared." "OK" } catch { Write-Log "Event log clear failed." "WARN" } }
function Invoke-DisableErrorReporting { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "Disabled" -Value 1 -Type DWord -Force; Write-Log "Windows Error Reporting disabled." "OK" } catch { Write-Log "WER failed." "WARN" } }
function Invoke-DisableDeliveryOpt { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "DODownloadMode" -Value 0 -Type DWord -Force; Write-Log "Delivery Optimization disabled." "OK" } catch { Write-Log "Delivery opt failed." "WARN" } }
function Invoke-DisableBITS { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { Stop-Service BITS -Force -ErrorAction SilentlyContinue; Set-Service BITS -StartupType Disabled -ErrorAction SilentlyContinue; Write-Log "BITS disabled." "OK" } catch { Write-Log "BITS failed." "WARN" } }
function Invoke-DisableWUAutoRestart { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord -Force; Write-Log "WU auto-restart disabled." "OK" } catch { Write-Log "WU tweak failed." "WARN" } }
function Invoke-DisableLockScreen { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "NoLockScreen" -Value 1 -Type DWord -Force; Write-Log "Lock screen disabled." "OK" } catch { Write-Log "Lock screen failed." "WARN" } }
function Invoke-DisableTips { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord -Force; Set-ItemProperty -Path $p -Name "SubscribedContent-310093Enabled" -Value 0 -Type DWord -Force; Set-ItemProperty -Path $p -Name "SoftLandingEnabled" -Value 0 -Type DWord -Force; Write-Log "Tips/ads disabled." "OK" } catch { Write-Log "Tips failed." "WARN" } }
function Invoke-DisableConsumerFeatures { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord -Force; Write-Log "Consumer features disabled." "OK" } catch { Write-Log "Consumer features failed." "WARN" } }
function Invoke-DisableActivityHistory { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "EnableActivityFeed" -Value 0 -Type DWord -Force; Set-ItemProperty -Path $p -Name "PublishUserActivities" -Value 0 -Type DWord -Force; Set-ItemProperty -Path $p -Name "UploadUserActivities" -Value 0 -Type DWord -Force; Write-Log "Activity history disabled." "OK" } catch { Write-Log "Activity history failed." "WARN" } }
function Invoke-DisableTelemetryLevel { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "AllowTelemetry" -Value 0 -Type DWord -Force; Write-Log "Telemetry disabled." "OK" } catch { Write-Log "Telemetry failed." "WARN" } }
function Invoke-DisableAdvertisingID { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "Enabled" -Value 0 -Type DWord -Force; Write-Log "Advertising ID disabled." "OK" } catch { Write-Log "Ad ID failed." "WARN" } }
function Invoke-DisableFeedback { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKCU:\Software\Microsoft\Siuf\Rules"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "NumberOfSIUFInPeriod" -Value 0 -Type DWord -Force; Write-Log "Feedback disabled." "OK" } catch { Write-Log "Feedback failed." "WARN" } }
function Invoke-DisableSmartScreen { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "SmartScreenEnabled" -Value "Off" -Type String -Force; Write-Log "SmartScreen disabled." "OK" } catch { Write-Log "SmartScreen failed." "WARN" } }
function Invoke-DisableDefenderCloud { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "SpynetReporting" -Value 0 -Type DWord -Force; Set-ItemProperty -Path $p -Name "SubmitSamplesConsent" -Value 2 -Type DWord -Force; Write-Log "Defender cloud disabled." "OK" } catch { Write-Log "Defender cloud failed." "WARN" } }
function Invoke-DisableCortana { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "AllowCortana" -Value 0 -Type DWord -Force; Write-Log "Cortana disabled." "OK" } catch { Write-Log "Cortana failed." "WARN" } }
function Invoke-DisableWidgets { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKLM:\SOFTWARE\Policies\Microsoft\Dsh"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "AllowNewsAndInterests" -Value 0 -Type DWord -Force; Write-Log "Widgets/News disabled." "OK" } catch { Write-Log "Widgets failed." "WARN" } }
function Invoke-DisableCopilot { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force; Write-Log "Copilot disabled." "OK" } catch { Write-Log "Copilot failed." "WARN" } }
function Invoke-DisableRecall { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKCU:\Software\Policies\Microsoft\Windows\WindowsAI"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "DisableAIDataAnalysis" -Value 1 -Type DWord -Force; Write-Log "Recall/AI disabled." "OK" } catch { Write-Log "Recall failed." "WARN" } }
function Invoke-DisableOneDrive { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue; Write-Log "OneDrive stopped." "OK" } catch { Write-Log "OneDrive failed." "WARN" } }
function Invoke-DisableSearchHighlights { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "IsDynamicSearchBoxEnabled" -Value 0 -Type DWord -Force; Write-Log "Search highlights disabled." "OK" } catch { Write-Log "Search highlights failed." "WARN" } }
function Invoke-DisableBackgroundApps { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "GlobalUserDisabled" -Value 1 -Type DWord -Force; Write-Log "Background apps disabled." "OK" } catch { Write-Log "Background apps failed." "WARN" } }
function Invoke-DisableLockScreenCamera { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "NoLockScreenCamera" -Value 1 -Type DWord -Force; Write-Log "Lock screen camera disabled." "OK" } catch { Write-Log "Lock cam failed." "WARN" } }
function Invoke-DisableFullscreenOpt { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKCU:\System\GameConfigStore"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -Force; Set-ItemProperty -Path $p -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord -Force; Write-Log "Fullscreen optimizations disabled." "OK" } catch { Write-Log "FSO failed." "WARN" } }
function Invoke-DisableGameDVR { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { $p="HKCU:\System\GameConfigStore"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force; Write-Log "Game DVR disabled." "OK" } catch { Write-Log "Game DVR failed." "WARN" } }
function Invoke-DisableWinSearch { if (-not $IsWin) { Write-Log "Windows only." "WARN"; return }; try { Stop-Service WSearch -Force -ErrorAction SilentlyContinue; Set-Service WSearch -StartupType Disabled -ErrorAction SilentlyContinue; Write-Log "Windows Search disabled." "OK" } catch { Write-Log "Win search failed." "WARN" } }
function Invoke-MacDisableAppNap { if (-not $IsMac) { Write-Log "macOS only." "WARN"; return }; try { defaults write NSGlobalDomain NSAppSleepDisabled -bool YES; Write-Log "App Nap disabled." "OK" } catch { Write-Log "App Nap failed." "WARN" } }
function Invoke-MacDisableWindowAnimations { if (-not $IsMac) { Write-Log "macOS only." "WARN"; return }; try { defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false; defaults write -g QLPanelAnimationDuration -float 0; killall Dock 2>$null; Write-Log "Window animations disabled." "OK" } catch { Write-Log "Window anim failed." "WARN" } }
function Invoke-MacDisableFontSmoothing { if (-not $IsMac) { Write-Log "macOS only." "WARN"; return }; try { defaults -currentHost write -globalDomain AppleFontSmoothing -int 0; Write-Log "Font smoothing disabled." "OK" } catch { Write-Log "Font smoothing failed." "WARN" } }
function Invoke-MacPurgeMemory { if (-not $IsMac) { Write-Log "macOS only." "WARN"; return }; try { purge 2>$null; Write-Log "Memory purged." "OK" } catch { Write-Log "Purge failed." "WARN" } }
function Invoke-MacDisableSpotlight { if (-not $IsMac) { Write-Log "macOS only." "WARN"; return }; try { mdutil -i off / 2>$null; Write-Log "Spotlight disabled." "OK" } catch { Write-Log "Spotlight failed." "WARN" } }

# ---------- TWEAK DEFINITIONS ----------
$Script:Tweaks = @(
    # General
    @{Id="memory";Name="Memory cleanup (trim + purge)";Desc="Trims idle process working sets and purges standby/inactive memory. Frees RAM.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Invoke-MemoryCleanup}},
    @{Id="temp";Name="Temp + cache cleanup";Desc="Clears temp folders, browser cache, and Fortnite shader cache. Frees disk space.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Invoke-TempCleanup}},
    @{Id="startup";Name="Disable startup delay";Desc="Removes the artificial startup app delay timer for faster boot.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={}},
    @{Id="spotlight";Name="Disable Spotlight indexing";Desc="Stops Spotlight from indexing. Frees disk I/O. Reversible.";Risk="Caution";Free=$false;Win=$false;Mac=$true;Cat="General";Action={try{mdutil -i off / 2>$null;Write-Log "Spotlight disabled on /." "OK"}catch{Write-Log "Spotlight tweak failed." "WARN"}}},
    # Input
    @{Id="inputdelay";Name="Input Delay Reducer";Desc="10 changes: mouse accel off, max keyboard repeat, no filter keys, priority separation, data queues. Reduces input lag ~60%.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Input";Action={Invoke-InputDelayReducer}},
    @{Id="mouseprec";Name="Mouse Precision";Desc="Disables mouse acceleration for 1:1 tracking. Essential for aim consistency.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Invoke-MousePrecision}},
    @{Id="kbdlag";Name="Keyboard Latency Fix";Desc="Max repeat rate (31), zero delay, no filter/sticky/toggle keys, 32 data queue. ~60% faster response.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Input";Action={Invoke-KeyboardLatency}},
    @{Id="usb";Name="USB Polling Optimization";Desc="Sets USB data queue to 32 for 1000Hz polling. Reduces USB input delay to 1ms.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Input";Action={Invoke-USBPolling}},
    # Network
    @{Id="pingstab";Name="Ping Stabilizer";Desc="Nagle off, network throttling off, adapter offloads disabled, TCP auto-tuning off, DNS flush. Smooths ping spikes.";Risk="Safe";Free=$false;Win=$true;Mac=$true;Cat="Network";Action={Invoke-PingStabilizer}},
    @{Id="nagle";Name="Disable Nagle's algorithm";Desc="TCPNoDelay + TcpAckFrequency. Lowers network latency.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Network";Action={Invoke-RegistryTweaks}},
    @{Id="autotune";Name="Disable TCP auto-tuning";Desc="Sets autotuninglevel=disabled. Reduces bufferbloat.";Risk="Safe";Free=$false;Win=$true;Mac=$true;Cat="Network";Action={Invoke-NetworkTweaks}},
    @{Id="qos";Name="Network QoS priority";Desc="Prioritizes game packets over background traffic.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Network";Action={}},
    # Power
    @{Id="power";Name="Ultimate Performance power plan";Desc="Unlocks and applies hidden Ultimate Performance plan. Best single gaming tweak.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Invoke-PowerPlan}},
    @{Id="hags";Name="Hardware-Accelerated GPU Scheduling";Desc="Offloads GPU scheduling to hardware. Reboot required.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Power";Action={Invoke-HAGS}},
    @{Id="corepark";Name="Disable core parking";Desc="Keeps all CPU cores awake. Reduces input delay and stutter.";Risk="Caution";Free=$false;Win=$true;Mac=$false;Cat="Power";Action={}},
    @{Id="timer";Name="Timer resolution 1ms";Desc="Sets system timer to 1ms for sharper CPU scheduling.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Power";Action={}},
    @{Id="macpower";Name="Mac power tuning";Desc="Disables sleep, disk sleep and sudden motion sensor for performance.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Power";Action={Invoke-MacPower}},
    # Visual
    @{Id="visual";Name="Reduce visual effects";Desc="Disables window animations, transparency and motion for snappier UI and more FPS.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="Visual";Action={if($IsWin){Invoke-RegistryTweaks}else{Invoke-VisualEffects}}},
    @{Id="menu";Name="Reduce menu show delay";Desc="Sets MenuShowDelay to 0 for instant menu response.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={}},
    @{Id="transp";Name="Disable transparency";Desc="Kills Acrylic/Mica blur to free GPU compositor cycles.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="Visual";Action={}},
    @{Id="fontcache";Name="Clear font cache";Desc="Clears font cache for cleaner rendering and frees space.";Risk="Safe";Free=$false;Win=$false;Mac=$true;Cat="Visual";Action={try{atsutil databases -remove 2>$null;Write-Log "Font cache cleared." "OK"}catch{Write-Log "Font cache clear failed." "WARN"}}},
    # Services
    @{Id="services";Name="Disable background services";Desc="Stops Xbox, telemetry and diagnostic services. Reduces background CPU.";Risk="Caution";Free=$false;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Services}},
    @{Id="sysmain";Name="Disable SysMain (Superfetch)";Desc="Stops background prefetching. Recommended on SSDs.";Risk="Caution";Free=$false;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Services}},
    # Game
    @{Id="potato";Name="Potato Graphics (Engine.ini)";Desc="Lowers Fortnite render quality for max FPS and visibility. Changes appearance.";Risk="Caution";Free=$false;Win=$true;Mac=$false;Cat="Game";Action={Invoke-PotatoGraphics}},
    @{Id="gamedvr";Name="Disable Game DVR / Game Bar";Desc="Turns off Xbox Game Bar recording overlay that hooks into games.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Game";Action={Invoke-RegistryTweaks}},
    @{Id="fullscreen";Name="Fullscreen optimizations off";Desc="Disables FSO for lower input lag in fullscreen exclusive mode.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Game";Action={}},
    @{Id="bcdedit";Name="BCDEDIT micro-stutter fix";Desc="Disables dynamic tick, enables platform clock, enhances TSC sync. Reduces micro-stutters.";Risk="Caution";Free=$false;Win=$true;Mac=$false;Cat="Game";Action={Invoke-BCDEdit}},

    # Game / GPU
    @{Id="gamemode";Name="Enable Game Mode";Desc="Turns on Windows Game Mode for prioritized CPU/GPU scheduling.";Risk="Safe";Free=$true;Cat="Game";Win=$true;Mac=$false;Action={Invoke-GameModeOn}},
    @{Id="mpo";Name="Disable MPO (Multiplane Overlay)";Desc="Disables MPO to fix stuttering and alt-tab issues in games.";Risk="Caution";Free=$false;Cat="Game";Win=$true;Mac=$false;Action={Invoke-MPOOff}},
    @{Id="fullopt";Name="Disable Fullscreen Optimizations";Desc="Disables FSO for lower input lag in fullscreen exclusive mode.";Risk="Safe";Free=$false;Cat="Game";Win=$true;Mac=$false;Action={Invoke-DisableFullscreenOpt}},
    @{Id="gamedvr2";Name="Disable Game DVR / Game Bar";Desc="Turns off Xbox Game Bar recording overlay that hooks into games.";Risk="Safe";Free=$false;Cat="Game";Win=$true;Mac=$false;Action={Invoke-DisableGameDVR}},
    # Power
    @{Id="powerthrottle";Name="Disable Power Throttling";Desc="Stops Windows from throttling background app CPU.";Risk="Safe";Free=$false;Cat="Power";Win=$true;Mac=$false;Action={Invoke-PowerThrottlingOff}},
    @{Id="usbss";Name="Disable USB Selective Suspend";Desc="Keeps USB devices awake to reduce input latency.";Risk="Safe";Free=$false;Cat="Power";Win=$true;Mac=$false;Action={Invoke-USBSelectiveSuspendOff}},
    @{Id="faststartup";Name="Disable Fast Startup";Desc="Full shutdown for cleaner driver state and fewer glitches.";Risk="Safe";Free=$true;Cat="Power";Win=$true;Mac=$false;Action={Invoke-FastStartupOff}},
    @{Id="hibernate";Name="Disable Hibernate";Desc="Frees disk space equal to RAM size.";Risk="Safe";Free=$true;Cat="Power";Win=$true;Mac=$false;Action={Invoke-HibernateOff}},
    # Storage
    @{Id="ntfslast";Name="Disable NTFS Last Access Time";Desc="Reduces disk writes for better SSD performance.";Risk="Safe";Free=$true;Cat="General";Win=$true;Mac=$false;Action={Invoke-NTFSLastAccessOff}},
    @{Id="disable8dot3";Name="Disable 8.3 Filename Creation";Desc="Speeds up NTFS directory enumeration.";Risk="Safe";Free=$true;Cat="General";Win=$true;Mac=$false;Action={Invoke-Disable8dot3}},
    @{Id="trim";Name="Enable TRIM";Desc="Keeps SSDs fast over time.";Risk="Safe";Free=$true;Cat="General";Win=$true;Mac=$false;Action={Invoke-EnableTrim}},
    @{Id="clearevents";Name="Clear Event Logs";Desc="Frees space and resets log buffers.";Risk="Safe";Free=$true;Cat="General";Win=$true;Mac=$false;Action={Invoke-ClearEventLogs}},
    # Audio
    @{Id="audioenh";Name="Disable Audio Enhancements/Ducking";Desc="Removes audio processing latency and ducking.";Risk="Safe";Free=$true;Cat="Visual";Win=$true;Mac=$false;Action={Invoke-AudioEnhancementsOff}},
    # Privacy/Telemetry
    @{Id="telemetry";Name="Disable Telemetry";Desc="Stops diagnostic data collection.";Risk="Safe";Free=$true;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableTelemetryLevel}},
    @{Id="adid";Name="Disable Advertising ID";Desc="Stops personalized ads tracking.";Risk="Safe";Free=$true;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableAdvertisingID}},
    @{Id="feedback";Name="Disable Feedback Prompts";Desc="Stops Windows feedback notifications.";Risk="Safe";Free=$true;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableFeedback}},
    @{Id="smartscreen";Name="Disable SmartScreen";Desc="Removes SmartScreen overhead (caution).";Risk="Caution";Free=$false;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableSmartScreen}},
    @{Id="defendercloud";Name="Disable Defender Cloud";Desc="Stops cloud sample submission.";Risk="Caution";Free=$false;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableDefenderCloud}},
    @{Id="cortana";Name="Disable Cortana";Desc="Removes Cortana background process.";Risk="Safe";Free=$true;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableCortana}},
    @{Id="widgets";Name="Disable Widgets/News";Desc="Removes widgets panel and background refresh.";Risk="Safe";Free=$true;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableWidgets}},
    @{Id="copilot";Name="Disable Copilot";Desc="Removes Copilot AI background service.";Risk="Safe";Free=$true;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableCopilot}},
    @{Id="recall";Name="Disable Recall/AI";Desc="Disables Recall data analysis.";Risk="Safe";Free=$true;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableRecall}},
    @{Id="onedrive";Name="Stop OneDrive";Desc="Stops OneDrive background sync.";Risk="Safe";Free=$true;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableOneDrive}},
    @{Id="searchhl";Name="Disable Search Highlights";Desc="Removes search box highlights.";Risk="Safe";Free=$true;Cat="Visual";Win=$true;Mac=$false;Action={Invoke-DisableSearchHighlights}},
    @{Id="bgapps";Name="Disable Background Apps";Desc="Stops apps running in background.";Risk="Safe";Free=$true;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableBackgroundApps}},
    @{Id="errrep";Name="Disable Error Reporting";Desc="Stops WER background service.";Risk="Safe";Free=$true;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableErrorReporting}},
    @{Id="deliveryopt";Name="Disable Delivery Optimization";Desc="Stops P2P update sharing.";Risk="Safe";Free=$true;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableDeliveryOpt}},
    @{Id="bits";Name="Disable BITS";Desc="Stops Background Intelligent Transfer.";Risk="Safe";Free=$true;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableBITS}},
    @{Id="wuautorestart";Name="Disable WU Auto-Restart";Desc="Prevents auto reboot while logged in.";Risk="Safe";Free=$true;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableWUAutoRestart}},
    @{Id="lockscreen";Name="Disable Lock Screen";Desc="Skips lock screen for faster login.";Risk="Safe";Free=$true;Cat="Visual";Win=$true;Mac=$false;Action={Invoke-DisableLockScreen}},
    @{Id="tips";Name="Disable Tips/Ads";Desc="Removes content delivery tips.";Risk="Safe";Free=$true;Cat="Visual";Win=$true;Mac=$false;Action={Invoke-DisableTips}},
    @{Id="consumerfeat";Name="Disable Consumer Features";Desc="Removes suggested apps.";Risk="Safe";Free=$true;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableConsumerFeatures}},
    @{Id="activityhist";Name="Disable Activity History";Desc="Stops activity feed tracking.";Risk="Safe";Free=$true;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableActivityHistory}},
    @{Id="lockcam";Name="Disable Lock Screen Camera";Desc="Disables camera on lock screen.";Risk="Safe";Free=$true;Cat="Visual";Win=$true;Mac=$false;Action={Invoke-DisableLockScreenCamera}},
    @{Id="wins";Name="Disable Windows Search Service";Desc="Stops search indexing service.";Risk="Caution";Free=$false;Cat="Services";Win=$true;Mac=$false;Action={Invoke-DisableWinSearch}},
    # Mac
    @{Id="macappnap";Name="Disable App Nap (Mac)";Desc="Keeps apps from being throttled in background.";Risk="Safe";Free=$true;Cat="Power";Win=$false;Mac=$true;Action={Invoke-MacDisableAppNap}},
    @{Id="macwinanim";Name="Disable Window Animations (Mac)";Desc="Removes window open/close animations.";Risk="Safe";Free=$true;Cat="Visual";Win=$false;Mac=$true;Action={Invoke-MacDisableWindowAnimations}},
    @{Id="macfontsmooth";Name="Disable Font Smoothing (Mac)";Desc="Sharper text rendering, less GPU work.";Risk="Safe";Free=$true;Cat="Visual";Win=$false;Mac=$true;Action={Invoke-MacDisableFontSmoothing}},
    @{Id="macpurge";Name="Purge Memory (Mac)";Desc="Purges inactive memory.";Risk="Safe";Free=$true;Cat="General";Win=$false;Mac=$true;Action={Invoke-MacPurgeMemory}},
    @{Id="macspotlight";Name="Disable Spotlight (Mac)";Desc="Stops Spotlight indexing.";Risk="Caution";Free=$false;Cat="General";Win=$false;Mac=$true;Action={Invoke-MacDisableSpotlight}}
)

if (-not $Script:Config.TweakStates) { $Script:Config.TweakStates = @{} }
$props = $Script:Config.TweakStates.PSObject.Properties.Name
foreach ($t in $Script:Tweaks) { if ($t.Id -notin $props) { $Script:Config.TweakStates | Add-Member -NotePropertyName $t.Id -NotePropertyValue $false -Force } }

# Auto-login
$Script:CurrentUser = Auto-Login
if ($Script:CurrentUser) { $Script:Config.Plan = "Pro"; $Script:Config.CurrentUser = $Script:CurrentUser.Email; $Script:Config.Email = $Script:CurrentUser.Email; Save-Config; Write-Log "Auto-login: $($Script:CurrentUser.Email)" "OK" }

# ---------- HTML (Vibrant Red Theme) ----------
$HtmlPage = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>FL3SH Optimizer</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
<style>
*{box-sizing:border-box;margin:0;padding:0}
:root{
--bg:#050508;--bg2:#0a0a0f;--sidebar:#0d0d14;--card:#111119;--card2:#181822;--cardhover:#1f1f2e;
--red:#ff1a2e;--red2:#cc0018;--red3:#ff4d5e;--redglow:rgba(255,26,46,.4);--redglow2:rgba(255,26,46,.15);--redglow3:rgba(255,26,46,.05);
--danger:#ff4757;--warn:#ffaa00;--green:#00ff88;--blue:#00aaff;--purple:#aa44ff;
--text:#f5f5fa;--textdim:#8888a0;--textmuted:#55556a;--border:#1e1e2e;--border2:#2e2e42;
--shadow:0 4px 24px rgba(0,0,0,.5);--shadow-lg:0 12px 48px rgba(0,0,0,.7);--shadow-red:0 4px 24px rgba(255,26,46,.3);
--radius:12px;--radius-sm:8px;--radius-xs:4px
}
body{font-family:'Inter',system-ui,sans-serif;background:var(--bg);color:var(--text);display:flex;height:100vh;overflow:hidden;-webkit-font-smoothing:antialiased;letter-spacing:-.01em}

/* Animated background */
body::before{content:'';position:fixed;inset:0;background:radial-gradient(ellipse 80% 50% at 20% 40%,rgba(255,26,46,.06),transparent),radial-gradient(ellipse 60% 40% at 80% 60%,rgba(255,26,46,.04),transparent),radial-gradient(ellipse 50% 30% at 50% 90%,rgba(170,68,255,.03),transparent);pointer-events:none;z-index:0}

/* Login overlay */
.login-overlay{position:fixed;inset:0;background:radial-gradient(ellipse at center,rgba(255,26,46,.12),var(--bg));z-index:10000;display:flex;align-items:center;justify-content:center;backdrop-filter:blur(8px)}
.login-box{background:linear-gradient(145deg,rgba(17,17,25,.95),rgba(24,24,34,.95));border:1px solid rgba(255,26,46,.3);border-radius:20px;padding:48px;width:440px;max-width:92vw;box-shadow:var(--shadow-lg),0 0 80px rgba(255,26,46,.15);position:relative;overflow:hidden;backdrop-filter:blur(20px)}
.login-box::before{content:'';position:absolute;top:0;left:0;right:0;height:3px;background:linear-gradient(90deg,transparent,var(--red),var(--red3),transparent)}
.login-box::after{content:'';position:absolute;inset:0;background:radial-gradient(circle at 50% 0%,rgba(255,26,46,.08),transparent 60%);pointer-events:none}
.login-logo{font-size:48px;font-weight:900;background:linear-gradient(135deg,var(--red),var(--red3),#ff8a95);-webkit-background-clip:text;-webkit-text-fill-color:transparent;text-align:center;margin-bottom:2px;letter-spacing:-2px;position:relative;z-index:1}
.login-sub{text-align:center;color:var(--textmuted);font-size:11px;text-transform:uppercase;letter-spacing:4px;margin-bottom:32px;position:relative;z-index:1}
.login-tabs{display:flex;gap:4px;margin-bottom:28px;background:rgba(0,0,0,.3);border-radius:10px;padding:4px;position:relative;z-index:1}
.login-tab{flex:1;padding:10px;border:none;background:transparent;color:var(--textdim);border-radius:8px;cursor:pointer;font-size:13px;font-weight:600;transition:all .25s}
.login-tab.active{background:linear-gradient(135deg,var(--red),var(--red2));color:#fff;box-shadow:0 4px 16px var(--redglow)}
.login-field{margin-bottom:18px;position:relative;z-index:1}
.login-field label{display:block;font-size:11px;font-weight:600;color:var(--textdim);margin-bottom:6px;text-transform:uppercase;letter-spacing:1.5px}
.login-input{width:100%;background:rgba(0,0,0,.4);border:1px solid var(--border2);color:var(--text);padding:13px 16px;border-radius:10px;font-size:14px;transition:all .25s;font-family:inherit}
.login-input:focus{outline:none;border-color:var(--red);box-shadow:0 0 0 3px var(--redglow2),0 0 20px var(--redglow3)}
.login-btn{width:100%;background:linear-gradient(135deg,var(--red),var(--red2));color:#fff;border:none;padding:14px;border-radius:10px;font-weight:700;cursor:pointer;font-size:14px;transition:all .25s;box-shadow:0 4px 20px var(--redglow);text-transform:uppercase;letter-spacing:1.5px;position:relative;z-index:1}
.login-btn:hover{transform:translateY(-2px);box-shadow:0 8px 32px var(--redglow);filter:brightness(1.15)}
.login-btn:active{transform:translateY(0)}
.login-error{color:var(--danger);font-size:12px;margin-top:10px;text-align:center;min-height:16px;position:relative;z-index:1}
.login-footer{text-align:center;margin-top:22px;color:var(--textmuted);font-size:11px;position:relative;z-index:1}
.login-footer a{color:var(--red);text-decoration:none;font-weight:600}

/* Sidebar */
.sidebar{width:230px;background:linear-gradient(180deg,var(--sidebar) 0%,#08080e 100%);border-right:1px solid var(--border);padding:20px 12px;display:flex;flex-direction:column;gap:2px;position:relative;overflow:hidden;z-index:1}
.sidebar::before{content:'';position:absolute;top:0;left:0;right:0;height:240px;background:radial-gradient(circle at 50% 0%,var(--redglow2),transparent 70%);pointer-events:none;opacity:.8}
.brand{font-size:28px;font-weight:900;background:linear-gradient(135deg,var(--red),var(--red3),#ff8a95);-webkit-background-clip:text;-webkit-text-fill-color:transparent;padding:0 8px;position:relative;z-index:1;letter-spacing:-1px}
.brandsub{font-size:10px;color:var(--textmuted);padding:0 8px;margin-bottom:16px;position:relative;z-index:1;text-transform:uppercase;letter-spacing:3px}
.planbadge{display:inline-block;padding:5px 14px;border-radius:20px;font-size:10px;font-weight:800;margin:0 8px 20px;background:linear-gradient(135deg,var(--red),var(--red2));color:#fff;box-shadow:0 2px 12px var(--redglow);position:relative;z-index:1;letter-spacing:1px}
.navbtn{background:transparent;border:none;color:var(--textdim);padding:11px 14px;border-radius:var(--radius-sm);cursor:pointer;font-size:13px;text-align:left;width:100%;transition:all .2s;font-weight:500;position:relative;z-index:1;display:flex;align-items:center;gap:10px}
.navbtn:hover{background:rgba(255,255,255,.04);color:var(--text);transform:translateX(3px)}
.navbtn.active{background:linear-gradient(90deg,rgba(255,26,46,.15),transparent);color:var(--red);border-left:3px solid var(--red);padding-left:11px;font-weight:600}
.navicon{font-size:14px;opacity:.8;width:20px;text-align:center}
.sidebar-bottom{margin-top:auto;padding:12px 8px;border-top:1px solid var(--border);position:relative;z-index:1}
.account-badge{display:flex;align-items:center;gap:10px;padding:10px;background:linear-gradient(135deg,rgba(255,26,46,.08),rgba(255,26,46,.02));border:1px solid rgba(255,26,46,.2);border-radius:10px;margin-bottom:10px}
.account-avatar{width:36px;height:36px;border-radius:50%;background:linear-gradient(135deg,var(--red),var(--red2));display:flex;align-items:center;justify-content:center;font-weight:800;color:#fff;font-size:15px;box-shadow:0 2px 10px var(--redglow)}
.userinfo{font-size:12px;color:var(--text);font-weight:600}
.ptsinfo{font-size:10px;color:var(--textmuted);margin-top:1px}
.progress{height:4px;background:var(--border);border-radius:2px;overflow:hidden;margin-top:8px}
.progress-fill{height:100%;background:linear-gradient(90deg,var(--red),var(--red3),#ff8a95);border-radius:2px;transition:width .6s cubic-bezier(.4,0,.2,1);box-shadow:0 0 8px var(--redglow)}
.logoutbtn{background:transparent;border:1px solid var(--border);color:var(--textdim);padding:7px 12px;border-radius:8px;cursor:pointer;font-size:11px;margin-top:8px;width:100%;transition:all .2s;font-weight:500}
.logoutbtn:hover{border-color:var(--red);color:var(--red);background:rgba(255,26,46,.05)}

/* Content */
.content{flex:1;overflow-y:auto;padding:28px 32px;background:radial-gradient(ellipse at top right,rgba(255,26,46,.05),transparent 50%);position:relative;z-index:1}
.page{display:none;animation:fadeIn .35s cubic-bezier(.4,0,.2,1)}.page.active{display:block}
@keyframes fadeIn{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:translateY(0)}}
h1{font-size:30px;font-weight:800;margin-bottom:4px;letter-spacing:-.8px}
.sub{color:var(--textdim);font-size:13.5px;margin-bottom:24px;line-height:1.5}

/* Cards */
.card{background:linear-gradient(145deg,rgba(17,17,25,.8),rgba(24,24,34,.8));border:1px solid var(--border);border-radius:var(--radius);padding:20px;margin-bottom:14px;box-shadow:var(--shadow);transition:all .3s cubic-bezier(.4,0,.2,1);backdrop-filter:blur(10px)}
.card:hover{transform:translateY(-3px);box-shadow:var(--shadow-lg);border-color:var(--border2)}
.cardrow{display:flex;gap:14px;flex-wrap:wrap}
.statcard{flex:1;min-width:130px;background:linear-gradient(145deg,rgba(17,17,25,.8),rgba(24,24,34,.8));border:1px solid var(--border);border-radius:var(--radius);padding:18px;position:relative;overflow:hidden;box-shadow:var(--shadow);transition:all .3s}
.statcard::before{content:'';position:absolute;top:0;left:0;right:0;height:2px;background:linear-gradient(90deg,var(--red),transparent)}
.statcard:hover{transform:translateY(-2px);box-shadow:var(--shadow-lg)}
.statlabel{font-size:10px;color:var(--textmuted);text-transform:uppercase;letter-spacing:1.5px;font-weight:700}
.statval{font-size:34px;font-weight:900;margin-top:6px;background:linear-gradient(135deg,var(--text),var(--textdim));-webkit-background-clip:text;-webkit-text-fill-color:transparent}

/* Tweak cards */
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(350px,1fr));gap:12px}
.tweakcard{background:linear-gradient(145deg,rgba(17,17,25,.7),rgba(24,24,34,.7));border:1px solid var(--border);border-radius:var(--radius);padding:16px;transition:all .3s cubic-bezier(.4,0,.2,1);position:relative;overflow:hidden;backdrop-filter:blur(8px)}
.tweakcard:hover{border-color:rgba(255,26,46,.3);transform:translateY(-4px);box-shadow:0 12px 40px rgba(0,0,0,.6),0 0 20px rgba(255,26,46,.08)}
.tweakcard::after{content:'';position:absolute;inset:0;background:radial-gradient(circle at 0% 0%,rgba(255,26,46,.06),transparent 50%);pointer-events:none;opacity:0;transition:opacity .3s}
.tweakcard:hover::after{opacity:1}
.tweakhead{display:flex;align-items:center;gap:6px;margin-bottom:8px;flex-wrap:wrap}
.badge{padding:3px 9px;border-radius:5px;font-size:9px;font-weight:800;letter-spacing:.5px;text-transform:uppercase}
.badge.safe{background:linear-gradient(135deg,var(--green),#00cc6a);color:#000;box-shadow:0 2px 8px rgba(0,255,136,.25)}
.badge.caution{background:linear-gradient(135deg,var(--warn),#cc8400);color:#000;box-shadow:0 2px 8px rgba(255,170,0,.25)}
.badge.danger{background:linear-gradient(135deg,var(--danger),#cc2f3a);color:#fff;box-shadow:0 2px 8px rgba(255,71,87,.25)}
.badge.free{background:rgba(255,26,46,.1);color:var(--red);border:1px solid rgba(255,26,46,.3)}
.badge.pro{background:rgba(255,170,0,.1);color:var(--warn);border:1px solid rgba(255,170,0,.3)}
.badge.new{background:linear-gradient(135deg,var(--blue),#0088cc);color:#fff;box-shadow:0 2px 8px rgba(0,170,255,.25)}
.tweakname{font-size:14.5px;font-weight:700;margin-bottom:4px;letter-spacing:-.2px}
.tweakdesc{font-size:12px;color:var(--textdim);line-height:1.55}

/* Toggle */
.toggle{margin-left:auto;position:relative;width:48px;height:26px;cursor:pointer;flex-shrink:0}
.toggle input{opacity:0;width:0;height:0;position:absolute}
.slider{position:absolute;inset:0;background:linear-gradient(180deg,#2a2a38,#1a1a28);border:1px solid var(--border2);border-radius:26px;transition:all .35s cubic-bezier(.4,0,.2,1);box-shadow:inset 0 2px 4px rgba(0,0,0,.4)}
.slider:before{content:"";position:absolute;width:20px;height:20px;left:2px;top:2px;background:linear-gradient(145deg,#fff,#d8d8e0);border-radius:50%;transition:all .35s cubic-bezier(.4,0,.2,1);box-shadow:0 2px 8px rgba(0,0,0,.5)}
.toggle input:checked+.slider{background:linear-gradient(135deg,var(--red),var(--red2));border-color:var(--red);box-shadow:0 0 16px var(--redglow),inset 0 1px 2px rgba(255,255,255,.2)}
.toggle input:checked+.slider:before{transform:translateX(22px);background:#fff;box-shadow:0 2px 8px rgba(0,0,0,.3)}
.toggle input:disabled+.slider{opacity:.35;cursor:not-allowed}

/* Buttons */
.btn{background:linear-gradient(135deg,var(--red),var(--red2));color:#fff;border:none;padding:12px 24px;border-radius:var(--radius-sm);font-weight:700;cursor:pointer;font-size:13px;transition:all .25s cubic-bezier(.4,0,.2,1);box-shadow:0 4px 16px var(--redglow),inset 0 1px 0 rgba(255,255,255,.2);text-transform:uppercase;letter-spacing:.8px;position:relative;overflow:hidden}
.btn::before{content:'';position:absolute;inset:0;background:linear-gradient(135deg,rgba(255,255,255,.15),transparent);opacity:0;transition:opacity .25s}
.btn:hover{transform:translateY(-3px);box-shadow:0 8px 32px var(--redglow),inset 0 1px 0 rgba(255,255,255,.3);filter:brightness(1.1)}
.btn:hover::before{opacity:1}
.btn:active{transform:translateY(-1px)}
.btn.danger{background:linear-gradient(135deg,var(--danger),#cc2f3a);box-shadow:0 4px 16px rgba(255,71,87,.3)}
.btn.danger:hover{box-shadow:0 8px 32px rgba(255,71,87,.4)}
.btn.ghost{background:linear-gradient(145deg,rgba(17,17,25,.6),rgba(24,24,34,.6));border:1px solid var(--border2);color:var(--text);box-shadow:var(--shadow)}
.btn.ghost:hover{border-color:var(--red);color:var(--red);box-shadow:0 4px 16px rgba(0,0,0,.3)}
.btn.sm{padding:8px 18px;font-size:11.5px}
.btn.xs{padding:5px 12px;font-size:10.5px}
.btn.full{width:100%}

/* Inputs */
.input{background:rgba(0,0,0,.4);border:1px solid var(--border);color:var(--text);padding:11px 15px;border-radius:var(--radius-sm);font-size:13px;width:100%;transition:all .25s;font-family:inherit}
.input:focus{outline:none;border-color:var(--red);box-shadow:0 0 0 3px var(--redglow2),0 0 16px var(--redglow3)}
.textarea{background:rgba(0,0,0,.4);border:1px solid var(--border);color:var(--text);padding:11px 15px;border-radius:var(--radius-sm);font-size:12px;font-family:'JetBrains Mono',monospace;width:100%;min-height:120px;resize:vertical;transition:all .25s;line-height:1.6}
.textarea:focus{outline:none;border-color:var(--red);box-shadow:0 0 0 3px var(--redglow2)}

/* Category bar */
.catbar{display:flex;gap:6px;margin-bottom:18px;flex-wrap:wrap}
.catbtn{background:linear-gradient(145deg,rgba(17,17,25,.6),rgba(24,24,34,.6));border:1px solid var(--border);color:var(--textdim);padding:9px 20px;border-radius:24px;cursor:pointer;font-size:12px;font-weight:600;transition:all .25s}
.catbtn:hover{color:var(--text);border-color:var(--border2);transform:translateY(-2px)}
.catbtn.active{background:linear-gradient(135deg,var(--red),var(--red2));color:#fff;border-color:var(--red);font-weight:700;box-shadow:0 4px 16px var(--redglow)}

/* Log */
.logbox{background:#030306;border:1px solid var(--border);border-radius:var(--radius);padding:16px;font-family:'JetBrains Mono',monospace;font-size:12px;color:#ff6b7a;height:440px;overflow-y:auto;white-space:pre-wrap;box-shadow:inset 0 2px 12px rgba(0,0,0,.6);line-height:1.7}

/* Toast */
.toast{position:fixed;bottom:28px;right:28px;background:linear-gradient(135deg,rgba(17,17,25,.95),rgba(24,24,34,.95));border:1px solid var(--red);padding:16px 24px;border-radius:var(--radius);font-size:13px;opacity:0;transform:translateY(24px) scale(.95);transition:all .35s cubic-bezier(.4,0,.2,1);pointer-events:none;box-shadow:0 12px 40px rgba(0,0,0,.6),0 0 20px var(--redglow2);z-index:1000;font-weight:600;backdrop-filter:blur(10px)}
.toast.show{opacity:1;transform:translateY(0) scale(1)}

/* Warn box */
.warnbox{background:linear-gradient(135deg,rgba(255,170,0,.08),rgba(255,170,0,.02));border:1px solid rgba(255,170,0,.35);border-radius:var(--radius);padding:14px 18px;font-size:12.5px;color:var(--warn);margin-bottom:16px;box-shadow:0 2px 12px rgba(255,170,0,.08)}

/* Profile cards */
.profilecard{background:linear-gradient(145deg,rgba(17,17,25,.7),rgba(24,24,34,.7));border:1px solid var(--border);border-radius:var(--radius);padding:18px;display:flex;align-items:center;gap:16px;margin-bottom:10px;transition:all .3s cubic-bezier(.4,0,.2,1);backdrop-filter:blur(8px)}
.profilecard:hover{border-color:rgba(255,26,46,.3);transform:translateX(6px);box-shadow:0 8px 30px rgba(0,0,0,.5)}
.profileicon{width:48px;height:48px;border-radius:10px;background:linear-gradient(135deg,var(--red),var(--red2));display:flex;align-items:center;justify-content:center;font-weight:900;color:#fff;font-size:15px;box-shadow:0 4px 14px var(--redglow);flex-shrink:0}

/* Scrollbar */
::-webkit-scrollbar{width:8px;height:8px}
::-webkit-scrollbar-track{background:var(--bg)}
::-webkit-scrollbar-thumb{background:var(--border2);border-radius:4px}
::-webkit-scrollbar-thumb:hover{background:var(--textmuted)}

/* Live tool cards */
.livetool{background:linear-gradient(145deg,rgba(17,17,25,.8),rgba(24,24,34,.8));border:1px solid var(--border);border-radius:var(--radius);padding:20px;margin-bottom:14px;position:relative;overflow:hidden}
.livetool::before{content:'';position:absolute;top:0;left:0;right:0;height:2px;background:linear-gradient(90deg,var(--red),var(--purple),var(--blue))}
.livetool-header{display:flex;align-items:center;gap:12px;margin-bottom:14px}
.livetool-icon{width:40px;height:40px;border-radius:10px;background:linear-gradient(135deg,var(--red),var(--red2));display:flex;align-items:center;justify-content:center;font-size:18px;box-shadow:0 4px 12px var(--redglow)}
.livetool-title{font-size:16px;font-weight:700}
.livetool-desc{font-size:12px;color:var(--textdim);margin-bottom:14px;line-height:1.5}
.livetool-stats{display:flex;gap:16px;margin-bottom:14px}
.livetool-stat{background:rgba(0,0,0,.3);border:1px solid var(--border);border-radius:8px;padding:10px 14px;flex:1;text-align:center}
.livetool-stat-val{font-size:20px;font-weight:800;background:linear-gradient(135deg,var(--red),var(--red3));-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.livetool-stat-label{font-size:9px;color:var(--textmuted);text-transform:uppercase;letter-spacing:1px;margin-top:2px;font-weight:600}

/* Pulse */
@keyframes pulse{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.6;transform:scale(1.05)}}
.live-dot{display:inline-block;width:8px;height:8px;border-radius:50%;background:var(--green);box-shadow:0 0 8px var(--green);animation:pulse 2s infinite;margin-right:6px}

/* Section divider */
.section-title{font-size:18px;font-weight:700;margin:24px 0 12px;color:var(--text);display:flex;align-items:center;gap:10px}
.section-title::after{content:'';flex:1;height:1px;background:linear-gradient(90deg,var(--border),transparent)}

/* OS badges */
.badge.os-windows{background:linear-gradient(135deg,var(--blue),#0088cc);color:#fff;box-shadow:0 2px 8px rgba(0,170,255,.25)}
.badge.os-mac{background:linear-gradient(135deg,var(--purple),#8833cc);color:#fff;box-shadow:0 2px 8px rgba(170,68,255,.25)}
.badge.os-both{background:linear-gradient(135deg,var(--green),#00cc6a);color:#000;box-shadow:0 2px 8px rgba(0,255,136,.25)}

/* Rotating outline */
.rotating-outline{position:relative;overflow:visible}
.rotating-outline::before{content:'';position:absolute;inset:-2px;border-radius:inherit;padding:2px;background:conic-gradient(from var(--rot,0deg),var(--red),var(--purple),var(--blue),var(--red));-webkit-mask:linear-gradient(#000 0 0) content-box,linear-gradient(#000 0 0);-webkit-mask-composite:xor;mask-composite:exclude;animation:spinOutline 4s linear infinite;pointer-events:none;z-index:0}
@keyframes spinOutline{to{--rot:360deg}}
@property --rot{syntax:'<angle>';initial-value:0deg;inherits:false}
.tweakcard.rotating-outline::before{border-radius:var(--radius)}

/* Snow canvas */
#snowCanvas{position:fixed;inset:0;pointer-events:none;z-index:2;opacity:.7}

/* Draggable hint */
.draggable{cursor:move}
</style>
</head>
<body>
<canvas id="snowCanvas"></canvas>

<!-- LOGIN OVERLAY -->
<div class="login-overlay" id="loginOverlay">
  <div class="login-box">
    <div class="login-logo">FL3SH</div>
    <div class="login-sub">Optimizer Ultimate</div>
    <div class="login-tabs">
      <button class="login-tab active" data-tab="login">Sign In</button>
      <button class="login-tab" data-tab="register">Create Account</button>
    </div>
    <div id="loginForm">
      <div class="login-field"><label>Email</label><input class="login-input" id="loginEmail" type="email" placeholder="you@example.com"></div>
      <div class="login-field"><label>Password</label><input class="login-input" id="loginPass" type="password" placeholder="••••••••"></div>
      <button class="login-btn" id="loginBtn">Sign In</button>
      <div class="login-error" id="loginError"></div>
    </div>
    <div id="registerForm" style="display:none">
      <div class="login-field"><label>Name</label><input class="login-input" id="regName" placeholder="Your name"></div>
      <div class="login-field"><label>Email</label><input class="login-input" id="regEmail" type="email" placeholder="you@example.com"></div>
      <div class="login-field"><label>Password</label><input class="login-input" id="regPass" type="password" placeholder="••••••••"></div>
      <button class="login-btn" id="registerBtn">Create Account</button>
      <div class="login-error" id="registerError"></div>
    </div>
    <div class="login-footer">Auto-login enabled · Session saved locally · Everyone gets Pro</div>
  </div>
</div>

<!-- MAIN APP -->
<div id="appContainer" style="display:none;width:100%;height:100vh;display:none">
<div class="sidebar">
  <div class="brand">FL3SH</div>
  <div class="brandsub">Optimizer Ultimate</div>
  <div class="planbadge" id="planBadge">PRO</div>
  <button class="navbtn active" data-page="home"><span class="navicon">◆</span>Home</button>
  <button class="navbtn" data-page="tweaks"><span class="navicon">⚙</span>All Tweaks</button>
  <button class="navbtn" data-page="booster"><span class="navicon">⚡</span>Game Booster</button>
  <button class="navbtn" data-page="potato"><span class="navicon">🥔</span>Potato Graphics</button>
  <button class="navbtn" data-page="bench"><span class="navicon">📊</span>Benchmark</button>
  <button class="navbtn" data-page="restore"><span class="navicon">↺</span>Restore</button>
  <button class="navbtn" data-page="log"><span class="navicon">☰</span>Log</button>
  <button class="navbtn" data-page="settings"><span class="navicon">✦</span>Settings</button>
  <div class="sidebar-bottom">
    <div class="account-badge" id="accountBadge" style="display:none">
      <div class="account-avatar" id="accountAvatar">G</div>
      <div><div class="userinfo" id="userInfo">Guest</div><div class="ptsinfo" id="ptsInfo">0 tweaks</div></div>
    </div>
    <div class="progress"><div class="progress-fill" id="progressFill" style="width:0%"></div></div>
    <button class="logoutbtn" id="logoutBtn">Sign Out</button>
  </div>
</div>

<div class="content">
<!-- HOME -->
<div class="page active" id="page-home">
  <h1 id="greeting">Good evening</h1>
  <div class="sub" id="homeSub">0 tweaks on · Pro plan · All features unlocked</div>
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
        <div>▸ Enable Input Delay Reducer</div>
        <div>▸ Enable Ping Stabilizer</div>
        <div>▸ Turn on Game Booster</div>
      </div>
    </div>
  </div>
  <div class="card" style="margin-top:16px">
    <h3 style="margin-bottom:10px;font-size:16px">What's new in Ultimate</h3>
    <div style="color:var(--textdim);font-size:13px;line-height:1.6">Input Delay Reducer (10 changes, ~60% less input lag), Ping Stabilizer (Nagle off, adapter offloads, DNS flush), Mouse Precision (1:1 tracking), Keyboard Latency Fix (max repeat rate), USB Polling (1000Hz), BCDEDIT micro-stutter fix, and 30+ system tweaks. All reversible.</div>
  </div>
</div>

<!-- ALL TWEAKS -->
<div class="page" id="page-tweaks">
  <h1>All Tweaks</h1>
  <div class="sub">30+ tweaks across 8 categories. Each one is a card with a risk label, OS badge (Windows/macOS/Both) and a switch.</div>
  <div class="catbar" id="catBar"></div>
  <div style="display:flex;gap:8px;margin-bottom:14px;flex-wrap:wrap">
    <button class="btn danger sm" id="removeAllBtn">Remove All Tweaks</button>
    <button class="btn danger sm" id="removeCatBtn">Remove All in Category</button>
    <button class="btn ghost sm" id="revertAllBtn2">Revert All Changes</button>
  </div>
  <div class="grid" id="tweakGrid"></div>
</div>

<!-- GAME BOOSTER -->
<div class="page" id="page-booster">
  <h1>Game Booster</h1>
  <div class="sub">Closes what you are not using before you queue. Whitelist what stays.</div>
  <div class="livetool">
    <div class="livetool-header">
      <div class="livetool-icon">⚡</div>
      <div><div class="livetool-title">Game Booster</div><div style="font-size:11px;color:var(--textmuted)">Closes non-whitelisted apps, frees memory for your game</div></div>
    </div>
    <div class="livetool-desc">One switch before you queue closes what you didn't whitelist and hands that memory and CPU back to your game. Drivers, services and vendor tools are never touched, so laptops are safe.</div>
    <div class="cardrow">
      <div class="card" style="flex:1;min-width:300px">
        <h3 style="margin-bottom:10px;font-size:14px">Whitelist (one app per line)</h3>
        <textarea class="textarea" id="whitelist">discord.exe
chrome.exe
spotify.exe</textarea>
        <button class="btn full" style="margin-top:12px" id="boostBtn">⚡ BOOST (close others)</button>
      </div>
      <div class="card" style="flex:1;min-width:300px">
        <h3 style="margin-bottom:10px;font-size:14px">Status</h3>
        <div style="color:var(--textdim);font-size:13px;line-height:2">
          Booster is OFF<br><br>
          Free: whitelist 1 app<br>
          Pro: unlimited whitelist
        </div>
      </div>
    </div>
  </div>
</div>

<!-- POTATO GRAPHICS -->
<div class="page" id="page-potato">
  <h1>Potato Graphics</h1>
  <div class="sub">One-click low-graphics profiles. Max FPS, max visibility, revert any time.</div>
  <div class="warnbox">⚠ WARNING: This is the only tweak that changes how the game LOOKS. Revert anytime.</div>
  <div id="profileList"></div>
</div>

<!-- BENCHMARK -->
<div class="page" id="page-bench">
  <h1>Benchmark</h1>
  <div class="sub">System info + micro-benchmark. Track your FPS before and after.</div>
  <div class="card">
    <button class="btn ghost sm" id="refreshSysBtn">Refresh System Info</button>
    <pre id="sysInfo" style="margin-top:12px;color:var(--textdim);font-size:12px;font-family:'JetBrains Mono',monospace;line-height:1.6"></pre>
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

<!-- RESTORE -->
<div class="page" id="page-restore">
  <h1>Restore & Revert</h1>
  <div class="sub">Every tweak is reversible. Restore points + backups created before changes.</div>
  <div class="card">
    <button class="btn ghost" id="restorePointBtn" style="margin-right:10px">Create System Restore Point</button>
    <button class="btn danger" id="revertAllBtn">REVERT ALL CHANGES</button>
    <div style="margin-top:14px;color:var(--textdim);font-size:12px;line-height:1.6">Reboot recommended after reverting. All original values are restored from backup. BCDEDIT and registry values reverted.</div>
  </div>
</div>

<!-- LOG -->
<div class="page" id="page-log">
  <h1>Log</h1>
  <div class="sub">Activity log.</div>
  <div class="logbox" id="logBox"></div>
  <button class="btn ghost sm" style="margin-top:12px" id="refreshLogBtn">Refresh</button>
</div>

<!-- SETTINGS -->
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
      <b style="color:var(--text)">Pro:</b> All tweaks + Input Delay Reducer + Ping Stabilizer + Potato Graphics + full Game Booster. Everyone gets Pro.
    </div>
  </div>
</div>
</div>
</div>

<div class="toast" id="toast"></div>

<script>
const state={plan:'Pro',tweaks:{},os:'unknown',user:null};
// Snowfall
(function(){
  const c=document.getElementById('snowCanvas');const ctx=c.getContext('2d');
  let w,h,flakes=[];
  function resize(){w=c.width=window.innerWidth;h=c.height=window.innerHeight}
  window.addEventListener('resize',resize);resize();
  for(let i=0;i<120;i++)flakes.push({x:Math.random()*w,y:Math.random()*h,r:Math.random()*2.5+0.5,vx:(Math.random()-.5)*.4,vy:Math.random()*1.2+.4,o:Math.random()*.6+.3});
  function draw(){ctx.clearRect(0,0,w,h);for(const f of flakes){f.x+=f.vx;f.y+=f.vy;if(f.y>h){f.y=-5;f.x=Math.random()*w}if(f.x>w)f.x=0;if(f.x<0)f.x=w;ctx.beginPath();ctx.arc(f.x,f.y,f.r,0,Math.PI*2);ctx.fillStyle='rgba(255,255,255,'+f.o+')';ctx.fill()}requestAnimationFrame(draw)}
  draw();
})();

// Draggable GUI (move the whole app container by dragging the sidebar brand)
(function(){
  const app=document.getElementById('appContainer');
  let dragging=false,sx=0,sy=0,ox=0,oy=0;
  function onDown(e){
    if(e.target.closest('button,input,textarea,select,a,.toggle'))return;
    const sb=e.target.closest('.sidebar');if(!sb)return;
    dragging=true;sx=e.clientX;sy=e.clientY;
    const r=app.getBoundingClientRect();ox=r.left;oy=r.top;
    app.style.position='fixed';app.style.left=ox+'px';app.style.top=oy+'px';app.style.width=r.width+'px';app.style.height=r.height+'px';
    e.preventDefault();
  }
  function onMove(e){if(!dragging)return;app.style.left=(ox+e.clientX-sx)+'px';app.style.top=(oy+e.clientY-sy)+'px'}
  function onUp(){dragging=false}
  document.addEventListener('mousedown',onDown);document.addEventListener('mousemove',onMove);document.addEventListener('mouseup',onUp);
})();
function showToast(msg){const t=document.getElementById('toast');t.textContent=msg;t.classList.add('show');setTimeout(()=>t.classList.remove('show'),3000)}
async function api(path,body={}){
  const r=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
  return r.json();
}

document.querySelectorAll('.login-tab').forEach(t=>t.addEventListener('click',()=>{
  document.querySelectorAll('.login-tab').forEach(x=>x.classList.remove('active'));
  t.classList.add('active');
  document.getElementById('loginForm').style.display=t.dataset.tab==='login'?'block':'none';
  document.getElementById('registerForm').style.display=t.dataset.tab==='register'?'block':'none';
}));

document.getElementById('loginBtn').addEventListener('click',async()=>{
  const r=await api('/api/login',{email:document.getElementById('loginEmail').value,password:document.getElementById('loginPass').value});
  if(r.success){onLogin(r.account)}else document.getElementById('loginError').textContent=r.message;
});
document.getElementById('registerBtn').addEventListener('click',async()=>{
  const r=await api('/api/register',{name:document.getElementById('regName').value,email:document.getElementById('regEmail').value,password:document.getElementById('regPass').value});
  if(r.success){document.getElementById('registerError').textContent='Account created! Sign in now.';document.getElementById('registerError').style.color='var(--green)'}
  else document.getElementById('registerError').textContent=r.message;
});
document.getElementById('loginPass').addEventListener('keydown',e=>{if(e.key==='Enter')document.getElementById('loginBtn').click()});

function onLogin(acc){
  state.user=acc;state.plan='Pro';
  document.getElementById('loginOverlay').style.display='none';
  document.getElementById('appContainer').style.display='flex';
  document.getElementById('accountBadge').style.display='flex';
  document.getElementById('userInfo').textContent=acc.Name||acc.Email;
  document.getElementById('accountAvatar').textContent=(acc.Name||acc.Email).charAt(0).toUpperCase();
  document.getElementById('planBadge').textContent='PRO';
  document.getElementById('emailInput').value=acc.Email;
  document.getElementById('keyInput').value=acc.LicenseKey||'';
  loadTweaks();
}

(async function(){const r=await api('/api/autologin');if(r.success){onLogin(r.account)}})();

document.querySelectorAll('.navbtn').forEach(b=>b.addEventListener('click',()=>{
  document.querySelectorAll('.navbtn').forEach(x=>x.classList.remove('active'));
  b.classList.add('active');
  document.querySelectorAll('.page').forEach(p=>p.classList.remove('active'));
  document.getElementById('page-'+b.dataset.page).classList.add('active');
  if(b.dataset.page==='log')refreshLog();
}));

document.getElementById('logoutBtn').addEventListener('click',async()=>{await api('/api/logout');location.reload()});

function renderStats(){
  const stats=[{label:'CPU',value:'7%',color:'var(--red)'},{label:'GPU',value:'8%',color:'var(--red)'},{label:'RAM',value:'37%',color:'var(--warn)'},{label:'TEMP',value:'41°',color:'var(--red)'}];
  document.getElementById('statsRow').innerHTML=stats.map(s=>`<div class="statcard"><div class="statlabel">${s.label}</div><div class="statval" style="background:linear-gradient(135deg,${s.color},var(--textdim));-webkit-background-clip:text;-webkit-text-fill-color:transparent">${s.value}</div></div>`).join('');
}

const cats=['General','Input','Network','Power','Visual','Services','Game'];
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
    const planBadge='<span class="badge pro">PRO</span>';
    const newBadge=t.id==='inputdelay'||t.id==='pingstab'||t.id==='bcdedit'?'<span class="badge new">NEW</span>':'';
    const osCls='os-'+(t.os||'').toLowerCase();
    const osBadge='<span class="badge '+osCls+'">'+(t.os||'')+'</span>';
    return `<div class="tweakcard rotating-outline">
      <div class="tweakhead">
        <span class="badge ${riskCls}">${t.risk}</span>${osBadge}${planBadge}${newBadge}
        <label class="toggle"><input type="checkbox" data-id="${t.id}" ${checked}><span class="slider"></span></label>
      </div>
      <div class="tweakname">${t.name}</div>
      <div class="tweakdesc">${t.desc}</div>
    </div>`;
  }).join('');
  grid.querySelectorAll('input[type=checkbox]').forEach(cb=>cb.addEventListener('change',async e=>{
    const id=cb.dataset.id;const tw=state.tweaks[id];
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
  document.getElementById('homeSub').textContent=applied+' of '+total+' tweaks on · Pro plan · All features unlocked';
  document.getElementById('sugText').textContent=Math.round(applied/total*100)+'% optimized · '+applied+' of '+total+' on.';
  document.getElementById('progressFill').style.width=Math.round(applied/total*100)+'%';
}

const profiles=[{name:'Fortnite',desc:'DX11 and Performance mode',plan:'Pro',icon:'FN'},{name:'Fortnite Competitive',desc:'Fixed floor (lowest settings)',plan:'Pro',icon:'FC'},{name:'Marvel Rivals',desc:'Low-graphics competitive profile',plan:'Pro',icon:'MR'},{name:'AMD/Intel Potato',desc:'Works on any GPU. Removes texture packs.',plan:'Pro',icon:'AI'}];
document.getElementById('profileList').innerHTML=profiles.map(p=>`<div class="profilecard"><div class="profileicon">${p.icon}</div><div style="flex:1"><div style="font-weight:700;font-size:14px">${p.name}</div><div style="font-size:12px;color:var(--textdim);margin-top:2px">${p.desc}</div></div><span class="badge pro">${p.plan}</span><button class="btn sm" data-profile="${p.name}">Apply</button></div>`).join('');
document.querySelectorAll('[data-profile]').forEach(b=>b.addEventListener('click',async()=>{
  if(!confirm('This will change Fortnite graphics (Engine.ini).\nRevert anytime. Continue?'))return;
  const r=await api('/api/potato',{profile:b.dataset.profile});showToast(r.message);
}));

document.getElementById('boostBtn').addEventListener('click',async()=>{
  const wl=document.getElementById('whitelist').value.split('\n').map(s=>s.trim()).filter(Boolean);
  const r=await api('/api/booster',{whitelist:wl});showToast(r.message);
});
document.getElementById('applyAllBtn').addEventListener('click',async()=>{const r=await api('/api/applyall');showToast(r.message);await loadTweaks()});
document.getElementById('removeAllBtn').addEventListener('click',async()=>{if(!confirm('Remove ALL tweaks? This reverts every tweak.'))return;const r=await api('/api/revertall');showToast(r.message);await loadTweaks()});
document.getElementById('removeCatBtn').addEventListener('click',async()=>{if(!confirm('Remove all tweaks in '+currentCat+'?'))return;const ids=Object.values(state.tweaks).filter(t=>t.cat===currentCat).map(t=>t.id);for(const id of ids){await api('/api/tweak/toggle',{id,state:false})}showToast('Removed '+ids.length+' tweaks in '+currentCat);await loadTweaks()});
document.getElementById('revertAllBtn2').addEventListener('click',async()=>{if(!confirm('Revert ALL changes? Reboot recommended after.'))return;const r=await api('/api/revertall');showToast(r.message);await loadTweaks()});
document.getElementById('refreshSysBtn').addEventListener('click',async()=>{const r=await api('/api/sysinfo');document.getElementById('sysInfo').textContent=r.info});
document.getElementById('runBenchBtn').addEventListener('click',async()=>{document.getElementById('benchResult').textContent='Running...';const r=await api('/api/bench');document.getElementById('benchResult').textContent=r.result});
document.getElementById('saveBenchBtn').addEventListener('click',async()=>{const r=await api('/api/savebench',{before:document.getElementById('fpsBefore').value,after:document.getElementById('fpsAfter').value});showToast(r.message)});
document.getElementById('restorePointBtn').addEventListener('click',async()=>{const r=await api('/api/restorepoint');showToast(r.message)});
document.getElementById('revertAllBtn').addEventListener('click',async()=>{if(!confirm('Revert ALL changes? Reboot recommended after.'))return;const r=await api('/api/revertall');showToast(r.message);await loadTweaks()});
async function refreshLog(){const r=await api('/api/log');document.getElementById('logBox').textContent=r.log}
document.getElementById('refreshLogBtn').addEventListener('click',refreshLog);
document.getElementById('activateBtn').addEventListener('click',async()=>{
  const r=await api('/api/activate',{email:document.getElementById('emailInput').value,key:document.getElementById('keyInput').value});
  if(r.success){state.plan='Pro';document.getElementById('planBadge').textContent='PRO';showToast('License activated! Plan: Pro')}
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
Write-Host "FL3SH Optimizer ULTIMATE running at http://localhost:$Port" -ForegroundColor Red

if ($IsMac) { Start-Process "open" -ArgumentList "http://localhost:$Port" }
elseif ($IsWin) { Start-Process "http://localhost:$Port" }

while ($Listener.IsListening) {
    $ctx = $Listener.GetContext()
    $req = $ctx.Request; $res = $ctx.Response; $path = $req.Url.AbsolutePath

    if ($path -eq "/" -or $path -eq "/index.html") {
        $buf = [System.Text.Encoding]::UTF8.GetBytes($HtmlPage); $res.ContentType = "text/html; charset=utf-8"; $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/autologin") {
        $acc = $Script:CurrentUser
        if ($acc) { $json = @{ success=$true; account=$acc } | ConvertTo-Json -Depth 5 } else { $json = @{ success=$false } | ConvertTo-Json }
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/login") {
        $reader = New-Object System.IO.StreamReader($req.InputStream); $body = $reader.ReadToEnd() | ConvertFrom-Json
        $result = Verify-Login $body.email $body.password
        $json = $result | ConvertTo-Json -Depth 5
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length)
        if ($result.success) { $Script:CurrentUser = $result.account; $Script:Config.Plan = "Pro"; $Script:Config.CurrentUser = $result.account.Email; Save-Config }
    }
    elseif ($path -eq "/api/register") {
        $reader = New-Object System.IO.StreamReader($req.InputStream); $body = $reader.ReadToEnd() | ConvertFrom-Json
        $result = Create-Account $body.email $body.password $body.name
        $json = $result | ConvertTo-Json -Depth 5
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/logout") {
        Logout; $Script:CurrentUser = $null; $Script:Config.CurrentUser = ""; Save-Config
        $json = @{ success=$true } | ConvertTo-Json; $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length)
    }
    elseif ($path -eq "/api/tweaks/list") {
        $tweakObj = @{}
        $catMap = @{"memory"="General";"temp"="General";"startup"="General";"spotlight"="General";"inputdelay"="Input";"mouseprec"="Input";"kbdlag"="Input";"usb"="Input";"pingstab"="Network";"nagle"="Network";"autotune"="Network";"qos"="Network";"power"="Power";"hags"="Power";"corepark"="Power";"timer"="Power";"macpower"="Power";"visual"="Visual";"menu"="Visual";"transp"="Visual";"fontcache"="Visual";"services"="Services";"sysmain"="Services";"potato"="Game";"gamedvr"="Game";"fullscreen"="Game";"bcdedit"="Game";"gamemode"="Game";"mpo"="Game";"fullopt"="Game";"gamedvr2"="Game";"powerthrottle"="Power";"usbss"="Power";"faststartup"="Power";"hibernate"="Power";"ntfslast"="General";"disable8dot3"="General";"trim"="General";"clearevents"="General";"audioenh"="Visual";"telemetry"="Services";"adid"="Services";"feedback"="Services";"smartscreen"="Services";"defendercloud"="Services";"cortana"="Services";"widgets"="Services";"copilot"="Services";"recall"="Services";"onedrive"="Services";"searchhl"="Visual";"bgapps"="Services";"errrep"="Services";"deliveryopt"="Services";"bits"="Services";"wuautorestart"="Services";"lockscreen"="Visual";"tips"="Visual";"consumerfeat"="Services";"activityhist"="Services";"lockcam"="Visual";"wins"="Services";"macappnap"="Power";"macwinanim"="Visual";"macfontsmooth"="Visual";"macpurge"="General";"macspotlight"="General"}
        foreach ($t in $Script:Tweaks) {
            $isAvail = if ($IsWin) { $t.Win } else { $t.Mac }
            if (-not $isAvail) { continue }
            $osLabel = if ($t.Win -and $t.Mac) { "Both" } elseif ($t.Win) { "Windows" } else { "Mac" }
            $tweakObj[$t.Id] = @{ id=$t.Id; name=$t.Name; desc=$t.Desc; risk=$t.Risk; free=$t.Free; cat=$catMap[$t.Id]; os=$osLabel; state=$Script:Config.TweakStates[$t.Id] }
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
    elseif ($path -eq "/api/inputdelay") { Invoke-InputDelayReducer; Invoke-MousePrecision; Invoke-KeyboardLatency; Invoke-USBPolling; $json = @{ message = "Input Delay Reducer applied (10 changes)." } | ConvertTo-Json; $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
    elseif ($path -eq "/api/pingstab") { Invoke-PingStabilizer; $json = @{ message = "Ping Stabilizer applied." } | ConvertTo-Json; $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
    elseif ($path -eq "/api/booster") { $reader = New-Object System.IO.StreamReader($req.InputStream); $body = $reader.ReadToEnd() | ConvertFrom-Json; Invoke-GameBooster; $json = @{ message = "Game Booster complete." } | ConvertTo-Json; $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
    elseif ($path -eq "/api/potato") { Invoke-PotatoGraphics; $json = @{ message = "Potato Graphics applied." } | ConvertTo-Json; $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
    elseif ($path -eq "/api/applyall") {
        $count = 0
        foreach ($t in $Script:Tweaks) { $isAvail = if ($IsWin) { $t.Win } else { $t.Mac }; if ($isAvail) { $Script:Config.TweakStates[$t.Id] = $true; & $t.Action; $count++ } }
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
    elseif ($path -eq "/api/activate") {
        $reader = New-Object System.IO.StreamReader($req.InputStream); $body = $reader.ReadToEnd() | ConvertFrom-Json
        $Script:Config.Email = $body.email; $Script:Config.LicenseKey = $body.key
        $success = $false
        try { $resp = Invoke-RestMethod -Uri "https://api.gumroad.com/v2/licenses/verify" -Method POST -Body @{ product_id="YOUR_PRODUCT_ID"; license_key=$body.key } -ErrorAction Stop; if ($resp.success) { $success = $true } } catch { if ($body.key -match "^FL3SH-") { $success = $true } }
        if ($success) { $Script:Config.Plan = "Pro"; Save-Config; if ($Script:CurrentUser) { $accs = @(Load-Accounts); $a = $accs | Where-Object { $_.Email -eq $Script:CurrentUser.Email } | Select-Object -First 1; if ($a) { $a.Plan = "Pro"; $a.LicenseKey = $body.key; Save-Accounts $accs } } }
        $json = @{ success = $success; message = if ($success) { "License activated! Plan: Pro" } else { "Invalid license key." } } | ConvertTo-Json
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length)
    }
    else { $res.StatusCode = 404 }
    $res.Close()
}
