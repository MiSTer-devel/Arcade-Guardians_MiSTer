# Changelog

## Unreleased

## 1.1.0 - 2026-08-22

- Implemented the DX-101 raster timer's held-line re-arm. Guardians disables
  and re-enables raster IRQ line zero during the handler; the still-current
  source queues a second service after the handler returns. This replaces the
  MAME driver's guessed `+0x100`-pixel timer, which does not translate to the
  board-programmed 410-pixel raster, and starts the game's two-line scroll
  chain in time.
- Added a double-buffered raster rowscroll history. The scanline renderer now
  replays the final packed-descriptor scroll write for each even/odd line pair
  instead of preparing the row before the CPU interrupt handler has changed
  it. This restores the intro fire distortion and in-game line-scroll effects.
- Corrected DX-101 vertical coordinates to a 9-bit ring for both normal
  sprites and floating tilemap windows while retaining 10-bit horizontal
  coordinates. Guardians chains background chunks across `0x1f9 -> 0x039`;
  treating floating Y as 10-bit discarded the wrapped first chunk and left
  the top of gameplay backgrounds black.
- Replaced MAME's synthetic 512x256/60-Hz raster with the DX-101 timing
  programmed by Guardians: 410x258 total, 304x232 visible, and a 6.25-MHz dot
  clock (approximately 15.244 kHz / 59.085 Hz).
- Added MiSTer's standard video mixer, gamma path, `forced_scandoubler`
  support, and OSD HQ2x/CRT effects while retaining native 15-kHz RGB by
  default.
- Added left-analog-stick directional control for both players with a dead
  zone and digital D-pad priority.
- Registered SDRAM DQ in fixed FPGA I/O-cell flip-flops before distributing
  burst words, hardening graphics reads across different SDRAM modules.
- Corrected the DX-101 line renderer's remaining synthetic-raster constants so
  prefetch, line tags, queue ages, and wraparound all use the board's 410x258
  geometry end to end.
- Made background rendering raster-aware. Live descriptors are scanned only
  one row ahead, while completed per-line scroll writes are frozen at vertical
  blank and replayed by descriptor address during the next frame.
- Implemented signed circular span tests for 10-bit horizontal coordinates
  and the separate 9-bit vertical ring.
- Added focused tests for analog input, raster rowscroll history, and the
  registered SDRAM burst stage.
- Added DX-101 regressions for native line/prefetch wrap, raster look-ahead
  gating, and signed coordinate-ring crossings.
- Corrected original game credit to Winkysoft under Banpresto license.

## 1.0.0 - 2026-08-09

- Initial public release.
- Added direct, script-free MRA loading from an unmodified `grdians.zip` set.
- Implemented the TMP68301-compatible CPU subsystem, DX-101-compatible video,
  X1-010-compatible PCM audio, player controls, DIP switches, and service mode.
- Added SDRAM graphics streaming and DDR3-backed program/sample storage.
- Fixed registered descriptor-read latency, DX-101 register `0x26` display-list
  packing, atomic list-buffer transactions, and startup list termination.
- Fixed intermittent stripes, missing sprite segments, clipped frame regions,
  and delayed display-list collapse observed during long hardware runs.
- Added focused RTL tests and reproducible Quartus 17.0 project files.
