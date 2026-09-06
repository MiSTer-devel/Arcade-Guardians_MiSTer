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

$output = Join-Path $PSScriptRoot 'crt_vsize_compile.out'
& $iverilog -g2012 -s crt_vsize -o $output rtl/crt_vsize.sv
if ($LASTEXITCODE -ne 0) { throw 'CRT vertical geometry compilation failed' }

$output = Join-Path $PSScriptRoot 'crt_adjust_compile.out'
& $iverilog -g2012 -s crt_adjust -o $output rtl/crt_adjust.sv
if ($LASTEXITCODE -ne 0) { throw 'CRT horizontal geometry compilation failed' }

$output = Join-Path $PSScriptRoot 'pause_toggle.out'
& $iverilog -g2012 -s tb_gd_pause_toggle -o $output rtl/gd_pause_toggle.sv sim/tb_gd_pause_toggle.sv
if ($LASTEXITCODE -ne 0) { throw 'Pause unit-test compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'Pause unit test failed' }

$output = Join-Path $PSScriptRoot 'analog_to_digital.out'
& $iverilog -g2012 -s tb_gd_analog_to_digital -o $output rtl/gd_analog_to_digital.sv sim/tb_gd_analog_to_digital.sv
if ($LASTEXITCODE -ne 0) { throw 'Analog input unit-test compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'Analog input unit test failed' }

$output = Join-Path $PSScriptRoot 'ddr_memory.out'
& $iverilog -g2012 -s tb_gd_ddr_memory -o $output rtl/gd_ddr_memory.sv sim/tb_gd_ddr_memory.sv
if ($LASTEXITCODE -ne 0) { throw 'DDR memory unit-test compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'DDR memory unit test failed' }

$output = Join-Path $PSScriptRoot 'mra_cheat_engine.out'
& $iverilog -g2012 -s tb_gd_mra_cheat_engine -o $output rtl/gd_mra_cheat_engine.sv sim/tb_gd_mra_cheat_engine.sv
if ($LASTEXITCODE -ne 0) { throw 'MRA cheat-engine unit-test compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'MRA cheat-engine unit test failed' }

& (Join-Path $PSScriptRoot 'check_mra_cheats.ps1')
if ($LASTEXITCODE -ne 0) { throw 'MRA cheat-definition check failed' }

$output = Join-Path $PSScriptRoot 'video_timing.out'
& $iverilog -g2012 -s tb_gd_video_timing -o $output rtl/gd_video_timing.sv sim/tb_gd_video_timing.sv
if ($LASTEXITCODE -ne 0) { throw 'Video timing unit-test compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'Video timing unit test failed' }

$output = Join-Path $PSScriptRoot 'raster_irq.out'
& $iverilog -g2012 -s tb_gd_raster_irq -o $output rtl/gd_raster_irq.sv sim/tb_gd_raster_irq.sv
if ($LASTEXITCODE -ne 0) { throw 'Raster IRQ unit-test compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'Raster IRQ unit test failed' }

$output = Join-Path $PSScriptRoot 'rowscroll_history.out'
& $iverilog -g2012 -s tb_gd_rowscroll_history -o $output rtl/gd_rowscroll_history.sv sim/tb_gd_rowscroll_history.sv
if ($LASTEXITCODE -ne 0) { throw 'Rowscroll history unit-test compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'Rowscroll history unit test failed' }

$output = Join-Path $PSScriptRoot 'gfx_arbiter.out'
& $iverilog -g2012 -s tb_gd_gfx_arbiter -o $output rtl/gd_gfx_arbiter.sv sim/tb_gd_gfx_arbiter.sv
if ($LASTEXITCODE -ne 0) { throw 'Graphics arbiter unit-test compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'Graphics arbiter unit test failed' }

$output = Join-Path $PSScriptRoot 'rom_loader.out'
& $iverilog -g2012 -s tb_gd_rom_loader -o $output rtl/gd_rom_loader.sv sim/tb_gd_rom_loader.sv
if ($LASTEXITCODE -ne 0) { throw 'ROM loader unit-test compilation failed' }
& $vvp $output
if ($LASTEXITCODE -ne 0) { throw 'ROM loader unit test failed' }

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
