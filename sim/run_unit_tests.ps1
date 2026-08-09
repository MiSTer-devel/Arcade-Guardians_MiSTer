$ErrorActionPreference = 'Stop'
$iverilog = if ($env:IVERILOG) {
    $env:IVERILOG
} else {
    (Get-Command iverilog -ErrorAction Stop).Source
}
$vvp = if ($env:VVP) {
    $env:VVP
} else {
    (Get-Command vvp -ErrorAction Stop).Source
}
$output = Join-Path $PSScriptRoot 'ddr_memory.out'
& $iverilog -g2012 -s tb_gd_ddr_memory -o $output rtl/gd_ddr_memory.sv sim/tb_gd_ddr_memory.sv
if ($LASTEXITCODE -ne 0) { throw 'DDR memory unit-test compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'DDR memory unit test failed' }

$output = Join-Path $PSScriptRoot 'video_timing.out'
& $iverilog -g2012 -s tb_gd_video_timing -o $output rtl/gd_video_timing.sv sim/tb_gd_video_timing.sv
if ($LASTEXITCODE -ne 0) { throw 'Video timing unit-test compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'Video timing unit test failed' }

$output = Join-Path $PSScriptRoot 'gfx_arbiter.out'
& $iverilog -g2012 -s tb_gd_gfx_arbiter -o $output rtl/gd_gfx_arbiter.sv sim/tb_gd_gfx_arbiter.sv
if ($LASTEXITCODE -ne 0) { throw 'Graphics arbiter unit-test compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'Graphics arbiter unit test failed' }

$output = Join-Path $PSScriptRoot 'sdram_dma.out'
& $iverilog -g2012 -s tb_gd_sdram_dma -o $output rtl/gd_sdram.sv sim/tb_gd_sdram_dma.sv
if ($LASTEXITCODE -ne 0) { throw 'SDRAM DMA unit-test compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'SDRAM DMA unit test failed' }

$output = Join-Path $PSScriptRoot 'dx101_video.out'
& $iverilog -g2012 -s tb_gd_dx101_video -o $output rtl/gd_dx101_video.sv sim/tb_gd_dx101_video.sv
if ($LASTEXITCODE -ne 0) { throw 'DX-101 video unit-test compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'DX-101 video unit test failed' }

$output = Join-Path $PSScriptRoot 'sprite_ram.out'
& $iverilog -g2012 -s tb_gd_sprite_ram -o $output rtl/gd_sprite_ram.sv sim/tb_gd_sprite_ram.sv
if ($LASTEXITCODE -ne 0) { throw 'Sprite RAM unit-test compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'Sprite RAM unit test failed' }

$output = Join-Path $PSScriptRoot 'tmp68301.out'
& $iverilog -g2012 -s tb_gd_tmp68301 -o $output rtl/gd_tmp68301.sv sim/tb_gd_tmp68301.sv
if ($LASTEXITCODE -ne 0) { throw 'TMP68301 unit-test compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'TMP68301 unit test failed' }
