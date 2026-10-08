param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+(\.\d+)?$')]
    [string]$Version,
    [string]$OutputDirectory,
    [string]$BuildDirectory
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $projectRoot "dist/v$Version"
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$releasesPath = Join-Path $projectRoot 'releases'
$mraPath = Join-Path $releasesPath 'Guardians (Denjin Makai II).mra'
$releaseFiles = @(Get-ChildItem -LiteralPath $releasesPath -File -Recurse)
$releaseRbfs = @($releaseFiles | Where-Object {
    $_.DirectoryName -eq $releasesPath -and $_.Name -cmatch '^Arcade-Guardians_[0-9]{8}\.rbf$'
})
if ($releaseFiles.Count -ne 2 -or $releaseRbfs.Count -ne 1 -or
    -not (Test-Path -LiteralPath $mraPath -PathType Leaf)) {
    throw 'releases/ must contain exactly one Arcade-Guardians_YYYYMMDD.rbf and its matching undated MRA'
}
$rbfPath = $releaseRbfs[0].FullName
$buildDateText = $releaseRbfs[0].BaseName.Substring('Arcade-Guardians_'.Length)
$buildDate = [datetime]::MinValue
if (-not [datetime]::TryParseExact($buildDateText, 'yyyyMMdd',
    [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Globalization.DateTimeStyles]::None, [ref]$buildDate)) {
    throw 'The release RBF suffix must be a valid YYYYMMDD build date'
}
# MiSTer-devel distribution removes only Arcade-, retaining the build date.
$installedRbfName = $releaseRbfs[0].Name.Substring('Arcade-'.Length)
[xml]$mra = Get-Content -LiteralPath $mraPath -Raw
if ($mra.misterromdescription.rbf -cne 'Guardians') {
    throw 'The MRA must target Guardians, without the Arcade- prefix, date or extension'
}
if ($BuildDirectory) {
    $BuildDirectory = [System.IO.Path]::GetFullPath($BuildDirectory)
    $outputPath = Join-Path $BuildDirectory 'output_files'
    $settings = Get-Content -LiteralPath (Join-Path $BuildDirectory 'Arcade-Guardians.qsf') -Raw
    if ($settings -match 'GUARDIANS_SDRAM_|VERILOG_MACRO\s+"?(?!SYNTHESIS=1)[A-Z_]+=') {
        throw 'Production release must not contain private test macros'
    }
    $fit = Get-Content -LiteralPath (Join-Path $outputPath 'Arcade-Guardians.fit.summary') -Raw
    $buildLog = Get-Content -LiteralPath (Join-Path $outputPath 'production-build.log') -Raw
    if ($fit -notmatch 'Successful' -or $buildLog -notmatch 'Full Compilation was successful' -or
        $buildLog -match '(?m)^Error') { throw 'Production compilation/fitting failed' }
    $timing = Get-Content -LiteralPath (Join-Path $outputPath 'Arcade-Guardians.sta.summary') -Raw
    if ($timing -notmatch 'Slack\s*:' -or $timing -match 'Slack\s*:\s*-') { throw 'Production internal timing failed' }
    $audit = Get-Content -LiteralPath (Join-Path $outputPath 'sdram-f0-audit.log') -Raw
    if ($audit -notmatch 'PASS: sixteen fixed F0 input captures' -or $audit -match '(?m)^Error') {
        throw 'Production F0 fitted audit failed'
    }
    $conversion = Get-Content -LiteralPath (Join-Path $outputPath 'sdram-f0-convert.log') -Raw
    if ($conversion -notmatch 'successful' -or $conversion -notmatch 'bitstream_compression=on') {
        throw 'Standard compressed export not verified'
    }
    $fitDateText = [regex]::Match($fit, '(?m)^Fitter Status : Successful - (.+)$').Groups[1].Value.Trim()
    $fitDate = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($fitDateText, 'ddd MMM dd HH:mm:ss yyyy',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None, [ref]$fitDate) -or
        $fitDate.Date -ne $buildDate.Date) {
        throw 'The dated release filename must match the fitted build date'
    }
    $assembled = Join-Path $outputPath 'Arcade-Guardians.rbf'
    $converted = Join-Path $outputPath 'Guardians.rbf'
    $releaseHash = (Get-FileHash -LiteralPath $rbfPath).Hash
    if ($releaseHash -ne (Get-FileHash -LiteralPath $assembled).Hash -or
        $releaseHash -ne (Get-FileHash -LiteralPath $converted).Hash) {
        throw 'Release RBF must equal the standard assembler and compressed CPF output'
    }
    foreach ($sourceFile in @('Arcade-Guardians.sv', 'Arcade-Guardians.qsf', 'files.qip') +
        @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'rtl') -Recurse -File |
            Where-Object { $_.Extension -in '.sv', '.v', '.qip' } |
            ForEach-Object { $_.FullName.Substring($projectRoot.Length + 1) })) {
        if ((Get-FileHash -LiteralPath (Join-Path $projectRoot $sourceFile)).Hash -ne
            (Get-FileHash -LiteralPath (Join-Path $BuildDirectory $sourceFile)).Hash) {
            throw "Fitted source differs from current source: $sourceFile"
        }
    }
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
        $archive, $rbfPath, "_Arcade/cores/$installedRbfName",
        [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
}
finally {
    $archive.Dispose()
}

$rbfHash = (Get-FileHash -LiteralPath $rbfPath -Algorithm SHA256).Hash.ToLowerInvariant()
$mraHash = (Get-FileHash -LiteralPath $mraPath -Algorithm SHA256).Hash.ToLowerInvariant()
$zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
$checksums = @(
    "$rbfHash  _Arcade/cores/$installedRbfName",
    "$mraHash  _Arcade/Guardians (Denjin Makai II).mra",
    "$zipHash  $zipName"
)
[System.IO.File]::WriteAllText(
    $sumsPath, ($checksums -join "`n") + "`n", [System.Text.Encoding]::ASCII)
Write-Output "ZIP: $zipPath"
Write-Output "Checksums: $sumsPath"
Write-Output ($checksums -join "`n")
