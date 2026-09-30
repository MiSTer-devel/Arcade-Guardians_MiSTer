param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+(\.\d+)?$')]
    [string]$Version,
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $projectRoot "dist/v$Version"
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$releasesPath = Join-Path $projectRoot 'releases'
$rbfPath = Join-Path $releasesPath 'Arcade-Guardians.rbf'
$mraPath = Join-Path $releasesPath 'Guardians (Denjin Makai II).mra'
$releaseFiles = @(Get-ChildItem -LiteralPath $releasesPath -File -Recurse)
if ($releaseFiles.Count -ne 2 -or
    -not (Test-Path -LiteralPath $rbfPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $mraPath -PathType Leaf)) {
    throw 'releases/ must contain exactly Arcade-Guardians.rbf and its matching undated MRA'
}
[xml]$mra = Get-Content -LiteralPath $mraPath -Raw
if ($mra.misterromdescription.rbf -ne 'Guardians') {
    throw 'The MRA must target the installed Guardians.rbf filename'
}

$zipName = "Arcade-Guardians_MiSTer_v$Version.zip"
$zipPath = Join-Path $OutputDirectory $zipName
$sumsPath = Join-Path $OutputDirectory 'SHA256SUMS.txt'
foreach ($targetPath in @($zipPath, $sumsPath)) {
    if (Test-Path -LiteralPath $targetPath) {
        throw "Refusing to overwrite an existing release artifact: $targetPath"
    }
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open(
    $zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive, $mraPath, '_Arcade/Guardians (Denjin Makai II).mra',
        [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive, $rbfPath, '_Arcade/cores/Guardians.rbf',
        [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
}
finally {
    $archive.Dispose()
}

$rbfHash = (Get-FileHash -LiteralPath $rbfPath -Algorithm SHA256).Hash.ToLowerInvariant()
$mraHash = (Get-FileHash -LiteralPath $mraPath -Algorithm SHA256).Hash.ToLowerInvariant()
$zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
$checksums = @(
    "$rbfHash  _Arcade/cores/Guardians.rbf",
    "$mraHash  _Arcade/Guardians (Denjin Makai II).mra",
    "$zipHash  $zipName"
)
[System.IO.File]::WriteAllText(
    $sumsPath, ($checksums -join "`n") + "`n", [System.Text.Encoding]::ASCII)
Write-Output "ZIP: $zipPath"
Write-Output "Checksums: $sumsPath"
Write-Output ($checksums -join "`n")
