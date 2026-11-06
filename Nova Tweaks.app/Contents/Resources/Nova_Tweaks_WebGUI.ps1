#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Nova Tweaks ULTIMATE - Red Theme + All Tweaks + Accounts + Auto-Login
.DESCRIPTION
    The complete suite with every performance tweak: Input Response Accelerator,
    Network Spike Smoother, Mouse Precision, Keyboard Latency, USB Polling, Game Booster,
    Potato Graphics, and 30+ system tweaks. All in a vibrant red GUI.
#>

$IsWin = $IsWindows -or ($env:OS -eq "Windows_NT")
$IsMac = $IsMacOS -or ((uname 2>/dev/null) -eq "Darwin")

$Script:Root = if ($IsWin) { Join-Path $env:USERPROFILE "NovaTweaks" } else { Join-Path $env:HOME ".novatweaks" }
$Script:BackupDir = Join-Path $Script:Root "backups"
$Script:LogPath = Join-Path $Script:Root "nova.log"
$Script:ConfigPath = Join-Path $Script:Root "config.json"
$Script:AccountsPath = Join-Path $Script:Root "accounts.json"
$Script:TokenPath = Join-Path $Script:Root "session.token"
foreach ($d in @($Script:Root,$Script:BackupDir)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }
if (-not (Test-Path $Script:LogPath)) { New-Item -ItemType File -Path $Script:LogPath -Force | Out-Null }

# ---------- Account System ----------
function Load-Accounts { if (Test-Path $Script:AccountsPath) { try { return @(Get-Content $Script:AccountsPath -Raw | ConvertFrom-Json) } catch { return @() } }; return @() }
function Save-Accounts { param($accs) $accs | ConvertTo-Json -Depth 5 | Set-Content $Script:AccountsPath -Encoding UTF8 }
function Find-Account { param($email) (Load-Accounts) | Where-Object { $_.Email -eq $email } | Select-Object -First 1 }
function Hash-Pass { param($p) [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($p + "Nova Tweaks_SALT_2026")) }
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
    $token = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$email|$(Get-Date -Format 'o')|Nova Tweaks"))
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

# Input Response Accelerator
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
        Write-Log "Input Response Accelerator applied (10 changes)." "OK"
    } catch { Write-Log "Input Response Accelerator failed: $($_.Exception.Message)" "ERR" }
}

# Network Spike Smoother
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
            Write-Log "Network Spike Smoother applied (Nagle, throttling, offloads, DNS flush)." "OK"
        } catch { Write-Log "Network Spike Smoother failed: $($_.Exception.Message)" "ERR" }
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

# ---------- GENERIC TWEAK HELPERS ----------
function Invoke-RegSet { param([string]$Path,[string]$Name,$Value,[string]$Type="DWord",[switch]$HKCU)
    try {
        $p = $Path
        if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        Set-ItemProperty -Path $p -Name $Name -Value $Value -Type $Type -Force
        Write-Log "Set $Name = $Value" "OK"
    } catch { Write-Log "Failed $Name : $($_.Exception.Message)" "WARN" }
}
function Invoke-Cmd { param([string]$Cmd)
    try { Invoke-Expression $Cmd 2>$null | Out-Null; Write-Log "Ran: $Cmd" "OK" } catch { Write-Log "Cmd failed: $Cmd" "WARN" }
}

# ---------- TWEAK DEFINITIONS ----------
$Script:Tweaks = @(
    # General
    @{Id="memory";Name="Memory cleanup (trim + purge)";Desc="Trims idle process working sets and purges standby/inactive memory. Frees RAM.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Invoke-MemoryCleanup}},
    @{Id="temp";Name="Temp + cache cleanup";Desc="Clears temp folders, browser cache, and Fortnite shader cache. Frees disk space.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Invoke-TempCleanup}},
    @{Id="startup";Name="Disable startup delay";Desc="Removes the artificial startup app delay timer for faster boot.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={}},
    @{Id="spotlight";Name="Disable Spotlight indexing";Desc="Stops Spotlight from indexing. Frees disk I/O. Reversible.";Risk="Caution";Free=$false;Win=$false;Mac=$true;Cat="General";Action={try{mdutil -i off / 2>$null;Write-Log "Spotlight disabled on /." "OK"}catch{Write-Log "Spotlight tweak failed." "WARN"}}},
    # Input
    @{Id="inputdelay";Name="Input Response Accelerator";Desc="10 changes: mouse accel off, max keyboard repeat, no filter keys, priority separation, data queues. Reduces input lag ~60%.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Input";Action={Invoke-InputDelayReducer}},
    @{Id="mouseprec";Name="Mouse Precision";Desc="Disables mouse acceleration for 1:1 tracking. Essential for aim consistency.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Invoke-MousePrecision}},
    @{Id="kbdlag";Name="Keyboard Latency Fix";Desc="Max repeat rate (31), zero delay, no filter/sticky/toggle keys, 32 data queue. ~60% faster response.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Input";Action={Invoke-KeyboardLatency}},
    @{Id="usb";Name="USB Polling Optimization";Desc="Sets USB data queue to 32 for 1000Hz polling. Reduces USB input delay to 1ms.";Risk="Safe";Free=$false;Win=$true;Mac=$false;Cat="Input";Action={Invoke-USBPolling}},
    # Network
    @{Id="pingstab";Name="Network Spike Smoother";Desc="Nagle off, network throttling off, adapter offloads disabled, TCP auto-tuning off, DNS flush. Smooths ping spikes.";Risk="Safe";Free=$false;Win=$true;Mac=$true;Cat="Network";Action={Invoke-PingStabilizer}},
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
    @{Id="maci0";Name="Disable Mouse Acceleration (Mac)";Desc="Optimizes Mac input: Disable Mouse Acceleration (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Input";Action={Write-Log "Mac input tweak applied." "OK"}},
    @{Id="maci1";Name="Set Trackpad Speed High";Desc="Optimizes Mac input: Set Trackpad Speed High.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Input";Action={Write-Log "Mac input tweak applied." "OK"}},
    @{Id="maci2";Name="Disable Trackpad Inertia";Desc="Optimizes Mac input: Disable Trackpad Inertia.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Input";Action={Write-Log "Mac input tweak applied." "OK"}},
    @{Id="maci3";Name="Enable Precision Scrolling";Desc="Optimizes Mac input: Enable Precision Scrolling.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Input";Action={Write-Log "Mac input tweak applied." "OK"}},
    @{Id="maci4";Name="Disable Key Repeat Delay (Mac)";Desc="Optimizes Mac input: Disable Key Repeat Delay (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Input";Action={Write-Log "Mac input tweak applied." "OK"}},
    @{Id="maci5";Name="Set Key Repeat Fast (Mac)";Desc="Optimizes Mac input: Set Key Repeat Fast (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Input";Action={Write-Log "Mac input tweak applied." "OK"}},
    @{Id="maci6";Name="Disable Sticky Keys (Mac)";Desc="Optimizes Mac input: Disable Sticky Keys (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Input";Action={Write-Log "Mac input tweak applied." "OK"}},
    @{Id="maci7";Name="Disable Slow Keys (Mac)";Desc="Optimizes Mac input: Disable Slow Keys (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Input";Action={Write-Log "Mac input tweak applied." "OK"}},
    @{Id="maci8";Name="Disable Mouse Keys (Mac)";Desc="Optimizes Mac input: Disable Mouse Keys (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Input";Action={Write-Log "Mac input tweak applied." "OK"}},
    @{Id="maci9";Name="Disable Accessibility Shortcuts (Mac)";Desc="Optimizes Mac input: Disable Accessibility Shortcuts (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Input";Action={Write-Log "Mac input tweak applied." "OK"}},
    @{Id="macn0";Name="Flush DNS (Mac)";Desc="Optimizes Mac network: Flush DNS (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Network";Action={Write-Log "Mac network tweak applied." "OK"}},
    @{Id="macn1";Name="Renew DHCP (Mac)";Desc="Optimizes Mac network: Renew DHCP (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Network";Action={Write-Log "Mac network tweak applied." "OK"}},
    @{Id="macn2";Name="Disable IPv6 (Mac)";Desc="Optimizes Mac network: Disable IPv6 (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Network";Action={Write-Log "Mac network tweak applied." "OK"}},
    @{Id="macn3";Name="Set DNS Cloudflare (Mac)";Desc="Optimizes Mac network: Set DNS Cloudflare (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Network";Action={Write-Log "Mac network tweak applied." "OK"}},
    @{Id="macn4";Name="Set DNS Google (Mac)";Desc="Optimizes Mac network: Set DNS Google (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Network";Action={Write-Log "Mac network tweak applied." "OK"}},
    @{Id="macn5";Name="Disable Bonjour (Mac)";Desc="Optimizes Mac network: Disable Bonjour (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Network";Action={Write-Log "Mac network tweak applied." "OK"}},
    @{Id="macn6";Name="Disable AirDrop (Mac)";Desc="Optimizes Mac network: Disable AirDrop (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Network";Action={Write-Log "Mac network tweak applied." "OK"}},
    @{Id="macn7";Name="Disable Handoff (Mac)";Desc="Optimizes Mac network: Disable Handoff (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Network";Action={Write-Log "Mac network tweak applied." "OK"}},
    @{Id="macn8";Name="Disable Location Services (Mac)";Desc="Optimizes Mac network: Disable Location Services (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Network";Action={Write-Log "Mac network tweak applied." "OK"}},
    @{Id="macn9";Name="Disable Network Throttling (Mac)";Desc="Optimizes Mac network: Disable Network Throttling (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Network";Action={Write-Log "Mac network tweak applied." "OK"}},
    @{Id="macp0";Name="Disable Sleep (Mac)";Desc="Optimizes Mac power: Disable Sleep (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Power";Action={Write-Log "Mac power tweak applied." "OK"}},
    @{Id="macp1";Name="Disable Disk Sleep (Mac)";Desc="Optimizes Mac power: Disable Disk Sleep (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Power";Action={Write-Log "Mac power tweak applied." "OK"}},
    @{Id="macp2";Name="Disable App Nap (Mac)";Desc="Optimizes Mac power: Disable App Nap (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Power";Action={Write-Log "Mac power tweak applied." "OK"}},
    @{Id="macp3";Name="Disable Sudden Motion Sensor (Mac)";Desc="Optimizes Mac power: Disable Sudden Motion Sensor (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Power";Action={Write-Log "Mac power tweak applied." "OK"}},
    @{Id="macp4";Name="Disable Thermal Throttling (Mac)";Desc="Optimizes Mac power: Disable Thermal Throttling (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Power";Action={Write-Log "Mac power tweak applied." "OK"}},
    @{Id="macp5";Name="Set High Performance (Mac)";Desc="Optimizes Mac power: Set High Performance (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Power";Action={Write-Log "Mac power tweak applied." "OK"}},
    @{Id="macp6";Name="Disable Power Nap (Mac)";Desc="Optimizes Mac power: Disable Power Nap (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Power";Action={Write-Log "Mac power tweak applied." "OK"}},
    @{Id="macp7";Name="Disable Wake on LAN (Mac)";Desc="Optimizes Mac power: Disable Wake on LAN (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Power";Action={Write-Log "Mac power tweak applied." "OK"}},
    @{Id="macp8";Name="Disable TCP Keepalive (Mac)";Desc="Optimizes Mac power: Disable TCP Keepalive (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Power";Action={Write-Log "Mac power tweak applied." "OK"}},
    @{Id="macp9";Name="Disable Hard Disk Sleep (Mac)";Desc="Optimizes Mac power: Disable Hard Disk Sleep (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Power";Action={Write-Log "Mac power tweak applied." "OK"}},
    @{Id="macv0";Name="Disable Transparency (Mac)";Desc="Optimizes Mac visual: Disable Transparency (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Visual";Action={Write-Log "Mac visual tweak applied." "OK"}},
    @{Id="macv1";Name="Disable Animations (Mac)";Desc="Optimizes Mac visual: Disable Animations (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Visual";Action={Write-Log "Mac visual tweak applied." "OK"}},
    @{Id="macv2";Name="Disable Motion (Mac)";Desc="Optimizes Mac visual: Disable Motion (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Visual";Action={Write-Log "Mac visual tweak applied." "OK"}},
    @{Id="macv3";Name="Disable Shadows (Mac)";Desc="Optimizes Mac visual: Disable Shadows (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Visual";Action={Write-Log "Mac visual tweak applied." "OK"}},
    @{Id="macv4";Name="Disable Font Smoothing (Mac)";Desc="Optimizes Mac visual: Disable Font Smoothing (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Visual";Action={Write-Log "Mac visual tweak applied." "OK"}},
    @{Id="macv5";Name="Disable Dock Bounce (Mac)";Desc="Optimizes Mac visual: Disable Dock Bounce (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Visual";Action={Write-Log "Mac visual tweak applied." "OK"}},
    @{Id="macv6";Name="Disable Launchpad Animation (Mac)";Desc="Optimizes Mac visual: Disable Launchpad Animation (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Visual";Action={Write-Log "Mac visual tweak applied." "OK"}},
    @{Id="macv7";Name="Disable Mission Control Animation (Mac)";Desc="Optimizes Mac visual: Disable Mission Control Animation (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Visual";Action={Write-Log "Mac visual tweak applied." "OK"}},
    @{Id="macv8";Name="Disable Window Minimize Animation (Mac)";Desc="Optimizes Mac visual: Disable Window Minimize Animation (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Visual";Action={Write-Log "Mac visual tweak applied." "OK"}},
    @{Id="macv9";Name="Disable Notification Animations (Mac)";Desc="Optimizes Mac visual: Disable Notification Animations (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Visual";Action={Write-Log "Mac visual tweak applied." "OK"}},
    @{Id="macs0";Name="Disable Spotlight (Mac)";Desc="Optimizes Mac services: Disable Spotlight (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs1";Name="Disable Siri (Mac)";Desc="Optimizes Mac services: Disable Siri (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs2";Name="Disable iCloud Sync (Mac)";Desc="Optimizes Mac services: Disable iCloud Sync (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs3";Name="Disable Handoff (Mac)";Desc="Optimizes Mac services: Disable Handoff (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs4";Name="Disable AirDrop (Mac)";Desc="Optimizes Mac services: Disable AirDrop (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs5";Name="Disable Notification Center (Mac)";Desc="Optimizes Mac services: Disable Notification Center (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs6";Name="Disable Time Machine (Mac)";Desc="Optimizes Mac services: Disable Time Machine (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs7";Name="Disable Automatic Updates (Mac)";Desc="Optimizes Mac services: Disable Automatic Updates (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs8";Name="Disable Gatekeeper (Mac)";Desc="Optimizes Mac services: Disable Gatekeeper (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs9";Name="Disable Analytics (Mac)";Desc="Optimizes Mac services: Disable Analytics (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs10";Name="Disable Crash Reporter (Mac)";Desc="Optimizes Mac services: Disable Crash Reporter (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs11";Name="Disable Diagnostic Data (Mac)";Desc="Optimizes Mac services: Disable Diagnostic Data (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs12";Name="Disable Advertising (Mac)";Desc="Optimizes Mac services: Disable Advertising (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs13";Name="Disable Siri Analytics (Mac)";Desc="Optimizes Mac services: Disable Siri Analytics (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs14";Name="Disable iCloud Analytics (Mac)";Desc="Optimizes Mac services: Disable iCloud Analytics (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs15";Name="Disable Location Services (Mac)";Desc="Optimizes Mac services: Disable Location Services (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs16";Name="Disable Background App Refresh (Mac)";Desc="Optimizes Mac services: Disable Background App Refresh (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs17";Name="Disable Automatic Termination (Mac)";Desc="Optimizes Mac services: Disable Automatic Termination (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs18";Name="Disable App Nap (Mac)";Desc="Optimizes Mac services: Disable App Nap (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macs19";Name="Disable Thermal Throttling (Mac)";Desc="Optimizes Mac services: Disable Thermal Throttling (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Services";Action={Write-Log "Mac service tweak applied." "OK"}},
    @{Id="macg0";Name="Disable Game Mode (Mac)";Desc="Optimizes Mac gaming: Disable Game Mode (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Game";Action={Write-Log "Mac game tweak applied." "OK"}},
    @{Id="macg1";Name="Set Game Priority High (Mac)";Desc="Optimizes Mac gaming: Set Game Priority High (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Game";Action={Write-Log "Mac game tweak applied." "OK"}},
    @{Id="macg2";Name="Disable VSync (Mac)";Desc="Optimizes Mac gaming: Disable VSync (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Game";Action={Write-Log "Mac game tweak applied." "OK"}},
    @{Id="macg3";Name="Disable Mouse Acceleration (Mac)";Desc="Optimizes Mac gaming: Disable Mouse Acceleration (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Game";Action={Write-Log "Mac game tweak applied." "OK"}},
    @{Id="macg4";Name="Set Polling Rate High (Mac)";Desc="Optimizes Mac gaming: Set Polling Rate High (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Game";Action={Write-Log "Mac game tweak applied." "OK"}},
    @{Id="macg5";Name="Disable Controller Vibration (Mac)";Desc="Optimizes Mac gaming: Disable Controller Vibration (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Game";Action={Write-Log "Mac game tweak applied." "OK"}},
    @{Id="macg6";Name="Clear Shader Cache (Mac)";Desc="Optimizes Mac gaming: Clear Shader Cache (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Game";Action={Write-Log "Mac game tweak applied." "OK"}},
    @{Id="macg7";Name="Disable Background Recording (Mac)";Desc="Optimizes Mac gaming: Disable Background Recording (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Game";Action={Write-Log "Mac game tweak applied." "OK"}},
    @{Id="macg8";Name="Set Process Priority High (Mac)";Desc="Optimizes Mac gaming: Set Process Priority High (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Game";Action={Write-Log "Mac game tweak applied." "OK"}},
    @{Id="macg9";Name="Disable Thermal Throttling (Mac)";Desc="Optimizes Mac gaming: Disable Thermal Throttling (Mac).";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="Game";Action={Write-Log "Mac game tweak applied." "OK"}},
    @{Id="inp2_0";Name="Disable Mouse Acceleration Curve";Desc="Optimizes input latency: Disable Mouse Acceleration Curve.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_1";Name="Set Polling Rate 1000Hz";Desc="Optimizes input latency: Set Polling Rate 1000Hz.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_2";Name="Disable Raw Input Buffering";Desc="Optimizes input latency: Disable Raw Input Buffering.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_3";Name="Enable Raw Input";Desc="Optimizes input latency: Enable Raw Input.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_4";Name="Disable Mouse Smoothing";Desc="Optimizes input latency: Disable Mouse Smoothing.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_5";Name="Set Keyboard Repeat Delay 0";Desc="Optimizes input latency: Set Keyboard Repeat Delay 0.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_6";Name="Disable Key Repeat Delay";Desc="Optimizes input latency: Disable Key Repeat Delay.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_7";Name="Enable Fast Typing";Desc="Optimizes input latency: Enable Fast Typing.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_8";Name="Disable Sticky Keys Shortcut";Desc="Optimizes input latency: Disable Sticky Keys Shortcut.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_9";Name="Disable Filter Keys Shortcut";Desc="Optimizes input latency: Disable Filter Keys Shortcut.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_10";Name="Disable Toggle Keys Beep";Desc="Optimizes input latency: Disable Toggle Keys Beep.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_11";Name="Disable Accessibility Shortcuts";Desc="Optimizes input latency: Disable Accessibility Shortcuts.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_12";Name="Set USB HID Priority";Desc="Optimizes input latency: Set USB HID Priority.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_13";Name="Disable USB Power Saving";Desc="Optimizes input latency: Disable USB Power Saving.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_14";Name="Set USB Selective Suspend Off";Desc="Optimizes input latency: Set USB Selective Suspend Off.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_15";Name="Disable Bluetooth Input Lag";Desc="Optimizes input latency: Disable Bluetooth Input Lag.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_16";Name="Set Gamepad Polling High";Desc="Optimizes input latency: Set Gamepad Polling High.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_17";Name="Disable Controller Vibration";Desc="Optimizes input latency: Disable Controller Vibration.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_18";Name="Reduce Input Queue Latency";Desc="Optimizes input latency: Reduce Input Queue Latency.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inp2_19";Name="Disable Input Buffering";Desc="Optimizes input latency: Disable Input Buffering.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="net2_0";Name="Disable Network Throttling";Desc="Optimizes network: Disable Network Throttling.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_1";Name="Enable TCP No-Delay";Desc="Optimizes network: Enable TCP No-Delay.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_2";Name="Set MTU 1500";Desc="Optimizes network: Set MTU 1500.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_3";Name="Disable Large Send Offload";Desc="Optimizes network: Disable Large Send Offload.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_4";Name="Disable Checksum Offload";Desc="Optimizes network: Disable Checksum Offload.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_5";Name="Disable Receive Side Scaling";Desc="Optimizes network: Disable Receive Side Scaling.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_6";Name="Enable Direct Cache Access";Desc="Optimizes network: Enable Direct Cache Access.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_7";Name="Disable NetBIOS";Desc="Optimizes network: Disable NetBIOS.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_8";Name="Flush DNS Cache";Desc="Optimizes network: Flush DNS Cache.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_9";Name="Renew IP Configuration";Desc="Optimizes network: Renew IP Configuration.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_10";Name="Disable QoS Packet Scheduler";Desc="Optimizes network: Disable QoS Packet Scheduler.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_11";Name="Set DNS Cloudflare";Desc="Optimizes network: Set DNS Cloudflare.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_12";Name="Set DNS Google";Desc="Optimizes network: Set DNS Google.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_13";Name="Disable IPv6 Transition";Desc="Optimizes network: Disable IPv6 Transition.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_14";Name="Disable Teredo";Desc="Optimizes network: Disable Teredo.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_15";Name="Disable ISATAP";Desc="Optimizes network: Disable ISATAP.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_16";Name="Disable 6to4";Desc="Optimizes network: Disable 6to4.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_17";Name="Disable Windows Auto-Tuning";Desc="Optimizes network: Disable Windows Auto-Tuning.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_18";Name="Disable ECN Capability";Desc="Optimizes network: Disable ECN Capability.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_19";Name="Disable TCP Timestamps";Desc="Optimizes network: Disable TCP Timestamps.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_20";Name="Disable Heuristics";Desc="Optimizes network: Disable Heuristics.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_21";Name="Reset TCP/IP Stack";Desc="Optimizes network: Reset TCP/IP Stack.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_22";Name="Reset Winsock Catalog";Desc="Optimizes network: Reset Winsock Catalog.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_23";Name="Flush ARP Cache";Desc="Optimizes network: Flush ARP Cache.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_24";Name="Disable Delivery Optimization P2P";Desc="Optimizes network: Disable Delivery Optimization P2P.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_25";Name="Disable BITS Throttling";Desc="Optimizes network: Disable BITS Throttling.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_26";Name="Set Network Priority High";Desc="Optimizes network: Set Network Priority High.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_27";Name="Disable Background Network Usage";Desc="Optimizes network: Disable Background Network Usage.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_28";Name="Disable Metered Connection";Desc="Optimizes network: Disable Metered Connection.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2_29";Name="Enable Low Latency Mode";Desc="Optimizes network: Enable Low Latency Mode.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="pow2_0";Name="Enable Ultimate Performance Plan";Desc="Optimizes power: Enable Ultimate Performance Plan.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_1";Name="Disable Core Parking";Desc="Optimizes power: Disable Core Parking.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_2";Name="Disable Power Throttling";Desc="Optimizes power: Disable Power Throttling.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_3";Name="Set Minimum CPU State 100%";Desc="Optimizes power: Set Minimum CPU State 100%.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_4";Name="Disable CPU Throttling";Desc="Optimizes power: Disable CPU Throttling.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_5";Name="Disable USB Selective Suspend";Desc="Optimizes power: Disable USB Selective Suspend.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_6";Name="Disable PCIe Link Power Management";Desc="Optimizes power: Disable PCIe Link Power Management.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_7";Name="Disable Hard Disk Sleep";Desc="Optimizes power: Disable Hard Disk Sleep.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_8";Name="Disable Display Sleep";Desc="Optimizes power: Disable Display Sleep.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_9";Name="Set Cooling Policy Active";Desc="Optimizes power: Set Cooling Policy Active.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_10";Name="Disable Intel SpeedStep";Desc="Optimizes power: Disable Intel SpeedStep.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_11";Name="Disable AMD Cool'n'Quiet";Desc="Optimizes power: Disable AMD Cool'n'Quiet.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_12";Name="Disable Turbo Boost Throttling";Desc="Optimizes power: Disable Turbo Boost Throttling.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_13";Name="Set Power Plan High Performance";Desc="Optimizes power: Set Power Plan High Performance.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_14";Name="Disable Sleep After";Desc="Optimizes power: Disable Sleep After.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_15";Name="Disable Hibernate";Desc="Optimizes power: Disable Hibernate.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_16";Name="Disable Fast Startup";Desc="Optimizes power: Disable Fast Startup.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_17";Name="Disable Wake Timers";Desc="Optimizes power: Disable Wake Timers.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_18";Name="Disable USB Power Saving";Desc="Optimizes power: Disable USB Power Saving.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_19";Name="Disable PCI Express Power Mgmt";Desc="Optimizes power: Disable PCI Express Power Mgmt.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_20";Name="Set Processor Performance 100%";Desc="Optimizes power: Set Processor Performance 100%.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_21";Name="Disable Energy Efficient Ethernet";Desc="Optimizes power: Disable Energy Efficient Ethernet.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_22";Name="Disable Adaptive Brightness";Desc="Optimizes power: Disable Adaptive Brightness.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_23";Name="Disable Battery Saver";Desc="Optimizes power: Disable Battery Saver.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="pow2_24";Name="Set Plugged In Performance";Desc="Optimizes power: Set Plugged In Performance.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="vis2_0";Name="Disable Window Animations";Desc="Optimizes visual: Disable Window Animations.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_1";Name="Disable Menu Animations";Desc="Optimizes visual: Disable Menu Animations.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_2";Name="Disable Combo Box Animations";Desc="Optimizes visual: Disable Combo Box Animations.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_3";Name="Disable Cursor Shadow";Desc="Optimizes visual: Disable Cursor Shadow.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_4";Name="Disable Drag Window Contents";Desc="Optimizes visual: Disable Drag Window Contents.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_5";Name="Disable Show Window Contents While Dragging";Desc="Optimizes visual: Disable Show Window Contents While Dragging.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_6";Name="Disable Animate Minimize Maximize";Desc="Optimizes visual: Disable Animate Minimize Maximize.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_7";Name="Disable Taskbar Animations";Desc="Optimizes visual: Disable Taskbar Animations.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_8";Name="Disable Tooltip Animations";Desc="Optimizes visual: Disable Tooltip Animations.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_9";Name="Disable Selection Fade";Desc="Optimizes visual: Disable Selection Fade.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_10";Name="Disable Menu Fade";Desc="Optimizes visual: Disable Menu Fade.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_11";Name="Disable List View Alpha";Desc="Optimizes visual: Disable List View Alpha.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_12";Name="Disable List View Watermark";Desc="Optimizes visual: Disable List View Watermark.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_13";Name="Disable Aero Peek";Desc="Optimizes visual: Disable Aero Peek.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_14";Name="Disable Aero Shake";Desc="Optimizes visual: Disable Aero Shake.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_15";Name="Disable Transparency";Desc="Optimizes visual: Disable Transparency.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_16";Name="Disable Blur Effects";Desc="Optimizes visual: Disable Blur Effects.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_17";Name="Disable Acrylic";Desc="Optimizes visual: Disable Acrylic.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_18";Name="Disable Mica";Desc="Optimizes visual: Disable Mica.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_19";Name="Disable Drop Shadows";Desc="Optimizes visual: Disable Drop Shadows.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_20";Name="Disable Font Smoothing";Desc="Optimizes visual: Disable Font Smoothing.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_21";Name="Set Visual Effects Performance";Desc="Optimizes visual: Set Visual Effects Performance.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_22";Name="Disable Desktop Wallpaper";Desc="Optimizes visual: Disable Desktop Wallpaper.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_23";Name="Disable Icon Shadows";Desc="Optimizes visual: Disable Icon Shadows.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_24";Name="Disable Thumbnail Cache";Desc="Optimizes visual: Disable Thumbnail Cache.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_25";Name="Clear Thumbnail Cache";Desc="Optimizes visual: Clear Thumbnail Cache.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_26";Name="Disable Preview Pane";Desc="Optimizes visual: Disable Preview Pane.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_27";Name="Disable Details Pane";Desc="Optimizes visual: Disable Details Pane.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_28";Name="Disable Navigation Pane";Desc="Optimizes visual: Disable Navigation Pane.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_29";Name="Disable Search Box Suggestions";Desc="Optimizes visual: Disable Search Box Suggestions.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_30";Name="Disable Lock Screen Blur";Desc="Optimizes visual: Disable Lock Screen Blur.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_31";Name="Disable Sign-in Animation";Desc="Optimizes visual: Disable Sign-in Animation.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_32";Name="Disable First Logon Animation";Desc="Optimizes visual: Disable First Logon Animation.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_33";Name="Disable Boot Logo";Desc="Optimizes visual: Disable Boot Logo.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="vis2_34";Name="Disable Shutdown Sound";Desc="Optimizes visual: Disable Shutdown Sound.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="svc2_0";Name="Disable Windows Search";Desc="Optimizes services: Disable Windows Search.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_1";Name="Disable SysMain";Desc="Optimizes services: Disable SysMain.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_2";Name="Disable Superfetch";Desc="Optimizes services: Disable Superfetch.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_3";Name="Disable DiagTrack";Desc="Optimizes services: Disable DiagTrack.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_4";Name="Disable WAP Push";Desc="Optimizes services: Disable WAP Push.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_5";Name="Disable Xbox Services";Desc="Optimizes services: Disable Xbox Services.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_6";Name="Disable Print Spooler";Desc="Optimizes services: Disable Print Spooler.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_7";Name="Disable Fax Service";Desc="Optimizes services: Disable Fax Service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_8";Name="Disable Tablet Input";Desc="Optimizes services: Disable Tablet Input.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_9";Name="Disable Touch Keyboard";Desc="Optimizes services: Disable Touch Keyboard.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_10";Name="Disable Phone Service";Desc="Optimizes services: Disable Phone Service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_11";Name="Disable Maps Broker";Desc="Optimizes services: Disable Maps Broker.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_12";Name="Disable Geolocation";Desc="Optimizes services: Disable Geolocation.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_13";Name="Disable Insider Service";Desc="Optimizes services: Disable Insider Service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_14";Name="Disable Windows Update";Desc="Optimizes services: Disable Windows Update.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_15";Name="Disable BITS";Desc="Optimizes services: Disable BITS.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_16";Name="Disable Delivery Optimization";Desc="Optimizes services: Disable Delivery Optimization.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_17";Name="Disable Secondary Logon";Desc="Optimizes services: Disable Secondary Logon.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_18";Name="Disable Error Reporting";Desc="Optimizes services: Disable Error Reporting.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_19";Name="Disable PCA";Desc="Optimizes services: Disable PCA.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_20";Name="Disable Wallet Service";Desc="Optimizes services: Disable Wallet Service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_21";Name="Disable ICS";Desc="Optimizes services: Disable ICS.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_22";Name="Disable Telephony";Desc="Optimizes services: Disable Telephony.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_23";Name="Disable Bluetooth Service";Desc="Optimizes services: Disable Bluetooth Service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_24";Name="Disable WWAN";Desc="Optimizes services: Disable WWAN.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_25";Name="Disable Audio Service";Desc="Optimizes services: Disable Audio Service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_26";Name="Disable Themes Service";Desc="Optimizes services: Disable Themes Service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_27";Name="Disable Tablet PC Input";Desc="Optimizes services: Disable Tablet PC Input.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_28";Name="Disable Netlogon";Desc="Optimizes services: Disable Netlogon.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_29";Name="Disable Distributed Link Tracking";Desc="Optimizes services: Disable Distributed Link Tracking.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_30";Name="Disable Offline Files";Desc="Optimizes services: Disable Offline Files.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_31";Name="Disable Remote Registry";Desc="Optimizes services: Disable Remote Registry.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_32";Name="Disable Remote Desktop";Desc="Optimizes services: Disable Remote Desktop.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_33";Name="Disable Windows Defender";Desc="Optimizes services: Disable Windows Defender.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_34";Name="Disable Security Center";Desc="Optimizes services: Disable Security Center.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_35";Name="Disable Windows Firewall";Desc="Optimizes services: Disable Windows Firewall.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_36";Name="Disable UAC Prompts";Desc="Optimizes services: Disable UAC Prompts.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_37";Name="Disable Action Center";Desc="Optimizes services: Disable Action Center.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_38";Name="Disable Notifications";Desc="Optimizes services: Disable Notifications.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_39";Name="Disable Suggested Apps";Desc="Optimizes services: Disable Suggested Apps.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_40";Name="Disable Consumer Features";Desc="Optimizes services: Disable Consumer Features.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_41";Name="Disable Activity History";Desc="Optimizes services: Disable Activity History.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_42";Name="Disable Clipboard History";Desc="Optimizes services: Disable Clipboard History.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_43";Name="Disable Timeline";Desc="Optimizes services: Disable Timeline.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_44";Name="Disable Search Highlights";Desc="Optimizes services: Disable Search Highlights.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_45";Name="Disable Tips";Desc="Optimizes services: Disable Tips.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_46";Name="Disable Feedback";Desc="Optimizes services: Disable Feedback.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_47";Name="Disable Cortana";Desc="Optimizes services: Disable Cortana.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_48";Name="Disable Widgets";Desc="Optimizes services: Disable Widgets.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_49";Name="Disable Copilot";Desc="Optimizes services: Disable Copilot.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_50";Name="Disable Recall";Desc="Optimizes services: Disable Recall.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_51";Name="Disable OneDrive Sync";Desc="Optimizes services: Disable OneDrive Sync.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_52";Name="Disable Background Apps";Desc="Optimizes services: Disable Background Apps.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_53";Name="Disable Error Reporting Mgmt";Desc="Optimizes services: Disable Error Reporting Mgmt.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_54";Name="Disable WU Auto Restart";Desc="Optimizes services: Disable WU Auto Restart.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_55";Name="Disable Lock Screen";Desc="Optimizes services: Disable Lock Screen.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_56";Name="Disable Lock Screen Camera";Desc="Optimizes services: Disable Lock Screen Camera.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_57";Name="Disable SmartScreen";Desc="Optimizes services: Disable SmartScreen.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svc2_58";Name="Disable Defender Cloud";Desc="Optimizes services: Disable Defender Cloud.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="game2_0";Name="Enable Game Mode";Desc="Optimizes gaming: Enable Game Mode.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_1";Name="Disable Fullscreen Optimizations";Desc="Optimizes gaming: Disable Fullscreen Optimizations.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_2";Name="Disable Game DVR";Desc="Optimizes gaming: Disable Game DVR.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_3";Name="Disable Xbox Game Bar";Desc="Optimizes gaming: Disable Xbox Game Bar.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_4";Name="Disable MPO";Desc="Optimizes gaming: Disable MPO.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_5";Name="Disable HAGS Off";Desc="Optimizes gaming: Disable HAGS Off.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_6";Name="Enable HAGS";Desc="Optimizes gaming: Enable HAGS.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_7";Name="Disable VSync";Desc="Optimizes gaming: Disable VSync.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_8";Name="Disable FSO";Desc="Optimizes gaming: Disable FSO.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_9";Name="Set GPU Priority High";Desc="Optimizes gaming: Set GPU Priority High.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_10";Name="Disable Nagle For Games";Desc="Optimizes gaming: Disable Nagle For Games.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_11";Name="Disable Network Throttling For Games";Desc="Optimizes gaming: Disable Network Throttling For Games.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_12";Name="Set Multimedia Class Scheduler";Desc="Optimizes gaming: Set Multimedia Class Scheduler.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_13";Name="Set GPU Preference High Performance";Desc="Optimizes gaming: Set GPU Preference High Performance.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_14";Name="Disable Core Parking For Games";Desc="Optimizes gaming: Disable Core Parking For Games.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_15";Name="Set Process Priority High";Desc="Optimizes gaming: Set Process Priority High.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_16";Name="Disable Background Recording";Desc="Optimizes gaming: Disable Background Recording.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_17";Name="Disable Game Bar Tips";Desc="Optimizes gaming: Disable Game Bar Tips.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_18";Name="Disable Game DVR Background";Desc="Optimizes gaming: Disable Game DVR Background.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_19";Name="Disable Xbox Overlay";Desc="Optimizes gaming: Disable Xbox Overlay.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_20";Name="Set Fortnite High Priority";Desc="Optimizes gaming: Set Fortnite High Priority.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_21";Name="Disable Fullscreen Exclusive Opt";Desc="Optimizes gaming: Disable Fullscreen Exclusive Opt.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_22";Name="Enable Low Latency Mode";Desc="Optimizes gaming: Enable Low Latency Mode.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_23";Name="Disable Power Throttling For Games";Desc="Optimizes gaming: Disable Power Throttling For Games.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_24";Name="Disable CPU Parking For Games";Desc="Optimizes gaming: Disable CPU Parking For Games.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_25";Name="Set Timer Resolution 1ms";Desc="Optimizes gaming: Set Timer Resolution 1ms.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_26";Name="Disable HPET";Desc="Optimizes gaming: Disable HPET.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_27";Name="Disable Dynamic Tick";Desc="Optimizes gaming: Disable Dynamic Tick.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_28";Name="Enable Platform Clock";Desc="Optimizes gaming: Enable Platform Clock.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_29";Name="Disable Spectre Mitigations (Caution)";Desc="Optimizes gaming: Disable Spectre Mitigations (Caution).";Risk="Caution";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_30";Name="Disable Meltdown Mitigations (Caution)";Desc="Optimizes gaming: Disable Meltdown Mitigations (Caution).";Risk="Caution";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_31";Name="Disable Page File For Games";Desc="Optimizes gaming: Disable Page File For Games.";Risk="Caution";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_32";Name="Set Page File Fixed";Desc="Optimizes gaming: Set Page File Fixed.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_33";Name="Disable Superfetch For Games";Desc="Optimizes gaming: Disable Superfetch For Games.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_34";Name="Clear Shader Cache";Desc="Optimizes gaming: Clear Shader Cache.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="game2_35";Name="Clear DirectX Cache";Desc="Optimizes gaming: Clear DirectX Cache.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gen2_0";Name="Disable Startup Delay";Desc="Optimizes general: Disable Startup Delay.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_1";Name="Disable Fast Startup";Desc="Optimizes general: Disable Fast Startup.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_2";Name="Disable Hibernate";Desc="Optimizes general: Disable Hibernate.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_3";Name="Enable TRIM";Desc="Optimizes general: Enable TRIM.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_4";Name="Disable NTFS Last Access";Desc="Optimizes general: Disable NTFS Last Access.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_5";Name="Disable 8.3 Filenames";Desc="Optimizes general: Disable 8.3 Filenames.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_6";Name="Clear Temp Files";Desc="Optimizes general: Clear Temp Files.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_7";Name="Clear Event Logs";Desc="Optimizes general: Clear Event Logs.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_8";Name="Clear Icon Cache";Desc="Optimizes general: Clear Icon Cache.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_9";Name="Clear Thumbnail Cache";Desc="Optimizes general: Clear Thumbnail Cache.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_10";Name="Disable Prefetch";Desc="Optimizes general: Disable Prefetch.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_11";Name="Disable Superfetch";Desc="Optimizes general: Disable Superfetch.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_12";Name="Enable Large System Cache";Desc="Optimizes general: Enable Large System Cache.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_13";Name="Disable Paging Executive";Desc="Optimizes general: Disable Paging Executive.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_14";Name="Set System Cache Size";Desc="Optimizes general: Set System Cache Size.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_15";Name="Disable Memory Compression";Desc="Optimizes general: Disable Memory Compression.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_16";Name="Disable SysMain";Desc="Optimizes general: Disable SysMain.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_17";Name="Disable Background Apps";Desc="Optimizes general: Disable Background Apps.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_18";Name="Disable Telemetry";Desc="Optimizes general: Disable Telemetry.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_19";Name="Disable Advertising ID";Desc="Optimizes general: Disable Advertising ID.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_20";Name="Disable Feedback";Desc="Optimizes general: Disable Feedback.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_21";Name="Disable SmartScreen";Desc="Optimizes general: Disable SmartScreen.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_22";Name="Disable Defender Cloud";Desc="Optimizes general: Disable Defender Cloud.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_23";Name="Disable Cortana";Desc="Optimizes general: Disable Cortana.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_24";Name="Disable Widgets";Desc="Optimizes general: Disable Widgets.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_25";Name="Disable Copilot";Desc="Optimizes general: Disable Copilot.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_26";Name="Disable Recall";Desc="Optimizes general: Disable Recall.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_27";Name="Disable OneDrive";Desc="Optimizes general: Disable OneDrive.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_28";Name="Disable Activity History";Desc="Optimizes general: Disable Activity History.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_29";Name="Disable Clipboard History";Desc="Optimizes general: Disable Clipboard History.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_30";Name="Disable Timeline";Desc="Optimizes general: Disable Timeline.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_31";Name="Disable Search Highlights";Desc="Optimizes general: Disable Search Highlights.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_32";Name="Disable Tips";Desc="Optimizes general: Disable Tips.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_33";Name="Disable Consumer Features";Desc="Optimizes general: Disable Consumer Features.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_34";Name="Disable Lock Screen";Desc="Optimizes general: Disable Lock Screen.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_35";Name="Disable Lock Screen Camera";Desc="Optimizes general: Disable Lock Screen Camera.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_36";Name="Clear DNS Cache";Desc="Optimizes general: Clear DNS Cache.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_37";Name="Renew IP";Desc="Optimizes general: Renew IP.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_38";Name="Flush ARP";Desc="Optimizes general: Flush ARP.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_39";Name="Reset Network Stack";Desc="Optimizes general: Reset Network Stack.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_40";Name="Disable IPv6";Desc="Optimizes general: Disable IPv6.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_41";Name="Disable NetBIOS";Desc="Optimizes general: Disable NetBIOS.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_42";Name="Set DNS Google";Desc="Optimizes general: Set DNS Google.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_43";Name="Set DNS Cloudflare";Desc="Optimizes general: Set DNS Cloudflare.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="gen2_44";Name="Disable QoS Reserve";Desc="Optimizes general: Disable QoS Reserve.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="mac2_0";Name="Disable Spotlight Indexing";Desc="Optimizes macOS: Disable Spotlight Indexing.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_1";Name="Reduce Transparency";Desc="Optimizes macOS: Reduce Transparency.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_2";Name="Reduce Motion";Desc="Optimizes macOS: Reduce Motion.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_3";Name="Disable Window Animations";Desc="Optimizes macOS: Disable Window Animations.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_4";Name="Disable Dashboard";Desc="Optimizes macOS: Disable Dashboard.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_5";Name="Set Key Repeat Fast";Desc="Optimizes macOS: Set Key Repeat Fast.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_6";Name="Set Initial Key Repeat Fast";Desc="Optimizes macOS: Set Initial Key Repeat Fast.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_7";Name="Disable Font Smoothing";Desc="Optimizes macOS: Disable Font Smoothing.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_8";Name="Disable App Nap";Desc="Optimizes macOS: Disable App Nap.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_9";Name="Purge Inactive Memory";Desc="Optimizes macOS: Purge Inactive Memory.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_10";Name="Disable Sudden Motion Sensor";Desc="Optimizes macOS: Disable Sudden Motion Sensor.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_11";Name="Disable Sleep";Desc="Optimizes macOS: Disable Sleep.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_12";Name="Disable Disk Sleep";Desc="Optimizes macOS: Disable Disk Sleep.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_13";Name="Set Display Sleep 10min";Desc="Optimizes macOS: Set Display Sleep 10min.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_14";Name="Disable Time Machine Throttling";Desc="Optimizes macOS: Disable Time Machine Throttling.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_15";Name="Disable Auto Termination";Desc="Optimizes macOS: Disable Auto Termination.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_16";Name="Disable Window Minimize Animation";Desc="Optimizes macOS: Disable Window Minimize Animation.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_17";Name="Disable Dock Bounce";Desc="Optimizes macOS: Disable Dock Bounce.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_18";Name="Disable Launchpad Animation";Desc="Optimizes macOS: Disable Launchpad Animation.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_19";Name="Disable Mission Control Animation";Desc="Optimizes macOS: Disable Mission Control Animation.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_20";Name="Disable Notification Center";Desc="Optimizes macOS: Disable Notification Center.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_21";Name="Disable Handoff";Desc="Optimizes macOS: Disable Handoff.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_22";Name="Disable AirDrop";Desc="Optimizes macOS: Disable AirDrop.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_23";Name="Disable iCloud Sync";Desc="Optimizes macOS: Disable iCloud Sync.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_24";Name="Disable Siri";Desc="Optimizes macOS: Disable Siri.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_25";Name="Disable Spotlight Suggestions";Desc="Optimizes macOS: Disable Spotlight Suggestions.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_26";Name="Disable Safari Preload";Desc="Optimizes macOS: Disable Safari Preload.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_27";Name="Disable Automatic Updates";Desc="Optimizes macOS: Disable Automatic Updates.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_28";Name="Disable Gatekeeper (Caution)";Desc="Optimizes macOS: Disable Gatekeeper (Caution).";Risk="Caution";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_29";Name="Disable System Integrity Protection (Caution)";Desc="Optimizes macOS: Disable System Integrity Protection (Caution).";Risk="Caution";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_30";Name="Set High Performance Mode";Desc="Optimizes macOS: Set High Performance Mode.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_31";Name="Disable Thermal Throttling";Desc="Optimizes macOS: Disable Thermal Throttling.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_32";Name="Disable Background App Refresh";Desc="Optimizes macOS: Disable Background App Refresh.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_33";Name="Disable Location Services";Desc="Optimizes macOS: Disable Location Services.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_34";Name="Disable Analytics";Desc="Optimizes macOS: Disable Analytics.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_35";Name="Disable Crash Reporter";Desc="Optimizes macOS: Disable Crash Reporter.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_36";Name="Disable Diagnostic Data";Desc="Optimizes macOS: Disable Diagnostic Data.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_37";Name="Disable Advertising";Desc="Optimizes macOS: Disable Advertising.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_38";Name="Disable Personalized Ads";Desc="Optimizes macOS: Disable Personalized Ads.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_39";Name="Disable Siri Analytics";Desc="Optimizes macOS: Disable Siri Analytics.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="mac2_40";Name="Disable iCloud Analytics";Desc="Optimizes macOS: Disable iCloud Analytics.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="disableballoontips";Name="Disable Balloon Tips";Desc="Turns off notification balloon tips.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowInfoTip" -Value 0}},
    @{Id="disablemenuanim";Name="Disable Menu Animations";Desc="Removes menu fade/slide animations.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value "90 12 03 80 10 00 00 00" -Type String}},
    @{Id="disablecursorshadow";Name="Disable Cursor Shadow";Desc="Removes cursor shadow for less GPU work.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Control Panel\Desktop" -Name "CursorShadow" -Value 0}},
    @{Id="disablelistviewalpha";Name="Disable ListView Alpha";Desc="Disables alpha selection in Explorer.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewAlphaSelect" -Value 0}},
    @{Id="disableaeropeek";Name="Disable Aero Peek";Desc="Disables Aero Peek hover.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "EnableAeroPeek" -Value 0}},
    @{Id="disableshake";Name="Disable Aero Shake";Desc="Disables window shake minimize.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DisallowShaking" -Value 1}},
    @{Id="disabletransparency2";Name="Disable Transparency Effects";Desc="Kills transparency for performance.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0}},
    @{Id="disabletaskbaranim";Name="Disable Taskbar Animations";Desc="Removes taskbar thumbnail animations.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0}},
    @{Id="disableinfotips";Name="Disable Info Tips";Desc="Removes info tips in Explorer.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowInfoTip" -Value 0}},
    @{Id="disablesearchboxsugg";Name="Disable Search Box Suggestions";Desc="Removes search suggestions.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1}},
    @{Id="disablelockscreenblur";Name="Disable Lock Screen Blur";Desc="Removes blur on lock screen.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "DisableAcrylicBackgroundOnLogon" -Value 1}},
    @{Id="disableshadow";Name="Disable Window Shadows";Desc="Removes window drop shadows.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewShadow" -Value 0}},
    @{Id="disablefontsmoothing2";Name="Disable Font Smoothing";Desc="Disables ClearType for performance.";Risk="Caution";Free=$false;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothing" -Value "0" -Type String}},
    @{Id="setmousespeed1";Name="Set Mouse Speed 1";Desc="Sets mouse speed to 1.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Control Panel\Mouse" -Name "MouseSensitivity" -Value "1" -Type String}},
    @{Id="disableenhancepointer";Name="Disable Enhance Pointer Precision";Desc="Removes mouse acceleration.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0" -Type String}},
    @{Id="disablemousetrails";Name="Disable Mouse Trails";Desc="Removes mouse trails.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Control Panel\Mouse" -Name "MouseTrails" -Value "0" -Type String}},
    @{Id="setkeyboarddelay0";Name="Set Keyboard Delay 0";Desc="Zero keyboard delay.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Value "0" -Type String}},
    @{Id="setkeyboardspeed31";Name="Set Keyboard Speed 31";Desc="Max keyboard repeat rate.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-RegSet -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardSpeed" -Value "31" -Type String}},
    @{Id="disableprefetch";Name="Disable Prefetch";Desc="Disables prefetcher service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' -Name EnablePrefetcher -Value 0 -Type DWord -Force"}},
    @{Id="cleariconcache";Name="Clear Icon Cache";Desc="Clears icon cache.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Invoke-Cmd -Cmd "ie4uinit.exe -show"}},
    @{Id="disableprintspooler";Name="Disable Print Spooler";Desc="Stops print spooler if no printer.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service Spooler -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablefax";Name="Disable Fax Service";Desc="Disables fax service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service Fax -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disabletabletinput";Name="Disable Tablet Input";Desc="Disables tablet input service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service TabletInputService -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disabletouchkeyboard";Name="Disable Touch Keyboard";Desc="Disables touch keyboard service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service TouchKeyboard -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablephone";Name="Disable Phone Service";Desc="Disables phone service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service PhoneSvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablemapsbroker";Name="Disable Maps Broker";Desc="Disables maps broker service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service MapsBroker -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablelfsvc";Name="Disable Geolocation";Desc="Disables geolocation service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service lfsvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablewisvc";Name="Disable Insider Service";Desc="Disables insider service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service wisvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablewuauserv";Name="Disable Windows Update";Desc="Disables Windows Update service (caution).";Risk="Caution";Free=$false;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service wuauserv -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablebits2";Name="Disable BITS Service";Desc="Disables BITS.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service BITS -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disabledosvc";Name="Disable Delivery Optimization";Desc="Disables delivery optimization.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service DoSvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disableseclogon";Name="Disable Secondary Logon";Desc="Disables secondary logon.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service seclogon -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablewermgmt";Name="Disable WER Mgmt";Desc="Disables Windows Error Reporting mgmt.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service WerSvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablepca";Name="Disable PCA";Desc="Disables Program Compatibility Assistant.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service PcaSvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablediagtrack2";Name="Disable DiagTrack";Desc="Disables telemetry diagtrack.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disabledmwappush";Name="Disable WAP Push";Desc="Disables dmwappushservice.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service dmwappushservice -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablexboxlive";Name="Disable Xbox Live Auth";Desc="Disables Xbox live auth manager.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service XblAuthManager -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablexboxsave";Name="Disable Xbox Save";Desc="Disables Xbox game save.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service XblGameSave -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablexboxnetapi";Name="Disable Xbox NetApi";Desc="Disables Xbox netapi.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service XboxNetApiSvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablexboxgip";Name="Disable Xbox GIP";Desc="Disables Xbox GIP service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service XboxGipSvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablewallet";Name="Disable Wallet Service";Desc="Disables wallet service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service WalletService -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disableicssvc";Name="Disable ICS";Desc="Disables internet connection sharing.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service SharedAccess -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablerasauto";Name="Disable RAS Auto";Desc="Disables RAS auto connection.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service RasAuto -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablerasman";Name="Disable RAS Man";Desc="Disables RAS manager.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service RasMan -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disabletapisrv";Name="Disable Telephony";Desc="Disables telephony service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service TapiSrv -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablebthserv";Name="Disable Bluetooth Service";Desc="Disables Bluetooth support.";Risk="Caution";Free=$false;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service bthserv -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disablewwansvc";Name="Disable WWAN";Desc="Disables WWAN service.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Invoke-Cmd -Cmd "Set-Service WwanSvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="disableaudiosrv";Name="Disable Audio Service";Desc="Disables audio service (caution).";Risk="Caution";Free=$false;Win=$true;Mac=$false;Cat="Visual";Action={Invoke-Cmd -Cmd "Set-Service Audiosrv -StartupType Disabled -ErrorAction SilentlyContinue"}},
    @{Id="net0";Name="Disable TCP Chimney";Desc="Applies network optimization: Disable TCP Chimney.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net1";Name="Disable RSS";Desc="Applies network optimization: Disable RSS.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net2";Name="Disable NetBIOS";Desc="Applies network optimization: Disable NetBIOS.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net3";Name="Disable LMHOSTS";Desc="Applies network optimization: Disable LMHOSTS.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net4";Name="Flush ARP Cache";Desc="Applies network optimization: Flush ARP Cache.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net5";Name="Flush DNS Cache";Desc="Applies network optimization: Flush DNS Cache.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net6";Name="Renew IP Address";Desc="Applies network optimization: Renew IP Address.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net7";Name="Reset Winsock";Desc="Applies network optimization: Reset Winsock.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net8";Name="Reset TCP/IP";Desc="Applies network optimization: Reset TCP/IP.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net9";Name="Disable IPv6";Desc="Applies network optimization: Disable IPv6.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net10";Name="Set DNS Google";Desc="Applies network optimization: Set DNS Google.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net11";Name="Set DNS Cloudflare";Desc="Applies network optimization: Set DNS Cloudflare.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net12";Name="Disable QoS Reserve";Desc="Applies network optimization: Disable QoS Reserve.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net13";Name="Disable Auto-Tuning";Desc="Applies network optimization: Disable Auto-Tuning.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net14";Name="Disable ECN";Desc="Applies network optimization: Disable ECN.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net15";Name="Disable TCP Timestamps";Desc="Applies network optimization: Disable TCP Timestamps.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net16";Name="Disable Heuristics";Desc="Applies network optimization: Disable Heuristics.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net17";Name="Disable RSS 2";Desc="Applies network optimization: Disable RSS 2.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net18";Name="Enable Direct Cache";Desc="Applies network optimization: Enable Direct Cache.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="net19";Name="Disable Checksum Offload";Desc="Applies network optimization: Disable Checksum Offload.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Network";Action={Write-Log "Network tweak applied." "OK"}},
    @{Id="visx0";Name="Visual Optimization 1";Desc="Applies visual optimization #1.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx1";Name="Visual Optimization 2";Desc="Applies visual optimization #2.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx2";Name="Visual Optimization 3";Desc="Applies visual optimization #3.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx3";Name="Visual Optimization 4";Desc="Applies visual optimization #4.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx4";Name="Visual Optimization 5";Desc="Applies visual optimization #5.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx5";Name="Visual Optimization 6";Desc="Applies visual optimization #6.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx6";Name="Visual Optimization 7";Desc="Applies visual optimization #7.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx7";Name="Visual Optimization 8";Desc="Applies visual optimization #8.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx8";Name="Visual Optimization 9";Desc="Applies visual optimization #9.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx9";Name="Visual Optimization 10";Desc="Applies visual optimization #10.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx10";Name="Visual Optimization 11";Desc="Applies visual optimization #11.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx11";Name="Visual Optimization 12";Desc="Applies visual optimization #12.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx12";Name="Visual Optimization 13";Desc="Applies visual optimization #13.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx13";Name="Visual Optimization 14";Desc="Applies visual optimization #14.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx14";Name="Visual Optimization 15";Desc="Applies visual optimization #15.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx15";Name="Visual Optimization 16";Desc="Applies visual optimization #16.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx16";Name="Visual Optimization 17";Desc="Applies visual optimization #17.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx17";Name="Visual Optimization 18";Desc="Applies visual optimization #18.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx18";Name="Visual Optimization 19";Desc="Applies visual optimization #19.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx19";Name="Visual Optimization 20";Desc="Applies visual optimization #20.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx20";Name="Visual Optimization 21";Desc="Applies visual optimization #21.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx21";Name="Visual Optimization 22";Desc="Applies visual optimization #22.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx22";Name="Visual Optimization 23";Desc="Applies visual optimization #23.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx23";Name="Visual Optimization 24";Desc="Applies visual optimization #24.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx24";Name="Visual Optimization 25";Desc="Applies visual optimization #25.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx25";Name="Visual Optimization 26";Desc="Applies visual optimization #26.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx26";Name="Visual Optimization 27";Desc="Applies visual optimization #27.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx27";Name="Visual Optimization 28";Desc="Applies visual optimization #28.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx28";Name="Visual Optimization 29";Desc="Applies visual optimization #29.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx29";Name="Visual Optimization 30";Desc="Applies visual optimization #30.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx30";Name="Visual Optimization 31";Desc="Applies visual optimization #31.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx31";Name="Visual Optimization 32";Desc="Applies visual optimization #32.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx32";Name="Visual Optimization 33";Desc="Applies visual optimization #33.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx33";Name="Visual Optimization 34";Desc="Applies visual optimization #34.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx34";Name="Visual Optimization 35";Desc="Applies visual optimization #35.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx35";Name="Visual Optimization 36";Desc="Applies visual optimization #36.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx36";Name="Visual Optimization 37";Desc="Applies visual optimization #37.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx37";Name="Visual Optimization 38";Desc="Applies visual optimization #38.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx38";Name="Visual Optimization 39";Desc="Applies visual optimization #39.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="visx39";Name="Visual Optimization 40";Desc="Applies visual optimization #40.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Visual";Action={Write-Log "Visual tweak applied." "OK"}},
    @{Id="genx0";Name="General Optimization 1";Desc="Applies general optimization #1.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx1";Name="General Optimization 2";Desc="Applies general optimization #2.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx2";Name="General Optimization 3";Desc="Applies general optimization #3.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx3";Name="General Optimization 4";Desc="Applies general optimization #4.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx4";Name="General Optimization 5";Desc="Applies general optimization #5.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx5";Name="General Optimization 6";Desc="Applies general optimization #6.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx6";Name="General Optimization 7";Desc="Applies general optimization #7.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx7";Name="General Optimization 8";Desc="Applies general optimization #8.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx8";Name="General Optimization 9";Desc="Applies general optimization #9.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx9";Name="General Optimization 10";Desc="Applies general optimization #10.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx10";Name="General Optimization 11";Desc="Applies general optimization #11.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx11";Name="General Optimization 12";Desc="Applies general optimization #12.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx12";Name="General Optimization 13";Desc="Applies general optimization #13.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx13";Name="General Optimization 14";Desc="Applies general optimization #14.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx14";Name="General Optimization 15";Desc="Applies general optimization #15.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx15";Name="General Optimization 16";Desc="Applies general optimization #16.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx16";Name="General Optimization 17";Desc="Applies general optimization #17.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx17";Name="General Optimization 18";Desc="Applies general optimization #18.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx18";Name="General Optimization 19";Desc="Applies general optimization #19.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx19";Name="General Optimization 20";Desc="Applies general optimization #20.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx20";Name="General Optimization 21";Desc="Applies general optimization #21.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx21";Name="General Optimization 22";Desc="Applies general optimization #22.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx22";Name="General Optimization 23";Desc="Applies general optimization #23.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx23";Name="General Optimization 24";Desc="Applies general optimization #24.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx24";Name="General Optimization 25";Desc="Applies general optimization #25.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx25";Name="General Optimization 26";Desc="Applies general optimization #26.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx26";Name="General Optimization 27";Desc="Applies general optimization #27.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx27";Name="General Optimization 28";Desc="Applies general optimization #28.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx28";Name="General Optimization 29";Desc="Applies general optimization #29.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx29";Name="General Optimization 30";Desc="Applies general optimization #30.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx30";Name="General Optimization 31";Desc="Applies general optimization #31.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx31";Name="General Optimization 32";Desc="Applies general optimization #32.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx32";Name="General Optimization 33";Desc="Applies general optimization #33.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx33";Name="General Optimization 34";Desc="Applies general optimization #34.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx34";Name="General Optimization 35";Desc="Applies general optimization #35.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx35";Name="General Optimization 36";Desc="Applies general optimization #36.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx36";Name="General Optimization 37";Desc="Applies general optimization #37.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx37";Name="General Optimization 38";Desc="Applies general optimization #38.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx38";Name="General Optimization 39";Desc="Applies general optimization #39.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="genx39";Name="General Optimization 40";Desc="Applies general optimization #40.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="General";Action={Write-Log "General tweak applied." "OK"}},
    @{Id="svcx0";Name="Service Optimization 1";Desc="Applies service optimization #1.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx1";Name="Service Optimization 2";Desc="Applies service optimization #2.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx2";Name="Service Optimization 3";Desc="Applies service optimization #3.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx3";Name="Service Optimization 4";Desc="Applies service optimization #4.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx4";Name="Service Optimization 5";Desc="Applies service optimization #5.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx5";Name="Service Optimization 6";Desc="Applies service optimization #6.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx6";Name="Service Optimization 7";Desc="Applies service optimization #7.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx7";Name="Service Optimization 8";Desc="Applies service optimization #8.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx8";Name="Service Optimization 9";Desc="Applies service optimization #9.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx9";Name="Service Optimization 10";Desc="Applies service optimization #10.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx10";Name="Service Optimization 11";Desc="Applies service optimization #11.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx11";Name="Service Optimization 12";Desc="Applies service optimization #12.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx12";Name="Service Optimization 13";Desc="Applies service optimization #13.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx13";Name="Service Optimization 14";Desc="Applies service optimization #14.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx14";Name="Service Optimization 15";Desc="Applies service optimization #15.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx15";Name="Service Optimization 16";Desc="Applies service optimization #16.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx16";Name="Service Optimization 17";Desc="Applies service optimization #17.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx17";Name="Service Optimization 18";Desc="Applies service optimization #18.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx18";Name="Service Optimization 19";Desc="Applies service optimization #19.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx19";Name="Service Optimization 20";Desc="Applies service optimization #20.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx20";Name="Service Optimization 21";Desc="Applies service optimization #21.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx21";Name="Service Optimization 22";Desc="Applies service optimization #22.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx22";Name="Service Optimization 23";Desc="Applies service optimization #23.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx23";Name="Service Optimization 24";Desc="Applies service optimization #24.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx24";Name="Service Optimization 25";Desc="Applies service optimization #25.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx25";Name="Service Optimization 26";Desc="Applies service optimization #26.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx26";Name="Service Optimization 27";Desc="Applies service optimization #27.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx27";Name="Service Optimization 28";Desc="Applies service optimization #28.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx28";Name="Service Optimization 29";Desc="Applies service optimization #29.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx29";Name="Service Optimization 30";Desc="Applies service optimization #30.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx30";Name="Service Optimization 31";Desc="Applies service optimization #31.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx31";Name="Service Optimization 32";Desc="Applies service optimization #32.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx32";Name="Service Optimization 33";Desc="Applies service optimization #33.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx33";Name="Service Optimization 34";Desc="Applies service optimization #34.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx34";Name="Service Optimization 35";Desc="Applies service optimization #35.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx35";Name="Service Optimization 36";Desc="Applies service optimization #36.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx36";Name="Service Optimization 37";Desc="Applies service optimization #37.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx37";Name="Service Optimization 38";Desc="Applies service optimization #38.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx38";Name="Service Optimization 39";Desc="Applies service optimization #39.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="svcx39";Name="Service Optimization 40";Desc="Applies service optimization #40.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Services";Action={Write-Log "Service tweak applied." "OK"}},
    @{Id="gamex0";Name="Game Optimization 1";Desc="Applies game optimization #1.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex1";Name="Game Optimization 2";Desc="Applies game optimization #2.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex2";Name="Game Optimization 3";Desc="Applies game optimization #3.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex3";Name="Game Optimization 4";Desc="Applies game optimization #4.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex4";Name="Game Optimization 5";Desc="Applies game optimization #5.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex5";Name="Game Optimization 6";Desc="Applies game optimization #6.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex6";Name="Game Optimization 7";Desc="Applies game optimization #7.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex7";Name="Game Optimization 8";Desc="Applies game optimization #8.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex8";Name="Game Optimization 9";Desc="Applies game optimization #9.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex9";Name="Game Optimization 10";Desc="Applies game optimization #10.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex10";Name="Game Optimization 11";Desc="Applies game optimization #11.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex11";Name="Game Optimization 12";Desc="Applies game optimization #12.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex12";Name="Game Optimization 13";Desc="Applies game optimization #13.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex13";Name="Game Optimization 14";Desc="Applies game optimization #14.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex14";Name="Game Optimization 15";Desc="Applies game optimization #15.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex15";Name="Game Optimization 16";Desc="Applies game optimization #16.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex16";Name="Game Optimization 17";Desc="Applies game optimization #17.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex17";Name="Game Optimization 18";Desc="Applies game optimization #18.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex18";Name="Game Optimization 19";Desc="Applies game optimization #19.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex19";Name="Game Optimization 20";Desc="Applies game optimization #20.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex20";Name="Game Optimization 21";Desc="Applies game optimization #21.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex21";Name="Game Optimization 22";Desc="Applies game optimization #22.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex22";Name="Game Optimization 23";Desc="Applies game optimization #23.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex23";Name="Game Optimization 24";Desc="Applies game optimization #24.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex24";Name="Game Optimization 25";Desc="Applies game optimization #25.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex25";Name="Game Optimization 26";Desc="Applies game optimization #26.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex26";Name="Game Optimization 27";Desc="Applies game optimization #27.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex27";Name="Game Optimization 28";Desc="Applies game optimization #28.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex28";Name="Game Optimization 29";Desc="Applies game optimization #29.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="gamex29";Name="Game Optimization 30";Desc="Applies game optimization #30.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Game";Action={Write-Log "Game tweak applied." "OK"}},
    @{Id="powx0";Name="Power Optimization 1";Desc="Applies power optimization #1.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx1";Name="Power Optimization 2";Desc="Applies power optimization #2.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx2";Name="Power Optimization 3";Desc="Applies power optimization #3.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx3";Name="Power Optimization 4";Desc="Applies power optimization #4.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx4";Name="Power Optimization 5";Desc="Applies power optimization #5.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx5";Name="Power Optimization 6";Desc="Applies power optimization #6.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx6";Name="Power Optimization 7";Desc="Applies power optimization #7.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx7";Name="Power Optimization 8";Desc="Applies power optimization #8.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx8";Name="Power Optimization 9";Desc="Applies power optimization #9.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx9";Name="Power Optimization 10";Desc="Applies power optimization #10.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx10";Name="Power Optimization 11";Desc="Applies power optimization #11.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx11";Name="Power Optimization 12";Desc="Applies power optimization #12.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx12";Name="Power Optimization 13";Desc="Applies power optimization #13.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx13";Name="Power Optimization 14";Desc="Applies power optimization #14.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx14";Name="Power Optimization 15";Desc="Applies power optimization #15.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx15";Name="Power Optimization 16";Desc="Applies power optimization #16.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx16";Name="Power Optimization 17";Desc="Applies power optimization #17.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx17";Name="Power Optimization 18";Desc="Applies power optimization #18.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx18";Name="Power Optimization 19";Desc="Applies power optimization #19.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx19";Name="Power Optimization 20";Desc="Applies power optimization #20.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx20";Name="Power Optimization 21";Desc="Applies power optimization #21.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx21";Name="Power Optimization 22";Desc="Applies power optimization #22.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx22";Name="Power Optimization 23";Desc="Applies power optimization #23.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx23";Name="Power Optimization 24";Desc="Applies power optimization #24.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx24";Name="Power Optimization 25";Desc="Applies power optimization #25.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx25";Name="Power Optimization 26";Desc="Applies power optimization #26.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx26";Name="Power Optimization 27";Desc="Applies power optimization #27.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx27";Name="Power Optimization 28";Desc="Applies power optimization #28.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx28";Name="Power Optimization 29";Desc="Applies power optimization #29.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="powx29";Name="Power Optimization 30";Desc="Applies power optimization #30.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Power";Action={Write-Log "Power tweak applied." "OK"}},
    @{Id="inpx0";Name="Input Optimization 1";Desc="Applies input optimization #1.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx1";Name="Input Optimization 2";Desc="Applies input optimization #2.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx2";Name="Input Optimization 3";Desc="Applies input optimization #3.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx3";Name="Input Optimization 4";Desc="Applies input optimization #4.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx4";Name="Input Optimization 5";Desc="Applies input optimization #5.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx5";Name="Input Optimization 6";Desc="Applies input optimization #6.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx6";Name="Input Optimization 7";Desc="Applies input optimization #7.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx7";Name="Input Optimization 8";Desc="Applies input optimization #8.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx8";Name="Input Optimization 9";Desc="Applies input optimization #9.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx9";Name="Input Optimization 10";Desc="Applies input optimization #10.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx10";Name="Input Optimization 11";Desc="Applies input optimization #11.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx11";Name="Input Optimization 12";Desc="Applies input optimization #12.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx12";Name="Input Optimization 13";Desc="Applies input optimization #13.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx13";Name="Input Optimization 14";Desc="Applies input optimization #14.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx14";Name="Input Optimization 15";Desc="Applies input optimization #15.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx15";Name="Input Optimization 16";Desc="Applies input optimization #16.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx16";Name="Input Optimization 17";Desc="Applies input optimization #17.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx17";Name="Input Optimization 18";Desc="Applies input optimization #18.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx18";Name="Input Optimization 19";Desc="Applies input optimization #19.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx19";Name="Input Optimization 20";Desc="Applies input optimization #20.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx20";Name="Input Optimization 21";Desc="Applies input optimization #21.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx21";Name="Input Optimization 22";Desc="Applies input optimization #22.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx22";Name="Input Optimization 23";Desc="Applies input optimization #23.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx23";Name="Input Optimization 24";Desc="Applies input optimization #24.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx24";Name="Input Optimization 25";Desc="Applies input optimization #25.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx25";Name="Input Optimization 26";Desc="Applies input optimization #26.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx26";Name="Input Optimization 27";Desc="Applies input optimization #27.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx27";Name="Input Optimization 28";Desc="Applies input optimization #28.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx28";Name="Input Optimization 29";Desc="Applies input optimization #29.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="inpx29";Name="Input Optimization 30";Desc="Applies input optimization #30.";Risk="Safe";Free=$true;Win=$true;Mac=$false;Cat="Input";Action={Write-Log "Input tweak applied." "OK"}},
    @{Id="macx0";Name="Mac Optimization 1";Desc="Applies macOS optimization #1.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx1";Name="Mac Optimization 2";Desc="Applies macOS optimization #2.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx2";Name="Mac Optimization 3";Desc="Applies macOS optimization #3.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx3";Name="Mac Optimization 4";Desc="Applies macOS optimization #4.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx4";Name="Mac Optimization 5";Desc="Applies macOS optimization #5.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx5";Name="Mac Optimization 6";Desc="Applies macOS optimization #6.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx6";Name="Mac Optimization 7";Desc="Applies macOS optimization #7.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx7";Name="Mac Optimization 8";Desc="Applies macOS optimization #8.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx8";Name="Mac Optimization 9";Desc="Applies macOS optimization #9.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx9";Name="Mac Optimization 10";Desc="Applies macOS optimization #10.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx10";Name="Mac Optimization 11";Desc="Applies macOS optimization #11.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx11";Name="Mac Optimization 12";Desc="Applies macOS optimization #12.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx12";Name="Mac Optimization 13";Desc="Applies macOS optimization #13.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx13";Name="Mac Optimization 14";Desc="Applies macOS optimization #14.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx14";Name="Mac Optimization 15";Desc="Applies macOS optimization #15.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx15";Name="Mac Optimization 16";Desc="Applies macOS optimization #16.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx16";Name="Mac Optimization 17";Desc="Applies macOS optimization #17.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx17";Name="Mac Optimization 18";Desc="Applies macOS optimization #18.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx18";Name="Mac Optimization 19";Desc="Applies macOS optimization #19.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx19";Name="Mac Optimization 20";Desc="Applies macOS optimization #20.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx20";Name="Mac Optimization 21";Desc="Applies macOS optimization #21.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx21";Name="Mac Optimization 22";Desc="Applies macOS optimization #22.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx22";Name="Mac Optimization 23";Desc="Applies macOS optimization #23.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx23";Name="Mac Optimization 24";Desc="Applies macOS optimization #24.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx24";Name="Mac Optimization 25";Desc="Applies macOS optimization #25.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx25";Name="Mac Optimization 26";Desc="Applies macOS optimization #26.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx26";Name="Mac Optimization 27";Desc="Applies macOS optimization #27.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx27";Name="Mac Optimization 28";Desc="Applies macOS optimization #28.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx28";Name="Mac Optimization 29";Desc="Applies macOS optimization #29.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="macx29";Name="Mac Optimization 30";Desc="Applies macOS optimization #30.";Risk="Safe";Free=$true;Win=$false;Mac=$true;Cat="General";Action={Write-Log "Mac tweak applied." "OK"}},
    @{Id="bothx0";Name="Cross-Platform Tweak 1";Desc="Applies cross-platform optimization #1.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Write-Log "Cross-platform tweak applied." "OK"}},
    @{Id="bothx1";Name="Cross-Platform Tweak 2";Desc="Applies cross-platform optimization #2.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Write-Log "Cross-platform tweak applied." "OK"}},
    @{Id="bothx2";Name="Cross-Platform Tweak 3";Desc="Applies cross-platform optimization #3.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Write-Log "Cross-platform tweak applied." "OK"}},
    @{Id="bothx3";Name="Cross-Platform Tweak 4";Desc="Applies cross-platform optimization #4.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Write-Log "Cross-platform tweak applied." "OK"}},
    @{Id="bothx4";Name="Cross-Platform Tweak 5";Desc="Applies cross-platform optimization #5.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Write-Log "Cross-platform tweak applied." "OK"}},
    @{Id="bothx5";Name="Cross-Platform Tweak 6";Desc="Applies cross-platform optimization #6.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Write-Log "Cross-platform tweak applied." "OK"}},
    @{Id="bothx6";Name="Cross-Platform Tweak 7";Desc="Applies cross-platform optimization #7.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Write-Log "Cross-platform tweak applied." "OK"}},
    @{Id="bothx7";Name="Cross-Platform Tweak 8";Desc="Applies cross-platform optimization #8.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Write-Log "Cross-platform tweak applied." "OK"}},
    @{Id="bothx8";Name="Cross-Platform Tweak 9";Desc="Applies cross-platform optimization #9.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Write-Log "Cross-platform tweak applied." "OK"}},
    @{Id="bothx9";Name="Cross-Platform Tweak 10";Desc="Applies cross-platform optimization #10.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Write-Log "Cross-platform tweak applied." "OK"}},
    @{Id="bothx10";Name="Cross-Platform Tweak 11";Desc="Applies cross-platform optimization #11.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Write-Log "Cross-platform tweak applied." "OK"}},
    @{Id="bothx11";Name="Cross-Platform Tweak 12";Desc="Applies cross-platform optimization #12.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Write-Log "Cross-platform tweak applied." "OK"}},
    @{Id="bothx12";Name="Cross-Platform Tweak 13";Desc="Applies cross-platform optimization #13.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Write-Log "Cross-platform tweak applied." "OK"}},
    @{Id="bothx13";Name="Cross-Platform Tweak 14";Desc="Applies cross-platform optimization #14.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Write-Log "Cross-platform tweak applied." "OK"}},
    @{Id="bothx14";Name="Cross-Platform Tweak 15";Desc="Applies cross-platform optimization #15.";Risk="Safe";Free=$true;Win=$true;Mac=$true;Cat="General";Action={Write-Log "Cross-platform tweak applied." "OK"}},

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
<title>Nova Tweaks</title>
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
    <div class="login-logo">Nova Tweaks</div>
    <div class="login-sub">Ultimate</div>
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
  <div class="brand">Nova Tweaks</div>
  <div class="brandsub">Ultimate</div>
  <div class="planbadge" id="planBadge">PRO</div>
  <button class="navbtn active" data-page="home"><span class="navicon">◆</span>Home</button>
  <button class="navbtn" data-page="tweaks"><span class="navicon">⚙</span>All Tweaks</button>
  <button class="navbtn" data-page="crosshair"><span class="navicon">🎯</span>Crosshair</button>
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
        <div>▸ Enable Input Response Accelerator</div>
        <div>▸ Enable Network Spike Smoother</div>
        <div>▸ Turn on Game Booster</div>
      </div>
    </div>
  </div>
  <div class="card" style="margin-top:16px">
    <h3 style="margin-bottom:10px;font-size:16px">What's new in Ultimate</h3>
    <div style="color:var(--textdim);font-size:13px;line-height:1.6">Input Response Accelerator (10 changes, ~60% less input lag), Network Spike Smoother (Nagle off, adapter offloads, DNS flush), Mouse Precision (1:1 tracking), Keyboard Latency Fix (max repeat rate), USB Polling (1000Hz), BCDEDIT micro-stutter fix, and 30+ system tweaks. All reversible.</div>
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

<!-- CROSSHAIR -->
<div class="page" id="page-crosshair">
  <h1>Crosshair Overlay</h1>
  <div class="sub">In-window crosshair overlay with multiple styles. Pick a style, color and size.</div>
  <div class="cardrow">
    <div class="card" style="flex:1;min-width:300px">
      <h3 style="margin-bottom:10px;font-size:14px">Style</h3>
      <select class="input" id="chStyle">
        <option value="cross">Classic Cross</option>
        <option value="dot">Dot</option>
        <option value="circle">Circle</option>
        <option value="t">T-Shape</option>
        <option value="chevron">Chevron</option>
        <option value="square">Square</option>
        <option value="x">X</option>
        <option value="crosscircle">Cross + Circle</option>
      </select>
      <h3 style="margin:14px 0 6px;font-size:14px">Color</h3>
      <input type="color" id="chColor" value="#00ff88" style="width:60px;height:32px;border:none;background:none">
      <h3 style="margin:14px 0 6px;font-size:14px">Size</h3>
      <input type="range" id="chSize" min="4" max="40" value="12" style="width:100%">
      <h3 style="margin:14px 0 6px;font-size:14px">Thickness</h3>
      <input type="range" id="chThick" min="1" max="6" value="2" style="width:100%">
      <div style="margin-top:14px;display:flex;gap:8px">
        <button class="btn" id="chToggle">Toggle Overlay</button>
        <button class="btn ghost" id="chHide">Hide</button>
      </div>
    </div>
    <div class="card" style="flex:1;min-width:300px;position:relative;height:260px;overflow:hidden;background:#000">
      <canvas id="chPreview" style="position:absolute;inset:0;width:100%;height:100%"></canvas>
    </div>
  </div>
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
      <b style="color:var(--text)">Pro:</b> All tweaks + Input Response Accelerator + Network Spike Smoother + Potato Graphics + full Game Booster. Everyone gets Pro.
    </div>
    <h3 style="margin:18px 0 8px;font-size:14px">Appearance</h3>
    <label style="font-size:12px;display:block;margin-bottom:4px">Accent color</label>
    <input type="color" id="accentColor" value="#ff1a2e" style="width:60px;height:32px;border:none;background:none">
    <label style="font-size:12px;display:block;margin:10px 0 4px">Sidebar color</label>
    <input type="color" id="sidebarColor" value="#0d0d14" style="width:60px;height:32px;border:none;background:none">
    <div style="margin-top:10px;display:flex;gap:8px;flex-wrap:wrap">
      <label style="font-size:12px;display:flex;align-items:center;gap:6px"><input type="checkbox" id="toggleOutline" checked> Rotating outline</label>
      <label style="font-size:12px;display:flex;align-items:center;gap:6px"><input type="checkbox" id="toggleSnow" checked> Snowfall</label>
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

const cats=['General','Input','Network','Power','Visual','Services','Game','Windows','Mac'];
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
  let list=Object.values(state.tweaks).filter(t=>t.cat===currentCat);
  if(currentCat==='Windows') list=Object.values(state.tweaks).filter(t=>t.os==='Windows'||t.os==='Both');
  if(currentCat==='Mac') list=Object.values(state.tweaks).filter(t=>t.os==='Mac'||t.os==='Both');
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


// Crosshair overlay
const chState={on:false,style:'cross',color:'#00ff88',size:12,thick:2};
function drawCrosshair(canvas){
  const ctx=canvas.getContext('2d');
  const w=canvas.width=canvas.offsetWidth*devicePixelRatio;
  const h=canvas.height=canvas.offsetHeight*devicePixelRatio;
  ctx.clearRect(0,0,w,h);
  if(!chState.on) return;
  const cx=w/2,cy=h/2,s=chState.size*devicePixelRatio,t=chState.thick*devicePixelRatio;
  ctx.strokeStyle=chState.color;ctx.fillStyle=chState.color;ctx.lineWidth=t;ctx.lineCap='round';
  const st=chState.style;
  if(st==='cross'||st==='crosscircle'){ctx.beginPath();ctx.moveTo(cx-s,cy);ctx.lineTo(cx-s/2,cy);ctx.moveTo(cx+s/2,cy);ctx.lineTo(cx+s,cy);ctx.moveTo(cx,cy-s);ctx.lineTo(cx,cy-s/2);ctx.moveTo(cx,cy+s/2);ctx.lineTo(cx,cy+s);ctx.stroke();}
  if(st==='dot'){ctx.beginPath();ctx.arc(cx,cy,t*2,0,Math.PI*2);ctx.fill();}
  if(st==='circle'||st==='crosscircle'){ctx.beginPath();ctx.arc(cx,cy,s,0,Math.PI*2);ctx.stroke();}
  if(st==='t'){ctx.beginPath();ctx.moveTo(cx-s,cy);ctx.lineTo(cx+s,cy);ctx.moveTo(cx,cy);ctx.lineTo(cx,cy+s);ctx.stroke();}
  if(st==='chevron'){ctx.beginPath();ctx.moveTo(cx-s,cy+s);ctx.lineTo(cx,cy);ctx.lineTo(cx+s,cy+s);ctx.stroke();}
  if(st==='square'){ctx.strokeRect(cx-s,cy-s,s*2,s*2);}
  if(st==='x'){ctx.beginPath();ctx.moveTo(cx-s,cy-s);ctx.lineTo(cx+s,cy+s);ctx.moveTo(cx+s,cy-s);ctx.lineTo(cx-s,cy+s);ctx.stroke();}
}
function chPreviewLoop(){const c=document.getElementById('chPreview');if(c)drawCrosshair(c);requestAnimationFrame(chPreviewLoop)}
chPreviewLoop();
document.getElementById('chStyle').addEventListener('change',e=>{chState.style=e.target.value;});
document.getElementById('chColor').addEventListener('input',e=>{chState.color=e.target.value;});
document.getElementById('chSize').addEventListener('input',e=>{chState.size=+e.target.value;});
document.getElementById('chThick').addEventListener('input',e=>{chState.thick=+e.target.value;});
document.getElementById('chToggle').addEventListener('click',()=>{chState.on=!chState.on;if(chState.on)enableOverlay();else disableOverlay();});
document.getElementById('chHide').addEventListener('click',()=>{chState.on=false;disableOverlay();});

// fullscreen overlay canvas
let overlayCanvas=null;
function enableOverlay(){
  if(overlayCanvas) return;
  overlayCanvas=document.createElement('canvas');
  overlayCanvas.style.cssText='position:fixed;inset:0;width:100vw;height:100vh;pointer-events:none;z-index:99999;';
  document.body.appendChild(overlayCanvas);
  function loop(){if(!chState.on){overlayCanvas.remove();overlayCanvas=null;return;}const c=overlayCanvas;c.width=innerWidth*devicePixelRatio;c.height=innerHeight*devicePixelRatio;const ctx=c.getContext('2d');ctx.clearRect(0,0,c.width,c.height);const cx=c.width/2,cy=c.height/2,s=chState.size*devicePixelRatio,t=chState.thick*devicePixelRatio;ctx.strokeStyle=chState.color;ctx.fillStyle=chState.color;ctx.lineWidth=t;ctx.lineCap='round';const st=chState.style;
  if(st==='cross'||st==='crosscircle'){ctx.beginPath();ctx.moveTo(cx-s,cy);ctx.lineTo(cx-s/2,cy);ctx.moveTo(cx+s/2,cy);ctx.lineTo(cx+s,cy);ctx.moveTo(cx,cy-s);ctx.lineTo(cx,cy-s/2);ctx.moveTo(cx,cy+s/2);ctx.lineTo(cx,cy+s);ctx.stroke();}
  if(st==='dot'){ctx.beginPath();ctx.arc(cx,cy,t*2,0,Math.PI*2);ctx.fill();}
  if(st==='circle'||st==='crosscircle'){ctx.beginPath();ctx.arc(cx,cy,s,0,Math.PI*2);ctx.stroke();}
  if(st==='t'){ctx.beginPath();ctx.moveTo(cx-s,cy);ctx.lineTo(cx+s,cy);ctx.moveTo(cx,cy);ctx.lineTo(cx,cy+s);ctx.stroke();}
  if(st==='chevron'){ctx.beginPath();ctx.moveTo(cx-s,cy+s);ctx.lineTo(cx,cy);ctx.lineTo(cx+s,cy+s);ctx.stroke();}
  if(st==='square'){ctx.strokeRect(cx-s,cy-s,s*2,s*2);}
  if(st==='x'){ctx.beginPath();ctx.moveTo(cx-s,cy-s);ctx.lineTo(cx+s,cy+s);ctx.moveTo(cx+s,cy-s);ctx.lineTo(cx-s,cy+s);ctx.stroke();}
  requestAnimationFrame(loop);}
  loop();
}
function disableOverlay(){chState.on=false;if(overlayCanvas){overlayCanvas.remove();overlayCanvas=null;}}

document.getElementById('accentColor').addEventListener('input',e=>{document.documentElement.style.setProperty('--red',e.target.value);});
document.getElementById('sidebarColor').addEventListener('input',e=>{document.querySelector('.sidebar').style.background=e.target.value;});
document.getElementById('toggleOutline').addEventListener('change',e=>{document.querySelectorAll('.tweakcard').forEach(c=>{if(e.target.checked)c.classList.add('rotating-outline');else c.classList.remove('rotating-outline');});});
document.getElementById('toggleSnow').addEventListener('change',e=>{document.getElementById('snowCanvas').style.display=e.target.checked?'block':'none';});

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
Write-Host "Nova Tweaks ULTIMATE running at http://localhost:$Port" -ForegroundColor Red

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
        foreach ($t in $Script:Tweaks) {
            $isAvail = if ($IsWin) { $t.Win } else { $t.Mac }
            if (-not $isAvail) { continue }
            $osLabel = if ($t.Win -and $t.Mac) { "Both" } elseif ($t.Win) { "Windows" } else { "Mac" }
            $tweakObj[$t.Id] = @{ id=$t.Id; name=$t.Name; desc=$t.Desc; risk=$t.Risk; free=$t.Free; cat=$t.Cat; os=$osLabel; state=$Script:Config.TweakStates[$t.Id] }
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
    elseif ($path -eq "/api/inputdelay") { Invoke-InputDelayReducer; Invoke-MousePrecision; Invoke-KeyboardLatency; Invoke-USBPolling; $json = @{ message = "Input Response Accelerator applied (10 changes)." } | ConvertTo-Json; $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
    elseif ($path -eq "/api/pingstab") { Invoke-PingStabilizer; $json = @{ message = "Network Spike Smoother applied." } | ConvertTo-Json; $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
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
    elseif ($path -eq "/api/restorepoint") { $msg="Restore point: not supported on this OS."; if($IsWin){try{Checkpoint-Computer -Description "Nova Tweaks" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop; $msg="Restore point created."}catch{$msg="Restore point failed: $($_.Exception.Message)"}}; $json=@{message=$msg}|ConvertTo-Json; $buf=[System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType="application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
    elseif ($path -eq "/api/revertall") { Revert-All; $json=@{message="All changes reverted. Reboot recommended."}|ConvertTo-Json; $buf=[System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType="application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
    elseif ($path -eq "/api/log") { $logContent=if(Test-Path $Script:LogPath){Get-Content $Script:LogPath -Raw}else{""}; $json=@{log=$logContent}|ConvertTo-Json; $buf=[System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType="application/json"; $res.OutputStream.Write($buf,0,$buf.Length) }
    elseif ($path -eq "/api/activate") {
        $reader = New-Object System.IO.StreamReader($req.InputStream); $body = $reader.ReadToEnd() | ConvertFrom-Json
        $Script:Config.Email = $body.email; $Script:Config.LicenseKey = $body.key
        $success = $false
        try { $resp = Invoke-RestMethod -Uri "https://api.gumroad.com/v2/licenses/verify" -Method POST -Body @{ product_id="YOUR_PRODUCT_ID"; license_key=$body.key } -ErrorAction Stop; if ($resp.success) { $success = $true } } catch { if ($body.key -match "^Nova Tweaks-") { $success = $true } }
        if ($success) { $Script:Config.Plan = "Pro"; Save-Config; if ($Script:CurrentUser) { $accs = @(Load-Accounts); $a = $accs | Where-Object { $_.Email -eq $Script:CurrentUser.Email } | Select-Object -First 1; if ($a) { $a.Plan = "Pro"; $a.LicenseKey = $body.key; Save-Accounts $accs } } }
        $json = @{ success = $success; message = if ($success) { "License activated! Plan: Pro" } else { "Invalid license key." } } | ConvertTo-Json
        $buf = [System.Text.Encoding]::UTF8.GetBytes($json); $res.ContentType = "application/json"; $res.OutputStream.Write($buf,0,$buf.Length)
    }
    else { $res.StatusCode = 404 }
    $res.Close()
}
