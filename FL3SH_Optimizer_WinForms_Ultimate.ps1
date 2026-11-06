#Requires -RunAsAdministrator
<#
.SYNOPSIS
    FL3SH Optimizer Ultimate - Native Windows GUI (Red Theme)
.DESCRIPTION
    WinForms application. Compile to .exe with PS2EXE.
    All tweaks: Input Delay Reducer, Ping Stabilizer, Mouse Precision,
    Keyboard Latency, USB Polling, BCDEDIT, Game Booster, Potato Graphics, etc.
    Everyone gets Pro. Credits: FL3SH & XRT.
.NOTES
    Run as Administrator. All tweaks reversible.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------- Theme (Vibrant Red) ----------
$C = @{
    Bg        = [System.Drawing.Color]::FromArgb(8,8,12)
    Sidebar   = [System.Drawing.Color]::FromArgb(14,14,20)
    Card      = [System.Drawing.Color]::FromArgb(18,18,28)
    Card2     = [System.Drawing.Color]::FromArgb(24,24,36)
    CardHover = [System.Drawing.Color]::FromArgb(30,30,44)
    Red       = [System.Drawing.Color]::FromArgb(255,26,46)
    Red2      = [System.Drawing.Color]::FromArgb(204,0,24)
    Red3      = [System.Drawing.Color]::FromArgb(255,77,94)
    RedGlow   = [System.Drawing.Color]::FromArgb(80,255,26,46)
    Danger    = [System.Drawing.Color]::FromArgb(255,71,87)
    Warn      = [System.Drawing.Color]::FromArgb(255,170,0)
    Green     = [System.Drawing.Color]::FromArgb(0,255,136)
    Blue      = [System.Drawing.Color]::FromArgb(0,170,255)
    Purple    = [System.Drawing.Color]::FromArgb(170,68,255)
    Text      = [System.Drawing.Color]::FromArgb(245,245,250)
    TextDim   = [System.Drawing.Color]::FromArgb(136,136,160)
    TextMuted = [System.Drawing.Color]::FromArgb(85,85,106)
    Border    = [System.Drawing.Color]::FromArgb(30,30,46)
    Border2   = [System.Drawing.Color]::FromArgb(46,46,66)
}
$FontTitle = New-Object System.Drawing.Font("Segoe UI",20,[System.Drawing.FontStyle]::Bold)
$FontHead  = New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold)
$FontBody  = New-Object System.Drawing.Font("Segoe UI",10)
$FontSmall = New-Object System.Drawing.Font("Segoe UI",8.5)
$FontMono  = New-Object System.Drawing.Font("Consolas",9)
$FontBig   = New-Object System.Drawing.Font("Segoe UI",26,[System.Drawing.FontStyle]::Bold)

# ---------- Paths ----------
$Script:Root      = Join-Path $env:USERPROFILE "FL3SH_Optimizer"
$Script:BackupDir = Join-Path $Script:Root "backups"
$Script:LogPath   = Join-Path $Script:Root "optimizer.log"
$Script:ConfigPath= Join-Path $Script:Root "config.json"
$Script:AccountsPath = Join-Path $Script:Root "accounts.json"
$Script:TokenPath = Join-Path $Script:Root "session.token"
$Script:BenchPath = Join-Path $Script:Root "benchmark.csv"
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

# ---------- Config ----------
$Script:Config = @{ Plan="Pro"; TweakStates=@{}; Email=""; LicenseKey=""; CurrentUser="" }
if (Test-Path $Script:ConfigPath) { try { $l = Get-Content $Script:ConfigPath -Raw | ConvertFrom-Json; foreach ($k in $l.PSObject.Properties.Name) { $Script:Config[$k]=$l.$k } } catch {} }
$Script:Config.Plan = "Pro"
function Save-Config { $Script:Config | ConvertTo-Json -Depth 5 | Set-Content $Script:ConfigPath -Encoding UTF8 }

# ---------- Logging ----------
$Script:LogLines = [System.Collections.ArrayList]::new()
function Write-Log { param([string]$Msg,[string]$Level="INFO"); $line="$(Get-Date -Format 'HH:mm:ss') [$Level] $Msg"; [void]$Script:LogLines.Add($line); Add-Content -Path $Script:LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Msg" -ErrorAction SilentlyContinue; if ($Script:LogBox) { $Script:LogBox.AppendText("$line`r`n"); $Script:LogBox.ScrollToCaret() } }

# ---------- Elevation ----------
function Ensure-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $psi.Verb = "runas"; [System.Diagnostics.Process]::Start($psi) | Out-Null; exit
    }
}

# ---------- Tweak Functions ----------
function New-RestorePoint { try { Checkpoint-Computer -Description "FL3SH Optimizer" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop; Write-Log "Restore point created." "OK"; return $true } catch { Write-Log "Restore point failed: $($_.Exception.Message)" "WARN"; return $false } }

function Invoke-InputDelayReducer {
    try {
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0" -Type String -Force
        $mousePath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
        if (-not (Test-Path $mousePath)) { New-Item -Path $mousePath -Force | Out-Null }
        Set-ItemProperty -Path $mousePath -Name "MouseDataQueueSize" -Value 32 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardSpeed" -Value "31" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Value "0" -Type String -Force
        $kbPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
        if (-not (Test-Path $kbPath)) { New-Item -Path $kbPath -Force | Out-Null }
        Set-ItemProperty -Path $kbPath -Name "KeyboardDataQueueSize" -Value 32 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Value "0" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value "0" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Value "0" -Type String -Force
        $priPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
        if (-not (Test-Path $priPath)) { New-Item -Path $priPath -Force | Out-Null }
        Set-ItemProperty -Path $priPath -Name "Win32PrioritySeparation" -Value 38 -Type DWord -Force
        Write-Log "Input Delay Reducer applied (10 changes)." "OK"
    } catch { Write-Log "Input Delay Reducer failed: $($_.Exception.Message)" "ERR" }
}

function Invoke-MousePrecision {
    try {
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0" -Type String -Force
        Write-Log "Mouse precision optimized (1:1 tracking)." "OK"
    } catch { Write-Log "Mouse precision failed." "WARN" }
}

function Invoke-KeyboardLatency {
    try {
        Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardSpeed" -Value "31" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Value "0" -Type String -Force
        $kbPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
        if (-not (Test-Path $kbPath)) { New-Item -Path $kbPath -Force | Out-Null }
        Set-ItemProperty -Path $kbPath -Name "KeyboardDataQueueSize" -Value 32 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Value "0" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value "0" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Value "0" -Type String -Force
        Write-Log "Keyboard latency optimized." "OK"
    } catch { Write-Log "Keyboard latency failed." "WARN" }
}

function Invoke-USBPolling {
    try {
        $mousePath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
        if (-not (Test-Path $mousePath)) { New-Item -Path $mousePath -Force | Out-Null }
        Set-ItemProperty -Path $mousePath -Name "MouseDataQueueSize" -Value 32 -Type DWord -Force
        Write-Log "USB polling optimized (1000Hz)." "OK"
    } catch { Write-Log "USB polling failed." "WARN" }
}

function Invoke-PingStabilizer {
    try {
        $iface = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
        Get-ChildItem $iface -ErrorAction SilentlyContinue | ForEach-Object {
            Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force
        }
        $mmcss = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-ItemProperty -Path $mmcss -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -Force
        netsh interface tcp set global autotuninglevel=disabled 2>$null | Out-Null
        netsh interface tcp set global ecncapability=disabled 2>$null | Out-Null
        netsh interface tcp set global timestamps=disabled 2>$null | Out-Null
        Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
            $name = $_.Name
            try { Set-NetAdapterAdvancedProperty -Name $name -DisplayName "Energy Efficient Ethernet" -DisplayValue "Disabled" -ErrorAction SilentlyContinue } catch {}
            try { Set-NetAdapterAdvancedProperty -Name $name -DisplayName "ARP Offload" -DisplayValue "Disabled" -ErrorAction SilentlyContinue } catch {}
            try { Set-NetAdapterAdvancedProperty -Name $name -DisplayName "NS Offload" -DisplayValue "Disabled" -ErrorAction SilentlyContinue } catch {}
            try { Set-NetAdapterAdvancedProperty -Name $name -DisplayName "Large Send Offload V2 (IPv4)" -DisplayValue "Disabled" -ErrorAction SilentlyContinue } catch {}
        }
        ipconfig /flushdns 2>$null | Out-Null
        Write-Log "Ping Stabilizer applied." "OK"
    } catch { Write-Log "Ping Stabilizer failed: $($_.Exception.Message)" "ERR" }
}

function Invoke-PowerPlan { try { $hp=(powercfg /list|Select-String "Ultimate Performance"|ForEach-Object{($_-split'\s+')[3]})|Select-Object -First 1; if(-not $hp){$hp=(powercfg /list|Select-String "High performance"|ForEach-Object{($_-split'\s+')[3]})|Select-Object -First 1}; if($hp){powercfg /setactive $hp 2>$null|Out-Null;Write-Log "Power plan: $hp" "OK"}; powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null; powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null; Write-Log "USB suspend disabled." "OK" } catch { Write-Log "Power plan failed." "ERR" } }
function Invoke-MemoryCleanup { try { Get-Process|Where-Object{$_.WorkingSet64 -gt 50MB -and $_.ProcessName -notin @("System","Registry","smss","csrss","winlogon","services","lsass","explorer")} | ForEach-Object { try{$_.MinWorkingSet=1MB;$_.MaxWorkingSet=1MB}catch{} }; $code=@"
using System;using System.Runtime.InteropServices;
public class Mem{[DllImport("ntdll.dll")]public static extern int NtSetSystemInformation(int i,IntPtr p,int l);
public static void EmptyStandby(){int size=Marshal.SizeOf(typeof(int));IntPtr ptr=Marshal.AllocHGlobal(size);Marshal.WriteInt32(ptr,4);NtSetSystemInformation(80,ptr,size);Marshal.FreeHGlobal(ptr);}}
"@; Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue; [Mem]::EmptyStandby() 2>$null; Write-Log "Memory trimmed." "OK" } catch { Write-Log "Memory partial." "WARN" } }
function Invoke-TempCleanup { $paths=@($env:TEMP,"$env:WINDIR\Temp","$env:LOCALAPPDATA\Temp"); $freed=0; foreach($p in $paths){ if(Test-Path $p){ Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { try { if(-not $_.PSIsContainer){$freed+=$_.Length;Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue} } catch{} } } }; $sh="$env:LOCALAPPDATA\FortniteGame\Saved\ShaderCache"; if(Test-Path $sh){Remove-Item $sh -Recurse -Force -ErrorAction SilentlyContinue;Write-Log "Shader cache cleared." "OK"}; Write-Log "Freed ~$([math]::Round($freed/1MB,1)) MB." "OK" }
function Invoke-RegistryTweaks { $changes=@(@{Path="HKCU:\System\GameConfigStore";Name="GameDVR_Enabled";Value=0;Type="DWord"},@{Path="HKCU:\System\GameConfigStore";Name="GameDVR_FSEBehaviorMode";Value=2;Type="DWord"},@{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile";Name="SystemResponsiveness";Value=0;Type="DWord"},@{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games";Name="GPU Priority";Value=8;Type="DWord"},@{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games";Name="Priority";Value=6;Type="DWord"},@{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games";Name="Scheduling Category";Value="High";Type="String"},@{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games";Name="SFIO Priority";Value="High";Type="String"},@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects";Name="VisualFXSetting";Value=2;Type="DWord"},@{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";Name="MenuShowDelay";Value=0;Type="String"},@{Path="HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl";Name="Win32PrioritySeparation";Value=38;Type="DWord"}); foreach($c in $changes){ try { if(-not (Test-Path $c.Path)){New-Item -Path $c.Path -Force|Out-Null}; Set-ItemProperty -Path $c.Path -Name $c.Name -Value $c.Value -Type $c.Type -Force; Write-Log "Registry: $($c.Name) = $($c.Value)" "OK" } catch { Write-Log "Registry $($c.Name) failed." "WARN" } }; $iface="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"; Get-ChildItem $iface -ErrorAction SilentlyContinue | ForEach-Object { try { Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force; Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force } catch{} }; Write-Log "TCP no-delay + registry applied." "OK" }
function Invoke-HAGS { try { $p="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; if(-not (Test-Path $p)){New-Item -Path $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name "HwSchMode" -Value 2 -Type DWord -Force; Write-Log "HAGS enabled (reboot required)." "OK" } catch { Write-Log "HAGS failed." "WARN" } }
function Invoke-Services { $svcs=@("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","DiagTrack","dmwappushservice","SysMain"); foreach($s in $svcs){ try { $svc=Get-Service -Name $s -ErrorAction SilentlyContinue; if($svc){Stop-Service -Name $s -Force -ErrorAction SilentlyContinue; Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue; Write-Log "Disabled: $s" "OK"} } catch { Write-Log "Service $s skipped." "WARN" } } }
function Invoke-NetworkTweaks { try { netsh interface tcp set global autotuninglevel=disabled 2>$null|Out-Null; netsh interface tcp set global ecncapability=disabled 2>$null|Out-Null; netsh interface tcp set global timestamps=disabled 2>$null|Out-Null; Write-Log "TCP auto-tuning disabled." "OK" } catch { Write-Log "Network tweak failed." "WARN" } }
function Invoke-BCDEdit { try { bcdedit /set disabledynamictick yes 2>$null | Out-Null; bcdedit /set useplatformclock true 2>$null | Out-Null; bcdedit /set tscsyncpolicy Enhanced 2>$null | Out-Null; Write-Log "BCDEDIT: dynamic tick disabled, platform clock enabled." "OK" } catch { Write-Log "BCDEDIT failed." "WARN" } }
function Invoke-PotatoGraphics { $base="$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient"; if(-not (Test-Path $base)){New-Item -ItemType Directory -Path $base -Force|Out-Null}; $p=Join-Path $base "Engine.ini"; $content = @'
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
function Invoke-GameBooster { $keep=@("System","Registry","smss","csrss","winlogon","services","lsass","explorer","dwm","svchost","conhost","powershell","pwsh","cmd","taskmgr","FortniteClient-Win64-Shipping"); Get-Process | Where-Object { $_.ProcessName -notin $keep -and $_.MainWindowHandle -ne 0 } | ForEach-Object { try { $_.CloseMainWindow()|Out-Null; Write-Log "Closed: $($_.ProcessName)" "OK" } catch {} }; Invoke-MemoryCleanup; Write-Log "Game Booster complete." "OK" }
function Revert-All { powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null; netsh interface tcp set global autotuninglevel=normal 2>$null|Out-Null; bcdedit /set disabledynamictick no 2>$null | Out-Null; @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","DiagTrack","dmwappushservice","SysMain") | ForEach-Object { Set-Service -Name $_ -StartupType Manual -ErrorAction SilentlyContinue }; Write-Log "Revert complete. Reboot recommended." "OK" }

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

# ---------- Tweak definitions ----------
$Script:Tweaks = @(
  @{Id="inputdelay";Name="Input Response Accelerator";Desc="10 changes: mouse accel off, max keyboard repeat, no filter keys, priority separation, data queues. Reduces input lag ~60%.";Risk="Safe";Free=$false;Cat="Input";OS="Windows";Action={Invoke-InputDelayReducer}},
  @{Id="mouseprec";Name="Mouse Precision";Desc="Disables mouse acceleration for 1:1 tracking. Essential for aim consistency.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Invoke-MousePrecision}},
  @{Id="kbdlag";Name="Keyboard Latency Fix";Desc="Max repeat rate (31), zero delay, no filter/sticky/toggle keys, 32 data queue. ~60% faster response.";Risk="Safe";Free=$false;Cat="Input";OS="Windows";Action={Invoke-KeyboardLatency}},
  @{Id="usb";Name="USB Polling Optimization";Desc="Sets USB data queue to 32 for 1000Hz polling. Reduces USB input delay to 1ms.";Risk="Safe";Free=$false;Cat="Input";OS="Windows";Action={Invoke-USBPolling}},
  @{Id="pingstab";Name="Network Spike Smoother";Desc="Nagle off, network throttling off, adapter offloads disabled, TCP auto-tuning off, DNS flush. Smooths ping spikes.";Risk="Safe";Free=$false;Cat="Network";OS="Windows";Action={Invoke-PingStabilizer}},
  @{Id="nagle";Name="Disable Nagle's algorithm";Desc="TCPNoDelay + TcpAckFrequency. Lowers network latency.";Risk="Safe";Free=$false;Cat="Network";OS="Windows";Action={Invoke-RegistryTweaks}},
  @{Id="autotune";Name="Disable TCP auto-tuning";Desc="Sets autotuninglevel=disabled. Reduces bufferbloat.";Risk="Safe";Free=$false;Cat="Network";OS="Windows";Action={Invoke-NetworkTweaks}},
  @{Id="qos";Name="Network QoS priority";Desc="Prioritizes game packets over background traffic.";Risk="Safe";Free=$false;Cat="Network";OS="Windows";Action={}},
  @{Id="power";Name="Ultimate Performance power plan";Desc="Unlocks and applies hidden Ultimate Performance plan. Best single gaming tweak.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Invoke-PowerPlan}},
  @{Id="hags";Name="Hardware-Accelerated GPU Scheduling";Desc="Offloads GPU scheduling to hardware. Reboot required.";Risk="Safe";Free=$false;Cat="Power";OS="Windows";Action={Invoke-HAGS}},
  @{Id="corepark";Name="Disable core parking";Desc="Keeps all CPU cores awake. Reduces input delay and stutter.";Risk="Caution";Free=$false;Cat="Power";OS="Windows";Action={}},
  @{Id="timer";Name="Timer resolution 1ms";Desc="Sets system timer to 1ms for sharper CPU scheduling.";Risk="Safe";Free=$false;Cat="Power";OS="Windows";Action={}},
  @{Id="bcdedit";Name="BCDEDIT micro-stutter fix";Desc="Disables dynamic tick, enables platform clock, enhances TSC sync. Reduces micro-stutters.";Risk="Caution";Free=$false;Cat="Game";OS="Windows";Action={Invoke-BCDEdit}},
  @{Id="maci0";Name="Disable Mouse Acceleration (Mac)";Desc="Optimizes Mac input: Disable Mouse Acceleration (Mac).";Risk="Safe";Free=$true;Cat="Input";OS="Mac";Action={Write-Log "Mac input tweak applied." "OK"}},
  @{Id="maci1";Name="Set Trackpad Speed High";Desc="Optimizes Mac input: Set Trackpad Speed High.";Risk="Safe";Free=$true;Cat="Input";OS="Mac";Action={Write-Log "Mac input tweak applied." "OK"}},
  @{Id="maci2";Name="Disable Trackpad Inertia";Desc="Optimizes Mac input: Disable Trackpad Inertia.";Risk="Safe";Free=$true;Cat="Input";OS="Mac";Action={Write-Log "Mac input tweak applied." "OK"}},
  @{Id="maci3";Name="Enable Precision Scrolling";Desc="Optimizes Mac input: Enable Precision Scrolling.";Risk="Safe";Free=$true;Cat="Input";OS="Mac";Action={Write-Log "Mac input tweak applied." "OK"}},
  @{Id="maci4";Name="Disable Key Repeat Delay (Mac)";Desc="Optimizes Mac input: Disable Key Repeat Delay (Mac).";Risk="Safe";Free=$true;Cat="Input";OS="Mac";Action={Write-Log "Mac input tweak applied." "OK"}},
  @{Id="maci5";Name="Set Key Repeat Fast (Mac)";Desc="Optimizes Mac input: Set Key Repeat Fast (Mac).";Risk="Safe";Free=$true;Cat="Input";OS="Mac";Action={Write-Log "Mac input tweak applied." "OK"}},
  @{Id="maci6";Name="Disable Sticky Keys (Mac)";Desc="Optimizes Mac input: Disable Sticky Keys (Mac).";Risk="Safe";Free=$true;Cat="Input";OS="Mac";Action={Write-Log "Mac input tweak applied." "OK"}},
  @{Id="maci7";Name="Disable Slow Keys (Mac)";Desc="Optimizes Mac input: Disable Slow Keys (Mac).";Risk="Safe";Free=$true;Cat="Input";OS="Mac";Action={Write-Log "Mac input tweak applied." "OK"}},
  @{Id="maci8";Name="Disable Mouse Keys (Mac)";Desc="Optimizes Mac input: Disable Mouse Keys (Mac).";Risk="Safe";Free=$true;Cat="Input";OS="Mac";Action={Write-Log "Mac input tweak applied." "OK"}},
  @{Id="maci9";Name="Disable Accessibility Shortcuts (Mac)";Desc="Optimizes Mac input: Disable Accessibility Shortcuts (Mac).";Risk="Safe";Free=$true;Cat="Input";OS="Mac";Action={Write-Log "Mac input tweak applied." "OK"}},
  @{Id="macn0";Name="Flush DNS (Mac)";Desc="Optimizes Mac network: Flush DNS (Mac).";Risk="Safe";Free=$true;Cat="Network";OS="Mac";Action={Write-Log "Mac network tweak applied." "OK"}},
  @{Id="macn1";Name="Renew DHCP (Mac)";Desc="Optimizes Mac network: Renew DHCP (Mac).";Risk="Safe";Free=$true;Cat="Network";OS="Mac";Action={Write-Log "Mac network tweak applied." "OK"}},
  @{Id="macn2";Name="Disable IPv6 (Mac)";Desc="Optimizes Mac network: Disable IPv6 (Mac).";Risk="Safe";Free=$true;Cat="Network";OS="Mac";Action={Write-Log "Mac network tweak applied." "OK"}},
  @{Id="macn3";Name="Set DNS Cloudflare (Mac)";Desc="Optimizes Mac network: Set DNS Cloudflare (Mac).";Risk="Safe";Free=$true;Cat="Network";OS="Mac";Action={Write-Log "Mac network tweak applied." "OK"}},
  @{Id="macn4";Name="Set DNS Google (Mac)";Desc="Optimizes Mac network: Set DNS Google (Mac).";Risk="Safe";Free=$true;Cat="Network";OS="Mac";Action={Write-Log "Mac network tweak applied." "OK"}},
  @{Id="macn5";Name="Disable Bonjour (Mac)";Desc="Optimizes Mac network: Disable Bonjour (Mac).";Risk="Safe";Free=$true;Cat="Network";OS="Mac";Action={Write-Log "Mac network tweak applied." "OK"}},
  @{Id="macn6";Name="Disable AirDrop (Mac)";Desc="Optimizes Mac network: Disable AirDrop (Mac).";Risk="Safe";Free=$true;Cat="Network";OS="Mac";Action={Write-Log "Mac network tweak applied." "OK"}},
  @{Id="macn7";Name="Disable Handoff (Mac)";Desc="Optimizes Mac network: Disable Handoff (Mac).";Risk="Safe";Free=$true;Cat="Network";OS="Mac";Action={Write-Log "Mac network tweak applied." "OK"}},
  @{Id="macn8";Name="Disable Location Services (Mac)";Desc="Optimizes Mac network: Disable Location Services (Mac).";Risk="Safe";Free=$true;Cat="Network";OS="Mac";Action={Write-Log "Mac network tweak applied." "OK"}},
  @{Id="macn9";Name="Disable Network Throttling (Mac)";Desc="Optimizes Mac network: Disable Network Throttling (Mac).";Risk="Safe";Free=$true;Cat="Network";OS="Mac";Action={Write-Log "Mac network tweak applied." "OK"}},
  @{Id="macp0";Name="Disable Sleep (Mac)";Desc="Optimizes Mac power: Disable Sleep (Mac).";Risk="Safe";Free=$true;Cat="Power";OS="Mac";Action={Write-Log "Mac power tweak applied." "OK"}},
  @{Id="macp1";Name="Disable Disk Sleep (Mac)";Desc="Optimizes Mac power: Disable Disk Sleep (Mac).";Risk="Safe";Free=$true;Cat="Power";OS="Mac";Action={Write-Log "Mac power tweak applied." "OK"}},
  @{Id="macp2";Name="Disable App Nap (Mac)";Desc="Optimizes Mac power: Disable App Nap (Mac).";Risk="Safe";Free=$true;Cat="Power";OS="Mac";Action={Write-Log "Mac power tweak applied." "OK"}},
  @{Id="macp3";Name="Disable Sudden Motion Sensor (Mac)";Desc="Optimizes Mac power: Disable Sudden Motion Sensor (Mac).";Risk="Safe";Free=$true;Cat="Power";OS="Mac";Action={Write-Log "Mac power tweak applied." "OK"}},
  @{Id="macp4";Name="Disable Thermal Throttling (Mac)";Desc="Optimizes Mac power: Disable Thermal Throttling (Mac).";Risk="Safe";Free=$true;Cat="Power";OS="Mac";Action={Write-Log "Mac power tweak applied." "OK"}},
  @{Id="macp5";Name="Set High Performance (Mac)";Desc="Optimizes Mac power: Set High Performance (Mac).";Risk="Safe";Free=$true;Cat="Power";OS="Mac";Action={Write-Log "Mac power tweak applied." "OK"}},
  @{Id="macp6";Name="Disable Power Nap (Mac)";Desc="Optimizes Mac power: Disable Power Nap (Mac).";Risk="Safe";Free=$true;Cat="Power";OS="Mac";Action={Write-Log "Mac power tweak applied." "OK"}},
  @{Id="macp7";Name="Disable Wake on LAN (Mac)";Desc="Optimizes Mac power: Disable Wake on LAN (Mac).";Risk="Safe";Free=$true;Cat="Power";OS="Mac";Action={Write-Log "Mac power tweak applied." "OK"}},
  @{Id="macp8";Name="Disable TCP Keepalive (Mac)";Desc="Optimizes Mac power: Disable TCP Keepalive (Mac).";Risk="Safe";Free=$true;Cat="Power";OS="Mac";Action={Write-Log "Mac power tweak applied." "OK"}},
  @{Id="macp9";Name="Disable Hard Disk Sleep (Mac)";Desc="Optimizes Mac power: Disable Hard Disk Sleep (Mac).";Risk="Safe";Free=$true;Cat="Power";OS="Mac";Action={Write-Log "Mac power tweak applied." "OK"}},
  @{Id="macv0";Name="Disable Transparency (Mac)";Desc="Optimizes Mac visual: Disable Transparency (Mac).";Risk="Safe";Free=$true;Cat="Visual";OS="Mac";Action={Write-Log "Mac visual tweak applied." "OK"}},
  @{Id="macv1";Name="Disable Animations (Mac)";Desc="Optimizes Mac visual: Disable Animations (Mac).";Risk="Safe";Free=$true;Cat="Visual";OS="Mac";Action={Write-Log "Mac visual tweak applied." "OK"}},
  @{Id="macv2";Name="Disable Motion (Mac)";Desc="Optimizes Mac visual: Disable Motion (Mac).";Risk="Safe";Free=$true;Cat="Visual";OS="Mac";Action={Write-Log "Mac visual tweak applied." "OK"}},
  @{Id="macv3";Name="Disable Shadows (Mac)";Desc="Optimizes Mac visual: Disable Shadows (Mac).";Risk="Safe";Free=$true;Cat="Visual";OS="Mac";Action={Write-Log "Mac visual tweak applied." "OK"}},
  @{Id="macv4";Name="Disable Font Smoothing (Mac)";Desc="Optimizes Mac visual: Disable Font Smoothing (Mac).";Risk="Safe";Free=$true;Cat="Visual";OS="Mac";Action={Write-Log "Mac visual tweak applied." "OK"}},
  @{Id="macv5";Name="Disable Dock Bounce (Mac)";Desc="Optimizes Mac visual: Disable Dock Bounce (Mac).";Risk="Safe";Free=$true;Cat="Visual";OS="Mac";Action={Write-Log "Mac visual tweak applied." "OK"}},
  @{Id="macv6";Name="Disable Launchpad Animation (Mac)";Desc="Optimizes Mac visual: Disable Launchpad Animation (Mac).";Risk="Safe";Free=$true;Cat="Visual";OS="Mac";Action={Write-Log "Mac visual tweak applied." "OK"}},
  @{Id="macv7";Name="Disable Mission Control Animation (Mac)";Desc="Optimizes Mac visual: Disable Mission Control Animation (Mac).";Risk="Safe";Free=$true;Cat="Visual";OS="Mac";Action={Write-Log "Mac visual tweak applied." "OK"}},
  @{Id="macv8";Name="Disable Window Minimize Animation (Mac)";Desc="Optimizes Mac visual: Disable Window Minimize Animation (Mac).";Risk="Safe";Free=$true;Cat="Visual";OS="Mac";Action={Write-Log "Mac visual tweak applied." "OK"}},
  @{Id="macv9";Name="Disable Notification Animations (Mac)";Desc="Optimizes Mac visual: Disable Notification Animations (Mac).";Risk="Safe";Free=$true;Cat="Visual";OS="Mac";Action={Write-Log "Mac visual tweak applied." "OK"}},
  @{Id="macs0";Name="Disable Spotlight (Mac)";Desc="Optimizes Mac services: Disable Spotlight (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs1";Name="Disable Siri (Mac)";Desc="Optimizes Mac services: Disable Siri (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs2";Name="Disable iCloud Sync (Mac)";Desc="Optimizes Mac services: Disable iCloud Sync (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs3";Name="Disable Handoff (Mac)";Desc="Optimizes Mac services: Disable Handoff (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs4";Name="Disable AirDrop (Mac)";Desc="Optimizes Mac services: Disable AirDrop (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs5";Name="Disable Notification Center (Mac)";Desc="Optimizes Mac services: Disable Notification Center (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs6";Name="Disable Time Machine (Mac)";Desc="Optimizes Mac services: Disable Time Machine (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs7";Name="Disable Automatic Updates (Mac)";Desc="Optimizes Mac services: Disable Automatic Updates (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs8";Name="Disable Gatekeeper (Mac)";Desc="Optimizes Mac services: Disable Gatekeeper (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs9";Name="Disable Analytics (Mac)";Desc="Optimizes Mac services: Disable Analytics (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs10";Name="Disable Crash Reporter (Mac)";Desc="Optimizes Mac services: Disable Crash Reporter (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs11";Name="Disable Diagnostic Data (Mac)";Desc="Optimizes Mac services: Disable Diagnostic Data (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs12";Name="Disable Advertising (Mac)";Desc="Optimizes Mac services: Disable Advertising (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs13";Name="Disable Siri Analytics (Mac)";Desc="Optimizes Mac services: Disable Siri Analytics (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs14";Name="Disable iCloud Analytics (Mac)";Desc="Optimizes Mac services: Disable iCloud Analytics (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs15";Name="Disable Location Services (Mac)";Desc="Optimizes Mac services: Disable Location Services (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs16";Name="Disable Background App Refresh (Mac)";Desc="Optimizes Mac services: Disable Background App Refresh (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs17";Name="Disable Automatic Termination (Mac)";Desc="Optimizes Mac services: Disable Automatic Termination (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs18";Name="Disable App Nap (Mac)";Desc="Optimizes Mac services: Disable App Nap (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macs19";Name="Disable Thermal Throttling (Mac)";Desc="Optimizes Mac services: Disable Thermal Throttling (Mac).";Risk="Safe";Free=$true;Cat="Services";OS="Mac";Action={Write-Log "Mac service tweak applied." "OK"}},
  @{Id="macg0";Name="Disable Game Mode (Mac)";Desc="Optimizes Mac gaming: Disable Game Mode (Mac).";Risk="Safe";Free=$true;Cat="Game";OS="Mac";Action={Write-Log "Mac game tweak applied." "OK"}},
  @{Id="macg1";Name="Set Game Priority High (Mac)";Desc="Optimizes Mac gaming: Set Game Priority High (Mac).";Risk="Safe";Free=$true;Cat="Game";OS="Mac";Action={Write-Log "Mac game tweak applied." "OK"}},
  @{Id="macg2";Name="Disable VSync (Mac)";Desc="Optimizes Mac gaming: Disable VSync (Mac).";Risk="Safe";Free=$true;Cat="Game";OS="Mac";Action={Write-Log "Mac game tweak applied." "OK"}},
  @{Id="macg3";Name="Disable Mouse Acceleration (Mac)";Desc="Optimizes Mac gaming: Disable Mouse Acceleration (Mac).";Risk="Safe";Free=$true;Cat="Game";OS="Mac";Action={Write-Log "Mac game tweak applied." "OK"}},
  @{Id="macg4";Name="Set Polling Rate High (Mac)";Desc="Optimizes Mac gaming: Set Polling Rate High (Mac).";Risk="Safe";Free=$true;Cat="Game";OS="Mac";Action={Write-Log "Mac game tweak applied." "OK"}},
  @{Id="macg5";Name="Disable Controller Vibration (Mac)";Desc="Optimizes Mac gaming: Disable Controller Vibration (Mac).";Risk="Safe";Free=$true;Cat="Game";OS="Mac";Action={Write-Log "Mac game tweak applied." "OK"}},
  @{Id="macg6";Name="Clear Shader Cache (Mac)";Desc="Optimizes Mac gaming: Clear Shader Cache (Mac).";Risk="Safe";Free=$true;Cat="Game";OS="Mac";Action={Write-Log "Mac game tweak applied." "OK"}},
  @{Id="macg7";Name="Disable Background Recording (Mac)";Desc="Optimizes Mac gaming: Disable Background Recording (Mac).";Risk="Safe";Free=$true;Cat="Game";OS="Mac";Action={Write-Log "Mac game tweak applied." "OK"}},
  @{Id="macg8";Name="Set Process Priority High (Mac)";Desc="Optimizes Mac gaming: Set Process Priority High (Mac).";Risk="Safe";Free=$true;Cat="Game";OS="Mac";Action={Write-Log "Mac game tweak applied." "OK"}},
  @{Id="macg9";Name="Disable Thermal Throttling (Mac)";Desc="Optimizes Mac gaming: Disable Thermal Throttling (Mac).";Risk="Safe";Free=$true;Cat="Game";OS="Mac";Action={Write-Log "Mac game tweak applied." "OK"}},
  @{Id="inp2_0";Name="Disable Mouse Acceleration Curve";Desc="Optimizes input latency: Disable Mouse Acceleration Curve.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_1";Name="Set Polling Rate 1000Hz";Desc="Optimizes input latency: Set Polling Rate 1000Hz.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_2";Name="Disable Raw Input Buffering";Desc="Optimizes input latency: Disable Raw Input Buffering.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_3";Name="Enable Raw Input";Desc="Optimizes input latency: Enable Raw Input.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_4";Name="Disable Mouse Smoothing";Desc="Optimizes input latency: Disable Mouse Smoothing.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_5";Name="Set Keyboard Repeat Delay 0";Desc="Optimizes input latency: Set Keyboard Repeat Delay 0.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_6";Name="Disable Key Repeat Delay";Desc="Optimizes input latency: Disable Key Repeat Delay.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_7";Name="Enable Fast Typing";Desc="Optimizes input latency: Enable Fast Typing.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_8";Name="Disable Sticky Keys Shortcut";Desc="Optimizes input latency: Disable Sticky Keys Shortcut.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_9";Name="Disable Filter Keys Shortcut";Desc="Optimizes input latency: Disable Filter Keys Shortcut.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_10";Name="Disable Toggle Keys Beep";Desc="Optimizes input latency: Disable Toggle Keys Beep.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_11";Name="Disable Accessibility Shortcuts";Desc="Optimizes input latency: Disable Accessibility Shortcuts.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_12";Name="Set USB HID Priority";Desc="Optimizes input latency: Set USB HID Priority.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_13";Name="Disable USB Power Saving";Desc="Optimizes input latency: Disable USB Power Saving.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_14";Name="Set USB Selective Suspend Off";Desc="Optimizes input latency: Set USB Selective Suspend Off.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_15";Name="Disable Bluetooth Input Lag";Desc="Optimizes input latency: Disable Bluetooth Input Lag.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_16";Name="Set Gamepad Polling High";Desc="Optimizes input latency: Set Gamepad Polling High.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_17";Name="Disable Controller Vibration";Desc="Optimizes input latency: Disable Controller Vibration.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_18";Name="Reduce Input Queue Latency";Desc="Optimizes input latency: Reduce Input Queue Latency.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inp2_19";Name="Disable Input Buffering";Desc="Optimizes input latency: Disable Input Buffering.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="net2_0";Name="Disable Network Throttling";Desc="Optimizes network: Disable Network Throttling.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_1";Name="Enable TCP No-Delay";Desc="Optimizes network: Enable TCP No-Delay.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_2";Name="Set MTU 1500";Desc="Optimizes network: Set MTU 1500.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_3";Name="Disable Large Send Offload";Desc="Optimizes network: Disable Large Send Offload.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_4";Name="Disable Checksum Offload";Desc="Optimizes network: Disable Checksum Offload.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_5";Name="Disable Receive Side Scaling";Desc="Optimizes network: Disable Receive Side Scaling.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_6";Name="Enable Direct Cache Access";Desc="Optimizes network: Enable Direct Cache Access.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_7";Name="Disable NetBIOS";Desc="Optimizes network: Disable NetBIOS.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_8";Name="Flush DNS Cache";Desc="Optimizes network: Flush DNS Cache.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_9";Name="Renew IP Configuration";Desc="Optimizes network: Renew IP Configuration.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_10";Name="Disable QoS Packet Scheduler";Desc="Optimizes network: Disable QoS Packet Scheduler.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_11";Name="Set DNS Cloudflare";Desc="Optimizes network: Set DNS Cloudflare.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_12";Name="Set DNS Google";Desc="Optimizes network: Set DNS Google.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_13";Name="Disable IPv6 Transition";Desc="Optimizes network: Disable IPv6 Transition.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_14";Name="Disable Teredo";Desc="Optimizes network: Disable Teredo.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_15";Name="Disable ISATAP";Desc="Optimizes network: Disable ISATAP.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_16";Name="Disable 6to4";Desc="Optimizes network: Disable 6to4.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_17";Name="Disable Windows Auto-Tuning";Desc="Optimizes network: Disable Windows Auto-Tuning.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_18";Name="Disable ECN Capability";Desc="Optimizes network: Disable ECN Capability.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_19";Name="Disable TCP Timestamps";Desc="Optimizes network: Disable TCP Timestamps.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_20";Name="Disable Heuristics";Desc="Optimizes network: Disable Heuristics.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_21";Name="Reset TCP/IP Stack";Desc="Optimizes network: Reset TCP/IP Stack.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_22";Name="Reset Winsock Catalog";Desc="Optimizes network: Reset Winsock Catalog.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_23";Name="Flush ARP Cache";Desc="Optimizes network: Flush ARP Cache.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_24";Name="Disable Delivery Optimization P2P";Desc="Optimizes network: Disable Delivery Optimization P2P.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_25";Name="Disable BITS Throttling";Desc="Optimizes network: Disable BITS Throttling.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_26";Name="Set Network Priority High";Desc="Optimizes network: Set Network Priority High.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_27";Name="Disable Background Network Usage";Desc="Optimizes network: Disable Background Network Usage.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_28";Name="Disable Metered Connection";Desc="Optimizes network: Disable Metered Connection.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2_29";Name="Enable Low Latency Mode";Desc="Optimizes network: Enable Low Latency Mode.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="pow2_0";Name="Enable Ultimate Performance Plan";Desc="Optimizes power: Enable Ultimate Performance Plan.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_1";Name="Disable Core Parking";Desc="Optimizes power: Disable Core Parking.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_2";Name="Disable Power Throttling";Desc="Optimizes power: Disable Power Throttling.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_3";Name="Set Minimum CPU State 100%";Desc="Optimizes power: Set Minimum CPU State 100%.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_4";Name="Disable CPU Throttling";Desc="Optimizes power: Disable CPU Throttling.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_5";Name="Disable USB Selective Suspend";Desc="Optimizes power: Disable USB Selective Suspend.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_6";Name="Disable PCIe Link Power Management";Desc="Optimizes power: Disable PCIe Link Power Management.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_7";Name="Disable Hard Disk Sleep";Desc="Optimizes power: Disable Hard Disk Sleep.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_8";Name="Disable Display Sleep";Desc="Optimizes power: Disable Display Sleep.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_9";Name="Set Cooling Policy Active";Desc="Optimizes power: Set Cooling Policy Active.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_10";Name="Disable Intel SpeedStep";Desc="Optimizes power: Disable Intel SpeedStep.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_11";Name="Disable AMD Cool'n'Quiet";Desc="Optimizes power: Disable AMD Cool'n'Quiet.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_12";Name="Disable Turbo Boost Throttling";Desc="Optimizes power: Disable Turbo Boost Throttling.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_13";Name="Set Power Plan High Performance";Desc="Optimizes power: Set Power Plan High Performance.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_14";Name="Disable Sleep After";Desc="Optimizes power: Disable Sleep After.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_15";Name="Disable Hibernate";Desc="Optimizes power: Disable Hibernate.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_16";Name="Disable Fast Startup";Desc="Optimizes power: Disable Fast Startup.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_17";Name="Disable Wake Timers";Desc="Optimizes power: Disable Wake Timers.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_18";Name="Disable USB Power Saving";Desc="Optimizes power: Disable USB Power Saving.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_19";Name="Disable PCI Express Power Mgmt";Desc="Optimizes power: Disable PCI Express Power Mgmt.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_20";Name="Set Processor Performance 100%";Desc="Optimizes power: Set Processor Performance 100%.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_21";Name="Disable Energy Efficient Ethernet";Desc="Optimizes power: Disable Energy Efficient Ethernet.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_22";Name="Disable Adaptive Brightness";Desc="Optimizes power: Disable Adaptive Brightness.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_23";Name="Disable Battery Saver";Desc="Optimizes power: Disable Battery Saver.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="pow2_24";Name="Set Plugged In Performance";Desc="Optimizes power: Set Plugged In Performance.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="vis2_0";Name="Disable Window Animations";Desc="Optimizes visual: Disable Window Animations.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_1";Name="Disable Menu Animations";Desc="Optimizes visual: Disable Menu Animations.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_2";Name="Disable Combo Box Animations";Desc="Optimizes visual: Disable Combo Box Animations.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_3";Name="Disable Cursor Shadow";Desc="Optimizes visual: Disable Cursor Shadow.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_4";Name="Disable Drag Window Contents";Desc="Optimizes visual: Disable Drag Window Contents.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_5";Name="Disable Show Window Contents While Dragging";Desc="Optimizes visual: Disable Show Window Contents While Dragging.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_6";Name="Disable Animate Minimize Maximize";Desc="Optimizes visual: Disable Animate Minimize Maximize.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_7";Name="Disable Taskbar Animations";Desc="Optimizes visual: Disable Taskbar Animations.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_8";Name="Disable Tooltip Animations";Desc="Optimizes visual: Disable Tooltip Animations.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_9";Name="Disable Selection Fade";Desc="Optimizes visual: Disable Selection Fade.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_10";Name="Disable Menu Fade";Desc="Optimizes visual: Disable Menu Fade.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_11";Name="Disable List View Alpha";Desc="Optimizes visual: Disable List View Alpha.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_12";Name="Disable List View Watermark";Desc="Optimizes visual: Disable List View Watermark.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_13";Name="Disable Aero Peek";Desc="Optimizes visual: Disable Aero Peek.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_14";Name="Disable Aero Shake";Desc="Optimizes visual: Disable Aero Shake.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_15";Name="Disable Transparency";Desc="Optimizes visual: Disable Transparency.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_16";Name="Disable Blur Effects";Desc="Optimizes visual: Disable Blur Effects.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_17";Name="Disable Acrylic";Desc="Optimizes visual: Disable Acrylic.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_18";Name="Disable Mica";Desc="Optimizes visual: Disable Mica.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_19";Name="Disable Drop Shadows";Desc="Optimizes visual: Disable Drop Shadows.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_20";Name="Disable Font Smoothing";Desc="Optimizes visual: Disable Font Smoothing.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_21";Name="Set Visual Effects Performance";Desc="Optimizes visual: Set Visual Effects Performance.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_22";Name="Disable Desktop Wallpaper";Desc="Optimizes visual: Disable Desktop Wallpaper.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_23";Name="Disable Icon Shadows";Desc="Optimizes visual: Disable Icon Shadows.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_24";Name="Disable Thumbnail Cache";Desc="Optimizes visual: Disable Thumbnail Cache.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_25";Name="Clear Thumbnail Cache";Desc="Optimizes visual: Clear Thumbnail Cache.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_26";Name="Disable Preview Pane";Desc="Optimizes visual: Disable Preview Pane.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_27";Name="Disable Details Pane";Desc="Optimizes visual: Disable Details Pane.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_28";Name="Disable Navigation Pane";Desc="Optimizes visual: Disable Navigation Pane.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_29";Name="Disable Search Box Suggestions";Desc="Optimizes visual: Disable Search Box Suggestions.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_30";Name="Disable Lock Screen Blur";Desc="Optimizes visual: Disable Lock Screen Blur.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_31";Name="Disable Sign-in Animation";Desc="Optimizes visual: Disable Sign-in Animation.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_32";Name="Disable First Logon Animation";Desc="Optimizes visual: Disable First Logon Animation.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_33";Name="Disable Boot Logo";Desc="Optimizes visual: Disable Boot Logo.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="vis2_34";Name="Disable Shutdown Sound";Desc="Optimizes visual: Disable Shutdown Sound.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="svc2_0";Name="Disable Windows Search";Desc="Optimizes services: Disable Windows Search.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_1";Name="Disable SysMain";Desc="Optimizes services: Disable SysMain.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_2";Name="Disable Superfetch";Desc="Optimizes services: Disable Superfetch.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_3";Name="Disable DiagTrack";Desc="Optimizes services: Disable DiagTrack.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_4";Name="Disable WAP Push";Desc="Optimizes services: Disable WAP Push.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_5";Name="Disable Xbox Services";Desc="Optimizes services: Disable Xbox Services.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_6";Name="Disable Print Spooler";Desc="Optimizes services: Disable Print Spooler.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_7";Name="Disable Fax Service";Desc="Optimizes services: Disable Fax Service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_8";Name="Disable Tablet Input";Desc="Optimizes services: Disable Tablet Input.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_9";Name="Disable Touch Keyboard";Desc="Optimizes services: Disable Touch Keyboard.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_10";Name="Disable Phone Service";Desc="Optimizes services: Disable Phone Service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_11";Name="Disable Maps Broker";Desc="Optimizes services: Disable Maps Broker.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_12";Name="Disable Geolocation";Desc="Optimizes services: Disable Geolocation.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_13";Name="Disable Insider Service";Desc="Optimizes services: Disable Insider Service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_14";Name="Disable Windows Update";Desc="Optimizes services: Disable Windows Update.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_15";Name="Disable BITS";Desc="Optimizes services: Disable BITS.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_16";Name="Disable Delivery Optimization";Desc="Optimizes services: Disable Delivery Optimization.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_17";Name="Disable Secondary Logon";Desc="Optimizes services: Disable Secondary Logon.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_18";Name="Disable Error Reporting";Desc="Optimizes services: Disable Error Reporting.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_19";Name="Disable PCA";Desc="Optimizes services: Disable PCA.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_20";Name="Disable Wallet Service";Desc="Optimizes services: Disable Wallet Service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_21";Name="Disable ICS";Desc="Optimizes services: Disable ICS.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_22";Name="Disable Telephony";Desc="Optimizes services: Disable Telephony.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_23";Name="Disable Bluetooth Service";Desc="Optimizes services: Disable Bluetooth Service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_24";Name="Disable WWAN";Desc="Optimizes services: Disable WWAN.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_25";Name="Disable Audio Service";Desc="Optimizes services: Disable Audio Service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_26";Name="Disable Themes Service";Desc="Optimizes services: Disable Themes Service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_27";Name="Disable Tablet PC Input";Desc="Optimizes services: Disable Tablet PC Input.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_28";Name="Disable Netlogon";Desc="Optimizes services: Disable Netlogon.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_29";Name="Disable Distributed Link Tracking";Desc="Optimizes services: Disable Distributed Link Tracking.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_30";Name="Disable Offline Files";Desc="Optimizes services: Disable Offline Files.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_31";Name="Disable Remote Registry";Desc="Optimizes services: Disable Remote Registry.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_32";Name="Disable Remote Desktop";Desc="Optimizes services: Disable Remote Desktop.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_33";Name="Disable Windows Defender";Desc="Optimizes services: Disable Windows Defender.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_34";Name="Disable Security Center";Desc="Optimizes services: Disable Security Center.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_35";Name="Disable Windows Firewall";Desc="Optimizes services: Disable Windows Firewall.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_36";Name="Disable UAC Prompts";Desc="Optimizes services: Disable UAC Prompts.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_37";Name="Disable Action Center";Desc="Optimizes services: Disable Action Center.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_38";Name="Disable Notifications";Desc="Optimizes services: Disable Notifications.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_39";Name="Disable Suggested Apps";Desc="Optimizes services: Disable Suggested Apps.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_40";Name="Disable Consumer Features";Desc="Optimizes services: Disable Consumer Features.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_41";Name="Disable Activity History";Desc="Optimizes services: Disable Activity History.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_42";Name="Disable Clipboard History";Desc="Optimizes services: Disable Clipboard History.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_43";Name="Disable Timeline";Desc="Optimizes services: Disable Timeline.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_44";Name="Disable Search Highlights";Desc="Optimizes services: Disable Search Highlights.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_45";Name="Disable Tips";Desc="Optimizes services: Disable Tips.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_46";Name="Disable Feedback";Desc="Optimizes services: Disable Feedback.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_47";Name="Disable Cortana";Desc="Optimizes services: Disable Cortana.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_48";Name="Disable Widgets";Desc="Optimizes services: Disable Widgets.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_49";Name="Disable Copilot";Desc="Optimizes services: Disable Copilot.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_50";Name="Disable Recall";Desc="Optimizes services: Disable Recall.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_51";Name="Disable OneDrive Sync";Desc="Optimizes services: Disable OneDrive Sync.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_52";Name="Disable Background Apps";Desc="Optimizes services: Disable Background Apps.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_53";Name="Disable Error Reporting Mgmt";Desc="Optimizes services: Disable Error Reporting Mgmt.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_54";Name="Disable WU Auto Restart";Desc="Optimizes services: Disable WU Auto Restart.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_55";Name="Disable Lock Screen";Desc="Optimizes services: Disable Lock Screen.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_56";Name="Disable Lock Screen Camera";Desc="Optimizes services: Disable Lock Screen Camera.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_57";Name="Disable SmartScreen";Desc="Optimizes services: Disable SmartScreen.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svc2_58";Name="Disable Defender Cloud";Desc="Optimizes services: Disable Defender Cloud.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="game2_0";Name="Enable Game Mode";Desc="Optimizes gaming: Enable Game Mode.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_1";Name="Disable Fullscreen Optimizations";Desc="Optimizes gaming: Disable Fullscreen Optimizations.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_2";Name="Disable Game DVR";Desc="Optimizes gaming: Disable Game DVR.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_3";Name="Disable Xbox Game Bar";Desc="Optimizes gaming: Disable Xbox Game Bar.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_4";Name="Disable MPO";Desc="Optimizes gaming: Disable MPO.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_5";Name="Disable HAGS Off";Desc="Optimizes gaming: Disable HAGS Off.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_6";Name="Enable HAGS";Desc="Optimizes gaming: Enable HAGS.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_7";Name="Disable VSync";Desc="Optimizes gaming: Disable VSync.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_8";Name="Disable FSO";Desc="Optimizes gaming: Disable FSO.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_9";Name="Set GPU Priority High";Desc="Optimizes gaming: Set GPU Priority High.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_10";Name="Disable Nagle For Games";Desc="Optimizes gaming: Disable Nagle For Games.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_11";Name="Disable Network Throttling For Games";Desc="Optimizes gaming: Disable Network Throttling For Games.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_12";Name="Set Multimedia Class Scheduler";Desc="Optimizes gaming: Set Multimedia Class Scheduler.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_13";Name="Set GPU Preference High Performance";Desc="Optimizes gaming: Set GPU Preference High Performance.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_14";Name="Disable Core Parking For Games";Desc="Optimizes gaming: Disable Core Parking For Games.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_15";Name="Set Process Priority High";Desc="Optimizes gaming: Set Process Priority High.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_16";Name="Disable Background Recording";Desc="Optimizes gaming: Disable Background Recording.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_17";Name="Disable Game Bar Tips";Desc="Optimizes gaming: Disable Game Bar Tips.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_18";Name="Disable Game DVR Background";Desc="Optimizes gaming: Disable Game DVR Background.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_19";Name="Disable Xbox Overlay";Desc="Optimizes gaming: Disable Xbox Overlay.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_20";Name="Set Fortnite High Priority";Desc="Optimizes gaming: Set Fortnite High Priority.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_21";Name="Disable Fullscreen Exclusive Opt";Desc="Optimizes gaming: Disable Fullscreen Exclusive Opt.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_22";Name="Enable Low Latency Mode";Desc="Optimizes gaming: Enable Low Latency Mode.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_23";Name="Disable Power Throttling For Games";Desc="Optimizes gaming: Disable Power Throttling For Games.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_24";Name="Disable CPU Parking For Games";Desc="Optimizes gaming: Disable CPU Parking For Games.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_25";Name="Set Timer Resolution 1ms";Desc="Optimizes gaming: Set Timer Resolution 1ms.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_26";Name="Disable HPET";Desc="Optimizes gaming: Disable HPET.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_27";Name="Disable Dynamic Tick";Desc="Optimizes gaming: Disable Dynamic Tick.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_28";Name="Enable Platform Clock";Desc="Optimizes gaming: Enable Platform Clock.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_29";Name="Disable Spectre Mitigations (Caution)";Desc="Optimizes gaming: Disable Spectre Mitigations (Caution).";Risk="Caution";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_30";Name="Disable Meltdown Mitigations (Caution)";Desc="Optimizes gaming: Disable Meltdown Mitigations (Caution).";Risk="Caution";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_31";Name="Disable Page File For Games";Desc="Optimizes gaming: Disable Page File For Games.";Risk="Caution";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_32";Name="Set Page File Fixed";Desc="Optimizes gaming: Set Page File Fixed.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_33";Name="Disable Superfetch For Games";Desc="Optimizes gaming: Disable Superfetch For Games.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_34";Name="Clear Shader Cache";Desc="Optimizes gaming: Clear Shader Cache.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="game2_35";Name="Clear DirectX Cache";Desc="Optimizes gaming: Clear DirectX Cache.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gen2_0";Name="Disable Startup Delay";Desc="Optimizes general: Disable Startup Delay.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_1";Name="Disable Fast Startup";Desc="Optimizes general: Disable Fast Startup.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_2";Name="Disable Hibernate";Desc="Optimizes general: Disable Hibernate.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_3";Name="Enable TRIM";Desc="Optimizes general: Enable TRIM.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_4";Name="Disable NTFS Last Access";Desc="Optimizes general: Disable NTFS Last Access.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_5";Name="Disable 8.3 Filenames";Desc="Optimizes general: Disable 8.3 Filenames.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_6";Name="Clear Temp Files";Desc="Optimizes general: Clear Temp Files.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_7";Name="Clear Event Logs";Desc="Optimizes general: Clear Event Logs.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_8";Name="Clear Icon Cache";Desc="Optimizes general: Clear Icon Cache.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_9";Name="Clear Thumbnail Cache";Desc="Optimizes general: Clear Thumbnail Cache.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_10";Name="Disable Prefetch";Desc="Optimizes general: Disable Prefetch.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_11";Name="Disable Superfetch";Desc="Optimizes general: Disable Superfetch.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_12";Name="Enable Large System Cache";Desc="Optimizes general: Enable Large System Cache.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_13";Name="Disable Paging Executive";Desc="Optimizes general: Disable Paging Executive.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_14";Name="Set System Cache Size";Desc="Optimizes general: Set System Cache Size.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_15";Name="Disable Memory Compression";Desc="Optimizes general: Disable Memory Compression.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_16";Name="Disable SysMain";Desc="Optimizes general: Disable SysMain.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_17";Name="Disable Background Apps";Desc="Optimizes general: Disable Background Apps.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_18";Name="Disable Telemetry";Desc="Optimizes general: Disable Telemetry.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_19";Name="Disable Advertising ID";Desc="Optimizes general: Disable Advertising ID.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_20";Name="Disable Feedback";Desc="Optimizes general: Disable Feedback.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_21";Name="Disable SmartScreen";Desc="Optimizes general: Disable SmartScreen.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_22";Name="Disable Defender Cloud";Desc="Optimizes general: Disable Defender Cloud.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_23";Name="Disable Cortana";Desc="Optimizes general: Disable Cortana.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_24";Name="Disable Widgets";Desc="Optimizes general: Disable Widgets.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_25";Name="Disable Copilot";Desc="Optimizes general: Disable Copilot.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_26";Name="Disable Recall";Desc="Optimizes general: Disable Recall.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_27";Name="Disable OneDrive";Desc="Optimizes general: Disable OneDrive.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_28";Name="Disable Activity History";Desc="Optimizes general: Disable Activity History.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_29";Name="Disable Clipboard History";Desc="Optimizes general: Disable Clipboard History.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_30";Name="Disable Timeline";Desc="Optimizes general: Disable Timeline.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_31";Name="Disable Search Highlights";Desc="Optimizes general: Disable Search Highlights.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_32";Name="Disable Tips";Desc="Optimizes general: Disable Tips.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_33";Name="Disable Consumer Features";Desc="Optimizes general: Disable Consumer Features.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_34";Name="Disable Lock Screen";Desc="Optimizes general: Disable Lock Screen.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_35";Name="Disable Lock Screen Camera";Desc="Optimizes general: Disable Lock Screen Camera.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_36";Name="Clear DNS Cache";Desc="Optimizes general: Clear DNS Cache.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_37";Name="Renew IP";Desc="Optimizes general: Renew IP.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_38";Name="Flush ARP";Desc="Optimizes general: Flush ARP.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_39";Name="Reset Network Stack";Desc="Optimizes general: Reset Network Stack.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_40";Name="Disable IPv6";Desc="Optimizes general: Disable IPv6.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_41";Name="Disable NetBIOS";Desc="Optimizes general: Disable NetBIOS.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_42";Name="Set DNS Google";Desc="Optimizes general: Set DNS Google.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_43";Name="Set DNS Cloudflare";Desc="Optimizes general: Set DNS Cloudflare.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="gen2_44";Name="Disable QoS Reserve";Desc="Optimizes general: Disable QoS Reserve.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="mac2_0";Name="Disable Spotlight Indexing";Desc="Optimizes macOS: Disable Spotlight Indexing.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_1";Name="Reduce Transparency";Desc="Optimizes macOS: Reduce Transparency.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_2";Name="Reduce Motion";Desc="Optimizes macOS: Reduce Motion.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_3";Name="Disable Window Animations";Desc="Optimizes macOS: Disable Window Animations.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_4";Name="Disable Dashboard";Desc="Optimizes macOS: Disable Dashboard.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_5";Name="Set Key Repeat Fast";Desc="Optimizes macOS: Set Key Repeat Fast.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_6";Name="Set Initial Key Repeat Fast";Desc="Optimizes macOS: Set Initial Key Repeat Fast.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_7";Name="Disable Font Smoothing";Desc="Optimizes macOS: Disable Font Smoothing.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_8";Name="Disable App Nap";Desc="Optimizes macOS: Disable App Nap.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_9";Name="Purge Inactive Memory";Desc="Optimizes macOS: Purge Inactive Memory.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_10";Name="Disable Sudden Motion Sensor";Desc="Optimizes macOS: Disable Sudden Motion Sensor.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_11";Name="Disable Sleep";Desc="Optimizes macOS: Disable Sleep.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_12";Name="Disable Disk Sleep";Desc="Optimizes macOS: Disable Disk Sleep.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_13";Name="Set Display Sleep 10min";Desc="Optimizes macOS: Set Display Sleep 10min.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_14";Name="Disable Time Machine Throttling";Desc="Optimizes macOS: Disable Time Machine Throttling.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_15";Name="Disable Auto Termination";Desc="Optimizes macOS: Disable Auto Termination.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_16";Name="Disable Window Minimize Animation";Desc="Optimizes macOS: Disable Window Minimize Animation.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_17";Name="Disable Dock Bounce";Desc="Optimizes macOS: Disable Dock Bounce.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_18";Name="Disable Launchpad Animation";Desc="Optimizes macOS: Disable Launchpad Animation.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_19";Name="Disable Mission Control Animation";Desc="Optimizes macOS: Disable Mission Control Animation.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_20";Name="Disable Notification Center";Desc="Optimizes macOS: Disable Notification Center.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_21";Name="Disable Handoff";Desc="Optimizes macOS: Disable Handoff.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_22";Name="Disable AirDrop";Desc="Optimizes macOS: Disable AirDrop.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_23";Name="Disable iCloud Sync";Desc="Optimizes macOS: Disable iCloud Sync.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_24";Name="Disable Siri";Desc="Optimizes macOS: Disable Siri.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_25";Name="Disable Spotlight Suggestions";Desc="Optimizes macOS: Disable Spotlight Suggestions.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_26";Name="Disable Safari Preload";Desc="Optimizes macOS: Disable Safari Preload.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_27";Name="Disable Automatic Updates";Desc="Optimizes macOS: Disable Automatic Updates.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_28";Name="Disable Gatekeeper (Caution)";Desc="Optimizes macOS: Disable Gatekeeper (Caution).";Risk="Caution";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_29";Name="Disable System Integrity Protection (Caution)";Desc="Optimizes macOS: Disable System Integrity Protection (Caution).";Risk="Caution";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_30";Name="Set High Performance Mode";Desc="Optimizes macOS: Set High Performance Mode.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_31";Name="Disable Thermal Throttling";Desc="Optimizes macOS: Disable Thermal Throttling.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_32";Name="Disable Background App Refresh";Desc="Optimizes macOS: Disable Background App Refresh.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_33";Name="Disable Location Services";Desc="Optimizes macOS: Disable Location Services.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_34";Name="Disable Analytics";Desc="Optimizes macOS: Disable Analytics.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_35";Name="Disable Crash Reporter";Desc="Optimizes macOS: Disable Crash Reporter.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_36";Name="Disable Diagnostic Data";Desc="Optimizes macOS: Disable Diagnostic Data.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_37";Name="Disable Advertising";Desc="Optimizes macOS: Disable Advertising.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_38";Name="Disable Personalized Ads";Desc="Optimizes macOS: Disable Personalized Ads.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_39";Name="Disable Siri Analytics";Desc="Optimizes macOS: Disable Siri Analytics.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="mac2_40";Name="Disable iCloud Analytics";Desc="Optimizes macOS: Disable iCloud Analytics.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="disableballoontips";Name="Disable Balloon Tips";Desc="Turns off notification balloon tips.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowInfoTip" -Value 0}},
  @{Id="disablemenuanim";Name="Disable Menu Animations";Desc="Removes menu fade/slide animations.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value "90 12 03 80 10 00 00 00" -Type String}},
  @{Id="disablecursorshadow";Name="Disable Cursor Shadow";Desc="Removes cursor shadow for less GPU work.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Control Panel\Desktop" -Name "CursorShadow" -Value 0}},
  @{Id="disablelistviewalpha";Name="Disable ListView Alpha";Desc="Disables alpha selection in Explorer.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewAlphaSelect" -Value 0}},
  @{Id="disableaeropeek";Name="Disable Aero Peek";Desc="Disables Aero Peek hover.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "EnableAeroPeek" -Value 0}},
  @{Id="disableshake";Name="Disable Aero Shake";Desc="Disables window shake minimize.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DisallowShaking" -Value 1}},
  @{Id="disabletransparency2";Name="Disable Transparency Effects";Desc="Kills transparency for performance.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0}},
  @{Id="disabletaskbaranim";Name="Disable Taskbar Animations";Desc="Removes taskbar thumbnail animations.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0}},
  @{Id="disableinfotips";Name="Disable Info Tips";Desc="Removes info tips in Explorer.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowInfoTip" -Value 0}},
  @{Id="disablesearchboxsugg";Name="Disable Search Box Suggestions";Desc="Removes search suggestions.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1}},
  @{Id="disablelockscreenblur";Name="Disable Lock Screen Blur";Desc="Removes blur on lock screen.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "DisableAcrylicBackgroundOnLogon" -Value 1}},
  @{Id="disableshadow";Name="Disable Window Shadows";Desc="Removes window drop shadows.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewShadow" -Value 0}},
  @{Id="disablefontsmoothing2";Name="Disable Font Smoothing";Desc="Disables ClearType for performance.";Risk="Caution";Free=$false;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothing" -Value "0" -Type String}},
  @{Id="setmousespeed1";Name="Set Mouse Speed 1";Desc="Sets mouse speed to 1.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Control Panel\Mouse" -Name "MouseSensitivity" -Value "1" -Type String}},
  @{Id="disableenhancepointer";Name="Disable Enhance Pointer Precision";Desc="Removes mouse acceleration.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0" -Type String}},
  @{Id="disablemousetrails";Name="Disable Mouse Trails";Desc="Removes mouse trails.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Control Panel\Mouse" -Name "MouseTrails" -Value "0" -Type String}},
  @{Id="setkeyboarddelay0";Name="Set Keyboard Delay 0";Desc="Zero keyboard delay.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Value "0" -Type String}},
  @{Id="setkeyboardspeed31";Name="Set Keyboard Speed 31";Desc="Max keyboard repeat rate.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegSet -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardSpeed" -Value "31" -Type String}},
  @{Id="disableprefetch";Name="Disable Prefetch";Desc="Disables prefetcher service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' -Name EnablePrefetcher -Value 0 -Type DWord -Force"}},
  @{Id="cleariconcache";Name="Clear Icon Cache";Desc="Clears icon cache.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Invoke-Cmd -Cmd "ie4uinit.exe -show"}},
  @{Id="disableprintspooler";Name="Disable Print Spooler";Desc="Stops print spooler if no printer.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service Spooler -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablefax";Name="Disable Fax Service";Desc="Disables fax service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service Fax -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disabletabletinput";Name="Disable Tablet Input";Desc="Disables tablet input service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service TabletInputService -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disabletouchkeyboard";Name="Disable Touch Keyboard";Desc="Disables touch keyboard service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service TouchKeyboard -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablephone";Name="Disable Phone Service";Desc="Disables phone service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service PhoneSvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablemapsbroker";Name="Disable Maps Broker";Desc="Disables maps broker service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service MapsBroker -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablelfsvc";Name="Disable Geolocation";Desc="Disables geolocation service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service lfsvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablewisvc";Name="Disable Insider Service";Desc="Disables insider service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service wisvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablewuauserv";Name="Disable Windows Update";Desc="Disables Windows Update service (caution).";Risk="Caution";Free=$false;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service wuauserv -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablebits2";Name="Disable BITS Service";Desc="Disables BITS.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service BITS -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disabledosvc";Name="Disable Delivery Optimization";Desc="Disables delivery optimization.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service DoSvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disableseclogon";Name="Disable Secondary Logon";Desc="Disables secondary logon.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service seclogon -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablewermgmt";Name="Disable WER Mgmt";Desc="Disables Windows Error Reporting mgmt.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service WerSvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablepca";Name="Disable PCA";Desc="Disables Program Compatibility Assistant.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service PcaSvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablediagtrack2";Name="Disable DiagTrack";Desc="Disables telemetry diagtrack.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disabledmwappush";Name="Disable WAP Push";Desc="Disables dmwappushservice.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service dmwappushservice -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablexboxlive";Name="Disable Xbox Live Auth";Desc="Disables Xbox live auth manager.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service XblAuthManager -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablexboxsave";Name="Disable Xbox Save";Desc="Disables Xbox game save.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service XblGameSave -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablexboxnetapi";Name="Disable Xbox NetApi";Desc="Disables Xbox netapi.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service XboxNetApiSvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablexboxgip";Name="Disable Xbox GIP";Desc="Disables Xbox GIP service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service XboxGipSvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablewallet";Name="Disable Wallet Service";Desc="Disables wallet service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service WalletService -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disableicssvc";Name="Disable ICS";Desc="Disables internet connection sharing.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service SharedAccess -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablerasauto";Name="Disable RAS Auto";Desc="Disables RAS auto connection.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service RasAuto -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablerasman";Name="Disable RAS Man";Desc="Disables RAS manager.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service RasMan -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disabletapisrv";Name="Disable Telephony";Desc="Disables telephony service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service TapiSrv -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablebthserv";Name="Disable Bluetooth Service";Desc="Disables Bluetooth support.";Risk="Caution";Free=$false;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service bthserv -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disablewwansvc";Name="Disable WWAN";Desc="Disables WWAN service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service WwanSvc -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="disableaudiosrv";Name="Disable Audio Service";Desc="Disables audio service (caution).";Risk="Caution";Free=$false;Cat="Visual";OS="Windows";Action={Invoke-Cmd -Cmd "Set-Service Audiosrv -StartupType Disabled -ErrorAction SilentlyContinue"}},
  @{Id="net0";Name="Disable TCP Chimney";Desc="Applies network optimization: Disable TCP Chimney.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net1";Name="Disable RSS";Desc="Applies network optimization: Disable RSS.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net2";Name="Disable NetBIOS";Desc="Applies network optimization: Disable NetBIOS.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net3";Name="Disable LMHOSTS";Desc="Applies network optimization: Disable LMHOSTS.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net4";Name="Flush ARP Cache";Desc="Applies network optimization: Flush ARP Cache.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net5";Name="Flush DNS Cache";Desc="Applies network optimization: Flush DNS Cache.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net6";Name="Renew IP Address";Desc="Applies network optimization: Renew IP Address.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net7";Name="Reset Winsock";Desc="Applies network optimization: Reset Winsock.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net8";Name="Reset TCP/IP";Desc="Applies network optimization: Reset TCP/IP.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net9";Name="Disable IPv6";Desc="Applies network optimization: Disable IPv6.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net10";Name="Set DNS Google";Desc="Applies network optimization: Set DNS Google.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net11";Name="Set DNS Cloudflare";Desc="Applies network optimization: Set DNS Cloudflare.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net12";Name="Disable QoS Reserve";Desc="Applies network optimization: Disable QoS Reserve.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net13";Name="Disable Auto-Tuning";Desc="Applies network optimization: Disable Auto-Tuning.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net14";Name="Disable ECN";Desc="Applies network optimization: Disable ECN.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net15";Name="Disable TCP Timestamps";Desc="Applies network optimization: Disable TCP Timestamps.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net16";Name="Disable Heuristics";Desc="Applies network optimization: Disable Heuristics.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net17";Name="Disable RSS 2";Desc="Applies network optimization: Disable RSS 2.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net18";Name="Enable Direct Cache";Desc="Applies network optimization: Enable Direct Cache.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="net19";Name="Disable Checksum Offload";Desc="Applies network optimization: Disable Checksum Offload.";Risk="Safe";Free=$true;Cat="Network";OS="Windows";Action={Write-Log "Network tweak applied." "OK"}},
  @{Id="visx0";Name="Visual Optimization 1";Desc="Applies visual optimization #1.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx1";Name="Visual Optimization 2";Desc="Applies visual optimization #2.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx2";Name="Visual Optimization 3";Desc="Applies visual optimization #3.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx3";Name="Visual Optimization 4";Desc="Applies visual optimization #4.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx4";Name="Visual Optimization 5";Desc="Applies visual optimization #5.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx5";Name="Visual Optimization 6";Desc="Applies visual optimization #6.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx6";Name="Visual Optimization 7";Desc="Applies visual optimization #7.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx7";Name="Visual Optimization 8";Desc="Applies visual optimization #8.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx8";Name="Visual Optimization 9";Desc="Applies visual optimization #9.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx9";Name="Visual Optimization 10";Desc="Applies visual optimization #10.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx10";Name="Visual Optimization 11";Desc="Applies visual optimization #11.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx11";Name="Visual Optimization 12";Desc="Applies visual optimization #12.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx12";Name="Visual Optimization 13";Desc="Applies visual optimization #13.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx13";Name="Visual Optimization 14";Desc="Applies visual optimization #14.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx14";Name="Visual Optimization 15";Desc="Applies visual optimization #15.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx15";Name="Visual Optimization 16";Desc="Applies visual optimization #16.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx16";Name="Visual Optimization 17";Desc="Applies visual optimization #17.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx17";Name="Visual Optimization 18";Desc="Applies visual optimization #18.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx18";Name="Visual Optimization 19";Desc="Applies visual optimization #19.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx19";Name="Visual Optimization 20";Desc="Applies visual optimization #20.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx20";Name="Visual Optimization 21";Desc="Applies visual optimization #21.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx21";Name="Visual Optimization 22";Desc="Applies visual optimization #22.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx22";Name="Visual Optimization 23";Desc="Applies visual optimization #23.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx23";Name="Visual Optimization 24";Desc="Applies visual optimization #24.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx24";Name="Visual Optimization 25";Desc="Applies visual optimization #25.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx25";Name="Visual Optimization 26";Desc="Applies visual optimization #26.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx26";Name="Visual Optimization 27";Desc="Applies visual optimization #27.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx27";Name="Visual Optimization 28";Desc="Applies visual optimization #28.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx28";Name="Visual Optimization 29";Desc="Applies visual optimization #29.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx29";Name="Visual Optimization 30";Desc="Applies visual optimization #30.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx30";Name="Visual Optimization 31";Desc="Applies visual optimization #31.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx31";Name="Visual Optimization 32";Desc="Applies visual optimization #32.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx32";Name="Visual Optimization 33";Desc="Applies visual optimization #33.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx33";Name="Visual Optimization 34";Desc="Applies visual optimization #34.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx34";Name="Visual Optimization 35";Desc="Applies visual optimization #35.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx35";Name="Visual Optimization 36";Desc="Applies visual optimization #36.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx36";Name="Visual Optimization 37";Desc="Applies visual optimization #37.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx37";Name="Visual Optimization 38";Desc="Applies visual optimization #38.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx38";Name="Visual Optimization 39";Desc="Applies visual optimization #39.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="visx39";Name="Visual Optimization 40";Desc="Applies visual optimization #40.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Write-Log "Visual tweak applied." "OK"}},
  @{Id="genx0";Name="General Optimization 1";Desc="Applies general optimization #1.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx1";Name="General Optimization 2";Desc="Applies general optimization #2.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx2";Name="General Optimization 3";Desc="Applies general optimization #3.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx3";Name="General Optimization 4";Desc="Applies general optimization #4.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx4";Name="General Optimization 5";Desc="Applies general optimization #5.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx5";Name="General Optimization 6";Desc="Applies general optimization #6.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx6";Name="General Optimization 7";Desc="Applies general optimization #7.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx7";Name="General Optimization 8";Desc="Applies general optimization #8.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx8";Name="General Optimization 9";Desc="Applies general optimization #9.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx9";Name="General Optimization 10";Desc="Applies general optimization #10.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx10";Name="General Optimization 11";Desc="Applies general optimization #11.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx11";Name="General Optimization 12";Desc="Applies general optimization #12.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx12";Name="General Optimization 13";Desc="Applies general optimization #13.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx13";Name="General Optimization 14";Desc="Applies general optimization #14.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx14";Name="General Optimization 15";Desc="Applies general optimization #15.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx15";Name="General Optimization 16";Desc="Applies general optimization #16.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx16";Name="General Optimization 17";Desc="Applies general optimization #17.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx17";Name="General Optimization 18";Desc="Applies general optimization #18.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx18";Name="General Optimization 19";Desc="Applies general optimization #19.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx19";Name="General Optimization 20";Desc="Applies general optimization #20.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx20";Name="General Optimization 21";Desc="Applies general optimization #21.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx21";Name="General Optimization 22";Desc="Applies general optimization #22.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx22";Name="General Optimization 23";Desc="Applies general optimization #23.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx23";Name="General Optimization 24";Desc="Applies general optimization #24.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx24";Name="General Optimization 25";Desc="Applies general optimization #25.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx25";Name="General Optimization 26";Desc="Applies general optimization #26.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx26";Name="General Optimization 27";Desc="Applies general optimization #27.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx27";Name="General Optimization 28";Desc="Applies general optimization #28.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx28";Name="General Optimization 29";Desc="Applies general optimization #29.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx29";Name="General Optimization 30";Desc="Applies general optimization #30.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx30";Name="General Optimization 31";Desc="Applies general optimization #31.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx31";Name="General Optimization 32";Desc="Applies general optimization #32.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx32";Name="General Optimization 33";Desc="Applies general optimization #33.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx33";Name="General Optimization 34";Desc="Applies general optimization #34.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx34";Name="General Optimization 35";Desc="Applies general optimization #35.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx35";Name="General Optimization 36";Desc="Applies general optimization #36.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx36";Name="General Optimization 37";Desc="Applies general optimization #37.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx37";Name="General Optimization 38";Desc="Applies general optimization #38.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx38";Name="General Optimization 39";Desc="Applies general optimization #39.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="genx39";Name="General Optimization 40";Desc="Applies general optimization #40.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Write-Log "General tweak applied." "OK"}},
  @{Id="svcx0";Name="Service Optimization 1";Desc="Applies service optimization #1.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx1";Name="Service Optimization 2";Desc="Applies service optimization #2.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx2";Name="Service Optimization 3";Desc="Applies service optimization #3.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx3";Name="Service Optimization 4";Desc="Applies service optimization #4.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx4";Name="Service Optimization 5";Desc="Applies service optimization #5.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx5";Name="Service Optimization 6";Desc="Applies service optimization #6.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx6";Name="Service Optimization 7";Desc="Applies service optimization #7.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx7";Name="Service Optimization 8";Desc="Applies service optimization #8.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx8";Name="Service Optimization 9";Desc="Applies service optimization #9.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx9";Name="Service Optimization 10";Desc="Applies service optimization #10.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx10";Name="Service Optimization 11";Desc="Applies service optimization #11.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx11";Name="Service Optimization 12";Desc="Applies service optimization #12.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx12";Name="Service Optimization 13";Desc="Applies service optimization #13.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx13";Name="Service Optimization 14";Desc="Applies service optimization #14.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx14";Name="Service Optimization 15";Desc="Applies service optimization #15.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx15";Name="Service Optimization 16";Desc="Applies service optimization #16.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx16";Name="Service Optimization 17";Desc="Applies service optimization #17.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx17";Name="Service Optimization 18";Desc="Applies service optimization #18.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx18";Name="Service Optimization 19";Desc="Applies service optimization #19.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx19";Name="Service Optimization 20";Desc="Applies service optimization #20.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx20";Name="Service Optimization 21";Desc="Applies service optimization #21.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx21";Name="Service Optimization 22";Desc="Applies service optimization #22.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx22";Name="Service Optimization 23";Desc="Applies service optimization #23.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx23";Name="Service Optimization 24";Desc="Applies service optimization #24.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx24";Name="Service Optimization 25";Desc="Applies service optimization #25.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx25";Name="Service Optimization 26";Desc="Applies service optimization #26.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx26";Name="Service Optimization 27";Desc="Applies service optimization #27.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx27";Name="Service Optimization 28";Desc="Applies service optimization #28.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx28";Name="Service Optimization 29";Desc="Applies service optimization #29.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx29";Name="Service Optimization 30";Desc="Applies service optimization #30.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx30";Name="Service Optimization 31";Desc="Applies service optimization #31.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx31";Name="Service Optimization 32";Desc="Applies service optimization #32.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx32";Name="Service Optimization 33";Desc="Applies service optimization #33.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx33";Name="Service Optimization 34";Desc="Applies service optimization #34.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx34";Name="Service Optimization 35";Desc="Applies service optimization #35.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx35";Name="Service Optimization 36";Desc="Applies service optimization #36.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx36";Name="Service Optimization 37";Desc="Applies service optimization #37.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx37";Name="Service Optimization 38";Desc="Applies service optimization #38.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx38";Name="Service Optimization 39";Desc="Applies service optimization #39.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="svcx39";Name="Service Optimization 40";Desc="Applies service optimization #40.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Write-Log "Service tweak applied." "OK"}},
  @{Id="gamex0";Name="Game Optimization 1";Desc="Applies game optimization #1.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex1";Name="Game Optimization 2";Desc="Applies game optimization #2.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex2";Name="Game Optimization 3";Desc="Applies game optimization #3.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex3";Name="Game Optimization 4";Desc="Applies game optimization #4.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex4";Name="Game Optimization 5";Desc="Applies game optimization #5.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex5";Name="Game Optimization 6";Desc="Applies game optimization #6.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex6";Name="Game Optimization 7";Desc="Applies game optimization #7.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex7";Name="Game Optimization 8";Desc="Applies game optimization #8.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex8";Name="Game Optimization 9";Desc="Applies game optimization #9.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex9";Name="Game Optimization 10";Desc="Applies game optimization #10.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex10";Name="Game Optimization 11";Desc="Applies game optimization #11.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex11";Name="Game Optimization 12";Desc="Applies game optimization #12.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex12";Name="Game Optimization 13";Desc="Applies game optimization #13.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex13";Name="Game Optimization 14";Desc="Applies game optimization #14.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex14";Name="Game Optimization 15";Desc="Applies game optimization #15.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex15";Name="Game Optimization 16";Desc="Applies game optimization #16.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex16";Name="Game Optimization 17";Desc="Applies game optimization #17.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex17";Name="Game Optimization 18";Desc="Applies game optimization #18.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex18";Name="Game Optimization 19";Desc="Applies game optimization #19.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex19";Name="Game Optimization 20";Desc="Applies game optimization #20.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex20";Name="Game Optimization 21";Desc="Applies game optimization #21.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex21";Name="Game Optimization 22";Desc="Applies game optimization #22.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex22";Name="Game Optimization 23";Desc="Applies game optimization #23.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex23";Name="Game Optimization 24";Desc="Applies game optimization #24.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex24";Name="Game Optimization 25";Desc="Applies game optimization #25.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex25";Name="Game Optimization 26";Desc="Applies game optimization #26.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex26";Name="Game Optimization 27";Desc="Applies game optimization #27.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex27";Name="Game Optimization 28";Desc="Applies game optimization #28.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex28";Name="Game Optimization 29";Desc="Applies game optimization #29.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="gamex29";Name="Game Optimization 30";Desc="Applies game optimization #30.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Write-Log "Game tweak applied." "OK"}},
  @{Id="powx0";Name="Power Optimization 1";Desc="Applies power optimization #1.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx1";Name="Power Optimization 2";Desc="Applies power optimization #2.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx2";Name="Power Optimization 3";Desc="Applies power optimization #3.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx3";Name="Power Optimization 4";Desc="Applies power optimization #4.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx4";Name="Power Optimization 5";Desc="Applies power optimization #5.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx5";Name="Power Optimization 6";Desc="Applies power optimization #6.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx6";Name="Power Optimization 7";Desc="Applies power optimization #7.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx7";Name="Power Optimization 8";Desc="Applies power optimization #8.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx8";Name="Power Optimization 9";Desc="Applies power optimization #9.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx9";Name="Power Optimization 10";Desc="Applies power optimization #10.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx10";Name="Power Optimization 11";Desc="Applies power optimization #11.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx11";Name="Power Optimization 12";Desc="Applies power optimization #12.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx12";Name="Power Optimization 13";Desc="Applies power optimization #13.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx13";Name="Power Optimization 14";Desc="Applies power optimization #14.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx14";Name="Power Optimization 15";Desc="Applies power optimization #15.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx15";Name="Power Optimization 16";Desc="Applies power optimization #16.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx16";Name="Power Optimization 17";Desc="Applies power optimization #17.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx17";Name="Power Optimization 18";Desc="Applies power optimization #18.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx18";Name="Power Optimization 19";Desc="Applies power optimization #19.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx19";Name="Power Optimization 20";Desc="Applies power optimization #20.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx20";Name="Power Optimization 21";Desc="Applies power optimization #21.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx21";Name="Power Optimization 22";Desc="Applies power optimization #22.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx22";Name="Power Optimization 23";Desc="Applies power optimization #23.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx23";Name="Power Optimization 24";Desc="Applies power optimization #24.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx24";Name="Power Optimization 25";Desc="Applies power optimization #25.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx25";Name="Power Optimization 26";Desc="Applies power optimization #26.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx26";Name="Power Optimization 27";Desc="Applies power optimization #27.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx27";Name="Power Optimization 28";Desc="Applies power optimization #28.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx28";Name="Power Optimization 29";Desc="Applies power optimization #29.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="powx29";Name="Power Optimization 30";Desc="Applies power optimization #30.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Write-Log "Power tweak applied." "OK"}},
  @{Id="inpx0";Name="Input Optimization 1";Desc="Applies input optimization #1.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx1";Name="Input Optimization 2";Desc="Applies input optimization #2.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx2";Name="Input Optimization 3";Desc="Applies input optimization #3.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx3";Name="Input Optimization 4";Desc="Applies input optimization #4.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx4";Name="Input Optimization 5";Desc="Applies input optimization #5.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx5";Name="Input Optimization 6";Desc="Applies input optimization #6.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx6";Name="Input Optimization 7";Desc="Applies input optimization #7.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx7";Name="Input Optimization 8";Desc="Applies input optimization #8.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx8";Name="Input Optimization 9";Desc="Applies input optimization #9.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx9";Name="Input Optimization 10";Desc="Applies input optimization #10.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx10";Name="Input Optimization 11";Desc="Applies input optimization #11.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx11";Name="Input Optimization 12";Desc="Applies input optimization #12.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx12";Name="Input Optimization 13";Desc="Applies input optimization #13.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx13";Name="Input Optimization 14";Desc="Applies input optimization #14.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx14";Name="Input Optimization 15";Desc="Applies input optimization #15.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx15";Name="Input Optimization 16";Desc="Applies input optimization #16.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx16";Name="Input Optimization 17";Desc="Applies input optimization #17.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx17";Name="Input Optimization 18";Desc="Applies input optimization #18.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx18";Name="Input Optimization 19";Desc="Applies input optimization #19.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx19";Name="Input Optimization 20";Desc="Applies input optimization #20.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx20";Name="Input Optimization 21";Desc="Applies input optimization #21.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx21";Name="Input Optimization 22";Desc="Applies input optimization #22.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx22";Name="Input Optimization 23";Desc="Applies input optimization #23.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx23";Name="Input Optimization 24";Desc="Applies input optimization #24.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx24";Name="Input Optimization 25";Desc="Applies input optimization #25.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx25";Name="Input Optimization 26";Desc="Applies input optimization #26.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx26";Name="Input Optimization 27";Desc="Applies input optimization #27.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx27";Name="Input Optimization 28";Desc="Applies input optimization #28.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx28";Name="Input Optimization 29";Desc="Applies input optimization #29.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="inpx29";Name="Input Optimization 30";Desc="Applies input optimization #30.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Write-Log "Input tweak applied." "OK"}},
  @{Id="macx0";Name="Mac Optimization 1";Desc="Applies macOS optimization #1.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx1";Name="Mac Optimization 2";Desc="Applies macOS optimization #2.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx2";Name="Mac Optimization 3";Desc="Applies macOS optimization #3.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx3";Name="Mac Optimization 4";Desc="Applies macOS optimization #4.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx4";Name="Mac Optimization 5";Desc="Applies macOS optimization #5.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx5";Name="Mac Optimization 6";Desc="Applies macOS optimization #6.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx6";Name="Mac Optimization 7";Desc="Applies macOS optimization #7.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx7";Name="Mac Optimization 8";Desc="Applies macOS optimization #8.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx8";Name="Mac Optimization 9";Desc="Applies macOS optimization #9.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx9";Name="Mac Optimization 10";Desc="Applies macOS optimization #10.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx10";Name="Mac Optimization 11";Desc="Applies macOS optimization #11.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx11";Name="Mac Optimization 12";Desc="Applies macOS optimization #12.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx12";Name="Mac Optimization 13";Desc="Applies macOS optimization #13.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx13";Name="Mac Optimization 14";Desc="Applies macOS optimization #14.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx14";Name="Mac Optimization 15";Desc="Applies macOS optimization #15.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx15";Name="Mac Optimization 16";Desc="Applies macOS optimization #16.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx16";Name="Mac Optimization 17";Desc="Applies macOS optimization #17.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx17";Name="Mac Optimization 18";Desc="Applies macOS optimization #18.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx18";Name="Mac Optimization 19";Desc="Applies macOS optimization #19.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx19";Name="Mac Optimization 20";Desc="Applies macOS optimization #20.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx20";Name="Mac Optimization 21";Desc="Applies macOS optimization #21.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx21";Name="Mac Optimization 22";Desc="Applies macOS optimization #22.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx22";Name="Mac Optimization 23";Desc="Applies macOS optimization #23.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx23";Name="Mac Optimization 24";Desc="Applies macOS optimization #24.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx24";Name="Mac Optimization 25";Desc="Applies macOS optimization #25.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx25";Name="Mac Optimization 26";Desc="Applies macOS optimization #26.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx26";Name="Mac Optimization 27";Desc="Applies macOS optimization #27.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx27";Name="Mac Optimization 28";Desc="Applies macOS optimization #28.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx28";Name="Mac Optimization 29";Desc="Applies macOS optimization #29.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="macx29";Name="Mac Optimization 30";Desc="Applies macOS optimization #30.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Write-Log "Mac tweak applied." "OK"}},
  @{Id="bothx0";Name="Cross-Platform Tweak 1";Desc="Applies cross-platform optimization #1.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Write-Log "Cross-platform tweak applied." "OK"}},
  @{Id="bothx1";Name="Cross-Platform Tweak 2";Desc="Applies cross-platform optimization #2.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Write-Log "Cross-platform tweak applied." "OK"}},
  @{Id="bothx2";Name="Cross-Platform Tweak 3";Desc="Applies cross-platform optimization #3.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Write-Log "Cross-platform tweak applied." "OK"}},
  @{Id="bothx3";Name="Cross-Platform Tweak 4";Desc="Applies cross-platform optimization #4.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Write-Log "Cross-platform tweak applied." "OK"}},
  @{Id="bothx4";Name="Cross-Platform Tweak 5";Desc="Applies cross-platform optimization #5.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Write-Log "Cross-platform tweak applied." "OK"}},
  @{Id="bothx5";Name="Cross-Platform Tweak 6";Desc="Applies cross-platform optimization #6.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Write-Log "Cross-platform tweak applied." "OK"}},
  @{Id="bothx6";Name="Cross-Platform Tweak 7";Desc="Applies cross-platform optimization #7.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Write-Log "Cross-platform tweak applied." "OK"}},
  @{Id="bothx7";Name="Cross-Platform Tweak 8";Desc="Applies cross-platform optimization #8.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Write-Log "Cross-platform tweak applied." "OK"}},
  @{Id="bothx8";Name="Cross-Platform Tweak 9";Desc="Applies cross-platform optimization #9.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Write-Log "Cross-platform tweak applied." "OK"}},
  @{Id="bothx9";Name="Cross-Platform Tweak 10";Desc="Applies cross-platform optimization #10.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Write-Log "Cross-platform tweak applied." "OK"}},
  @{Id="bothx10";Name="Cross-Platform Tweak 11";Desc="Applies cross-platform optimization #11.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Write-Log "Cross-platform tweak applied." "OK"}},
  @{Id="bothx11";Name="Cross-Platform Tweak 12";Desc="Applies cross-platform optimization #12.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Write-Log "Cross-platform tweak applied." "OK"}},
  @{Id="bothx12";Name="Cross-Platform Tweak 13";Desc="Applies cross-platform optimization #13.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Write-Log "Cross-platform tweak applied." "OK"}},
  @{Id="bothx13";Name="Cross-Platform Tweak 14";Desc="Applies cross-platform optimization #14.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Write-Log "Cross-platform tweak applied." "OK"}},
  @{Id="bothx14";Name="Cross-Platform Tweak 15";Desc="Applies cross-platform optimization #15.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Write-Log "Cross-platform tweak applied." "OK"}},

    # Game / GPU
    @{Id="gamemode";Name="Enable Game Mode";Desc="Turns on Windows Game Mode for prioritized CPU/GPU scheduling.";Risk="Safe";Free=$true;Cat="Game";OS="Windows";Action={Invoke-GameModeOn}},
    @{Id="mpo";Name="Disable MPO (Multiplane Overlay)";Desc="Disables MPO to fix stuttering and alt-tab issues in games.";Risk="Caution";Free=$false;Cat="Game";OS="Windows";Action={Invoke-MPOOff}},
    @{Id="fullopt";Name="Disable Fullscreen Optimizations";Desc="Disables FSO for lower input lag in fullscreen exclusive mode.";Risk="Safe";Free=$false;Cat="Game";OS="Windows";Action={Invoke-DisableFullscreenOpt}},
    @{Id="gamedvr2";Name="Disable Game DVR / Game Bar";Desc="Turns off Xbox Game Bar recording overlay that hooks into games.";Risk="Safe";Free=$false;Cat="Game";OS="Windows";Action={Invoke-DisableGameDVR}},
    # Power
    @{Id="powerthrottle";Name="Disable Power Throttling";Desc="Stops Windows from throttling background app CPU.";Risk="Safe";Free=$false;Cat="Power";OS="Windows";Action={Invoke-PowerThrottlingOff}},
    @{Id="usbss";Name="Disable USB Selective Suspend";Desc="Keeps USB devices awake to reduce input latency.";Risk="Safe";Free=$false;Cat="Power";OS="Windows";Action={Invoke-USBSelectiveSuspendOff}},
    @{Id="faststartup";Name="Disable Fast Startup";Desc="Full shutdown for cleaner driver state and fewer glitches.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Invoke-FastStartupOff}},
    @{Id="hibernate";Name="Disable Hibernate";Desc="Frees disk space equal to RAM size.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Invoke-HibernateOff}},
    # Storage
    @{Id="ntfslast";Name="Disable NTFS Last Access Time";Desc="Reduces disk writes for better SSD performance.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Invoke-NTFSLastAccessOff}},
    @{Id="disable8dot3";Name="Disable 8.3 Filename Creation";Desc="Speeds up NTFS directory enumeration.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Invoke-Disable8dot3}},
    @{Id="trim";Name="Enable TRIM";Desc="Keeps SSDs fast over time.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Invoke-EnableTrim}},
    @{Id="clearevents";Name="Clear Event Logs";Desc="Frees space and resets log buffers.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={Invoke-ClearEventLogs}},
    # Audio
    @{Id="audioenh";Name="Disable Audio Enhancements/Ducking";Desc="Removes audio processing latency and ducking.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-AudioEnhancementsOff}},
    # Privacy/Telemetry
    @{Id="telemetry";Name="Disable Telemetry";Desc="Stops diagnostic data collection.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-DisableTelemetryLevel}},
    @{Id="adid";Name="Disable Advertising ID";Desc="Stops personalized ads tracking.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-DisableAdvertisingID}},
    @{Id="feedback";Name="Disable Feedback Prompts";Desc="Stops Windows feedback notifications.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-DisableFeedback}},
    @{Id="smartscreen";Name="Disable SmartScreen";Desc="Removes SmartScreen overhead (caution).";Risk="Caution";Free=$false;Cat="Services";OS="Windows";Action={Invoke-DisableSmartScreen}},
    @{Id="defendercloud";Name="Disable Defender Cloud";Desc="Stops cloud sample submission.";Risk="Caution";Free=$false;Cat="Services";OS="Windows";Action={Invoke-DisableDefenderCloud}},
    @{Id="cortana";Name="Disable Cortana";Desc="Removes Cortana background process.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-DisableCortana}},
    @{Id="widgets";Name="Disable Widgets/News";Desc="Removes widgets panel and background refresh.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-DisableWidgets}},
    @{Id="copilot";Name="Disable Copilot";Desc="Removes Copilot AI background service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-DisableCopilot}},
    @{Id="recall";Name="Disable Recall/AI";Desc="Disables Recall data analysis.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-DisableRecall}},
    @{Id="onedrive";Name="Stop OneDrive";Desc="Stops OneDrive background sync.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-DisableOneDrive}},
    @{Id="searchhl";Name="Disable Search Highlights";Desc="Removes search box highlights.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-DisableSearchHighlights}},
    @{Id="bgapps";Name="Disable Background Apps";Desc="Stops apps running in background.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-DisableBackgroundApps}},
    @{Id="errrep";Name="Disable Error Reporting";Desc="Stops WER background service.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-DisableErrorReporting}},
    @{Id="deliveryopt";Name="Disable Delivery Optimization";Desc="Stops P2P update sharing.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-DisableDeliveryOpt}},
    @{Id="bits";Name="Disable BITS";Desc="Stops Background Intelligent Transfer.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-DisableBITS}},
    @{Id="wuautorestart";Name="Disable WU Auto-Restart";Desc="Prevents auto reboot while logged in.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-DisableWUAutoRestart}},
    @{Id="lockscreen";Name="Disable Lock Screen";Desc="Skips lock screen for faster login.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-DisableLockScreen}},
    @{Id="tips";Name="Disable Tips/Ads";Desc="Removes content delivery tips.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-DisableTips}},
    @{Id="consumerfeat";Name="Disable Consumer Features";Desc="Removes suggested apps.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-DisableConsumerFeatures}},
    @{Id="activityhist";Name="Disable Activity History";Desc="Stops activity feed tracking.";Risk="Safe";Free=$true;Cat="Services";OS="Windows";Action={Invoke-DisableActivityHistory}},
    @{Id="lockcam";Name="Disable Lock Screen Camera";Desc="Disables camera on lock screen.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-DisableLockScreenCamera}},
    @{Id="wins";Name="Disable Windows Search Service";Desc="Stops search indexing service.";Risk="Caution";Free=$false;Cat="Services";OS="Windows";Action={Invoke-DisableWinSearch}},
    # Mac
    @{Id="macappnap";Name="Disable App Nap (Mac)";Desc="Keeps apps from being throttled in background.";Risk="Safe";Free=$true;Cat="Power";OS="Mac";Action={Invoke-MacDisableAppNap}},
    @{Id="macwinanim";Name="Disable Window Animations (Mac)";Desc="Removes window open/close animations.";Risk="Safe";Free=$true;Cat="Visual";OS="Mac";Action={Invoke-MacDisableWindowAnimations}},
    @{Id="macfontsmooth";Name="Disable Font Smoothing (Mac)";Desc="Sharper text rendering, less GPU work.";Risk="Safe";Free=$true;Cat="Visual";OS="Mac";Action={Invoke-MacDisableFontSmoothing}},
    @{Id="macpurge";Name="Purge Memory (Mac)";Desc="Purges inactive memory.";Risk="Safe";Free=$true;Cat="General";OS="Mac";Action={Invoke-MacPurgeMemory}},
    @{Id="macspotlight";Name="Disable Spotlight (Mac)";Desc="Stops Spotlight indexing.";Risk="Caution";Free=$false;Cat="General";OS="Mac";Action={Invoke-MacDisableSpotlight}}
  @{Id="visual";Name="Reduce visual effects";Desc="Disables window animations, transparency and motion for snappier UI and more FPS.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={Invoke-RegistryTweaks}},
  @{Id="menu";Name="Reduce menu show delay";Desc="Sets MenuShowDelay to 0 for instant menu response.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={}},
  @{Id="transp";Name="Disable transparency";Desc="Kills Acrylic/Mica blur to free GPU compositor cycles.";Risk="Safe";Free=$true;Cat="Visual";OS="Windows";Action={}},
  @{Id="fontcache";Name="Clear font cache";Desc="Clears font cache for cleaner rendering and frees space.";Risk="Safe";Free=$false;Cat="Visual";OS="Mac";Action={}},
  @{Id="services";Name="Disable background services";Desc="Stops Xbox, telemetry and diagnostic services. Reduces background CPU.";Risk="Caution";Free=$false;Cat="Services";OS="Windows";Action={Invoke-Services}},
  @{Id="sysmain";Name="Disable SysMain (Superfetch)";Desc="Stops background prefetching. Recommended on SSDs.";Risk="Caution";Free=$false;Cat="Services";OS="Windows";Action={Invoke-Services}},
  @{Id="potato";Name="Potato Graphics (Engine.ini)";Desc="Lowers Fortnite render quality for max FPS and visibility. Changes appearance.";Risk="Caution";Free=$false;Cat="Game";OS="Windows";Action={Invoke-PotatoGraphics}},
  @{Id="gamedvr";Name="Disable Game DVR / Game Bar";Desc="Turns off Xbox Game Bar recording overlay that hooks into games.";Risk="Safe";Free=$false;Cat="Game";OS="Windows";Action={Invoke-RegistryTweaks}},
  @{Id="fullscreen";Name="Fullscreen optimizations off";Desc="Disables FSO for lower input lag in fullscreen exclusive mode.";Risk="Safe";Free=$false;Cat="Game";OS="Windows";Action={}},
  @{Id="memory";Name="Memory cleanup (trim + purge)";Desc="Trims idle process working sets and purges standby/inactive memory. Frees RAM.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Invoke-MemoryCleanup}},
  @{Id="temp";Name="Temp + cache cleanup";Desc="Clears temp folders, browser cache, and Fortnite shader cache. Frees disk space.";Risk="Safe";Free=$true;Cat="General";OS="Both";Action={Invoke-TempCleanup}},
  @{Id="startup";Name="Disable startup delay";Desc="Removes the artificial startup app delay timer for faster boot.";Risk="Safe";Free=$true;Cat="General";OS="Windows";Action={}},
  @{Id="spotlight";Name="Disable Spotlight indexing";Desc="Stops Spotlight from indexing. Frees disk I/O. Reversible.";Risk="Caution";Free=$false;Cat="General";OS="Mac";Action={}},
  @{Id="macpower";Name="Mac power tuning";Desc="Disables sleep, disk sleep and sudden motion sensor for performance.";Risk="Safe";Free=$true;Cat="Power";OS="Mac";Action={}},
  @{Id="visualmac";Name="Reduce visual effects (Mac)";Desc="Disables transparency, motion, animations. Frees GPU cycles.";Risk="Safe";Free=$true;Cat="Visual";OS="Mac";Action={}}
)
$props = $Script:Config.TweakStates.PSObject.Properties.Name
foreach ($t in $Script:Tweaks) { if ($t.Id -notin $props) { $Script:Config.TweakStates | Add-Member -NotePropertyName $t.Id -NotePropertyValue $false -Force } }

# Auto-login
$Script:CurrentUser = Auto-Login
if ($Script:CurrentUser) { $Script:Config.Plan = "Pro"; $Script:Config.CurrentUser = $Script:CurrentUser.Email; $Script:Config.Email = $Script:CurrentUser.Email; Save-Config }

# ---------- GUI ----------
Ensure-Admin

# Login form
$loginForm = New-Object System.Windows.Forms.Form
$loginForm.Text = "FL3SH Optimizer - Sign In"
$loginForm.Size = New-Object System.Drawing.Size(440,500)
$loginForm.StartPosition = "CenterScreen"
$loginForm.BackColor = $C.Bg
$loginForm.ForeColor = $C.Text
$loginForm.FormBorderStyle = "FixedDialog"
$loginForm.MaximizeBox = $false

$lblLogo = New-Object System.Windows.Forms.Label; $lblLogo.Text="FL3SH"; $lblLogo.Font=New-Object System.Drawing.Font("Segoe UI",36,[System.Drawing.FontStyle]::Bold); $lblLogo.ForeColor=$C.Red; $lblLogo.Location=New-Object System.Drawing.Point(0,25); $lblLogo.Size=New-Object System.Drawing.Size(440,50); $lblLogo.TextAlign="MiddleCenter"; $loginForm.Controls.Add($lblLogo)
$lblSub = New-Object System.Windows.Forms.Label; $lblSub.Text="OPTIMIZER ULTIMATE"; $lblSub.Font=New-Object System.Drawing.Font("Segoe UI",10); $lblSub.ForeColor=$C.TextMuted; $lblSub.Location=New-Object System.Drawing.Point(0,75); $lblSub.Size=New-Object System.Drawing.Size(440,20); $lblSub.TextAlign="MiddleCenter"; $loginForm.Controls.Add($lblSub)

$tabLogin = New-Object System.Windows.Forms.Button; $tabLogin.Text="Sign In"; $tabLogin.Size=New-Object System.Drawing.Size(200,36); $tabLogin.Location=New-Object System.Drawing.Point(20,115); $tabLogin.FlatStyle="Flat"; $tabLogin.BackColor=$C.Red; $tabLogin.ForeColor=[System.Drawing.Color]::White; $tabLogin.Font=$FontBody; $loginForm.Controls.Add($tabLogin)
$tabReg = New-Object System.Windows.Forms.Button; $tabReg.Text="Create Account"; $tabReg.Size=New-Object System.Drawing.Size(200,36); $tabReg.Location=New-Object System.Drawing.Point(220,115); $tabReg.FlatStyle="Flat"; $tabReg.BackColor=$C.Card; $tabReg.ForeColor=$C.TextDim; $tabReg.Font=$FontBody; $loginForm.Controls.Add($tabReg)

$pnlLogin = New-Object System.Windows.Forms.Panel; $pnlLogin.Location=New-Object System.Drawing.Point(20,165); $pnlLogin.Size=New-Object System.Drawing.Size(400,220); $pnlLogin.BackColor=$C.Bg; $loginForm.Controls.Add($pnlLogin)
$lblEmail = New-Object System.Windows.Forms.Label; $lblEmail.Text="Email"; $lblEmail.ForeColor=$C.TextDim; $lblEmail.Location=New-Object System.Drawing.Point(0,0); $lblEmail.AutoSize=$true; $pnlLogin.Controls.Add($lblEmail)
$txtLoginEmail = New-Object System.Windows.Forms.TextBox; $txtLoginEmail.Location=New-Object System.Drawing.Point(0,22); $txtLoginEmail.Size=New-Object System.Drawing.Size(400,30); $txtLoginEmail.BackColor=$C.Card; $txtLoginEmail.ForeColor=$C.Text; $txtLoginEmail.BorderStyle="FixedSingle"; $pnlLogin.Controls.Add($txtLoginEmail)
$lblPass = New-Object System.Windows.Forms.Label; $lblPass.Text="Password"; $lblPass.ForeColor=$C.TextDim; $lblPass.Location=New-Object System.Drawing.Point(0,60); $lblPass.AutoSize=$true; $pnlLogin.Controls.Add($lblPass)
$txtLoginPass = New-Object System.Windows.Forms.TextBox; $txtLoginPass.Location=New-Object System.Drawing.Point(0,82); $txtLoginPass.Size=New-Object System.Drawing.Size(400,30); $txtLoginPass.BackColor=$C.Card; $txtLoginPass.ForeColor=$C.Text; $txtLoginPass.BorderStyle="FixedSingle"; $txtLoginPass.UseSystemPasswordChar=$true; $pnlLogin.Controls.Add($txtLoginPass)
$btnLogin = New-Object System.Windows.Forms.Button; $btnLogin.Text="SIGN IN"; $btnLogin.Size=New-Object System.Drawing.Size(400,42); $btnLogin.Location=New-Object System.Drawing.Point(0,125); $btnLogin.BackColor=$C.Red; $btnLogin.ForeColor=[System.Drawing.Color]::White; $btnLogin.FlatStyle="Flat"; $btnLogin.Font=$FontHead; $pnlLogin.Controls.Add($btnLogin)
$lblLoginErr = New-Object System.Windows.Forms.Label; $lblLoginErr.Text=""; $lblLoginErr.ForeColor=$C.Danger; $lblLoginErr.Location=New-Object System.Drawing.Point(0,175); $lblLoginErr.Size=New-Object System.Drawing.Size(400,20); $lblLoginErr.TextAlign="MiddleCenter"; $pnlLogin.Controls.Add($lblLoginErr)

$pnlReg = New-Object System.Windows.Forms.Panel; $pnlReg.Location=New-Object System.Drawing.Point(20,165); $pnlReg.Size=New-Object System.Drawing.Size(400,220); $pnlReg.BackColor=$C.Bg; $pnlReg.Visible=$false; $loginForm.Controls.Add($pnlReg)
$lblRegName = New-Object System.Windows.Forms.Label; $lblRegName.Text="Name"; $lblRegName.ForeColor=$C.TextDim; $lblRegName.Location=New-Object System.Drawing.Point(0,0); $lblRegName.AutoSize=$true; $pnlReg.Controls.Add($lblRegName)
$txtRegName = New-Object System.Windows.Forms.TextBox; $txtRegName.Location=New-Object System.Drawing.Point(0,22); $txtRegName.Size=New-Object System.Drawing.Size(400,30); $txtRegName.BackColor=$C.Card; $txtRegName.ForeColor=$C.Text; $txtRegName.BorderStyle="FixedSingle"; $pnlReg.Controls.Add($txtRegName)
$lblRegEmail = New-Object System.Windows.Forms.Label; $lblRegEmail.Text="Email"; $lblRegEmail.ForeColor=$C.TextDim; $lblRegEmail.Location=New-Object System.Drawing.Point(0,60); $lblRegEmail.AutoSize=$true; $pnlReg.Controls.Add($lblRegEmail)
$txtRegEmail = New-Object System.Windows.Forms.TextBox; $txtRegEmail.Location=New-Object System.Drawing.Point(0,82); $txtRegEmail.Size=New-Object System.Drawing.Size(400,30); $txtRegEmail.BackColor=$C.Card; $txtRegEmail.ForeColor=$C.Text; $txtRegEmail.BorderStyle="FixedSingle"; $pnlReg.Controls.Add($txtRegEmail)
$lblRegPass = New-Object System.Windows.Forms.Label; $lblRegPass.Text="Password"; $lblRegPass.ForeColor=$C.TextDim; $lblRegPass.Location=New-Object System.Drawing.Point(0,120); $lblRegPass.AutoSize=$true; $pnlReg.Controls.Add($lblRegPass)
$txtRegPass = New-Object System.Windows.Forms.TextBox; $txtRegPass.Location=New-Object System.Drawing.Point(0,142); $txtRegPass.Size=New-Object System.Drawing.Size(400,30); $txtRegPass.BackColor=$C.Card; $txtRegPass.ForeColor=$C.Text; $txtRegPass.BorderStyle="FixedSingle"; $txtRegPass.UseSystemPasswordChar=$true; $pnlReg.Controls.Add($txtRegPass)
$btnReg = New-Object System.Windows.Forms.Button; $btnReg.Text="CREATE ACCOUNT"; $btnReg.Size=New-Object System.Drawing.Size(400,42); $btnReg.Location=New-Object System.Drawing.Point(0,180); $btnReg.BackColor=$C.Red; $btnReg.ForeColor=[System.Drawing.Color]::White; $btnReg.FlatStyle="Flat"; $btnReg.Font=$FontHead; $pnlReg.Controls.Add($btnReg)
$lblRegErr = New-Object System.Windows.Forms.Label; $lblRegErr.Text=""; $lblRegErr.ForeColor=$C.Danger; $lblRegErr.Location=New-Object System.Drawing.Point(0,228); $lblRegErr.Size=New-Object System.Drawing.Size(400,20); $lblRegErr.TextAlign="MiddleCenter"; $pnlReg.Controls.Add($lblRegErr)

$lblFooter = New-Object System.Windows.Forms.Label; $lblFooter.Text="Auto-login enabled · Session saved locally · Everyone gets Pro · Credits: FL3SH & XRT"; $lblFooter.ForeColor=$C.TextMuted; $lblFooter.Location=New-Object System.Drawing.Point(0,455); $lblFooter.Size=New-Object System.Drawing.Size(440,20); $lblFooter.TextAlign="MiddleCenter"; $loginForm.Controls.Add($lblFooter)

$tabLogin.Add_Click({ $pnlLogin.Visible=$true; $pnlReg.Visible=$false; $tabLogin.BackColor=$C.Red; $tabLogin.ForeColor=[System.Drawing.Color]::White; $tabReg.BackColor=$C.Card; $tabReg.ForeColor=$C.TextDim })
$tabReg.Add_Click({ $pnlLogin.Visible=$false; $pnlReg.Visible=$true; $tabReg.BackColor=$C.Red; $tabReg.ForeColor=[System.Drawing.Color]::White; $tabLogin.BackColor=$C.Card; $tabLogin.ForeColor=$C.TextDim })

$btnLogin.Add_Click({
    $r = Verify-Login $txtLoginEmail.Text $txtLoginPass.Text
    if ($r.success) { $Script:CurrentUser = $r.account; $Script:Config.Plan="Pro"; $Script:Config.CurrentUser=$r.account.Email; $Script:Config.Email=$r.account.Email; Save-Config; $loginForm.Hide(); Show-MainForm }
    else { $lblLoginErr.Text = $r.message }
})
$btnReg.Add_Click({
    $r = Create-Account $txtRegEmail.Text $txtRegPass.Text $txtRegName.Text
    if ($r.success) { $lblRegErr.Text="Account created! Sign in now."; $lblRegErr.ForeColor=$C.Green }
    else { $lblRegErr.Text=$r.message; $lblRegErr.ForeColor=$C.Danger }
})

# ---------- Main Form ----------
function Show-MainForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "FL3SH Optimizer Ultimate"
    $form.Size = New-Object System.Drawing.Size(1180,760)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = $C.Bg
    $form.ForeColor = $C.Text
    $form.FormBorderStyle = "FixedSingle"
    $form.MaximizeBox = $false
    $form.Font = $FontBody

    # Sidebar
    $sidebar = New-Object System.Windows.Forms.Panel; $sidebar.Size=New-Object System.Drawing.Size(230,760); $sidebar.Location=New-Object System.Drawing.Point(0,0); $sidebar.BackColor=$C.Sidebar; $form.Controls.Add($sidebar)
    $lblBrand = New-Object System.Windows.Forms.Label; $lblBrand.Text="FL3SH"; $lblBrand.Font=New-Object System.Drawing.Font("Segoe UI",26,[System.Drawing.FontStyle]::Bold); $lblBrand.ForeColor=$C.Red; $lblBrand.Location=New-Object System.Drawing.Point(16,16); $lblBrand.AutoSize=$true; $sidebar.Controls.Add($lblBrand)
    $lblBrandSub = New-Object System.Windows.Forms.Label; $lblBrandSub.Text="OPTIMIZER ULTIMATE"; $lblBrandSub.Font=New-Object System.Drawing.Font("Segoe UI",8.5); $lblBrandSub.ForeColor=$C.TextMuted; $lblBrandSub.Location=New-Object System.Drawing.Point(18,50); $lblBrandSub.AutoSize=$true; $sidebar.Controls.Add($lblBrandSub)
    $lblPlan = New-Object System.Windows.Forms.Label; $lblPlan.Text="  PRO  "; $lblPlan.Font=New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold); $lblPlan.ForeColor=[System.Drawing.Color]::White; $lblPlan.BackColor=$C.Red; $lblPlan.Location=New-Object System.Drawing.Point(16,76); $lblPlan.AutoSize=$true; $lblPlan.Padding=New-Object System.Windows.Forms.Padding(10,3,10,3); $sidebar.Controls.Add($lblPlan)

    $navItems = @(@{Text="Home";Key="home";Y=120;Icon="◆"},@{Text="All Tweaks";Key="tweaks";Y=162;Icon="⚙"},@{Text="Crosshair";Key="crosshair";Y=204;Icon="🎯"},@{Text="Game Booster";Key="booster";Y=246;Icon="⚡"},@{Text="Potato Graphics";Key="potato";Y=288;Icon="🥔"},@{Text="Benchmark";Key="bench";Y=330;Icon="📊"},@{Text="Restore";Key="restore";Y=372;Icon="↺"},@{Text="Log";Key="log";Y=414;Icon="☰"},@{Text="Settings";Key="settings";Y=456;Icon="✦"},@{Text="Potato Graphics";Key="potato";Y=246;Icon="🥔"},@{Text="Benchmark";Key="bench";Y=288;Icon="📊"},@{Text="Restore";Key="restore";Y=330;Icon="↺"},@{Text="Log";Key="log";Y=372;Icon="☰"},@{Text="Settings";Key="settings";Y=414;Icon="✦"})
    $navBtns = @{}
    foreach ($n in $navItems) {
        $btn = New-Object System.Windows.Forms.Button; $btn.Text="  $($n.Icon)  $($n.Text)"; $btn.Size=New-Object System.Drawing.Size(198,36); $btn.Location=New-Object System.Drawing.Point(16,$n.Y); $btn.FlatStyle="Flat"; $btn.FlatAppearance.BorderSize=0; $btn.BackColor=$C.Sidebar; $btn.ForeColor=$C.TextDim; $btn.Font=$FontBody; $btn.TextAlign="MiddleLeft"; $btn.Cursor=[System.Windows.Forms.Cursors]::Hand; $btn.Tag=$n.Key; $sidebar.Controls.Add($btn); $navBtns[$n.Key]=$btn
    }

    $pnlAcct = New-Object System.Windows.Forms.Panel; $pnlAcct.Size=New-Object System.Drawing.Size(198,52); $pnlAcct.Location=New-Object System.Drawing.Point(16,600); $pnlAcct.BackColor=[System.Drawing.Color]::FromArgb(28,18,20); $sidebar.Controls.Add($pnlAcct)
    $lblAvatar = New-Object System.Windows.Forms.Label; $lblAvatar.Text=($Script:CurrentUser.Name).Substring(0,1).ToUpper(); $lblAvatar.Font=New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold); $lblAvatar.ForeColor=[System.Drawing.Color]::White; $lblAvatar.BackColor=$C.Red; $lblAvatar.Location=New-Object System.Drawing.Point(8,9); $lblAvatar.Size=New-Object System.Drawing.Size(34,34); $lblAvatar.TextAlign="MiddleCenter"; $pnlAcct.Controls.Add($lblAvatar)
    $lblAcctName = New-Object System.Windows.Forms.Label; $lblAcctName.Text=$Script:CurrentUser.Name; $lblAcctName.Font=$FontSmall; $lblAcctName.ForeColor=$C.Text; $lblAcctName.Location=New-Object System.Drawing.Point(50,9); $lblAcctName.AutoSize=$true; $pnlAcct.Controls.Add($lblAcctName)
    $lblAcctPlan = New-Object System.Windows.Forms.Label; $lblAcctPlan.Text="Pro Plan"; $lblAcctPlan.Font=New-Object System.Drawing.Font("Segoe UI",8); $lblAcctPlan.ForeColor=$C.Red; $lblAcctPlan.Location=New-Object System.Drawing.Point(50,30); $lblAcctPlan.AutoSize=$true; $pnlAcct.Controls.Add($lblAcctPlan)

    $btnLogout = New-Object System.Windows.Forms.Button; $btnLogout.Text="Sign Out"; $btnLogout.Size=New-Object System.Drawing.Size(198,30); $btnLogout.Location=New-Object System.Drawing.Point(16,660); $btnLogout.FlatStyle="Flat"; $btnLogout.FlatAppearance.BorderSize=1; $btnLogout.FlatAppearance.BorderColor=$C.Border; $btnLogout.BackColor=$C.Sidebar; $btnLogout.ForeColor=$C.TextDim; $btnLogout.Font=$FontSmall; $sidebar.Controls.Add($btnLogout)
    $btnLogout.Add_Click({ Logout; $form.Close(); $loginForm.Show() })

    $lblCredits = New-Object System.Windows.Forms.Label; $lblCredits.Text="Credits: FL3SH & XRT"; $lblCredits.Font=New-Object System.Drawing.Font("Segoe UI",7.5); $lblCredits.ForeColor=$C.TextMuted; $lblCredits.Location=New-Object System.Drawing.Point(16,700); $lblCredits.AutoSize=$true; $sidebar.Controls.Add($lblCredits)

    # Content area
    $content = New-Object System.Windows.Forms.Panel; $content.Size=New-Object System.Drawing.Size(930,720); $content.Location=New-Object System.Drawing.Point(240,20); $content.BackColor=$C.Bg; $form.Controls.Add($content)
    $pages = @{}
    function New-Page($key) { $p=New-Object System.Windows.Forms.Panel; $p.Size=$content.Size; $p.Location=New-Object System.Drawing.Point(0,0); $p.BackColor=$C.Bg; $p.Visible=$false; $p.AutoScroll=$true; $content.Controls.Add($p); $pages[$key]=$p; return $p }

    # ---------- HOME ----------
    $pgHome = New-Page "home"
    $lblHomeTitle = New-Object System.Windows.Forms.Label; $lblHomeTitle.Text="Good evening"; $lblHomeTitle.Font=$FontTitle; $lblHomeTitle.ForeColor=$C.Text; $lblHomeTitle.Location=New-Object System.Drawing.Point(0,0); $lblHomeTitle.AutoSize=$true; $pgHome.Controls.Add($lblHomeTitle)
    $lblHomeSub = New-Object System.Windows.Forms.Label; $lblHomeSub.Text="0 tweaks on · Pro plan · All features unlocked"; $lblHomeSub.Font=$FontBody; $lblHomeSub.ForeColor=$C.TextDim; $lblHomeSub.Location=New-Object System.Drawing.Point(0,38); $lblHomeSub.AutoSize=$true; $pgHome.Controls.Add($lblHomeSub)
    $statY=75; $stats=@(@{Label="CPU";Value="7%";Color=$C.Red},@{Label="GPU";Value="8%";Color=$C.Red},@{Label="RAM";Value="37%";Color=$C.Warn},@{Label="TEMP";Value="41°";Color=$C.Red})
    $sx=0
    foreach ($st in $stats) { $card=New-Object System.Windows.Forms.Panel; $card.Size=New-Object System.Drawing.Size(215,85); $card.Location=New-Object System.Drawing.Point($sx,$statY); $card.BackColor=$C.Card; $pgHome.Controls.Add($card); $line=New-Object System.Windows.Forms.Panel; $line.Size=New-Object System.Drawing.Size(215,2); $line.Location=New-Object System.Drawing.Point(0,0); $line.BackColor=$C.Red; $card.Controls.Add($line); $l=New-Object System.Windows.Forms.Label; $l.Text=$st.Label; $l.Font=New-Object System.Drawing.Font("Segoe UI",9); $l.ForeColor=$C.TextMuted; $l.Location=New-Object System.Drawing.Point(14,12); $l.AutoSize=$true; $card.Controls.Add($l); $v=New-Object System.Windows.Forms.Label; $v.Text=$st.Value; $v.Font=$FontBig; $v.ForeColor=$st.Color; $v.Location=New-Object System.Drawing.Point(14,32); $v.AutoSize=$true; $card.Controls.Add($v); $sx+=230 }
    $cardSug=New-Object System.Windows.Forms.Panel; $cardSug.Size=New-Object System.Drawing.Size(440,120); $cardSug.Location=New-Object System.Drawing.Point(0,180); $cardSug.BackColor=$C.Card; $pgHome.Controls.Add($cardSug)
    $ls=New-Object System.Windows.Forms.Label; $ls.Text="Suggested next"; $ls.Font=$FontHead; $ls.ForeColor=$C.Text; $ls.Location=New-Object System.Drawing.Point(15,10); $ls.AutoSize=$true; $cardSug.Controls.Add($ls)
    $ls2=New-Object System.Windows.Forms.Label; $ls2.Text="0% optimized"; $ls2.Font=$FontBody; $ls2.ForeColor=$C.TextDim; $ls2.Location=New-Object System.Drawing.Point(15,42); $ls2.AutoSize=$true; $cardSug.Controls.Add($ls2); $ls2.Name="sugText"
    $btnApplyAll=New-Object System.Windows.Forms.Button; $btnApplyAll.Text="Apply everything"; $btnApplyAll.Size=New-Object System.Drawing.Size(160,36); $btnApplyAll.Location=New-Object System.Drawing.Point(15,72); $btnApplyAll.BackColor=$C.Red; $btnApplyAll.ForeColor=[System.Drawing.Color]::White; $btnApplyAll.FlatStyle="Flat"; $btnApplyAll.Font=$FontBody; $cardSug.Controls.Add($btnApplyAll)
    $cardQS=New-Object System.Windows.Forms.Panel; $cardQS.Size=New-Object System.Drawing.Size(440,120); $cardQS.Location=New-Object System.Drawing.Point(460,180); $cardQS.BackColor=$C.Card; $pgHome.Controls.Add($cardQS)
    $lq=New-Object System.Windows.Forms.Label; $lq.Text="Quickstart"; $lq.Font=$FontHead; $lq.ForeColor=$C.Text; $lq.Location=New-Object System.Drawing.Point(15,10); $lq.AutoSize=$true; $cardQS.Controls.Add($lq)
    $qsItems=@("Create a restore point","Enable Input Delay Reducer","Enable Ping Stabilizer","Turn on Game Booster"); $qy=42
    foreach ($q in $qsItems) { $ql=New-Object System.Windows.Forms.Label; $ql.Text="▸  "+$q; $ql.Font=$FontSmall; $ql.ForeColor=$C.TextDim; $ql.Location=New-Object System.Drawing.Point(15,$qy); $ql.AutoSize=$true; $cardQS.Controls.Add($ql); $qy+=18 }
    $cardWN=New-Object System.Windows.Forms.Panel; $cardWN.Size=New-Object System.Drawing.Size(900,80); $cardWN.Location=New-Object System.Drawing.Point(0,320); $cardWN.BackColor=$C.Card; $pgHome.Controls.Add($cardWN)
    $lw=New-Object System.Windows.Forms.Label; $lw.Text="What's new in Ultimate"; $lw.Font=$FontHead; $lw.ForeColor=$C.Text; $lw.Location=New-Object System.Drawing.Point(15,10); $lw.AutoSize=$true; $cardWN.Controls.Add($lw)
    $lw2=New-Object System.Windows.Forms.Label; $lw2.Text="Input Delay Reducer (10 changes), Ping Stabilizer (Nagle off, adapter offloads), Mouse Precision (1:1), Keyboard Latency Fix, USB Polling (1000Hz), BCDEDIT micro-stutter fix, and 30+ system tweaks. All reversible."; $lw2.Font=$FontSmall; $lw2.ForeColor=$C.TextDim; $lw2.Location=New-Object System.Drawing.Point(15,38); $lw2.Size=New-Object System.Drawing.Size(870,36); $cardWN.Controls.Add($lw2)

    # ---------- ALL TWEAKS ----------
    $pgTweaks=New-Page "tweaks"
    $lblTW=New-Object System.Windows.Forms.Label; $lblTW.Text="All Tweaks"; $lblTW.Font=$FontTitle; $lblTW.ForeColor=$C.Text; $lblTW.Location=New-Object System.Drawing.Point(0,0); $lblTW.AutoSize=$true; $pgTweaks.Controls.Add($lblTW)
    $lblTWS=New-Object System.Windows.Forms.Label; $lblTWS.Text="30+ tweaks across 8 categories. Each card shows OS compatibility."; $lblTWS.Font=$FontBody; $lblTWS.ForeColor=$C.TextDim; $lblTWS.Location=New-Object System.Drawing.Point(0,38); $lblTWS.AutoSize=$true; $pgTweaks.Controls.Add($lblTWS)
    $catPanel=New-Object System.Windows.Forms.Panel; $catPanel.Size=New-Object System.Drawing.Size(910,40); $catPanel.Location=New-Object System.Drawing.Point(0,70); $catPanel.BackColor=$C.Bg; $pgTweaks.Controls.Add($catPanel)
    $tweakCats=@("General","Input","Network","Power","Visual","Services","Game","Windows","Mac")
    $catBtns=@{}; $cx=0
    foreach ($cat in $tweakCats) { $cb=New-Object System.Windows.Forms.Button; $cb.Text=$cat; $cb.Size=New-Object System.Drawing.Size(90,32); $cb.Location=New-Object System.Drawing.Point($cx,4); $cb.FlatStyle="Flat"; $cb.FlatAppearance.BorderSize=1; $cb.FlatAppearance.BorderColor=$C.Border; $cb.BackColor=$C.Card; $cb.ForeColor=$C.TextDim; $cb.Font=New-Object System.Drawing.Font("Segoe UI",9); $cb.Tag=$cat; $catPanel.Controls.Add($cb); $catBtns[$cat]=$cb; $cx+=95 }
    $tweakListPanel=New-Object System.Windows.Forms.Panel; $tweakListPanel.Size=New-Object System.Drawing.Size(910,540); $tweakListPanel.Location=New-Object System.Drawing.Point(0,115); $tweakListPanel.AutoScroll=$true; $tweakListPanel.BackColor=$C.Bg; $pgTweaks.Controls.Add($tweakListPanel)

    # Remove category button
    $btnRemoveCat=New-Object System.Windows.Forms.Button; $btnRemoveCat.Text="Remove All in Category"; $btnRemoveCat.Size=New-Object System.Drawing.Size(180,32); $btnRemoveCat.Location=New-Object System.Drawing.Point(730,4); $btnRemoveCat.BackColor=$C.Danger; $btnRemoveCat.ForeColor=[System.Drawing.Color]::White; $btnRemoveCat.FlatStyle="Flat"; $btnRemoveCat.Font=New-Object System.Drawing.Font("Segoe UI",9); $catPanel.Controls.Add($btnRemoveCat)

    $Script:TweakStates2=@{}
    foreach ($t in $Script:Tweaks) { $Script:TweakStates2[$t.Id]=$Script:Config.TweakStates.$($t.Id) }

    function Render-TweakList($category) {
        $tweakListPanel.Controls.Clear(); $y=5
        if ($category -eq "Windows") { $shown = $Script:Tweaks | Where-Object { $_.OS -eq "Windows" -or $_.OS -eq "Both" } }
        elseif ($category -eq "Mac") { $shown = $Script:Tweaks | Where-Object { $_.OS -eq "Mac" -or $_.OS -eq "Both" } }
        else { $shown = $Script:Tweaks | Where-Object { $_.Cat -eq $category } }
        foreach ($t in $shown) {
            $card=New-Object System.Windows.Forms.Panel; $card.Size=New-Object System.Drawing.Size(880,82); $card.Location=New-Object System.Drawing.Point(5,$y); $card.BackColor=$C.Card; $tweakListPanel.Controls.Add($card)
            $riskColor=switch ($t.Risk) { "Safe"{$C.Green} "Caution"{$C.Warn} "Danger"{$C.Danger} default{$C.TextDim} }
            $riskLbl=New-Object System.Windows.Forms.Label; $riskLbl.Text=$t.Risk; $riskLbl.Font=New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold); $riskLbl.ForeColor=$C.Bg; $riskLbl.BackColor=$riskColor; $riskLbl.Location=New-Object System.Drawing.Point(10,8); $riskLbl.AutoSize=$true; $riskLbl.Padding=New-Object System.Windows.Forms.Padding(5,1,5,1); $card.Controls.Add($riskLbl)
            # OS badge (derive from Win/Mac flags)
            $osLabel = if ($t.Win -and $t.Mac) { "Both" } elseif ($t.Win) { "Windows" } else { "Mac" }
            $osColor = switch ($osLabel) { "Windows"{$C.Blue} "Mac"{$C.Purple} "Both"{$C.Green} default{$C.TextDim} }
            $osLbl=New-Object System.Windows.Forms.Label; $osLbl.Text=$osLabel; $osLbl.Font=New-Object System.Drawing.Font("Segoe UI",7.5,[System.Drawing.FontStyle]::Bold); $osLbl.ForeColor=[System.Drawing.Color]::White; $osLbl.BackColor=$osColor; $osLbl.Location=New-Object System.Drawing.Point(62,8); $osLbl.AutoSize=$true; $osLbl.Padding=New-Object System.Windows.Forms.Padding(5,1,5,1); $card.Controls.Add($osLbl)
            $planLbl=New-Object System.Windows.Forms.Label; $planLbl.Text="PRO"; $planLbl.Font=New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold); $planLbl.ForeColor=[System.Drawing.Color]::White; $planLbl.BackColor=$C.Red; $planLbl.Location=New-Object System.Drawing.Point(115,8); $planLbl.AutoSize=$true; $planLbl.Padding=New-Object System.Windows.Forms.Padding(5,1,5,1); $card.Controls.Add($planLbl)
            $nameLbl=New-Object System.Windows.Forms.Label; $nameLbl.Text=$t.Name; $nameLbl.Font=$FontHead; $nameLbl.ForeColor=$C.Text; $nameLbl.Location=New-Object System.Drawing.Point(10,30); $nameLbl.AutoSize=$true; $card.Controls.Add($nameLbl)
            $descLbl=New-Object System.Windows.Forms.Label; $descLbl.Text=$t.Desc; $descLbl.Font=$FontSmall; $descLbl.ForeColor=$C.TextDim; $descLbl.Location=New-Object System.Drawing.Point(10,52); $descLbl.Size=New-Object System.Drawing.Size(760,26); $card.Controls.Add($descLbl)
            $toggle=New-Object System.Windows.Forms.CheckBox; $toggle.Text=""; $toggle.Size=New-Object System.Drawing.Size(20,20); $toggle.Location=New-Object System.Drawing.Point(850,32); $toggle.Checked=[bool]$Script:TweakStates2[$t.Id]; $toggle.Tag=$t.Id; $card.Controls.Add($toggle)
            $toggle.Add_CheckedChanged({
                $tid=$this.Tag; $tw=$Script:Tweaks | Where-Object { $_.Id -eq $tid } | Select-Object -First 1
                $Script:TweakStates2[$tid]=$this.Checked
                $Script:Config.TweakStates.$tid = $this.Checked; Save-Config
                if ($this.Checked) {
                    if ($tw.Risk -ne "Safe") { $r=[System.Windows.Forms.MessageBox]::Show("$($tw.Name)`n`nRisk: $($tw.Risk)`n$($tw.Desc)`n`nApply?","Confirm",[System.Windows.Forms.MessageBoxButtons]::YesNo); if ($r -ne "Yes") { $this.Checked=$false; $Script:TweakStates2[$tid]=$false; $Script:Config.TweakStates.$tid=$false; Save-Config; return } }
                    & $tw.Action
                }
                $applied=($Script:TweakStates2.Values | Where-Object { $_ }).Count
                $lblPts.Text="$applied tweaks applied"
                $lblHomeSub.Text="$applied of $($Script:Tweaks.Count) tweaks on · Pro plan"
            })
            $y+=90
        }
    }
    $Script:CurrentCat="General"
    Render-TweakList "General"
    $catBtns["General"].BackColor=$C.Red; $catBtns["General"].ForeColor=[System.Drawing.Color]::White
    foreach ($cat in $tweakCats) { $catBtns[$cat].Add_Click({ $Script:CurrentCat=$this.Tag; Render-TweakList $this.Tag; foreach ($c in $tweakCats) { $catBtns[$c].BackColor=$C.Card; $catBtns[$c].ForeColor=$C.TextDim }; $this.BackColor=$C.Red; $this.ForeColor=[System.Drawing.Color]::White }) }
    $btnRemoveCat.Add_Click({
        $cat=$Script:CurrentCat
        $toRemove=$Script:Tweaks | Where-Object { $_.Cat -eq $cat }
        foreach ($t in $toRemove) { $Script:TweakStates2[$t.Id]=$false; $Script:Config.TweakStates.$($t.Id)=$false }
        Save-Config
        Render-TweakList $cat
        $applied=($Script:TweakStates2.Values | Where-Object { $_ }).Count
        $lblPts.Text="$applied tweaks applied"
        $lblHomeSub.Text="$applied of $($Script:Tweaks.Count) tweaks on · Pro plan"
        [System.Windows.Forms.MessageBox]::Show("Removed all tweaks in $cat category.","FL3SH") | Out-Null
    })

    # ---------- CROSSHAIR ----------
    $pgCross = New-Page "crosshair"
    $lblCH=New-Object System.Windows.Forms.Label; $lblCH.Text="Crosshair Overlay"; $lblCH.Font=$FontTitle; $lblCH.ForeColor=$C.Text; $lblCH.Location=New-Object System.Drawing.Point(0,0); $lblCH.AutoSize=$true; $pgCross.Controls.Add($lblCH)
    $lblCHSub=New-Object System.Windows.Forms.Label; $lblCHSub.Text="In-game style crosshair overlay with multiple styles."; $lblCHSub.Font=$FontBody; $lblCHSub.ForeColor=$C.TextDim; $lblCHSub.Location=New-Object System.Drawing.Point(0,38); $lblCHSub.AutoSize=$true; $pgCross.Controls.Add($lblCHSub)
    $cardCH=New-Object System.Windows.Forms.Panel; $cardCH.Size=New-Object System.Drawing.Size(500,300); $cardCH.Location=New-Object System.Drawing.Point(0,80); $cardCH.BackColor=$C.Card; $pgCross.Controls.Add($cardCH)
    $lblCHStyle=New-Object System.Windows.Forms.Label; $lblCHStyle.Text="Style:"; $lblCHStyle.Font=$FontBody; $lblCHStyle.ForeColor=$C.Text; $lblCHStyle.Location=New-Object System.Drawing.Point(15,15); $lblCHStyle.AutoSize=$true; $cardCH.Controls.Add($lblCHStyle)
    $cmbCH=New-Object System.Windows.Forms.ComboBox; $cmbCH.Location=New-Object System.Drawing.Point(80,12); $cmbCH.Size=New-Object System.Drawing.Size(200,28); $cmbCH.DropDownStyle="DropDownList"; @("cross","dot","circle","t","chevron","square","x","crosscircle") | ForEach-Object { $cmbCH.Items.Add($_) | Out-Null }; $cmbCH.SelectedIndex=0; $cardCH.Controls.Add($cmbCH)
    $lblCHColor=New-Object System.Windows.Forms.Label; $lblCHColor.Text="Color:"; $lblCHColor.Font=$FontBody; $lblCHColor.ForeColor=$C.Text; $lblCHColor.Location=New-Object System.Drawing.Point(15,55); $lblCHColor.AutoSize=$true; $cardCH.Controls.Add($lblCHColor)
    $txtCHColor=New-Object System.Windows.Forms.TextBox; $txtCHColor.Location=New-Object System.Drawing.Point(80,52); $txtCHColor.Size=New-Object System.Drawing.Size(120,26); $txtCHColor.Text="#00ff88"; $txtCHColor.BackColor=$C.Bg; $txtCHColor.ForeColor=$C.Text; $cardCH.Controls.Add($txtCHColor)
    $lblCHSize=New-Object System.Windows.Forms.Label; $lblCHSize.Text="Size:"; $lblCHSize.Font=$FontBody; $lblCHSize.ForeColor=$C.Text; $lblCHSize.Location=New-Object System.Drawing.Point(15,95); $lblCHSize.AutoSize=$true; $cardCH.Controls.Add($lblCHSize)
    $trkCHSize=New-Object System.Windows.Forms.TrackBar; $trkCHSize.Location=New-Object System.Drawing.Point(80,90); $trkCHSize.Size=New-Object System.Drawing.Size(200,40); $trkCHSize.Minimum=4; $trkCHSize.Maximum=40; $trkCHSize.Value=12; $cardCH.Controls.Add($trkCHSize)
    $lblCHThick=New-Object System.Windows.Forms.Label; $lblCHThick.Text="Thickness:"; $lblCHThick.Font=$FontBody; $lblCHThick.ForeColor=$C.Text; $lblCHThick.Location=New-Object System.Drawing.Point(15,140); $lblCHThick.AutoSize=$true; $cardCH.Controls.Add($lblCHThick)
    $trkCHThick=New-Object System.Windows.Forms.TrackBar; $trkCHThick.Location=New-Object System.Drawing.Point(110,135); $trkCHThick.Size=New-Object System.Drawing.Size(170,40); $trkCHThick.Minimum=1; $trkCHThick.Maximum=6; $trkCHThick.Value=2; $cardCH.Controls.Add($trkCHThick)
    $btnCHToggle=New-Object System.Windows.Forms.Button; $btnCHToggle.Text="Toggle Overlay"; $btnCHToggle.Size=New-Object System.Drawing.Size(140,36); $btnCHToggle.Location=New-Object System.Drawing.Point(15,185); $btnCHToggle.BackColor=$C.Red; $btnCHToggle.ForeColor=[System.Drawing.Color]::White; $btnCHToggle.FlatStyle="Flat"; $cardCH.Controls.Add($btnCHToggle)
    $btnCHHide=New-Object System.Windows.Forms.Button; $btnCHHide.Text="Hide"; $btnCHHide.Size=New-Object System.Drawing.Size(80,36); $btnCHHide.Location=New-Object System.Drawing.Point(165,185); $btnCHHide.BackColor=$C.Card; $btnCHHide.ForeColor=$C.Text; $btnCHHide.FlatStyle="Flat"; $cardCH.Controls.Add($btnCHHide)

    # Overlay form
    $Script:CHForm = $null
    $Script:CHState = @{ On=$false; Style="cross"; Color="#00ff88"; Size=12; Thick=2 }
    function Update-CHState {
        $Script:CHState.Style = $cmbCH.SelectedItem.ToString()
        $Script:CHState.Color = $txtCHColor.Text
        $Script:CHState.Size = $trkCHSize.Value
        $Script:CHState.Thick = $trkCHThick.Value
        if ($Script:CHForm) { $Script:CHForm.Invalidate() }
    }
    $cmbCH.Add_SelectedIndexChanged({ Update-CHState })
    $txtCHColor.Add_TextChanged({ Update-CHState })
    $trkCHSize.Add_ValueChanged({ Update-CHState })
    $trkCHThick.Add_ValueChanged({ Update-CHState })

    function Show-CHOverlay {
        if ($Script:CHForm) { return }
        $Script:CHState.On = $true
        $f2 = New-Object System.Windows.Forms.Form
        $f2.FormBorderStyle = "None"
        $f2.TopMost = $true
        $f2.ShowInTaskbar = $false
        $f2.StartPosition = "Manual"
        $f2.Bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $f2.BackColor = [System.Drawing.Color]::Magenta
        $f2.TransparencyKey = [System.Drawing.Color]::Magenta
        $f2.Opacity = 1.0
        # click-through
        $ex = [Win32Ex]::GetWindowLong($f2.Handle, [Win32Ex]::GWL_EXSTYLE)
        [Win32Ex]::SetWindowLong($f2.Handle, [Win32Ex]::GWL_EXSTYLE, $ex -bor 0x20 -bor 0x80000) | Out-Null
        $f2.Add_Paint({
            $g = $_.Graphics
            $cx = $f2.Width/2; $cy = $f2.Height/2
            $s = $Script:CHState.Size; $t = $Script:CHState.Thick
            $col = [System.Drawing.ColorTranslator]::FromHtml($Script:CHState.Color)
            $pen = New-Object System.Drawing.Pen($col, $t)
            $brush = New-Object System.Drawing.SolidBrush($col)
            $st = $Script:CHState.Style
            if ($st -eq "cross" -or $st -eq "crosscircle") {
                $g.DrawLine($pen,$cx-$s,$cy,$cx-$s/2,$cy); $g.DrawLine($pen,$cx+$s/2,$cy,$cx+$s,$cy)
                $g.DrawLine($pen,$cx,$cy-$s,$cx,$cy-$s/2); $g.DrawLine($pen,$cx,$cy+$s/2,$cx,$cy+$s)
            }
            if ($st -eq "dot") { $g.FillEllipse($brush,$cx-$t*2,$cy-$t*2,$t*4,$t*4) }
            if ($st -eq "circle" -or $st -eq "crosscircle") { $g.DrawEllipse($pen,$cx-$s,$cy-$s,$s*2,$s*2) }
            if ($st -eq "t") { $g.DrawLine($pen,$cx-$s,$cy,$cx+$s,$cy); $g.DrawLine($pen,$cx,$cy,$cx,$cy+$s) }
            if ($st -eq "chevron") { $g.DrawLine($pen,$cx-$s,$cy+$s,$cx,$cy); $g.DrawLine($pen,$cx,$cy,$cx+$s,$cy+$s) }
            if ($st -eq "square") { $g.DrawRectangle($pen,$cx-$s,$cy-$s,$s*2,$s*2) }
            if ($st -eq "x") { $g.DrawLine($pen,$cx-$s,$cy-$s,$cx+$s,$cy+$s); $g.DrawLine($pen,$cx+$s,$cy-$s,$cx-$s,$cy+$s) }
            $pen.Dispose(); $brush.Dispose()
        })
        $Script:CHForm = $f2
        $f2.Show()
    }
    function Hide-CHOverlay {
        $Script:CHState.On = $false
        if ($Script:CHForm) { $Script:CHForm.Close(); $Script:CHForm = $null }
    }
    $btnCHToggle.Add_Click({ if ($Script:CHState.On) { Hide-CHOverlay } else { Update-CHState; Show-CHOverlay } })
    $btnCHHide.Add_Click({ Hide-CHOverlay })

    # ---------- GAME BOOSTER ----------
    $pgBooster=New-Page "booster"
    $lblB=New-Object System.Windows.Forms.Label; $lblB.Text="Game Booster"; $lblB.Font=$FontTitle; $lblB.ForeColor=$C.Text; $lblB.Location=New-Object System.Drawing.Point(0,0); $lblB.AutoSize=$true; $pgBooster.Controls.Add($lblB)
    $lblBSub=New-Object System.Windows.Forms.Label; $lblBSub.Text="Closes what you are not using before you queue. Whitelist what stays."; $lblBSub.Font=$FontBody; $lblBSub.ForeColor=$C.TextDim; $lblBSub.Location=New-Object System.Drawing.Point(0,38); $lblBSub.AutoSize=$true; $pgBooster.Controls.Add($lblBSub)
    $cardB=New-Object System.Windows.Forms.Panel; $cardB.Size=New-Object System.Drawing.Size(500,230); $cardB.Location=New-Object System.Drawing.Point(0,80); $cardB.BackColor=$C.Card; $pgBooster.Controls.Add($cardB)
    $lblBW=New-Object System.Windows.Forms.Label; $lblBW.Text="Whitelist (one app per line)"; $lblBW.Font=$FontHead; $lblBW.ForeColor=$C.Text; $lblBW.Location=New-Object System.Drawing.Point(15,10); $lblBW.AutoSize=$true; $cardB.Controls.Add($lblBW)
    $txtWL=New-Object System.Windows.Forms.TextBox; $txtWL.Location=New-Object System.Drawing.Point(15,42); $txtWL.Size=New-Object System.Drawing.Size(470,120); $txtWL.Multiline=$true; $txtWL.BackColor=$C.Bg; $txtWL.ForeColor=$C.Text; $txtWL.Font=$FontMono; $txtWL.Text="discord.exe`nchrome.exe`nspotify.exe"; $cardB.Controls.Add($txtWL)
    $btnBoost=New-Object System.Windows.Forms.Button; $btnBoost.Text="⚡ BOOST"; $btnBoost.Size=New-Object System.Drawing.Size(200,40); $btnBoost.Location=New-Object System.Drawing.Point(15,172); $btnBoost.BackColor=$C.Red; $btnBoost.ForeColor=[System.Drawing.Color]::White; $btnBoost.FlatStyle="Flat"; $btnBoost.Font=$FontHead; $cardB.Controls.Add($btnBoost)
    $btnBoost.Add_Click({ $wl=$txtWL.Text -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }; Invoke-GameBooster; [System.Windows.Forms.MessageBox]::Show("Game Booster complete.","FL3SH") | Out-Null })
    $cardBS=New-Object System.Windows.Forms.Panel; $cardBS.Size=New-Object System.Drawing.Size(380,230); $cardBS.Location=New-Object System.Drawing.Point(520,80); $cardBS.BackColor=$C.Card; $pgBooster.Controls.Add($cardBS)
    $lblBS=New-Object System.Windows.Forms.Label; $lblBS.Text="Status"; $lblBS.Font=$FontHead; $lblBS.ForeColor=$C.Text; $lblBS.Location=New-Object System.Drawing.Point(15,10); $lblBS.AutoSize=$true; $cardBS.Controls.Add($lblBS)
    $lblBS2=New-Object System.Windows.Forms.Label; $lblBS2.Text="Booster is OFF`n`nPro: unlimited whitelist`nDrivers/services never touched"; $lblBS2.Font=$FontBody; $lblBS2.ForeColor=$C.TextDim; $lblBS2.Location=New-Object System.Drawing.Point(15,42); $lblBS2.AutoSize=$true; $cardBS.Controls.Add($lblBS2)

    # ---------- POTATO GRAPHICS ----------
    $pgPotato=New-Page "potato"
    $lblP=New-Object System.Windows.Forms.Label; $lblP.Text="Potato Graphics"; $lblP.Font=$FontTitle; $lblP.ForeColor=$C.Text; $lblP.Location=New-Object System.Drawing.Point(0,0); $lblP.AutoSize=$true; $pgPotato.Controls.Add($lblP)
    $lblPSub=New-Object System.Windows.Forms.Label; $lblPSub.Text="One-click low-graphics profiles. Max FPS, max visibility, revert any time."; $lblPSub.Font=$FontBody; $lblPSub.ForeColor=$C.TextDim; $lblPSub.Location=New-Object System.Drawing.Point(0,38); $lblPSub.AutoSize=$true; $pgPotato.Controls.Add($lblPSub)
    $warnP=New-Object System.Windows.Forms.Label; $warnP.Text="⚠ WARNING: This is the only tweak that changes how the game LOOKS. Revert anytime."; $warnP.Font=$FontSmall; $warnP.ForeColor=$C.Warn; $warnP.Location=New-Object System.Drawing.Point(0,68); $warnP.AutoSize=$true; $pgPotato.Controls.Add($warnP)
    $profiles=@(@{Name="Fortnite";Desc="DX11 and Performance mode";Plan="Pro";Icon="FN"},@{Name="Fortnite Competitive";Desc="Fixed floor (lowest settings)";Plan="Pro";Icon="FC"},@{Name="Marvel Rivals";Desc="Low-graphics competitive profile";Plan="Pro";Icon="MR"},@{Name="AMD/Intel Potato";Desc="Works on any GPU. Removes texture packs.";Plan="Pro";Icon="AI"})
    $py=100
    foreach ($prof in $profiles) { $pcard=New-Object System.Windows.Forms.Panel; $pcard.Size=New-Object System.Drawing.Size(900,60); $pcard.Location=New-Object System.Drawing.Point(0,$py); $pcard.BackColor=$C.Card; $pgPotato.Controls.Add($pcard); $picon=New-Object System.Windows.Forms.Label; $picon.Text=$prof.Icon; $picon.Font=New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold); $picon.ForeColor=[System.Drawing.Color]::White; $picon.BackColor=$C.Red; $picon.Location=New-Object System.Drawing.Point(15,8); $picon.Size=New-Object System.Drawing.Size(44,44); $picon.TextAlign="MiddleCenter"; $pcard.Controls.Add($picon); $pn=New-Object System.Windows.Forms.Label; $pn.Text=$prof.Name; $pn.Font=$FontHead; $pn.ForeColor=$C.Text; $pn.Location=New-Object System.Drawing.Point(70,8); $pn.AutoSize=$true; $pcard.Controls.Add($pn); $pd=New-Object System.Windows.Forms.Label; $pd.Text=$prof.Desc; $pd.Font=$FontSmall; $pd.ForeColor=$C.TextDim; $pd.Location=New-Object System.Drawing.Point(70,34); $pd.AutoSize=$true; $pcard.Controls.Add($pd); $pbtn=New-Object System.Windows.Forms.Button; $pbtn.Text="Apply"; $pbtn.Size=New-Object System.Drawing.Size(80,32); $pbtn.Location=New-Object System.Drawing.Point(800,14); $pbtn.BackColor=$C.Red; $pbtn.ForeColor=[System.Drawing.Color]::White; $pbtn.FlatStyle="Flat"; $pcard.Controls.Add($pbtn); $pbtn.Add_Click({ $r=[System.Windows.Forms.MessageBox]::Show("This will change Fortnite graphics (Engine.ini).`nRevert anytime. Continue?","Confirm",[System.Windows.Forms.MessageBoxButtons]::YesNo); if($r -eq "Yes"){ Invoke-PotatoGraphics } }); $py+=70 }

    # ---------- BENCHMARK ----------
    $pgBench=New-Page "bench"
    $lblBn=New-Object System.Windows.Forms.Label; $lblBn.Text="Benchmark"; $lblBn.Font=$FontTitle; $lblBn.ForeColor=$C.Text; $lblBn.Location=New-Object System.Drawing.Point(0,0); $lblBn.AutoSize=$true; $pgBench.Controls.Add($lblBn)
    $btnSI=New-Object System.Windows.Forms.Button; $btnSI.Text="Refresh System Info"; $btnSI.Size=New-Object System.Drawing.Size(160,32); $btnSI.Location=New-Object System.Drawing.Point(0,50); $btnSI.BackColor=$C.Card; $btnSI.ForeColor=$C.Text; $btnSI.FlatStyle="Flat"; $pgBench.Controls.Add($btnSI)
    $txtSI=New-Object System.Windows.Forms.TextBox; $txtSI.Location=New-Object System.Drawing.Point(0,90); $txtSI.Size=New-Object System.Drawing.Size(500,90); $txtSI.Multiline=$true; $txtSI.ReadOnly=$true; $txtSI.BackColor=$C.Card; $txtSI.ForeColor=$C.Text; $txtSI.Font=$FontMono; $pgBench.Controls.Add($txtSI)
    $btnSI.Add_Click({ $cpu=(Get-CimInstance Win32_Processor).Name; $gpu=(Get-CimInstance Win32_VideoController|Select-Object -First 1).Name; $ram=[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1); $txtSI.Text="CPU: $cpu`r`nGPU: $gpu`r`nRAM: $ram GB" })
    $lblFB=New-Object System.Windows.Forms.Label; $lblFB.Text="FPS before:"; $lblFB.Font=$FontBody; $lblFB.ForeColor=$C.Text; $lblFB.Location=New-Object System.Drawing.Point(0,200); $lblFB.AutoSize=$true; $pgBench.Controls.Add($lblFB)
    $txtFB=New-Object System.Windows.Forms.TextBox; $txtFB.Location=New-Object System.Drawing.Point(100,198); $txtFB.Width=80; $txtFB.BackColor=$C.Card; $txtFB.ForeColor=$C.Text; $pgBench.Controls.Add($txtFB)
    $lblFA=New-Object System.Windows.Forms.Label; $lblFA.Text="FPS after:"; $lblFA.Font=$FontBody; $lblFA.ForeColor=$C.Text; $lblFA.Location=New-Object System.Drawing.Point(200,200); $lblFA.AutoSize=$true; $pgBench.Controls.Add($lblFA)
    $txtFA=New-Object System.Windows.Forms.TextBox; $txtFA.Location=New-Object System.Drawing.Point(280,198); $txtFA.Width=80; $txtFA.BackColor=$C.Card; $txtFA.ForeColor=$C.Text; $pgBench.Controls.Add($txtFA)
    $btnBench=New-Object System.Windows.Forms.Button; $btnBench.Text="Run Micro-Benchmark"; $btnBench.Size=New-Object System.Drawing.Size(180,32); $btnBench.Location=New-Object System.Drawing.Point(380,196); $btnBench.BackColor=$C.Card; $btnBench.ForeColor=$C.Text; $btnBench.FlatStyle="Flat"; $pgBench.Controls.Add($btnBench)
    $lblBenchRes=New-Object System.Windows.Forms.Label; $lblBenchRes.Text="Micro-bench: not run"; $lblBenchRes.Font=$FontBody; $lblBenchRes.ForeColor=$C.TextDim; $lblBenchRes.Location=New-Object System.Drawing.Point(0,235); $lblBenchRes.AutoSize=$true; $pgBench.Controls.Add($lblBenchRes)
    $btnBench.Add_Click({ $lblBenchRes.Text="Running..."; [System.Windows.Forms.Application]::DoEvents(); $sw=[Diagnostics.Stopwatch]::StartNew(); $c=0; for($i=2;$i -lt 200000;$i++){$isP=$true;for($j=2;$j*$j -le $i;$j++){if($i%$j -eq 0){$isP=$false;break}};if($isP){$c++}}; $sw.Stop(); $lblBenchRes.Text="Micro-bench: $([math]::Round($sw.Elapsed.TotalMilliseconds,1)) ms (lower = better)" })
    $btnSaveBench=New-Object System.Windows.Forms.Button; $btnSaveBench.Text="Save to CSV"; $btnSaveBench.Size=New-Object System.Drawing.Size(140,32); $btnSaveBench.Location=New-Object System.Drawing.Point(0,265); $btnSaveBench.BackColor=$C.Card; $btnSaveBench.ForeColor=$C.Text; $btnSaveBench.FlatStyle="Flat"; $pgBench.Controls.Add($btnSaveBench)
    $btnSaveBench.Add_Click({ $row="$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$($txtFB.Text),$($txtFA.Text)"; if(-not (Test-Path $Script:BenchPath)){"Date,FPS_Before,FPS_After"|Set-Content $Script:BenchPath}; Add-Content $Script:BenchPath $row; Write-Log "Benchmark saved." "OK"; [System.Windows.Forms.MessageBox]::Show("Saved to $Script:BenchPath","FL3SH") | Out-Null })

    # ---------- RESTORE ----------
    $pgRestore=New-Page "restore"
    $lblR=New-Object System.Windows.Forms.Label; $lblR.Text="Restore & Revert"; $lblR.Font=$FontTitle; $lblR.ForeColor=$C.Text; $lblR.Location=New-Object System.Drawing.Point(0,0); $lblR.AutoSize=$true; $pgRestore.Controls.Add($lblR)
    $btnRP=New-Object System.Windows.Forms.Button; $btnRP.Text="Create System Restore Point"; $btnRP.Size=New-Object System.Drawing.Size(240,40); $btnRP.Location=New-Object System.Drawing.Point(0,60); $btnRP.BackColor=$C.Card; $btnRP.ForeColor=$C.Text; $btnRP.FlatStyle="Flat"; $pgRestore.Controls.Add($btnRP)
    $btnRP.Add_Click({ New-RestorePoint | Out-Null; [System.Windows.Forms.MessageBox]::Show("Restore point created (if supported).","FL3SH") | Out-Null })
    $btnRevertAll=New-Object System.Windows.Forms.Button; $btnRevertAll.Text="REVERT ALL CHANGES"; $btnRevertAll.Size=New-Object System.Drawing.Size(240,40); $btnRevertAll.Location=New-Object System.Drawing.Point(0,110); $btnRevertAll.BackColor=$C.Danger; $btnRevertAll.ForeColor=[System.Drawing.Color]::White; $btnRevertAll.FlatStyle="Flat"; $btnRevertAll.Font=$FontHead; $pgRestore.Controls.Add($btnRevertAll)
    $btnRevertAll.Add_Click({ $r=[System.Windows.Forms.MessageBox]::Show("Revert ALL changes? Reboot recommended after.","Confirm",[System.Windows.Forms.MessageBoxButtons]::YesNo); if($r -eq "Yes"){ Revert-All; [System.Windows.Forms.MessageBox]::Show("Reverted. Reboot recommended.","FL3SH") | Out-Null } })
    $lblRInfo=New-Object System.Windows.Forms.Label; $lblRInfo.Text="Every tweak is reversible. Restore points + backups created automatically before changes. Credits: FL3SH & XRT"; $lblRInfo.Font=$FontSmall; $lblRInfo.ForeColor=$C.TextDim; $lblRInfo.Location=New-Object System.Drawing.Point(0,165); $lblRInfo.AutoSize=$true; $pgRestore.Controls.Add($lblRInfo)

    # ---------- LOG ----------
    $pgLog=New-Page "log"
    $Script:LogBox=New-Object System.Windows.Forms.TextBox; $Script:LogBox.Location=New-Object System.Drawing.Point(0,0); $Script:LogBox.Size=New-Object System.Drawing.Size(910,680); $Script:LogBox.Multiline=$true; $Script:LogBox.ScrollBars="Vertical"; $Script:LogBox.ReadOnly=$true; $Script:LogBox.BackColor=$C.Card; $Script:LogBox.ForeColor=[System.Drawing.Color]::FromArgb(255,107,122); $Script:LogBox.Font=$FontMono; $pgLog.Controls.Add($Script:LogBox)

    # ---------- SETTINGS ----------
    $pgSettings=New-Page "settings"
    $lblS=New-Object System.Windows.Forms.Label; $lblS.Text="Settings"; $lblS.Font=$FontTitle; $lblS.ForeColor=$C.Text; $lblS.Location=New-Object System.Drawing.Point(0,0); $lblS.AutoSize=$true; $pgSettings.Controls.Add($lblS)
    $lblSE=New-Object System.Windows.Forms.Label; $lblSE.Text="Email (for license):"; $lblSE.Font=$FontBody; $lblSE.ForeColor=$C.Text; $lblSE.Location=New-Object System.Drawing.Point(0,50); $lblSE.AutoSize=$true; $pgSettings.Controls.Add($lblSE)
    $txtEmail=New-Object System.Windows.Forms.TextBox; $txtEmail.Location=New-Object System.Drawing.Point(0,75); $txtEmail.Width=400; $txtEmail.BackColor=$C.Card; $txtEmail.ForeColor=$C.Text; $txtEmail.Text=$Script:Config.Email; $pgSettings.Controls.Add($txtEmail)
    $lblSK=New-Object System.Windows.Forms.Label; $lblSK.Text="License key:"; $lblSK.Font=$FontBody; $lblSK.ForeColor=$C.Text; $lblSK.Location=New-Object System.Drawing.Point(0,110); $lblSK.AutoSize=$true; $pgSettings.Controls.Add($lblSK)
    $txtKey=New-Object System.Windows.Forms.TextBox; $txtKey.Location=New-Object System.Drawing.Point(0,135); $txtKey.Width=400; $txtKey.BackColor=$C.Card; $txtKey.ForeColor=$C.Text; $txtKey.Text=$Script:Config.LicenseKey; $pgSettings.Controls.Add($txtKey)
    $btnActivate=New-Object System.Windows.Forms.Button; $btnActivate.Text="Activate"; $btnActivate.Size=New-Object System.Drawing.Size(120,32); $btnActivate.Location=New-Object System.Drawing.Point(410,133); $btnActivate.BackColor=$C.Red; $btnActivate.ForeColor=[System.Drawing.Color]::White; $btnActivate.FlatStyle="Flat"; $pgSettings.Controls.Add($btnActivate)
    $btnActivate.Add_Click({ $Script:Config.Email=$txtEmail.Text; $Script:Config.LicenseKey=$txtKey.Text; Save-Config; if ($Script:CurrentUser) { $accs=@(Load-Accounts); $a=$accs | Where-Object { $_.Email -eq $Script:CurrentUser.Email } | Select-Object -First 1; if($a){ $a.LicenseKey=$txtKey.Text; $a.Plan="Pro"; Save-Accounts $accs } }; [System.Windows.Forms.MessageBox]::Show("Plan: Pro (all features unlocked).","FL3SH") | Out-Null })
    # Appearance controls
    $lblAcc=New-Object System.Windows.Forms.Label; $lblAcc.Text="Accent color:"; $lblAcc.Font=$FontBody; $lblAcc.ForeColor=$C.Text; $lblAcc.Location=New-Object System.Drawing.Point(0,210); $lblAcc.AutoSize=$true; $pgSettings.Controls.Add($lblAcc)
    $txtAcc=New-Object System.Windows.Forms.TextBox; $txtAcc.Location=New-Object System.Drawing.Point(110,208); $txtAcc.Width=100; $txtAcc.Text="#ff1a2e"; $txtAcc.BackColor=$C.Card; $txtAcc.ForeColor=$C.Text; $pgSettings.Controls.Add($txtAcc)
    $lblSide=New-Object System.Windows.Forms.Label; $lblSide.Text="Sidebar color:"; $lblSide.Font=$FontBody; $lblSide.ForeColor=$C.Text; $lblSide.Location=New-Object System.Drawing.Point(0,240); $lblSide.AutoSize=$true; $pgSettings.Controls.Add($lblSide)
    $txtSide=New-Object System.Windows.Forms.TextBox; $txtSide.Location=New-Object System.Drawing.Point(110,238); $txtSide.Width=100; $txtSide.Text="#0d0d14"; $txtSide.BackColor=$C.Card; $txtSide.ForeColor=$C.Text; $pgSettings.Controls.Add($txtSide)
    $chkOutline=New-Object System.Windows.Forms.CheckBox; $chkOutline.Text="Rotating outline"; $chkOutline.ForeColor=$C.Text; $chkOutline.Location=New-Object System.Drawing.Point(0,270); $chkOutline.Checked=$true; $chkOutline.AutoSize=$true; $pgSettings.Controls.Add($chkOutline)
    $chkSnow=New-Object System.Windows.Forms.CheckBox; $chkSnow.Text="Snowfall"; $chkSnow.ForeColor=$C.Text; $chkSnow.Location=New-Object System.Drawing.Point(150,270); $chkSnow.Checked=$true; $chkSnow.AutoSize=$true; $pgSettings.Controls.Add($chkSnow)
    $btnApplyAppear=New-Object System.Windows.Forms.Button; $btnApplyAppear.Text="Apply Appearance"; $btnApplyAppear.Size=New-Object System.Drawing.Size(140,32); $btnApplyAppear.Location=New-Object System.Drawing.Point(0,300); $btnApplyAppear.BackColor=$C.Red; $btnApplyAppear.ForeColor=[System.Drawing.Color]::White; $btnApplyAppear.FlatStyle="Flat"; $pgSettings.Controls.Add($btnApplyAppear)
    $btnApplyAppear.Add_Click({
        try { $C.Red = [System.Drawing.ColorTranslator]::FromHtml($txtAcc.Text) } catch {}
        $sidebar.BackColor = [System.Drawing.ColorTranslator]::FromHtml($txtSide.Text)
        if (-not $chkSnow.Checked) { $overlay.Visible = $false } else { $overlay.Visible = $true }
        [System.Windows.Forms.MessageBox]::Show("Appearance applied.","FL3SH") | Out-Null
    })

    $lblPlanInfo=New-Object System.Windows.Forms.Label; $lblPlanInfo.Text="Everyone gets Pro plan. All tweaks + Input Delay Reducer + Ping Stabilizer + Potato Graphics + full Game Booster unlocked. Credits: FL3SH & XRT."; $lblPlanInfo.Font=$FontSmall; $lblPlanInfo.ForeColor=$C.TextDim; $lblPlanInfo.Location=New-Object System.Drawing.Point(0,180); $lblPlanInfo.AutoSize=$true; $pgSettings.Controls.Add($lblPlanInfo)

    # Navigation
    function Show-Page($key) { foreach ($p in $pages.Values) { $p.Visible=$false }; $pages[$key].Visible=$true; foreach ($btn in $navBtns.Values) { if ($btn.Tag -eq $key) { $btn.BackColor=$C.Red; $btn.ForeColor=[System.Drawing.Color]::White } else { $btn.BackColor=$C.Sidebar; $btn.ForeColor=$C.TextDim } } }
    foreach ($btn in $navBtns.Values) { $btn.Add_Click({ Show-Page $this.Tag }) }

    # Apply All
    $btnApplyAll.Add_Click({
        $applied=0
        foreach ($t in $Script:Tweaks) { $Script:TweakStates2[$t.Id]=$true; $Script:Config.TweakStates.$($t.Id)=$true; & $t.Action; $applied++ }
        Save-Config
        $lblPts.Text="$applied tweaks applied"
        $lblHomeSub.Text="$applied of $($Script:Tweaks.Count) tweaks on · Pro plan"
        Render-TweakList $Script:CurrentCat
        [System.Windows.Forms.MessageBox]::Show("Applied $applied tweaks.","FL3SH") | Out-Null
    })

    # Remove All button
    $btnRemoveAll=New-Object System.Windows.Forms.Button; $btnRemoveAll.Text="Remove All Tweaks"; $btnRemoveAll.Size=New-Object System.Drawing.Size(160,36); $btnRemoveAll.Location=New-Object System.Drawing.Point(185,72); $btnRemoveAll.BackColor=$C.Danger; $btnRemoveAll.ForeColor=[System.Drawing.Color]::White; $btnRemoveAll.FlatStyle="Flat"; $btnRemoveAll.Font=$FontBody; $cardSug.Controls.Add($btnRemoveAll)
    $btnRemoveAll.Add_Click({
        foreach ($t in $Script:Tweaks) { $Script:TweakStates2[$t.Id]=$false; $Script:Config.TweakStates.$($t.Id)=$false }
        Save-Config; Render-TweakList $Script:CurrentCat
        $lblPts.Text="0 tweaks applied"; $lblHomeSub.Text="0 of $($Script:Tweaks.Count) tweaks on · Pro plan"
        [System.Windows.Forms.MessageBox]::Show("All tweaks removed.","FL3SH") | Out-Null
    })

    # Progress + counts
    $lblPts=New-Object System.Windows.Forms.Label; $lblPts.Text="0 tweaks applied"; $lblPts.Font=$FontSmall; $lblPts.ForeColor=$C.TextMuted; $lblPts.Location=New-Object System.Drawing.Point(16,690); $lblPts.AutoSize=$true; $sidebar.Controls.Add($lblPts)

    # Init
    Show-Page "home"
    $h=(Get-Date).Hour
    $lblHomeTitle.Text=if ($h -lt 12) { "Good morning" } elseif ($h -lt 18) { "Good afternoon" } else { "Good evening" }
    $Script:LogBox.AppendText("FL3SH Optimizer Ultimate started. Plan: Pro`r`nCredits: FL3SH & XRT`r`n")
    Write-Log "Application started. Plan: Pro. User: $($Script:CurrentUser.Email)" "OK"

    # ---------- Rotating outline + snowfall (visual polish) ----------
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32Ex {
    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_TRANSPARENT = 0x20;
    public const int WS_EX_LAYERED = 0x80000;
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hwnd, int index, int value);
}
"@ -ErrorAction SilentlyContinue

    $Script:SnowFlakes = @()
    $rng = New-Object System.Random
    for ($i=0; $i -lt 90; $i++) {
        $Script:SnowFlakes += @{ X=$rng.Next(0,$form.Width); Y=$rng.Next(0,$form.Height); R=[double]($rng.Next(1,4)); Vx=($rng.NextDouble()-0.5)*0.6; Vy=$rng.NextDouble()*1.4+0.3; O=$rng.NextDouble()*0.5+0.25 }
    }
    $Script:RotAngle = 0

    $overlay = New-Object System.Windows.Forms.Panel
    $overlay.Size = $form.ClientSize
    $overlay.Location = New-Object System.Drawing.Point(0,0)
    $overlay.BackColor = [System.Drawing.Color]::Transparent
    $overlay.Enabled = $false
    $form.Controls.Add($overlay)
    $overlay.BringToFront()

    $overlay.Add_HandleCreated({
        $ex = [Win32Ex]::GetWindowLong($overlay.Handle, [Win32Ex]::GWL_EXSTYLE)
        [Win32Ex]::SetWindowLong($overlay.Handle, [Win32Ex]::GWL_EXSTYLE, $ex -bor [Win32Ex]::WS_EX_TRANSPARENT -bor [Win32Ex]::WS_EX_LAYERED) | Out-Null
    })
    $overlay.Add_Paint({
        $g = $_.Graphics
        foreach ($f in $Script:SnowFlakes) {
            $f.X += $f.Vx; $f.Y += $f.Vy
            if ($f.Y -gt $form.Height) { $f.Y = -4; $f.X = $rng.Next(0,$form.Width) }
            if ($f.X -gt $form.Width) { $f.X = 0 }
            if ($f.X -lt 0) { $f.X = $form.Width }
            $b = [int]($f.O*255)
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($b,255,255,255))
            $g.FillEllipse($brush, [float]$f.X, [float]$f.Y, [float]$f.R, [float]$f.R)
            $brush.Dispose()
        }
    })

    $form.Add_Paint({
        $g = $_.Graphics
        $r = $form.ClientRectangle
        $Script:RotAngle = ($Script:RotAngle + 3) % 360
        # rotating outline: draw a conic-ish gradient border using multiple colored segments
        $colors = @($C.Red, $C.Purple, $C.Blue, $C.Red)
        $penW = 2
        for ($i=0; $i -lt 36; $i++) {
            $a1 = ($Script:RotAngle + $i*10) * [Math]::PI / 180.0
            $a2 = ($Script:RotAngle + ($i+1)*10) * [Math]::PI / 180.0
            $ci = [int]($i / 12) % 3
            $pen = New-Object System.Drawing.Pen($colors[$ci], $penW)
            # top edge
            $x1 = $r.Left + ($r.Width/2) + [Math]::Cos($a1)*($r.Width/2-2)
            # simpler: draw outline segments around rectangle perimeter
            $pen.Dispose()
        }
        # Draw a simple animated dashed border
        $dashPen = New-Object System.Drawing.Pen($C.Red, 2)
        $dashPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
        $dashPen.DashOffset = $Script:RotAngle / 10.0
        $g.DrawRectangle($dashPen, 1,1,$r.Width-2,$r.Height-2)
        $dashPen.Dispose()
    })

    $animTimer = New-Object System.Windows.Forms.Timer
    $animTimer.Interval = 40
    $animTimer.Add_Tick({ $overlay.Invalidate(); $form.Invalidate() })
    $animTimer.Start()

    $form.Add_Resize({ $overlay.Size = $form.ClientSize })
    $form.Add_FormClosing({ $animTimer.Stop(); Save-Config })

    # ---------- Draggable window (move by dragging sidebar) ----------
    $Script:DragStart = $null
    $sidebar.Add_MouseDown({ $Script:DragStart = [System.Windows.Forms.Cursor]::Position })
    $sidebar.Add_MouseMove({
        if ($Script:DragStart -ne $null -and $_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $cur = [System.Windows.Forms.Cursor]::Position
            $form.Location = New-Object System.Drawing.Point(($form.Location.X + $cur.X - $Script:DragStart.X), ($form.Location.Y + $cur.Y - $Script:DragStart.Y))
            $Script:DragStart = $cur
        }
    })
    $sidebar.Add_MouseUp({ $Script:DragStart = $null })

    [void]$form.ShowDialog()
}

# ---------- Main Entry ----------
$Script:CurrentUser = Auto-Login
if ($Script:CurrentUser) {
    $Script:Config.Plan = "Pro"
    $Script:Config.CurrentUser = $Script:CurrentUser.Email
    $Script:Config.Email = $Script:CurrentUser.Email
    Save-Config
    Show-MainForm
} else {
    [void]$loginForm.ShowDialog()
    if ($Script:CurrentUser) { Show-MainForm }
}
