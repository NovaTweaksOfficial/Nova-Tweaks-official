param(
    [string]$Path = (Join-Path (Split-Path -Parent $PSScriptRoot) "Nova_Tweaks_WebGUI.ps1")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Path)) { throw "Script not found: $Path" }

$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path $Path).Path, [ref]$tokens, [ref]$parseErrors)

if ($parseErrors -and $parseErrors.Count -gt 0) {
    $parseErrors | Select-Object -First 10 | ForEach-Object {
        Write-Host "Parse error at line $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Red
    }
    throw "Cannot verify tweaks: the script does not parse."
}

# Hashtable values are PipelineAst/StatementAst nodes, so pull the nested
# constant or script block out of each value instead of reading .Value.
function Get-ConstantValue {
    param($Node)
    if ($null -eq $Node) { return $null }
    if ($Node -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
        return $Node.Value
    }
    $constant = $Node.Find({
        param($n)
        $n -is [System.Management.Automation.Language.StringConstantExpressionAst]
    }, $true) | Select-Object -First 1
    if ($constant) { return $constant.Value }
    return $null
}

function Get-ActionBody {
    param($Node)
    if ($null -eq $Node) { return $null }
    $scriptBlock = $Node.Find({
        param($n)
        $n -is [System.Management.Automation.Language.ScriptBlockExpressionAst]
    }, $true) | Select-Object -First 1
    if (-not $scriptBlock) { return $null }
    $text = $scriptBlock.ScriptBlock.Extent.Text.Trim()
    if ($text.StartsWith("{") -and $text.EndsWith("}")) {
        $text = $text.Substring(1, $text.Length - 2).Trim()
    }
    return $text
}

$assignment = $ast.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $node.Left.Extent.Text -eq '$Script:Tweaks'
}, $true) | Select-Object -First 1

if (-not $assignment) { throw "Could not find the `$Script:Tweaks array." }

$tweakTables = $assignment.Right.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.HashtableAst]
}, $true)

$definedFunctions = New-Object System.Collections.Generic.HashSet[string]
$ast.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
}, $true) | ForEach-Object { [void]$definedFunctions.Add($_.Name) }

$builtinVerbs = @(
    "Invoke-Expression", "Invoke-Command", "Invoke-Item", "Invoke-WebRequest",
    "Invoke-RestMethod", "Invoke-NovaApi"
)

$total = 0
$bad = New-Object System.Collections.Generic.List[string]
$ids = New-Object System.Collections.Generic.HashSet[string]
$missingOff = New-Object System.Collections.Generic.List[string]

foreach ($table in $tweakTables) {
    $id = $null
    $action = $null
    $hasOff = $false
    $name = $null
    $risk = $null
    $win = $null
    $mac = $null
    $cat = $null

    foreach ($pair in $table.KeyValuePairs) {
        $key = Get-ConstantValue $pair.Item1
        switch ($key) {
            "Id"     { $id = Get-ConstantValue $pair.Item2 }
            "Name"   { $name = Get-ConstantValue $pair.Item2 }
            "Risk"   { $risk = Get-ConstantValue $pair.Item2 }
            "Win"    { $win = $pair.Item2.Extent.Text.Trim() }
            "Mac"    { $mac = $pair.Item2.Extent.Text.Trim() }
            "Cat"    { $cat = Get-ConstantValue $pair.Item2 }
            "Action" { $action = Get-ActionBody $pair.Item2 }
            "Off"    { $hasOff = -not [string]::IsNullOrWhiteSpace((Get-ActionBody $pair.Item2)) }
        }
    }

    if (-not $id -or $null -eq $action) { continue }
    $total++

    if (-not $ids.Add([string]$id)) { $bad.Add("$id (duplicate id)") }
    if (-not $risk) { $bad.Add("$id (missing risk label)") }
    if (-not $cat) { $bad.Add("$id (missing category)") }
    if (($win -notmatch '\$true') -and ($mac -notmatch '\$true')) {
        $bad.Add("$id (no OS enabled)")
    }

    if ([string]::IsNullOrWhiteSpace($action)) {
        $bad.Add("$id (empty action)")
        continue
    }
    if ($action -match '^Write-Log\b') {
        $bad.Add("$id (log-only action)")
        continue
    }

    # Catch typo'd helper calls such as Invoke-NonexistentTweak.
    $invokeCalls = [regex]::Matches($action, '\bInvoke-[A-Za-z0-9_]+')
    foreach ($invokeCall in $invokeCalls) {
        $fn = $invokeCall.Value
        if ($builtinVerbs -contains $fn) { continue }
        if (-not $definedFunctions.Contains($fn)) {
            $bad.Add("$id (calls undefined function $fn)")
        }
    }

    # Informational: missing Off handler (non-fatal). Cleanups/one-way deletes are often intentional.
    $cleanupLike = ($id -match 'clear|cache|temp|crash|dump|log' -or ($name -and $name -match 'Clear|Cleanup|Delete|Remove cache|Purge'))
    if (-not $hasOff -and -not $cleanupLike) {
        $missingOff.Add("$id ($(if($name){$name}else{'unnamed'}))")
    }
}

if ($total -eq 0) { throw "No tweaks found. The array may have been renamed or broken." }

if ($bad.Count -gt 0) {
    Write-Host "Tweaks that are not shippable:" -ForegroundColor Red
    $bad | Sort-Object -Unique | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    throw "$($bad.Count) of $total tweaks failed the check."
}

Write-Host "Tweak check passed: $total tweaks, every action is implemented." -ForegroundColor Green
if ($missingOff.Count -gt 0) {
    Write-Host "Info: $($missingOff.Count) non-cleanup tweaks have no Off handler (restore-point/global revert still applies where implemented):" -ForegroundColor Yellow
    $missingOff | Select-Object -First 15 | ForEach-Object { Write-Host "  - $_" -ForegroundColor DarkYellow }
    if ($missingOff.Count -gt 15) { Write-Host "  ... and $($missingOff.Count - 15) more" -ForegroundColor DarkYellow }
}

$printable = New-Object System.Collections.Generic.List[string]
foreach ($table in $tweakTables) {
    foreach ($pair in $table.KeyValuePairs) {
        if ((Get-ConstantValue $pair.Item1) -eq "Id") {
            $value = Get-ConstantValue $pair.Item2
            if ($value) { $printable.Add($value) }
        }
    }
}
$printable | Sort-Object | ForEach-Object { Write-Host "  $_" }
