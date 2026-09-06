$ErrorActionPreference = 'Stop'

$mraPath = Join-Path $PSScriptRoot '..\mra\Guardians (Denjin Makai II).mra'
[xml]$mra = Get-Content -LiteralPath $mraPath -Raw
$cheats = @($mra.misterromdescription.cheats.cheat)

$rbfName = [string]$mra.misterromdescription.rbf
if ($rbfName -ne 'Arcade-Guardians') {
    throw "MRA references '$rbfName'; expected fixed core name 'Arcade-Guardians'"
}

$expected = [ordered]@{
    'Infinite Credits'    = 1
    'Infinite Time'       = 1
    'P1 Infinite Lives'   = 1
    'P1 Infinite Energy'  = 2
    'P1 Infinite Power'   = 2
    'P1 Invincibility'    = 1
    'P1 Always Special'   = 1
    'P2 Infinite Lives'   = 1
    'P2 Infinite Energy'  = 2
    'P2 Infinite Power'   = 2
    'P2 Invincibility'    = 1
    'P2 Always Special'   = 1
}

if ($cheats.Count -ne $expected.Count) {
    throw "Expected $($expected.Count) MRA cheats, found $($cheats.Count)"
}

foreach ($cheat in $cheats) {
    $name = [string]$cheat.name
    if (-not $expected.Contains($name)) { throw "Unexpected MRA cheat '$name'" }

    $codes = @(([string]$cheat.InnerText -split '\r?\n') |
        ForEach-Object { ($_ -replace '\s', '').Trim() } |
        Where-Object { $_ })
    if ($codes.Count -ne $expected[$name]) {
        throw "Cheat '$name' has $($codes.Count) codes; expected $($expected[$name])"
    }
    foreach ($code in $codes) {
        if ($code -notmatch '^[0-9A-Fa-f]{32}$') {
            throw "Cheat '$name' contains a malformed 16-byte code: $code"
        }
    }
}

Write-Output "PASS MRA targets Arcade-Guardians and contains $($cheats.Count) named cheats and 16 valid codes"
