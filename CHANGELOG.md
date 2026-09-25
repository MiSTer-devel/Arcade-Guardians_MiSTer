# Changelog

## 1.3.0 - 2026-09-25

- Restricted raster-scroll history to the DX-101 packed display-list range.
  Tilemap RAM writes during the flame-kick IRQ sequence no longer displace
  live scroll words or pollute the next frame's history. Verified the first
  striped kick frame and later full-screen fire frames with consecutive
  native-resolution MiSTer captures; removed temporary pixel probes.
- Raised the DX-101 private display-list limit from 32 to 128 headers. The
  attract demo can author 40 groups; the old forced end marker omitted its
  late full-screen overlay and made the top HUD disappear under load. Added
  40-header copy and scanout regressions and verified the previously blank
  79.65-second demo frame on MiSTer.
- Added a direct-to-DDR MRA staging path, adapted from Martin Donlon's PGM
  loader design. After MiSTer deposits ROM #0 at `0x30000000`, the FPGA reads
  it back in 64-bit words and feeds the existing program/graphics/sample
  loader. MRAs without direct DDR staging still use the original stream.
- Enabled MiSTer's 16-bit file-transfer mode. A back-pressured adapter feeds
  both bytes, in order, into the established byte-oriented ROM loader; DIP
  and MRA-cheat downloads now consume wide words directly. This targets the
  measured ~40-second `SENDING ROM #0` phase without changing the ROM ZIP.
- Replaced the old loading gradient/telemetry path with a black screen until
  the game CPU begins fetching program ROM.
- Shortened post-transfer startup by substituting the known-good program
  checksum result and skipping the 68000's exhaustive power-on RAM loop.
  The FPGA clears the same work/auxiliary RAM areas before releasing the CPU,
  including on soft reset. The supplied ROM ZIP stays unmodified, and the
  program's additive checksum remains unchanged through a tail-word correction.
- Moved the DX-101 list-copy reads onto the CPU-side sprite-RAM port while the
  68000 is held, leaving the renderer's read port available continuously.
  Removed the renderer's per-copy scanline abort and added a port-isolation
  regression for uninterrupted scanout during list transfers.
- Constrained frozen rowscroll replay to descriptors whose tilemap page and
  tile size still match, so a reused packed slot cannot inherit the prior
  scene's page. Added renderer and cold/warm RAM-scrub tests.
- Buffered eight complete eight-byte graphics blocks between the MiSTer ROM
  stream and SDRAM writes. Host back-pressure now occurs only when that queue
  fills, instead of after every block. The existing board-tested SDRAM write
  sequence and fixed `Arcade-Guardians.rbf` filename remain in use.
- Bound DX-101 packed sprite-list writes to the modeled 0x3000-byte
  destination and ignore saturated pointers during rendering, preventing a
  descriptor overload from overwriting source headers. Added overflow
  regressions; the original PCB's per-scanline sprite limit is still unknown.

## 1.2.1 - 2026-09-06

- Moved all twelve optional cheats from fixed `CONF_STR` status bits into the
  MRA's standard `<cheats>` block and replaced the game-specific work-RAM
  clamps with a generic MiSTer 16-byte read-override engine.
- Added 68000 big-endian byte/word/long-word handling, compare codes and
  replace/OR/AND methods, with focused engine and MRA-format regressions.
- Standardized distribution artifacts on the fixed filenames
  `Arcade-Guardians.rbf` and `Guardians (Denjin Makai II).mra`.

- Added a mappable Pause controller button. Pause freezes the CPU, TMP68301
  timers, and X1-010 playback state while preserving live video and OSD access.
- Expanded horizontal CRT positioning from an 8-pixel range to a 32-pixel
  range so narrow analog displays can expose the full left edge.
- Made the native-sync Cabinet vertical-size path the default for reliable CRT
  lock and retained retimed PVM mode as an explicit wide-lock-monitor option.
  Corrected the PVM generator to emit the positive sync pulses required by
  MiSTer's arcade video pipeline.
- Renamed the Quartus project and release core to `Arcade-Guardians`, added a
  standard `releases/` directory, and documented pinned upstream provenance for
  MiSTer-devel review.

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
