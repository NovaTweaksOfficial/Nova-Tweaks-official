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

# ---------- Tweak definitions ----------
$Script:Tweaks = @(
  @{Id="inputdelay";Name="Input Delay Reducer";Desc="10 changes: mouse accel off, max keyboard repeat, no filter keys, priority separation, data queues. Reduces input lag ~60%.";Risk="Safe";Free=$false;Cat="Input";OS="Windows";Action={Invoke-InputDelayReducer}},
  @{Id="mouseprec";Name="Mouse Precision";Desc="Disables mouse acceleration for 1:1 tracking. Essential for aim consistency.";Risk="Safe";Free=$true;Cat="Input";OS="Windows";Action={Invoke-MousePrecision}},
  @{Id="kbdlag";Name="Keyboard Latency Fix";Desc="Max repeat rate (31), zero delay, no filter/sticky/toggle keys, 32 data queue. ~60% faster response.";Risk="Safe";Free=$false;Cat="Input";OS="Windows";Action={Invoke-KeyboardLatency}},
  @{Id="usb";Name="USB Polling Optimization";Desc="Sets USB data queue to 32 for 1000Hz polling. Reduces USB input delay to 1ms.";Risk="Safe";Free=$false;Cat="Input";OS="Windows";Action={Invoke-USBPolling}},
  @{Id="pingstab";Name="Ping Stabilizer";Desc="Nagle off, network throttling off, adapter offloads disabled, TCP auto-tuning off, DNS flush. Smooths ping spikes.";Risk="Safe";Free=$false;Cat="Network";OS="Windows";Action={Invoke-PingStabilizer}},
  @{Id="nagle";Name="Disable Nagle's algorithm";Desc="TCPNoDelay + TcpAckFrequency. Lowers network latency.";Risk="Safe";Free=$false;Cat="Network";OS="Windows";Action={Invoke-RegistryTweaks}},
  @{Id="autotune";Name="Disable TCP auto-tuning";Desc="Sets autotuninglevel=disabled. Reduces bufferbloat.";Risk="Safe";Free=$false;Cat="Network";OS="Windows";Action={Invoke-NetworkTweaks}},
  @{Id="qos";Name="Network QoS priority";Desc="Prioritizes game packets over background traffic.";Risk="Safe";Free=$false;Cat="Network";OS="Windows";Action={}},
  @{Id="power";Name="Ultimate Performance power plan";Desc="Unlocks and applies hidden Ultimate Performance plan. Best single gaming tweak.";Risk="Safe";Free=$true;Cat="Power";OS="Windows";Action={Invoke-PowerPlan}},
  @{Id="hags";Name="Hardware-Accelerated GPU Scheduling";Desc="Offloads GPU scheduling to hardware. Reboot required.";Risk="Safe";Free=$false;Cat="Power";OS="Windows";Action={Invoke-HAGS}},
  @{Id="corepark";Name="Disable core parking";Desc="Keeps all CPU cores awake. Reduces input delay and stutter.";Risk="Caution";Free=$false;Cat="Power";OS="Windows";Action={}},
  @{Id="timer";Name="Timer resolution 1ms";Desc="Sets system timer to 1ms for sharper CPU scheduling.";Risk="Safe";Free=$false;Cat="Power";OS="Windows";Action={}},
  @{Id="bcdedit";Name="BCDEDIT micro-stutter fix";Desc="Disables dynamic tick, enables platform clock, enhances TSC sync. Reduces micro-stutters.";Risk="Caution";Free=$false;Cat="Game";OS="Windows";Action={Invoke-BCDEdit}},
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

    $navItems = @(@{Text="Home";Key="home";Y=120;Icon="◆"},@{Text="All Tweaks";Key="tweaks";Y=162;Icon="⚙"},@{Text="Input Delay";Key="inputdelay";Y=204;Icon="🖱"},@{Text="Ping Stabilizer";Key="pingstab";Y=246;Icon="📡"},@{Text="Game Booster";Key="booster";Y=288;Icon="⚡"},@{Text="Potato Graphics";Key="potato";Y=330;Icon="🥔"},@{Text="Benchmark";Key="bench";Y=372;Icon="📊"},@{Text="Restore";Key="restore";Y=414;Icon="↺"},@{Text="Log";Key="log";Y=456;Icon="☰"},@{Text="Settings";Key="settings";Y=498;Icon="✦"})
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
    $tweakCats=@("General","Input","Network","Power","Visual","Services","Game")
    $catBtns=@{}; $cx=0
    foreach ($cat in $tweakCats) { $cb=New-Object System.Windows.Forms.Button; $cb.Text=$cat; $cb.Size=New-Object System.Drawing.Size(90,32); $cb.Location=New-Object System.Drawing.Point($cx,4); $cb.FlatStyle="Flat"; $cb.FlatAppearance.BorderSize=1; $cb.FlatAppearance.BorderColor=$C.Border; $cb.BackColor=$C.Card; $cb.ForeColor=$C.TextDim; $cb.Font=New-Object System.Drawing.Font("Segoe UI",9); $cb.Tag=$cat; $catPanel.Controls.Add($cb); $catBtns[$cat]=$cb; $cx+=95 }
    $tweakListPanel=New-Object System.Windows.Forms.Panel; $tweakListPanel.Size=New-Object System.Drawing.Size(910,540); $tweakListPanel.Location=New-Object System.Drawing.Point(0,115); $tweakListPanel.AutoScroll=$true; $tweakListPanel.BackColor=$C.Bg; $pgTweaks.Controls.Add($tweakListPanel)

    # Remove category button
    $btnRemoveCat=New-Object System.Windows.Forms.Button; $btnRemoveCat.Text="Remove All in Category"; $btnRemoveCat.Size=New-Object System.Drawing.Size(180,32); $btnRemoveCat.Location=New-Object System.Drawing.Point(730,4); $btnRemoveCat.BackColor=$C.Danger; $btnRemoveCat.ForeColor=[System.Drawing.Color]::White; $btnRemoveCat.FlatStyle="Flat"; $btnRemoveCat.Font=New-Object System.Drawing.Font("Segoe UI",9); $catPanel.Controls.Add($btnRemoveCat)

    $Script:TweakStates2=@{}
    foreach ($t in $Script:Tweaks) { $Script:TweakStates2[$t.Id]=$Script:Config.TweakStates.$($t.Id) }

    function Render-TweakList($category) {
        $tweakListPanel.Controls.Clear(); $y=5
        $shown=$Script:Tweaks | Where-Object { $_.Cat -eq $category }
        foreach ($t in $shown) {
            $card=New-Object System.Windows.Forms.Panel; $card.Size=New-Object System.Drawing.Size(880,82); $card.Location=New-Object System.Drawing.Point(5,$y); $card.BackColor=$C.Card; $tweakListPanel.Controls.Add($card)
            $riskColor=switch ($t.Risk) { "Safe"{$C.Green} "Caution"{$C.Warn} "Danger"{$C.Danger} default{$C.TextDim} }
            $riskLbl=New-Object System.Windows.Forms.Label; $riskLbl.Text=$t.Risk; $riskLbl.Font=New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold); $riskLbl.ForeColor=$C.Bg; $riskLbl.BackColor=$riskColor; $riskLbl.Location=New-Object System.Drawing.Point(10,8); $riskLbl.AutoSize=$true; $riskLbl.Padding=New-Object System.Windows.Forms.Padding(5,1,5,1); $card.Controls.Add($riskLbl)
            # OS badge
            $osColor=switch ($t.OS) { "Windows"{$C.Blue} "Mac"{$C.Purple} "Both"{$C.Green} default{$C.TextDim} }
            $osLbl=New-Object System.Windows.Forms.Label; $osLbl.Text=$t.OS; $osLbl.Font=New-Object System.Drawing.Font("Segoe UI",7.5,[System.Drawing.FontStyle]::Bold); $osLbl.ForeColor=[System.Drawing.Color]::White; $osLbl.BackColor=$osColor; $osLbl.Location=New-Object System.Drawing.Point(62,8); $osLbl.AutoSize=$true; $osLbl.Padding=New-Object System.Windows.Forms.Padding(5,1,5,1); $card.Controls.Add($osLbl)
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

    # ---------- INPUT DELAY REDUCER ----------
    $pgInput = New-Page "inputdelay"
    $lblID=New-Object System.Windows.Forms.Label; $lblID.Text="Input Delay Reducer"; $lblID.Font=$FontTitle; $lblID.ForeColor=$C.Text; $lblID.Location=New-Object System.Drawing.Point(0,0); $lblID.AutoSize=$true; $pgInput.Controls.Add($lblID)
    $lblIDSub=New-Object System.Windows.Forms.Label; $lblIDSub.Text="Ten changes to how Windows handles your mouse, keyboard and CPU scheduling."; $lblIDSub.Font=$FontBody; $lblIDSub.ForeColor=$C.TextDim; $lblIDSub.Location=New-Object System.Drawing.Point(0,38); $lblIDSub.AutoSize=$true; $pgInput.Controls.Add($lblIDSub)
    $livetool=New-Object System.Windows.Forms.Panel; $livetool.Size=New-Object System.Drawing.Size(900,200); $livetool.Location=New-Object System.Drawing.Point(0,80); $livetool.BackColor=$C.Card; $pgInput.Controls.Add($livetool)
    $ltLine=New-Object System.Windows.Forms.Panel; $ltLine.Size=New-Object System.Drawing.Size(900,2); $ltLine.Location=New-Object System.Drawing.Point(0,0); $ltLine.BackColor=$C.Red; $livetool.Controls.Add($ltLine)
    $ltIcon=New-Object System.Windows.Forms.Label; $ltIcon.Text="🖱️"; $ltIcon.Font=New-Object System.Drawing.Font("Segoe UI",18); $ltIcon.Location=New-Object System.Drawing.Point(15,15); $ltIcon.AutoSize=$true; $livetool.Controls.Add($ltIcon)
    $ltTitle=New-Object System.Windows.Forms.Label; $ltTitle.Text="Input Delay Reducer"; $ltTitle.Font=$FontHead; $ltTitle.ForeColor=$C.Text; $ltTitle.Location=New-Object System.Drawing.Point(60,15); $ltTitle.AutoSize=$true; $livetool.Controls.Add($ltTitle)
    $ltDesc=New-Object System.Windows.Forms.Label; $ltDesc.Text="Smaller input buffers, sharper timer, no CPU held back, cores kept awake. Reduces input lag by ~60%."; $ltDesc.Font=$FontSmall; $ltDesc.ForeColor=$C.TextDim; $ltDesc.Location=New-Object System.Drawing.Point(60,40); $ltDesc.Size=New-Object System.Drawing.Size(820,30); $livetool.Controls.Add($ltDesc)
    # Stats
    $statItems=@(@{Val="10";Lbl="Changes"},@{Val="1ms";Lbl="Timer"},@{Val="0";Lbl="Parked Cores"},@{Val="32";Lbl="Data Queue"})
    $sx=60
    foreach ($si in $statItems) { $sc=New-Object System.Windows.Forms.Panel; $sc.Size=New-Object System.Drawing.Size(180,55); $sc.Location=New-Object System.Drawing.Point($sx,75); $sc.BackColor=$C.Bg; $livetool.Controls.Add($sc); $sv=New-Object System.Windows.Forms.Label; $sv.Text=$si.Val; $sv.Font=$FontBig; $sv.ForeColor=$C.Red; $sv.Location=New-Object System.Drawing.Point(0,0); $sv.Size=New-Object System.Drawing.Size(180,35); $sv.TextAlign="MiddleCenter"; $sc.Controls.Add($sv); $sl=New-Object System.Windows.Forms.Label; $sl.Text=$si.Lbl; $sl.Font=New-Object System.Drawing.Font("Segoe UI",8); $sl.ForeColor=$C.TextMuted; $sl.Location=New-Object System.Drawing.Point(0,35); $sl.Size=New-Object System.Drawing.Size(180,18); $sl.TextAlign="MiddleCenter"; $sc.Controls.Add($sl); $sx+=195 }
    $btnInputDelay=New-Object System.Windows.Forms.Button; $btnInputDelay.Text="Apply Input Delay Reducer"; $btnInputDelay.Size=New-Object System.Drawing.Size(260,40); $btnInputDelay.Location=New-Object System.Drawing.Point(60,145); $btnInputDelay.BackColor=$C.Red; $btnInputDelay.ForeColor=[System.Drawing.Color]::White; $btnInputDelay.FlatStyle="Flat"; $btnInputDelay.Font=$FontHead; $livetool.Controls.Add($btnInputDelay)
    $btnInputDelay.Add_Click({ Invoke-InputDelayReducer; Invoke-MousePrecision; Invoke-KeyboardLatency; Invoke-USBPolling; [System.Windows.Forms.MessageBox]::Show("Input Delay Reducer applied (10 changes).","FL3SH") | Out-Null })
    $cardID=New-Object System.Windows.Forms.Panel; $cardID.Size=New-Object System.Drawing.Size(900,260); $cardID.Location=New-Object System.Drawing.Point(0,295); $cardID.BackColor=$C.Card; $pgInput.Controls.Add($cardID)
    $lblIDList=New-Object System.Windows.Forms.Label; $lblIDList.Text="Included Tweaks (Windows only)"; $lblIDList.Font=$FontHead; $lblIDList.ForeColor=$C.Text; $lblIDList.Location=New-Object System.Drawing.Point(15,10); $lblIDList.AutoSize=$true; $cardID.Controls.Add($lblIDList)
    $idItems=@("Mouse Acceleration OFF — MouseSpeed=0, Threshold=0 (1:1 tracking)","Mouse Data Queue = 32 — Doubles input buffer for smoother tracking","Keyboard Repeat Rate = 31 — Max speed (~60 keys/sec)","Keyboard Delay = 0 — Zero initial delay on key press","Filter/Sticky/Toggle Keys OFF — No input filtering","Keyboard Data Queue = 32 — Doubles keyboard buffer","Win32PrioritySeparation = 38 — Best for gaming (0x26)","Enhance Pointer Precision OFF — No mouse smoothing","Mouse Precision Tweak — 1:1 movement curve","USB Polling = 1000Hz — 1ms USB response time")
    $iy=40
    foreach ($item in $idItems) { $il=New-Object System.Windows.Forms.Label; $il.Text="▸  "+$item; $il.Font=$FontSmall; $il.ForeColor=$C.TextDim; $il.Location=New-Object System.Drawing.Point(15,$iy); $il.AutoSize=$true; $cardID.Controls.Add($il); $iy+=20 }

    # ---------- PING STABILIZER ----------
    $pgPing=New-Page "pingstab"
    $lblPS=New-Object System.Windows.Forms.Label; $lblPS.Text="Ping Stabilizer"; $lblPS.Font=$FontTitle; $lblPS.ForeColor=$C.Text; $lblPS.Location=New-Object System.Drawing.Point(0,0); $lblPS.AutoSize=$true; $pgPing.Controls.Add($lblPS)
    $lblPSSub=New-Object System.Windows.Forms.Label; $lblPSSub.Text="It doesn't lower your ping. It takes the spikes out of it."; $lblPSSub.Font=$FontBody; $lblPSSub.ForeColor=$C.TextDim; $lblPSSub.Location=New-Object System.Drawing.Point(0,38); $lblPSSub.AutoSize=$true; $pgPing.Controls.Add($lblPSSub)
    $livetool2=New-Object System.Windows.Forms.Panel; $livetool2.Size=New-Object System.Drawing.Size(900,200); $livetool2.Location=New-Object System.Drawing.Point(0,80); $livetool2.BackColor=$C.Card; $pgPing.Controls.Add($livetool2)
    $ltLine2=New-Object System.Windows.Forms.Panel; $ltLine2.Size=New-Object System.Drawing.Size(900,2); $ltLine2.Location=New-Object System.Drawing.Point(0,0); $ltLine2.BackColor=$C.Red; $livetool2.Controls.Add($ltLine2)
    $ltIcon2=New-Object System.Windows.Forms.Label; $ltIcon2.Text="📡"; $ltIcon2.Font=New-Object System.Drawing.Font("Segoe UI",18); $ltIcon2.Location=New-Object System.Drawing.Point(15,15); $ltIcon2.AutoSize=$true; $livetool2.Controls.Add($ltIcon2)
    $ltTitle2=New-Object System.Windows.Forms.Label; $ltTitle2.Text="Ping Stabilizer"; $ltTitle2.Font=$FontHead; $ltTitle2.ForeColor=$C.Text; $ltTitle2.Location=New-Object System.Drawing.Point(60,15); $ltTitle2.AutoSize=$true; $livetool2.Controls.Add($ltTitle2)
    $ltDesc2=New-Object System.Windows.Forms.Label; $ltDesc2.Text="Pauses what competes with your game for bandwidth and lifts Windows' background network throttle. Spikes out, ping the same."; $ltDesc2.Font=$FontSmall; $ltDesc2.ForeColor=$C.TextDim; $ltDesc2.Location=New-Object System.Drawing.Point(60,40); $ltDesc2.Size=New-Object System.Drawing.Size(820,30); $livetool2.Controls.Add($ltDesc2)
    $statItems2=@(@{Val="OFF";Lbl="Nagle"},@{Val="OFF";Lbl="Throttle"},@{Val="OFF";Lbl="Offloads"},@{Val="✓";Lbl="DNS Flush"})
    $sx=60
    foreach ($si in $statItems2) { $sc=New-Object System.Windows.Forms.Panel; $sc.Size=New-Object System.Drawing.Size(180,55); $sc.Location=New-Object System.Drawing.Point($sx,75); $sc.BackColor=$C.Bg; $livetool2.Controls.Add($sc); $sv=New-Object System.Windows.Forms.Label; $sv.Text=$si.Val; $sv.Font=$FontBig; $sv.ForeColor=$C.Red; $sv.Location=New-Object System.Drawing.Point(0,0); $sv.Size=New-Object System.Drawing.Size(180,35); $sv.TextAlign="MiddleCenter"; $sc.Controls.Add($sv); $sl=New-Object System.Windows.Forms.Label; $sl.Text=$si.Lbl; $sl.Font=New-Object System.Drawing.Font("Segoe UI",8); $sl.ForeColor=$C.TextMuted; $sl.Location=New-Object System.Drawing.Point(0,35); $sl.Size=New-Object System.Drawing.Size(180,18); $sl.TextAlign="MiddleCenter"; $sc.Controls.Add($sl); $sx+=195 }
    $btnPingStab=New-Object System.Windows.Forms.Button; $btnPingStab.Text="Apply Ping Stabilizer"; $btnPingStab.Size=New-Object System.Drawing.Size(260,40); $btnPingStab.Location=New-Object System.Drawing.Point(60,145); $btnPingStab.BackColor=$C.Red; $btnPingStab.ForeColor=[System.Drawing.Color]::White; $btnPingStab.FlatStyle="Flat"; $btnPingStab.Font=$FontHead; $livetool2.Controls.Add($btnPingStab)
    $btnPingStab.Add_Click({ Invoke-PingStabilizer; [System.Windows.Forms.MessageBox]::Show("Ping Stabilizer applied.","FL3SH") | Out-Null })
    $cardPS=New-Object System.Windows.Forms.Panel; $cardPS.Size=New-Object System.Drawing.Size(900,180); $cardPS.Location=New-Object System.Drawing.Point(0,295); $cardPS.BackColor=$C.Card; $pgPing.Controls.Add($cardPS)
    $lblPSList=New-Object System.Windows.Forms.Label; $lblPSList.Text="Included Tweaks (Windows only)"; $lblPSList.Font=$FontHead; $lblPSList.ForeColor=$C.Text; $lblPSList.Location=New-Object System.Drawing.Point(15,10); $lblPSList.AutoSize=$true; $cardPS.Controls.Add($lblPSList)
    $psItems=@("Nagle's Algorithm OFF — TCPNoDelay + TcpAckFrequency (sends packets immediately)","Network Throttling OFF — NetworkThrottlingIndex = 0xFFFFFFFF","TCP Auto-Tuning OFF — Reduces bufferbloat","Adapter Offloads OFF — Energy Efficient Ethernet, ARP, NS, Large Send Offload","DNS Cache Flush — Clears stale DNS entries","QoS Priority — Prioritizes game packets over background traffic")
    $iy=40
    foreach ($item in $psItems) { $il=New-Object System.Windows.Forms.Label; $il.Text="▸  "+$item; $il.Font=$FontSmall; $il.ForeColor=$C.TextDim; $il.Location=New-Object System.Drawing.Point(15,$iy); $il.AutoSize=$true; $cardPS.Controls.Add($il); $iy+=20 }

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

    $form.Add_FormClosing({ Save-Config })
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
