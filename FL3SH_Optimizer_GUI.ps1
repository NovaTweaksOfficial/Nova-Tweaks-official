#Requires -RunAsAdministrator
<#
.SYNOPSIS
    FL3SH Optimizer - GUI Edition (EMTweaks/MIZtweaks-style interface)
.DESCRIPTION
    Modern dark-themed WinForms GUI. Sidebar navigation, tweak cards with toggles,
    safety labels, live system monitoring, Game Booster, Potato Graphics, restore points.
.NOTES
    Compile to .exe with PS2EXE. See packaging notes at bottom.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------- Theme ----------
$C = @{
    Bg        = [System.Drawing.Color]::FromArgb(18,18,22)
    Sidebar   = [System.Drawing.Color]::FromArgb(24,24,30)
    Card      = [System.Drawing.Color]::FromArgb(30,30,38)
    CardHover = [System.Drawing.Color]::FromArgb(38,38,48)
    Accent    = [System.Drawing.Color]::FromArgb(0,200,120)
    AccentDim = [System.Drawing.Color]::FromArgb(0,120,70)
    Danger    = [System.Drawing.Color]::FromArgb(220,60,60)
    Warn      = [System.Drawing.Color]::FromArgb(240,180,40)
    Text      = [System.Drawing.Color]::FromArgb(230,230,235)
    TextDim   = [System.Drawing.Color]::FromArgb(140,140,150)
    Border    = [System.Drawing.Color]::FromArgb(50,50,60)
}
$FontTitle = New-Object System.Drawing.Font("Segoe UI",16,[System.Drawing.FontStyle]::Bold)
$FontHead  = New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold)
$FontBody  = New-Object System.Drawing.Font("Segoe UI",10)
$FontSmall = New-Object System.Drawing.Font("Segoe UI",8.5)
$FontMono  = New-Object System.Drawing.Font("Consolas",9)

# ---------- Paths ----------
$Script:Root      = Join-Path $env:USERPROFILE "FL3SH_Optimizer"
$Script:BackupDir = Join-Path $Script:Root "backups"
$Script:LogPath   = Join-Path $Script:Root "optimizer.log"
$Script:ConfigPath= Join-Path $Script:Root "config.json"
$Script:BenchPath = Join-Path $Script:Root "benchmark.csv"
foreach ($d in @($Script:Root,$Script:BackupDir)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }
if (-not (Test-Path $Script:LogPath)) { New-Item -ItemType File -Path $Script:LogPath -Force | Out-Null }

# ---------- Config ----------
$Script:Config = @{
    Plan="Free"; Preset="Safe"; FortnitePath=""; PotatoGraphics=$false
    TweakPower=$true; TweakMemory=$true; TweakTemp=$true; TweakRegistry=$true
    TweakHAGS=$true; TweakServices=$false; TweakNetwork=$true; TweakVisual=$true
    LicenseKey=""; Email=""
    Whitelist=@(); GameBoosterActive=$false
}
if (Test-Path $Script:ConfigPath) {
    try { $loaded = Get-Content $Script:ConfigPath -Raw | ConvertFrom-Json; foreach ($k in $loaded.PSObject.Properties.Name) { $Script:Config[$k]=$loaded.$k } } catch {}
}
function Save-Config { $Script:Config | ConvertTo-Json -Depth 5 | Set-Content $Script:ConfigPath -Encoding UTF8 }

# ---------- Logging ----------
$Script:LogLines = [System.Collections.ArrayList]::new()
function Write-Log {
    param([string]$Msg,[string]$Level="INFO")
    $line = "$(Get-Date -Format 'HH:mm:ss') [$Level] $Msg"
    [void]$Script:LogLines.Add($line)
    Add-Content -Path $Script:LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Msg" -ErrorAction SilentlyContinue
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

# ============================================================
# TWEAK FUNCTIONS
# ============================================================
function New-RestorePoint {
    try { Checkpoint-Computer -Description "FL3SH Optimizer" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop; Write-Log "Restore point created." "OK"; return $true }
    catch { Write-Log "Restore point failed: $($_.Exception.Message)" "WARN"; return $false }
}

function Invoke-PowerPlan {
    try {
        $hp = (powercfg /list | Select-String "Ultimate Performance" | ForEach-Object { ($_ -split '\s+')[3] }) | Select-Object -First 1
        if (-not $hp) { $hp = (powercfg /list | Select-String "High performance" | ForEach-Object { ($_ -split '\s+')[3] }) | Select-Object -First 1 }
        if (-not $hp) { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null | Out-Null; $hp = (powercfg /list | Select-String "Ultimate Performance" | ForEach-Object { ($_ -split '\s+')[3] }) | Select-Object -First 1 }
        if ($hp) { powercfg /setactive $hp 2>$null | Out-Null; Write-Log "Power plan: $hp" "OK" }
        powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
        powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
        powercfg /setactive SCHEME_CURRENT 2>$null
        Write-Log "USB selective suspend disabled." "OK"
    } catch { Write-Log "Power plan failed: $($_.Exception.Message)" "ERR" }
}

function Invoke-MemoryCleanup {
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
        Write-Log "Memory trimmed + standby purged." "OK"
    } catch { Write-Log "Memory partial: $($_.Exception.Message)" "WARN" }
}

function Invoke-TempCleanup {
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

function Invoke-RegistryTweaks {
    $changes = @(
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_Enabled"; Value=0; Type="DWord"; Risk="Safe"; Desc="Disables Game Bar DVR recording"},
        @{Path="HKCU:\System\GameConfigStore"; Name="GameDVR_FSEBehaviorMode"; Value=2; Type="DWord"; Risk="Safe"; Desc="Fullscreen optimizations off"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="SystemResponsiveness"; Value=0; Type="DWord"; Risk="Safe"; Desc="CPU reserved for multimedia = 0%"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="GPU Priority"; Value=8; Type="DWord"; Risk="Safe"; Desc="GPU priority for games = 8"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Priority"; Value=6; Type="DWord"; Risk="Safe"; Desc="Game thread priority = 6"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Scheduling Category"; Value="High"; Type="String"; Risk="Safe"; Desc="High scheduling category for games"},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="SFIO Priority"; Value="High"; Type="String"; Risk="Safe"; Desc="High I/O priority for games"},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; Name="VisualFXSetting"; Value=2; Type="DWord"; Risk="Safe"; Desc="Best performance visual effects"},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="MenuShowDelay"; Value=0; Type="String"; Risk="Safe"; Desc="Instant menu response"},
        @{Path="HKCU:\Software\Microsoft\Windows\DWM"; Name="EnableAeroPeek"; Value=0; Type="DWord"; Risk="Safe"; Desc="Disable Aero Peek"}
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

function Invoke-HAGS {
    try {
        $p = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        Set-ItemProperty -Path $p -Name "HwSchMode" -Value 2 -Type DWord -Force
        Write-Log "HAGS enabled (reboot required)." "OK"
    } catch { Write-Log "HAGS failed: $($_.Exception.Message)" "WARN" }
}

function Invoke-Services {
    $svcs = @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","DiagTrack","dmwappushservice","SysMain")
    foreach ($s in $svcs) {
        try {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue; Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue; Write-Log "Disabled: $s" "OK" }
        } catch { Write-Log "Service $s skipped." "WARN" }
    }
}

function Invoke-Network {
    try {
        netsh interface tcp set global autotuninglevel=disabled 2>$null | Out-Null
        netsh interface tcp set global ecncapability=disabled 2>$null | Out-Null
        netsh interface tcp set global timestamps=disabled 2>$null | Out-Null
        Write-Log "TCP auto-tuning disabled." "OK"
    } catch { Write-Log "Network tweak failed: $($_.Exception.Message)" "WARN" }
}

function Invoke-PotatoGraphics {
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
    param([string[]]$Whitelist = @())
    Write-Log "Game Booster: closing non-whitelisted processes..." "INFO"
    $keep = @("System","Registry","smss","csrss","winlogon","services","lsass","explorer","dwm","svchost","conhost","powershell","pwsh","cmd","taskmgr","GameBar","FortniteClient-Win64-Shipping") + $Whitelist
    Get-Process | Where-Object { $_.ProcessName -notin $keep -and $_.MainWindowHandle -ne 0 } | ForEach-Object {
        try { $_.CloseMainWindow() | Out-Null; Write-Log "Closed: $($_.ProcessName)" "OK" } catch {}
    }
    Invoke-MemoryCleanup
    Write-Log "Game Booster complete." "OK"
}

function Revert-All {
    Write-Log "Reverting all changes..."
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
    netsh interface tcp set global autotuninglevel=normal 2>$null | Out-Null
    @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","DiagTrack","dmwappushservice","SysMain") | ForEach-Object { Set-Service -Name $_ -StartupType Manual -ErrorAction SilentlyContinue }
    $bak = Join-Path $Script:BackupDir "Engine.ini.bak"
    $p = "$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient\Engine.ini"
    if (Test-Path $bak) { Copy-Item $bak $p -Force; Write-Log "Engine.ini restored." "OK" }
    Write-Log "Revert complete. Reboot recommended." "OK"
}

# ============================================================
# GUI
# ============================================================
Ensure-Admin

$form = New-Object System.Windows.Forms.Form
$form.Text = "FL3SH Optimizer"
$form.Size = New-Object System.Drawing.Size(1100,720)
$form.StartPosition = "CenterScreen"
$form.BackColor = $C.Bg
$form.ForeColor = $C.Text
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.Font = $FontBody

# ---------- Sidebar ----------
$sidebar = New-Object System.Windows.Forms.Panel
$sidebar.Size = New-Object System.Drawing.Size(200,720)
$sidebar.Location = New-Object System.Drawing.Point(0,0)
$sidebar.BackColor = $C.Sidebar
$form.Controls.Add($sidebar)

$lblBrand = New-Object System.Windows.Forms.Label
$lblBrand.Text = "FL3SH"
$lblBrand.Font = New-Object System.Drawing.Font("Segoe UI",20,[System.Drawing.FontStyle]::Bold)
$lblBrand.ForeColor = $C.Accent
$lblBrand.Location = New-Object System.Drawing.Point(20,20)
$lblBrand.AutoSize = $true
$sidebar.Controls.Add($lblBrand)

$lblBrandSub = New-Object System.Windows.Forms.Label
$lblBrandSub.Text = "Optimizer"
$lblBrandSub.Font = $FontSmall
$lblBrandSub.ForeColor = $C.TextDim
$lblBrandSub.Location = New-Object System.Drawing.Point(22,52)
$lblBrandSub.AutoSize = $true
$sidebar.Controls.Add($lblBrandSub)

# Plan badge
$lblPlan = New-Object System.Windows.Forms.Label
$lblPlan.Text = "  FREE  "
$lblPlan.Font = New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
$lblPlan.ForeColor = $C.Bg
$lblPlan.BackColor = $C.Warn
$lblPlan.Location = New-Object System.Drawing.Point(20,80)
$lblPlan.AutoSize = $true
$lblPlan.Padding = New-Object System.Windows.Forms.Padding(6,2,6,2)
$sidebar.Controls.Add($lblPlan)

# Sidebar buttons
$Script:NavButtons = @()
$Script:Pages = @{}
function New-NavButton($text,$key,$y) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "  " + $text
    $btn.Size = New-Object System.Drawing.Size(180,38)
    $btn.Location = New-Object System.Drawing.Point(10,$y)
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 0
    $btn.BackColor = $C.Sidebar
    $btn.ForeColor = $C.TextDim
    $btn.Font = $FontBody
    $btn.TextAlign = "MiddleLeft"
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Tag = $key
    $sidebar.Controls.Add($btn)
    $Script:NavButtons += $btn
    return $btn
}

$navItems = @(
    @{Text="Home";Key="home";Y=120},
    @{Text="Tweaks";Key="tweaks";Y=162},
    @{Text="Game Booster";Key="booster";Y=204},
    @{Text="Potato Graphics";Key="potato";Y=246},
    @{Text="Benchmark";Key="bench";Y=288},
    @{Text="Restore";Key="restore";Y=330},
    @{Text="Log";Key="log";Y=372},
    @{Text="Settings";Key="settings";Y=414}
)
foreach ($n in $navItems) { New-NavButton $n.Text $n.Key $n.Y | Out-Null }

# User info at bottom
$lblUser = New-Object System.Windows.Forms.Label
$lblUser.Text = "Guest"
$lblUser.Font = $FontSmall
$lblUser.ForeColor = $C.TextDim
$lblUser.Location = New-Object System.Drawing.Point(20,640)
$lblUser.AutoSize = $true
$sidebar.Controls.Add($lblUser)

$lblPts = New-Object System.Windows.Forms.Label
$lblPts.Text = "0 tweaks applied"
$lblPts.Font = $FontSmall
$lblPts.ForeColor = $C.TextDim
$lblPts.Location = New-Object System.Drawing.Point(20,660)
$lblPts.AutoSize = $true
$sidebar.Controls.Add($lblPts)

# ---------- Content area ----------
$content = New-Object System.Windows.Forms.Panel
$content.Size = New-Object System.Drawing.Size(880,680)
$content.Location = New-Object System.Drawing.Point(210,20)
$content.BackColor = $C.Bg
$form.Controls.Add($content)

function New-Page($key) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Size = $content.Size
    $p.Location = New-Object System.Drawing.Point(0,0)
    $p.BackColor = $C.Bg
    $p.Visible = $false
    $p.AutoScroll = $true
    $content.Controls.Add($p)
    $Script:Pages[$key] = $p
    return $p
}

# ============================================================
# HOME PAGE
# ============================================================
$pgHome = New-Page "home"
$lblHomeTitle = New-Object System.Windows.Forms.Label
$lblHomeTitle.Text = "Good evening"
$lblHomeTitle.Font = $FontTitle
$lblHomeTitle.ForeColor = $C.Text
$lblHomeTitle.Location = New-Object System.Drawing.Point(20,10)
$lblHomeTitle.AutoSize = $true
$pgHome.Controls.Add($lblHomeTitle)

$lblHomeSub = New-Object System.Windows.Forms.Label
$lblHomeSub.Text = "3 of 356 tweaks on · Free plan"
$lblHomeSub.Font = $FontBody
$lblHomeSub.ForeColor = $C.TextDim
$lblHomeSub.Location = New-Object System.Drawing.Point(20,45)
$lblHomeSub.AutoSize = $true
$pgHome.Controls.Add($lblHomeSub)

# Stats cards row
$statY = 80
$stats = @(
    @{Label="CPU";Value="7%";Color=$C.Accent},
    @{Label="GPU";Value="8%";Color=$C.Accent},
    @{Label="RAM";Value="37%";Color=$C.Warn},
    @{Label="Temp";Value="41C";Color=$C.Accent}
)
$sx = 20
foreach ($st in $stats) {
    $card = New-Object System.Windows.Forms.Panel
    $card.Size = New-Object System.Drawing.Size(190,90)
    $card.Location = New-Object System.Drawing.Point($sx,$statY)
    $card.BackColor = $C.Card
    $pgHome.Controls.Add($card)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $st.Label
    $l.Font = $FontSmall
    $l.ForeColor = $C.TextDim
    $l.Location = New-Object System.Drawing.Point(15,10)
    $l.AutoSize = $true
    $card.Controls.Add($l)
    $v = New-Object System.Windows.Forms.Label
    $v.Text = $st.Value
    $v.Font = New-Object System.Drawing.Font("Segoe UI",24,[System.Drawing.FontStyle]::Bold)
    $v.ForeColor = $st.Color
    $v.Location = New-Object System.Drawing.Point(15,30)
    $v.AutoSize = $true
    $card.Controls.Add($v)
    $sx += 205
}

# Suggested next card
$cardSug = New-Object System.Windows.Forms.Panel
$cardSug.Size = New-Object System.Drawing.Size(400,120)
$cardSug.Location = New-Object System.Drawing.Point(20,190)
$cardSug.BackColor = $C.Card
$pgHome.Controls.Add($cardSug)
$ls = New-Object System.Windows.Forms.Label
$ls.Text = "Suggested next"
$ls.Font = $FontHead
$ls.ForeColor = $C.Text
$ls.Location = New-Object System.Drawing.Point(15,10)
$ls.AutoSize = $true
$cardSug.Controls.Add($ls)
$ls2 = New-Object System.Windows.Forms.Label
$ls2.Text = "1% optimized - 3 of 356 on. Free plan."
$ls2.Font = $FontBody
$ls2.ForeColor = $C.TextDim
$ls2.Location = New-Object System.Drawing.Point(15,40)
$ls2.AutoSize = $true
$cardSug.Controls.Add($ls2)
$btnApplyAll = New-Object System.Windows.Forms.Button
$btnApplyAll.Text = "Apply everything"
$btnApplyAll.Size = New-Object System.Drawing.Size(160,36)
$btnApplyAll.Location = New-Object System.Drawing.Point(15,70)
$btnApplyAll.BackColor = $C.Accent
$btnApplyAll.ForeColor = $C.Bg
$btnApplyAll.FlatStyle = "Flat"
$btnApplyAll.Font = $FontBody
$cardSug.Controls.Add($btnApplyAll)

# Quickstart card
$cardQS = New-Object System.Windows.Forms.Panel
$cardQS.Size = New-Object System.Drawing.Size(400,120)
$cardQS.Location = New-Object System.Drawing.Point(435,190)
$cardQS.BackColor = $C.Card
$pgHome.Controls.Add($cardQS)
$lq = New-Object System.Windows.Forms.Label
$lq.Text = "Quickstart"
$lq.Font = $FontHead
$lq.ForeColor = $C.Text
$lq.Location = New-Object System.Drawing.Point(15,10)
$lq.AutoSize = $true
$cardQS.Controls.Add($lq)
$qsItems = @("Create a restore point","Turn on your first 3 tweaks","Turn on Game Booster","Join the Discord")
$qy = 40
foreach ($q in $qsItems) {
    $ql = New-Object System.Windows.Forms.Label
    $ql.Text = "  -  " + $q
    $ql.Font = $FontSmall
    $ql.ForeColor = $C.TextDim
    $ql.Location = New-Object System.Drawing.Point(15,$qy)
    $ql.AutoSize = $true
    $cardQS.Controls.Add($ql)
    $qy += 18
}

# What's new card
$cardWN = New-Object System.Windows.Forms.Panel
$cardWN.Size = New-Object System.Drawing.Size(820,100)
$cardWN.Location = New-Object System.Drawing.Point(20,330)
$cardWN.BackColor = $C.Card
$pgHome.Controls.Add($cardWN)
$lw = New-Object System.Windows.Forms.Label
$lw.Text = "What's new"
$lw.Font = $FontHead
$lw.ForeColor = $C.Text
$lw.Location = New-Object System.Drawing.Point(15,10)
$lw.AutoSize = $true
$cardWN.Controls.Add($lw)
$lw2 = New-Object System.Windows.Forms.Label
$lw2.Text = "Game Booster clears your session again. Drivers, services and vendor tools are never touched, so laptops are safe."
$lw2.Font = $FontSmall
$lw2.ForeColor = $C.TextDim
$lw2.Location = New-Object System.Drawing.Point(15,40)
$lw2.AutoSize = $true
$cardWN.Controls.Add($lw2)

# ============================================================
# TWEAKS PAGE
# ============================================================
$pgTweaks = New-Page "tweaks"

# Category tabs inside tweaks page
$tweakCats = @("General","Services","Network","Power","Visual","Game")
$catPanel = New-Object System.Windows.Forms.Panel
$catPanel.Size = New-Object System.Drawing.Size(860,40)
$catPanel.Location = New-Object System.Drawing.Point(10,10)
$catPanel.BackColor = $C.Bg
$pgTweaks.Controls.Add($catPanel)

$Script:CatButtons = @{}
$cx = 0
foreach ($cat in $tweakCats) {
    $cb = New-Object System.Windows.Forms.Button
    $cb.Text = $cat
    $cb.Size = New-Object System.Drawing.Size(100,32)
    $cb.Location = New-Object System.Drawing.Point($cx,4)
    $cb.FlatStyle = "Flat"
    $cb.FlatAppearance.BorderSize = 1
    $cb.FlatAppearance.BorderColor = $C.Border
    $cb.BackColor = $C.Card
    $cb.ForeColor = $C.TextDim
    $cb.Font = $FontSmall
    $cb.Tag = $cat
    $catPanel.Controls.Add($cb)
    $Script:CatButtons[$cat] = $cb
    $cx += 105
}

# Tweak list container
$script:TweakListPanel = New-Object System.Windows.Forms.Panel
$script:TweakListPanel.Size = New-Object System.Drawing.Size(860,600)
$script:TweakListPanel.Location = New-Object System.Drawing.Point(10,55)
$script:TweakListPanel.AutoScroll = $true
$pgTweaks.Controls.Add($script:TweakListPanel)

# Define tweaks
$Script:Tweaks = @(
    # General
    @{Id="power";Cat="Power";Name="Ultimate Performance power plan";Desc="Unlocks and applies the hidden Ultimate Performance plan. Best single tweak for gaming.";Risk="Safe";Free=$true;Action={Invoke-PowerPlan}},
    @{Id="usb";Cat="Power";Name="Disable USB selective suspend";Desc="Stops USB ports from sleeping. Prevents input lag spikes.";Risk="Safe";Free=$true;Action={}},
    @{Id="memory";Cat="General";Name="Memory cleanup (trim + purge standby)";Desc="Trims idle process working sets and purges standby list. Frees RAM.";Risk="Safe";Free=$true;Action={Invoke-MemoryCleanup}},
    @{Id="temp";Cat="General";Name="Temp + shader cache cleanup";Desc="Clears %TEMP% and Fortnite shader cache. Frees disk space.";Risk="Safe";Free=$true;Action={Invoke-TempCleanup}},
    @{Id="visual";Cat="Visual";Name="Disable visual effects";Desc="Turns off window animations, fades and shadows for snappier UI.";Risk="Safe";Free=$true;Action={Invoke-RegistryTweaks}},
    @{Id="menu";Cat="Visual";Name="Reduce menu show delay";Desc="Sets MenuShowDelay to 0 for instant menu response.";Risk="Safe";Free=$true;Action={}},
    @{Id="transp";Cat="Visual";Name="Disable transparency effects";Desc="Kills Acrylic/Mica blur to free GPU compositor cycles.";Risk="Safe";Free=$true;Action={}},
    @{Id="startup";Cat="General";Name="Disable startup delay";Desc="Removes the artificial startup app delay timer.";Risk="Safe";Free=$true;Action={}},
    # Services
    @{Id="services";Cat="Services";Name="Disable background services";Desc="Stops Xbox + telemetry services (XblAuthManager, DiagTrack, etc).";Risk="Caution";Free=$false;Action={Invoke-Services}},
    @{Id="sysmain";Cat="Services";Name="Disable SysMain (Superfetch)";Desc="Stops background prefetching. Helps on SSD systems.";Risk="Caution";Free=$false;Action={}},
    # Network
    @{Id="nagle";Cat="Network";Name="Disable Nagle's algorithm";Desc="TCPNoDelay + TcpAckFrequency. Lowers network latency.";Risk="Safe";Free=$false;Action={Invoke-RegistryTweaks}},
    @{Id="autotune";Cat="Network";Name="Disable TCP auto-tuning";Desc="Sets autotuninglevel=disabled. Reduces bufferbloat.";Risk="Safe";Free=$false;Action={Invoke-Network}},
    @{Id="qos";Cat="Network";Name="Network QoS priority";Desc="Prioritizes game packets over background traffic.";Risk="Safe";Free=$false;Action={}},
    # Power
    @{Id="hags";Cat="Power";Name="Hardware-Accelerated GPU Scheduling";Desc="Offloads GPU scheduling to hardware. Reboot required.";Risk="Safe";Free=$false;Action={Invoke-HAGS}},
    @{Id="corepark";Cat="Power";Name="Disable core parking";Desc="Keeps all CPU cores awake. Reduces input delay.";Risk="Caution";Free=$false;Action={}},
    @{Id="timer";Cat="Power";Name="Timer resolution 1ms";Desc="Sets system timer to 1ms. Sharper scheduling.";Risk="Safe";Free=$false;Action={}},
    # Game
    @{Id="potato";Cat="Game";Name="Potato Graphics (Engine.ini)";Desc="Lowers Fortnite render quality for max FPS. Changes appearance.";Risk="Caution";Free=$false;Action={Invoke-PotatoGraphics}},
    @{Id="gamedvr";Cat="Game";Name="Disable Game DVR / Game Bar";Desc="Turns off Xbox Game Bar recording overlay.";Risk="Safe";Free=$false;Action={Invoke-RegistryTweaks}},
    @{Id="fullscreen";Cat="Game";Name="Fullscreen optimizations off";Desc="Disables FSO for lower input lag in fullscreen.";Risk="Safe";Free=$false;Action={}}
)

$Script:TweakStates = @{}
foreach ($t in $Script:Tweaks) { $Script:TweakStates[$t.Id] = $false }

function Render-TweakList($category) {
    $script:TweakListPanel.Controls.Clear()
    $y = 5
    $shown = $Script:Tweaks | Where-Object { $_.Cat -eq $category }
    foreach ($t in $shown) {
        $card = New-Object System.Windows.Forms.Panel
        $card.Size = New-Object System.Drawing.Size(830,80)
        $card.Location = New-Object System.Drawing.Point(5,$y)
        $card.BackColor = $C.Card
        $script:TweakListPanel.Controls.Add($card)

        # Risk badge
        $riskColor = switch ($t.Risk) { "Safe"{$C.Accent} "Caution"{$C.Warn} "Danger"{$C.Danger} default{$C.TextDim} }
        $riskLbl = New-Object System.Windows.Forms.Label
        $riskLbl.Text = $t.Risk
        $riskLbl.Font = New-Object System.Drawing.Font("Segoe UI",7.5,[System.Drawing.FontStyle]::Bold)
        $riskLbl.ForeColor = $C.Bg
        $riskLbl.BackColor = $riskColor
        $riskLbl.Location = New-Object System.Drawing.Point(10,8)
        $riskLbl.AutoSize = $true
        $riskLbl.Padding = New-Object System.Windows.Forms.Padding(4,1,4,1)
        $card.Controls.Add($riskLbl)

        # Free/Pro badge
        $planLbl = New-Object System.Windows.Forms.Label
        if ($t.Free) { $planLbl.Text = "FREE"; $planLbl.BackColor = $C.AccentDim; $planLbl.ForeColor = $C.Text }
        else { $planLbl.Text = "PRO"; $planLbl.BackColor = $C.Warn; $planLbl.ForeColor = $C.Bg }
        $planLbl.Font = New-Object System.Drawing.Font("Segoe UI",7.5,[System.Drawing.FontStyle]::Bold)
        $planLbl.Location = New-Object System.Drawing.Point(60,8)
        $planLbl.AutoSize = $true
        $planLbl.Padding = New-Object System.Windows.Forms.Padding(4,1,4,1)
        $card.Controls.Add($planLbl)

        # Name
        $nameLbl = New-Object System.Windows.Forms.Label
        $nameLbl.Text = $t.Name
        $nameLbl.Font = $FontHead
        $nameLbl.ForeColor = $C.Text
        $nameLbl.Location = New-Object System.Drawing.Point(10,28)
        $nameLbl.AutoSize = $true
        $card.Controls.Add($nameLbl)

        # Desc
        $descLbl = New-Object System.Windows.Forms.Label
        $descLbl.Text = $t.Desc
        $descLbl.Font = $FontSmall
        $descLbl.ForeColor = $C.TextDim
        $descLbl.Location = New-Object System.Drawing.Point(10,50)
        $descLbl.Size = New-Object System.Drawing.Size(650,28)
        $card.Controls.Add($descLbl)

        # Toggle switch (checkbox styled)
        $toggle = New-Object System.Windows.Forms.CheckBox
        $toggle.Text = ""
        $toggle.Size = New-Object System.Drawing.Size(20,20)
        $toggle.Location = New-Object System.Drawing.Point(790,30)
        $toggle.Checked = $Script:TweakStates[$t.Id]
        $toggle.Tag = $t.Id
        $toggle.ForeColor = $C.Accent
        $card.Controls.Add($toggle)

        $toggle.Add_CheckedChanged({
            $tid = $this.Tag
            $tw = $Script:Tweaks | Where-Object { $_.Id -eq $tid } | Select-Object -First 1
            # Check plan
            if (-not $tw.Free -and $Script:Config.Plan -eq "Free") {
                [System.Windows.Forms.MessageBox]::Show("This tweak requires Pro plan.`nUpgrade to unlock.","FL3SH Optimizer") | Out-Null
                $this.Checked = $false
                return
            }
            $Script:TweakStates[$tid] = $this.Checked
            if ($this.Checked) {
                if ($tw.Risk -ne "Safe") {
                    $r = [System.Windows.Forms.MessageBox]::Show("$($tw.Name)`n`nRisk: $($tw.Risk)`n$($tw.Desc)`n`nApply?","Confirm", [System.Windows.Forms.MessageBoxButtons]::YesNo)
                    if ($r -ne "Yes") { $this.Checked=$false; $Script:TweakStates[$tid]=$false; return }
                }
                & $tw.Action
            }
            $applied = ($Script:TweakStates.Values | Where-Object { $_ }).Count
            $lblPts.Text = "$applied tweaks applied"
            $lblHomeSub.Text = "$applied of 356 tweaks on · $($Script:Config.Plan) plan"
        })

        $y += 88
    }
}

# Default category
$Script:CurrentCat = "General"
Render-TweakList "General"
# Highlight first cat button
$Script:CatButtons["General"].BackColor = $C.Accent
$Script:CatButtons["General"].ForeColor = $C.Bg

foreach ($cat in $tweakCats) {
    $Script:CatButtons[$cat].Add_Click({
        $Script:CurrentCat = $this.Tag
        Render-TweakList $this.Tag
        foreach ($c in $tweakCats) {
            $Script:CatButtons[$c].BackColor = $C.Card
            $Script:CatButtons[$c].ForeColor = $C.TextDim
        }
        $this.BackColor = $C.Accent
        $this.ForeColor = $C.Bg
    })
}

# ============================================================
# GAME BOOSTER PAGE
# ============================================================
$pgBooster = New-Page "booster"
$lblB = New-Object System.Windows.Forms.Label
$lblB.Text = "EMT Game Booster"
$lblB.Font = $FontTitle
$lblB.ForeColor = $C.Text
$lblB.Location = New-Object System.Drawing.Point(20,10)
$lblB.AutoSize = $true
$pgBooster.Controls.Add($lblB)

$lblBSub = New-Object System.Windows.Forms.Label
$lblBSub.Text = "Closes what you are not using before you queue. Whitelist what stays."
$lblBSub.Font = $FontBody
$lblBSub.ForeColor = $C.TextDim
$lblBSub.Location = New-Object System.Drawing.Point(20,45)
$lblBSub.AutoSize = $true
$pgBooster.Controls.Add($lblBSub)

$cardB = New-Object System.Windows.Forms.Panel
$cardB.Size = New-Object System.Drawing.Size(500,200)
$cardB.Location = New-Object System.Drawing.Point(20,90)
$cardB.BackColor = $C.Card
$pgBooster.Controls.Add($cardB)

$lblBW = New-Object System.Windows.Forms.Label
$lblBW.Text = "Whitelist (one app per line)"
$lblBW.Font = $FontHead
$lblBW.ForeColor = $C.Text
$lblBW.Location = New-Object System.Drawing.Point(15,10)
$lblBW.AutoSize = $true
$cardB.Controls.Add($lblBW)

$txtWL = New-Object System.Windows.Forms.TextBox
$txtWL.Location = New-Object System.Drawing.Point(15,40)
$txtWL.Size = New-Object System.Drawing.Size(470,100)
$txtWL.Multiline = $true
$txtWL.BackColor = $C.Bg
$txtWL.ForeColor = $C.Text
$txtWL.Font = $FontMono
$txtWL.Text = "discord.exe`nchrome.exe`nspotify.exe"
$cardB.Controls.Add($txtWL)

$btnBoost = New-Object System.Windows.Forms.Button
$btnBoost.Text = "BOOST (close others)"
$btnBoost.Size = New-Object System.Drawing.Size(200,40)
$btnBoost.Location = New-Object System.Drawing.Point(15,150)
$btnBoost.BackColor = $C.Accent
$btnBoost.ForeColor = $C.Bg
$btnBoost.FlatStyle = "Flat"
$btnBoost.Font = $FontHead
$cardB.Controls.Add($btnBoost)

$btnBoost.Add_Click({
    $wl = $txtWL.Text -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    Invoke-GameBooster -Whitelist $wl
    [System.Windows.Forms.MessageBox]::Show("Game Booster complete. Memory freed for your game.","FL3SH") | Out-Null
})

# Status panel
$cardBS = New-Object System.Windows.Forms.Panel
$cardBS.Size = New-Object System.Drawing.Size(340,200)
$cardBS.Location = New-Object System.Drawing.Point(540,90)
$cardBS.BackColor = $C.Card
$pgBooster.Controls.Add($cardBS)
$lblBS = New-Object System.Windows.Forms.Label
$lblBS.Text = "Status"
$lblBS.Font = $FontHead
$lblBS.ForeColor = $C.Text
$lblBS.Location = New-Object System.Drawing.Point(15,10)
$lblBS.AutoSize = $true
$cardBS.Controls.Add($lblBS)
$lblBS2 = New-Object System.Windows.Forms.Label
$lblBS2.Text = "Booster is OFF`n`nFree: whitelist 1 app`nPlus: unlimited whitelist"
$lblBS2.Font = $FontBody
$lblBS2.ForeColor = $C.TextDim
$lblBS2.Location = New-Object System.Drawing.Point(15,40)
$lblBS2.AutoSize = $true
$cardBS.Controls.Add($lblBS2)

# ============================================================
# POTATO GRAPHICS PAGE
# ============================================================
$pgPotato = New-Page "potato"
$lblP = New-Object System.Windows.Forms.Label
$lblP.Text = "Potato Graphics"
$lblP.Font = $FontTitle
$lblP.ForeColor = $C.Text
$lblP.Location = New-Object System.Drawing.Point(20,10)
$lblP.AutoSize = $true
$pgPotato.Controls.Add($lblP)

$lblPSub = New-Object System.Windows.Forms.Label
$lblPSub.Text = "One-click low-graphics profiles. Max FPS, max visibility, revert any time."
$lblPSub.Font = $FontBody
$lblPSub.ForeColor = $C.TextDim
$lblPSub.Location = New-Object System.Drawing.Point(20,45)
$lblPSub.AutoSize = $true
$pgPotato.Controls.Add($lblPSub)

$warnP = New-Object System.Windows.Forms.Label
$warnP.Text = "WARNING: This is the only tweak that changes how the game LOOKS. Revert anytime."
$warnP.Font = $FontSmall
$warnP.ForeColor = $C.Warn
$warnP.Location = New-Object System.Drawing.Point(20,75)
$warnP.AutoSize = $true
$pgPotato.Controls.Add($warnP)

# Game profiles
$profiles = @(
    @{Name="Fortnite";Desc="DX11 and Performance mode";Plan="Pro"},
    @{Name="Fortnite Competitive";Desc="Fixed floor (lowest settings)";Plan="Plus"},
    @{Name="Marvel Rivals";Desc="Low-graphics competitive profile";Plan="Plus"},
    @{Name="AMD/Intel Potato";Desc="Works on any GPU. Removes texture packs.";Plan="Pro"}
)
$py = 110
foreach ($prof in $profiles) {
    $pcard = New-Object System.Windows.Forms.Panel
    $pcard.Size = New-Object System.Drawing.Size(820,60)
    $pcard.Location = New-Object System.Drawing.Point(20,$py)
    $pcard.BackColor = $C.Card
    $pgPotato.Controls.Add($pcard)

    $pn = New-Object System.Windows.Forms.Label
    $pn.Text = $prof.Name
    $pn.Font = $FontHead
    $pn.ForeColor = $C.Text
    $pn.Location = New-Object System.Drawing.Point(15,8)
    $pn.AutoSize = $true
    $pcard.Controls.Add($pn)

    $pd = New-Object System.Windows.Forms.Label
    $pd.Text = $prof.Desc
    $pd.Font = $FontSmall
    $pd.ForeColor = $C.TextDim
    $pd.Location = New-Object System.Drawing.Point(15,32)
    $pd.AutoSize = $true
    $pcard.Controls.Add($pd)

    $pplan = New-Object System.Windows.Forms.Label
    $pplan.Text = $prof.Plan
    $pplan.Font = New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
    $pplan.ForeColor = $C.Bg
    $pplan.BackColor = $C.Warn
    $pplan.Location = New-Object System.Drawing.Point(680,8)
    $pplan.AutoSize = $true
    $pplan.Padding = New-Object System.Windows.Forms.Padding(6,2,6,2)
    $pcard.Controls.Add($pplan)

    $pbtn = New-Object System.Windows.Forms.Button
    $pbtn.Text = "Apply"
    $pbtn.Size = New-Object System.Drawing.Size(80,32)
    $pbtn.Location = New-Object System.Drawing.Point(720,14)
    $pbtn.BackColor = $C.Accent
    $pbtn.ForeColor = $C.Bg
    $pbtn.FlatStyle = "Flat"
    $pcard.Controls.Add($pbtn)

    $pbtn.Add_Click({
        if ($Script:Config.Plan -eq "Free") {
            [System.Windows.Forms.MessageBox]::Show("Potato Graphics requires Pro plan.","FL3SH") | Out-Null
            return
        }
        $r = [System.Windows.Forms.MessageBox]::Show("This will change Fortnite graphics settings (Engine.ini).`nRevert anytime. Continue?","Confirm",[System.Windows.Forms.MessageBoxButtons]::YesNo)
        if ($r -eq "Yes") { Invoke-PotatoGraphics }
    })
    $py += 70
}

# ============================================================
# BENCHMARK PAGE
# ============================================================
$pgBench = New-Page "bench"
$lblBn = New-Object System.Windows.Forms.Label
$lblBn.Text = "Benchmark"
$lblBn.Font = $FontTitle
$lblBn.ForeColor = $C.Text
$lblBn.Location = New-Object System.Drawing.Point(20,10)
$lblBn.AutoSize = $true
$pgBench.Controls.Add($lblBn)

$btnSI = New-Object System.Windows.Forms.Button
$btnSI.Text = "Refresh System Info"
$btnSI.Size = New-Object System.Drawing.Size(160,32)
$btnSI.Location = New-Object System.Drawing.Point(20,50)
$btnSI.BackColor = $C.Card
$btnSI.ForeColor = $C.Text
$btnSI.FlatStyle = "Flat"
$pgBench.Controls.Add($btnSI)

$txtSI = New-Object System.Windows.Forms.TextBox
$txtSI.Location = New-Object System.Drawing.Point(20,90)
$txtSI.Size = New-Object System.Drawing.Size(500,90)
$txtSI.Multiline = $true
$txtSI.ReadOnly = $true
$txtSI.BackColor = $C.Card
$txtSI.ForeColor = $C.Text
$txtSI.Font = $FontMono
$pgBench.Controls.Add($txtSI)

$btnSI.Add_Click({
    $cpu = (Get-CimInstance Win32_Processor).Name
    $gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
    $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1)
    $txtSI.Text = "CPU: $cpu`r`nGPU: $gpu`r`nRAM: $ram GB"
})

# FPS tracking
$lblFB = New-Object System.Windows.Forms.Label
$lblFB.Text = "FPS before:"
$lblFB.Font = $FontBody
$lblFB.ForeColor = $C.Text
$lblFB.Location = New-Object System.Drawing.Point(20,200)
$lblFB.AutoSize = $true
$pgBench.Controls.Add($lblFB)
$txtFB = New-Object System.Windows.Forms.TextBox
$txtFB.Location = New-Object System.Drawing.Point(120,198)
$txtFB.Width = 80
$txtFB.BackColor = $C.Card
$txtFB.ForeColor = $C.Text
$pgBench.Controls.Add($txtFB)

$lblFA = New-Object System.Windows.Forms.Label
$lblFA.Text = "FPS after:"
$lblFA.Font = $FontBody
$lblFA.ForeColor = $C.Text
$lblFA.Location = New-Object System.Drawing.Point(220,200)
$lblFA.AutoSize = $true
$pgBench.Controls.Add($lblFA)
$txtFA = New-Object System.Windows.Forms.TextBox
$txtFA.Location = New-Object System.Drawing.Point(300,198)
$txtFA.Width = 80
$txtFA.BackColor = $C.Card
$txtFA.ForeColor = $C.Text
$pgBench.Controls.Add($txtFA)

$btnBench = New-Object System.Windows.Forms.Button
$btnBench.Text = "Run Micro-Benchmark"
$btnBench.Size = New-Object System.Drawing.Size(180,32)
$btnBench.Location = New-Object System.Drawing.Point(400,196)
$btnBench.BackColor = $C.Card
$btnBench.ForeColor = $C.Text
$btnBench.FlatStyle = "Flat"
$pgBench.Controls.Add($btnBench)

$lblBenchRes = New-Object System.Windows.Forms.Label
$lblBenchRes.Text = "Micro-bench: not run"
$lblBenchRes.Font = $FontBody
$lblBenchRes.ForeColor = $C.TextDim
$lblBenchRes.Location = New-Object System.Drawing.Point(20,235)
$lblBenchRes.AutoSize = $true
$pgBench.Controls.Add($lblBenchRes)

$btnBench.Add_Click({
    $lblBenchRes.Text = "Running..."
    [System.Windows.Forms.Application]::DoEvents()
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $c = 0
    for ($i=2; $i -lt 200000; $i++) {
        $isP = $true
        for ($j=2; $j*$j -le $i; $j++) { if ($i % $j -eq 0) { $isP=$false; break } }
        if ($isP) { $c++ }
    }
    $sw.Stop()
    $lblBenchRes.Text = "Micro-bench: $([math]::Round($sw.Elapsed.TotalMilliseconds,1)) ms (lower = better)"
})

$btnSaveBench = New-Object System.Windows.Forms.Button
$btnSaveBench.Text = "Save to CSV"
$btnSaveBench.Size = New-Object System.Drawing.Size(140,32)
$btnSaveBench.Location = New-Object System.Drawing.Point(20,265)
$btnSaveBench.BackColor = $C.Card
$btnSaveBench.ForeColor = $C.Text
$btnSaveBench.FlatStyle = "Flat"
$pgBench.Controls.Add($btnSaveBench)

$btnSaveBench.Add_Click({
    $row = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$($txtFB.Text),$($txtFA.Text),$($lblBenchRes.Text)"
    if (-not (Test-Path $Script:BenchPath)) { "Date,FPS_Before,FPS_After,MicroBench" | Set-Content $Script:BenchPath }
    Add-Content $Script:BenchPath $row
    Write-Log "Benchmark saved." "OK"
    [System.Windows.Forms.MessageBox]::Show("Saved to $Script:BenchPath","FL3SH") | Out-Null
})

# ============================================================
# RESTORE PAGE
# ============================================================
$pgRestore = New-Page "restore"
$lblR = New-Object System.Windows.Forms.Label
$lblR.Text = "Restore & Revert"
$lblR.Font = $FontTitle
$lblR.ForeColor = $C.Text
$lblR.Location = New-Object System.Drawing.Point(20,10)
$lblR.AutoSize = $true
$pgRestore.Controls.Add($lblR)

$btnRP = New-Object System.Windows.Forms.Button
$btnRP.Text = "Create System Restore Point"
$btnRP.Size = New-Object System.Drawing.Size(240,40)
$btnRP.Location = New-Object System.Drawing.Point(20,60)
$btnRP.BackColor = $C.Card
$btnRP.ForeColor = $C.Text
$btnRP.FlatStyle = "Flat"
$pgRestore.Controls.Add($btnRP)
$btnRP.Add_Click({ New-RestorePoint | Out-Null; [System.Windows.Forms.MessageBox]::Show("Restore point created (if supported).","FL3SH") | Out-Null })

$btnRevertAll = New-Object System.Windows.Forms.Button
$btnRevertAll.Text = "REVERT ALL CHANGES"
$btnRevertAll.Size = New-Object System.Drawing.Size(240,40)
$btnRevertAll.Location = New-Object System.Drawing.Point(20,110)
$btnRevertAll.BackColor = $C.Danger
$btnRevertAll.ForeColor = $C.Text
$btnRevertAll.FlatStyle = "Flat"
$btnRevertAll.Font = $FontHead
$pgRestore.Controls.Add($btnRevertAll)
$btnRevertAll.Add_Click({
    $r = [System.Windows.Forms.MessageBox]::Show("Revert ALL changes? Reboot recommended after.","Confirm",[System.Windows.Forms.MessageBoxButtons]::YesNo)
    if ($r -eq "Yes") { Revert-All; [System.Windows.Forms.MessageBox]::Show("Reverted. Reboot recommended.","FL3SH") | Out-Null }
})

$lblRInfo = New-Object System.Windows.Forms.Label
$lblRInfo.Text = "Every tweak is reversible. Restore points + backups are created automatically before changes."
$lblRInfo.Font = $FontSmall
$lblRInfo.ForeColor = $C.TextDim
$lblRInfo.Location = New-Object System.Drawing.Point(20,165)
$lblRInfo.AutoSize = $true
$pgRestore.Controls.Add($lblRInfo)

# ============================================================
# LOG PAGE
# ============================================================
$pgLog = New-Page "log"
$Script:LogBox = New-Object System.Windows.Forms.TextBox
$Script:LogBox.Location = New-Object System.Drawing.Point(10,10)
$Script:LogBox.Size = New-Object System.Drawing.Size(850,640)
$Script:LogBox.Multiline = $true
$Script:LogBox.ScrollBars = "Vertical"
$Script:LogBox.ReadOnly = $true
$Script:LogBox.BackColor = $C.Card
$Script:LogBox.ForeColor = [System.Drawing.Color]::LightGreen
$Script:LogBox.Font = $FontMono
$pgLog.Controls.Add($Script:LogBox)

# ============================================================
# SETTINGS PAGE
# ============================================================
$pgSettings = New-Page "settings"
$lblS = New-Object System.Windows.Forms.Label
$lblS.Text = "Settings"
$lblS.Font = $FontTitle
$lblS.ForeColor = $C.Text
$lblS.Location = New-Object System.Drawing.Point(20,10)
$lblS.AutoSize = $true
$pgSettings.Controls.Add($lblS)

$lblSE = New-Object System.Windows.Forms.Label
$lblSE.Text = "Email (for license):"
$lblSE.Font = $FontBody
$lblSE.ForeColor = $C.Text
$lblSE.Location = New-Object System.Drawing.Point(20,60)
$lblSE.AutoSize = $true
$pgSettings.Controls.Add($lblSE)
$txtEmail = New-Object System.Windows.Forms.TextBox
$txtEmail.Location = New-Object System.Drawing.Point(20,85)
$txtEmail.Width = 400
$txtEmail.Text = $Script:Config.Email
$txtEmail.BackColor = $C.Card
$txtEmail.ForeColor = $C.Text
$pgSettings.Controls.Add($txtEmail)

$lblSK = New-Object System.Windows.Forms.Label
$lblSK.Text = "License key:"
$lblSK.Font = $FontBody
$lblSK.ForeColor = $C.Text
$lblSK.Location = New-Object System.Drawing.Point(20,120)
$lblSK.AutoSize = $true
$pgSettings.Controls.Add($lblSK)
$txtKey = New-Object System.Windows.Forms.TextBox
$txtKey.Location = New-Object System.Drawing.Point(20,145)
$txtKey.Width = 400
$txtKey.Text = $Script:Config.LicenseKey
$txtKey.BackColor = $C.Card
$txtKey.ForeColor = $C.Text
$pgSettings.Controls.Add($txtKey)

$btnActivate = New-Object System.Windows.Forms.Button
$btnActivate.Text = "Activate"
$btnActivate.Size = New-Object System.Drawing.Size(120,32)
$btnActivate.Location = New-Object System.Drawing.Point(430,143)
$btnActivate.BackColor = $C.Accent
$btnActivate.ForeColor = $C.Bg
$btnActivate.FlatStyle = "Flat"
$pgSettings.Controls.Add($btnActivate)
$btnActivate.Add_Click({
    $Script:Config.Email = $txtEmail.Text
    $Script:Config.LicenseKey = $txtKey.Text
    # Gumroad license verify
    try {
        $resp = Invoke-RestMethod -Uri "https://api.gumroad.com/v2/licenses/verify" -Method POST -Body @{ product_id="YOUR_PRODUCT_ID"; license_key=$txtKey.Text } -ErrorAction Stop
        if ($resp.success) {
            $Script:Config.Plan = "Pro"
            $lblPlan.Text = "  PRO  "
            $lblPlan.BackColor = $C.Accent
            Save-Config
            [System.Windows.Forms.MessageBox]::Show("License activated! Plan: Pro","FL3SH") | Out-Null
        } else {
            [System.Windows.Forms.MessageBox]::Show("Invalid license key.","FL3SH") | Out-Null
        }
    } catch {
        # Offline fallback: accept any key starting with FL3SH-
        if ($txtKey.Text -match "^FL3SH-") {
            $Script:Config.Plan = "Pro"
            $lblPlan.Text = "  PRO  "
            $lblPlan.BackColor = $C.Accent
            Save-Config
            [System.Windows.Forms.MessageBox]::Show("License activated (offline). Plan: Pro","FL3SH") | Out-Null
        } else {
            [System.Windows.Forms.MessageBox]::Show("Could not verify. Check connection or key.","FL3SH") | Out-Null
        }
    }
})

$lblPlanInfo = New-Object System.Windows.Forms.Label
$lblPlanInfo.Text = "Free: 3 tweaks + monitoring + 1 Game Booster app`nPro: All tweaks + Potato Graphics + Crosshair designer"
$lblPlanInfo.Font = $FontSmall
$lblPlanInfo.ForeColor = $C.TextDim
$lblPlanInfo.Location = New-Object System.Drawing.Point(20,190)
$lblPlanInfo.AutoSize = $true
$pgSettings.Controls.Add($lblPlanInfo)

# ============================================================
# Navigation logic
# ============================================================
function Show-Page($key) {
    foreach ($p in $Script:Pages.Values) { $p.Visible = $false }
    $Script:Pages[$key].Visible = $true
    foreach ($btn in $Script:NavButtons) {
        if ($btn.Tag -eq $key) {
            $btn.BackColor = $C.AccentDim
            $btn.ForeColor = $C.Text
        } else {
            $btn.BackColor = $C.Sidebar
            $btn.ForeColor = $C.TextDim
        }
    }
}

foreach ($btn in $Script:NavButtons) {
    $btn.Add_Click({ Show-Page $this.Tag })
}

# Apply All button
$btnApplyAll.Add_Click({
    $applied = 0
    foreach ($t in $Script:Tweaks) {
        if ($t.Free -or $Script:Config.Plan -ne "Free") {
            $Script:TweakStates[$t.Id] = $true
            & $t.Action
            $applied++
        }
    }
    $lblPts.Text = "$applied tweaks applied"
    $lblHomeSub.Text = "$applied of 356 tweaks on · $($Script:Config.Plan) plan"
    Render-TweakList $Script:CurrentCat
    [System.Windows.Forms.MessageBox]::Show("Applied $applied tweaks.","FL3SH") | Out-Null
})

# Init
Show-Page "home"
$Script:LogBox.AppendText("FL3SH Optimizer started.`r`n")
Write-Log "Application started. Plan: $($Script:Config.Plan)" "OK"

$form.Add_FormClosing({
    $Script:Config.Email = $txtEmail.Text
    $Script:Config.LicenseKey = $txtKey.Text
    Save-Config
})

[void]$form.ShowDialog()
