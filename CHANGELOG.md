# Changelog

## 1.2.0 - 2026-08-24

- Added an optional 25 MHz Turbo CPU mode (+50%) for extra gameplay processing
  headroom. Native raster cadence, TMP68301 timer timebases, and X1-010 audio
  timing remain at PCB speed; Turbo is disabled by default.
- Added independent horizontal size, horizontal shift, vertical size, and
  vertical shift controls for analog CRT alignment, with PVM and cabinet
  vertical-sizing modes. The native output is unchanged when CRT Geometry is
  off. Vertical sizing spans approximately +/-3.5%, a practical 15-kHz CRT
  range that avoids consuming the game core's fully allocated M10Ks.
- Added selectable normal and 180-degree rendering while retaining the native
  board raster and synchronization.
- Adapted the GPLv3 CRT output stages from rmonic79's MiSTer-CRT-Adjust, using
  Guardians' native RGB555 format internally to preserve colors while fitting
  the DE10-Nano memory budget.
- Made CRT Geometry a literal native-video bypass when disabled and
  automatically bypassed it for MiSTer's Scandoubler Fx modes and forced
  scandoubling. This keeps the scandoubler/HQ2x input uniformly clocked and
  prevents the displayed frame from freezing when an effect is selected.
- Added three standard MiSTer OSD cheat pages with twelve independently
  selectable work-RAM cheats: infinite credits/time and per-player lives,
  energy, power, invincibility, and special attack. All cheats default off and
  require no external file or helper.
- Reduced graphics-ROM loader handshakes by packing four 16-bit words per
  request. The SDRAM controller issues a real WRITE command for every word
  under one active row, preserving single-location write-mode correctness and
  auto-precharging only the final word.
- Added focused regressions for the full cheat address/byte-lane map, graphics
  byte packing, consecutive SDRAM write commands, column progression, and
  final-word auto-precharge.
- Implemented the DX-101 global half-scale X/Y mode used by the stage map and
  loading screen. Non-fixed map and preview layers now render at the board's
  programmed 1:2 scale while fixed-position frame graphics remain native size.
- Added focused loading-screen regressions for the global source-line step,
  horizontal pixel-pair scaling, sprite visibility, and fixed-header bypass.
- Verified the accelerated loader on a DE10-Nano with a cold MRA launch: the
  original game reported both ROM checksum and RAM access OK, then displayed
  correctly decoded intro graphics without the former diagnostic grid. The
  final build also passed loading-screen, intro, and live-gameplay validation.

## 1.1.1 - 2026-08-23

- Raised the internal system/renderer clock from 62.5 to 68.75 MHz while
  preserving the board's exact 6.25 MHz pixel clock with a divide-by-eleven
  enable. Retuned the CPU and X1-010 phase accumulators so game and audio speed
  remain unchanged.
- Added an open-page graphics DMA path. Consecutive graphics cache misses in
  the same SDRAM row now avoid redundant precharge/activate cycles while row
  changes, refreshes, and loader traffic retain explicit timing-safe handling.
- Expanded the completed-line reservoir from three rows ahead to the twelve-row
  hardware maximum without adding M10K blocks. Invisible vertical-blank rows
  bypass sprite-list rendering so the queue refills before active video.
- Routed blanking, sync, and RGB through MiSTer's standard `arcade_video`
  alignment stage and corrected the internal scandoubler line-store stride.
  This fixes scaler-backed analog-output slice displacement.
- Removed the diagnostic grid from normal ROM loading and retained the proven
  single-word SDRAM loader after an experimental write burst caused a
  post-download startup stall.
- Matched raster replay against the rewritten packed descriptor pointer used
  by the DX-101 private display list. Already-rendered non-floating actor
  pixels are protected from the late rowscrolled background plane, fixing the
  Stage 1 foreground heat leakage and post-effect background truncation.
- Added focused regressions for the faster renderer, open-page graphics DMA,
  deeper line reservoir, native video alignment, and packed-descriptor raster
  targeting. A captured Stage 1 trace confirms the packed target is exercised
  throughout the effect.

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
