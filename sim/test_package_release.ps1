param([string]$BuildDirectory = '')

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$distRoot = Join-Path $projectRoot 'dist'
$fixtureRoot = Join-Path $distRoot ("package-release-tests-" + [guid]::NewGuid().ToString('N'))
$sourceRbf = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'releases') -Filter '*.rbf')
if ($sourceRbf.Count -ne 1) { throw 'Test requires exactly one production RBF' }
$sourceMra = Join-Path $projectRoot 'releases/Guardians (Denjin Makai II).mra'
$packageScript = Join-Path $projectRoot 'scripts/package_release.ps1'
$reports = 0

function New-Fixture([string]$Name) {
    $root = Join-Path $fixtureRoot $Name
    New-Item -ItemType Directory -Path (Join-Path $root 'scripts'), (Join-Path $root 'releases') | Out-Null
    Copy-Item -LiteralPath $packageScript -Destination (Join-Path $root 'scripts/package_release.ps1')
    Copy-Item -LiteralPath $sourceRbf[0].FullName, $sourceMra -Destination (Join-Path $root 'releases')
    return $root
}

function Expect-Rejected([string]$Root, [string]$Reason, [string]$FittedBuild = '') {
    $caught = $false
    try {
        & (Join-Path $Root 'scripts/package_release.ps1') -Version 1.4.1 `
            -OutputDirectory (Join-Path $Root 'output') -BuildDirectory $FittedBuild | Out-Null
    }
    catch {
        if ($_.Exception.Message -notlike "*$Reason*") { throw }
        $caught = $true
    }
    if (-not $caught) { throw "Expected rejection: $Reason" }
    if (Test-Path -LiteralPath (Join-Path $Root 'output')) {
        throw 'Invalid release created an output directory'
    }
    $script:reports++
    Write-Output "PASS: rejected $Reason"
}

try {
    $valid = New-Fixture 'valid'
    $output = Join-Path $valid 'output'
    & (Join-Path $valid 'scripts/package_release.ps1') -Version 1.4.1 -OutputDirectory $output | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipPath = Join-Path $output 'Arcade-Guardians_MiSTer_v1.4.1.zip'
    $archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $expected = @{
            "_Arcade/cores/$($sourceRbf[0].Name.Substring('Arcade-'.Length))" = $sourceRbf[0].FullName
            '_Arcade/Guardians (Denjin Makai II).mra' = $sourceMra
        }
        if ($archive.Entries.Count -ne 2) { throw 'ZIP must contain exactly two files' }
        $manifest = Get-Content -LiteralPath (Join-Path $output 'SHA256SUMS.txt')
        foreach ($entry in $archive.Entries) {
            if (-not $expected.ContainsKey($entry.FullName)) { throw "Unexpected ZIP entry: $($entry.FullName)" }
            $stream = $entry.Open()
            $hasher = [System.Security.Cryptography.SHA256]::Create()
            try { $hash = ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
            finally { $stream.Dispose(); $hasher.Dispose() }
            if ($hash -ne (Get-FileHash -LiteralPath $expected[$entry.FullName]).Hash.ToLowerInvariant()) {
                throw "ZIP bytes changed: $($entry.FullName)"
            }
            if ($manifest -cnotcontains "$hash  $($entry.FullName)") { throw 'ZIP entry checksum missing' }
        }
    }
    finally { $archive.Dispose() }
    $reports++
    Write-Output 'PASS: dated installation layout, unchanged RBF/MRA bytes and ZIP-entry checksums'

    $zipHashBefore = (Get-FileHash -LiteralPath $zipPath).Hash
    if ($manifest -cnotcontains "$($zipHashBefore.ToLowerInvariant())  Arcade-Guardians_MiSTer_v1.4.1.zip") {
        throw 'ZIP archive checksum missing'
    }
    $overwriteRejected = $false
    try {
        & (Join-Path $valid 'scripts/package_release.ps1') -Version 1.4.1 -OutputDirectory $output | Out-Null
    }
    catch {
        if ($_.Exception.Message -notlike '*Refusing to overwrite*') { throw }
        $overwriteRejected = $true
    }
    if (-not $overwriteRejected -or (Get-FileHash -LiteralPath $zipPath).Hash -ne $zipHashBefore) {
        throw 'Existing installation ZIP was not preserved'
    }
    $reports++
    Write-Output 'PASS: preserves existing ZIPs'

    $undated = New-Fixture 'undated'
    Rename-Item -LiteralPath (Join-Path $undated "releases/$($sourceRbf[0].Name)") -NewName 'Arcade-Guardians.rbf'
    Expect-Rejected $undated 'exactly one Arcade-Guardians_YYYYMMDD.rbf'

    $invalidDate = New-Fixture 'invalid-date'
    Rename-Item -LiteralPath (Join-Path $invalidDate "releases/$($sourceRbf[0].Name)") -NewName 'Arcade-Guardians_20261332.rbf'
    Expect-Rejected $invalidDate 'valid YYYYMMDD build date'

    $duplicate = New-Fixture 'duplicate'
    Copy-Item -LiteralPath $sourceRbf[0].FullName -Destination (Join-Path $duplicate 'releases/Arcade-Guardians_20000101.rbf')
    Expect-Rejected $duplicate 'exactly one Arcade-Guardians_YYYYMMDD.rbf'

    $extra = New-Fixture 'extra'
    Copy-Item -LiteralPath $sourceMra -Destination (Join-Path $extra 'releases/extra.mra')
    Expect-Rejected $extra 'exactly one Arcade-Guardians_YYYYMMDD.rbf'

    foreach ($target in @('Arcade-Guardians', 'Guardians_20261005', 'Guardians.rbf')) {
        $badMra = New-Fixture "target-$target"
        $mraPath = Join-Path $badMra 'releases/Guardians (Denjin Makai II).mra'
        [xml]$xml = Get-Content -LiteralPath $mraPath -Raw
        $xml.misterromdescription.rbf = $target
        $xml.Save($mraPath)
        Expect-Rejected $badMra 'MRA must target Guardians'
    }

    if ($BuildDirectory) {
        $wrongBuildDate = New-Fixture 'wrong-build-date'
        Rename-Item -LiteralPath (Join-Path $wrongBuildDate "releases/$($sourceRbf[0].Name)") -NewName 'Arcade-Guardians_20000101.rbf'
        Expect-Rejected $wrongBuildDate 'filename must match the fitted build date' $BuildDirectory
    }
    Write-Output "PASS: $reports release-packaging reports"
}
finally {
    # Delete only this test's unique fixture directory within the repository's dist/.
    $safeRoot = [System.IO.Path]::GetFullPath($fixtureRoot)
    $safePrefix = [System.IO.Path]::GetFullPath($distRoot) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $safeRoot.StartsWith($safePrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path $safeRoot -Leaf) -notmatch '^package-release-tests-[a-f0-9]{32}$') {
        throw 'Refusing cleanup outside the unique test fixture directory'
    }
    if (Test-Path -LiteralPath $safeRoot) { Remove-Item -LiteralPath $safeRoot -Recurse -Force }
}
