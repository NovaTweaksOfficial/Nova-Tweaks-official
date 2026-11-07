#requires -Version 5.1
<#
.SYNOPSIS
  Issue Nova Tweaks gift codes and Pro/Ultimate license keys.

.DESCRIPTION
  Uses the same offline HMAC scheme as Nova_Tweaks_WebGUI.ps1. Gift codes add
  balance to an account. License keys add 30 days of Pro or Ultimate when the
  buyer pastes them into Account -> License key.

  The secrets below match the app defaults. If you change them in
  Nova_Tweaks_WebGUI.ps1, change them here too (or pass -GiftSecret /
  -LicenseSecret). This is offline validation, not a server-backed license:
  anyone who reads the public source can extract the secret.

.EXAMPLE
  ./tools/New-NovaKey.ps1 -Type Gift -Amount 15

.EXAMPLE
  ./tools/New-NovaKey.ps1 -Type Ultimate -Count 5

.EXAMPLE
  ./tools/New-NovaKey.ps1 -Type Pro -Count 10 | Out-File keys.txt
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Gift', 'Pro', 'Ultimate')]
    [string]$Type,

    # Gift value in whole dollars.
    [ValidateRange(1, 1000)]
    [int]$Amount = 5,

    # How many codes to print.
    [ValidateRange(1, 500)]
    [int]$Count = 1,

    # Keep in sync with Nova_Tweaks_WebGUI.ps1.
    [string]$GiftSecret = 'NovaTweaks-Gift-S3cr3t-2026-ChangeMe',
    [string]$LicenseSecret = 'NovaTweaks-License-S3cr3t-2026-ChangeMe'
)

$ErrorActionPreference = 'Stop'

function Get-NovaSignature {
    param(
        [Parameter(Mandatory = $true)][string]$Secret,
        [Parameter(Mandatory = $true)][string]$Data
    )
    $hmac = [System.Security.Cryptography.HMACSHA256]::new(
        [System.Text.Encoding]::UTF8.GetBytes($Secret)
    )
    try {
        $bytes = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Data))
        return ([System.BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant().Substring(0, 10)
    } finally {
        $hmac.Dispose()
    }
}

function New-NovaNonce {
    return [System.Guid]::NewGuid().ToString('N').Substring(0, 8).ToUpperInvariant()
}

# The app stores an absolute day index (days since 2024-01-01 UTC), not a duration.
$now = [int]((Get-Date).ToUniversalTime() - [datetime]'2024-01-01').TotalDays

for ($i = 0; $i -lt $Count; $i++) {
    $nonce = New-NovaNonce

    if ($Type -eq 'Gift') {
        $cents = [int]($Amount * 100)
        $sig = Get-NovaSignature -Secret $GiftSecret -Data "$cents`:$nonce"
        "NOVA-GIFT-$cents-$nonce-$sig"
    } else {
        $kind = if ($Type -eq 'Ultimate') { 'ULT' } else { 'PRO' }
        $sig = Get-NovaSignature -Secret $LicenseSecret -Data "$kind`:$now`:$nonce"
        "NOVA-$kind-$now-$nonce-$sig"
    }
}
