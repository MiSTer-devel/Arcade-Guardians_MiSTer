param(
    [string]$BaselineCommit = '742927e918f18fd01efe76fbb1506b81c250c8ef'
)
$ErrorActionPreference = 'Stop'
$iverilog = if ($env:IVERILOG) { $env:IVERILOG } else { (Get-Command iverilog).Source }
$vvp = if ($env:VVP) { $env:VVP } else { (Get-Command vvp).Source }
$baselineLines = & git show "${BaselineCommit}:rtl/gd_dx101_video.sv"
if ($LASTEXITCODE -ne 0) { throw 'Cannot read baseline renderer from Git history' }
$fixtureDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('guardians-unit-compare-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $fixtureDirectory | Out-Null
$baselinePath = Join-Path $fixtureDirectory 'gd_dx101_video_reference.sv'
# Mechanical module-name substitution for a generated comparison fixture.
# The implementation remains the exact baseline Git blob.
$baselineText = ($baselineLines -join "`n").Replace('module gd_dx101_video', 'module gd_dx101_video_reference')
[System.IO.File]::WriteAllText($baselinePath, $baselineText)
$output = Join-Path $fixtureDirectory 'unit_compare.out'
& $iverilog -g2012 -s tb_gd_unit_cycle_compare -o $output `
    rtl/gd_dx101_video.sv $baselinePath sim/tb_gd_unit_cycle_compare.sv
if ($LASTEXITCODE -ne 0) { throw 'Unit-cycle comparison compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'Unit-cycle comparison failed' }
