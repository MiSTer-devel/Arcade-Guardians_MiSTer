# Arcade-Guardians MiSTer 1.4

Native MiSTer FPGA core for Winkysoft's 1995 arcade game
*Guardians / Denjin Makai II*, licensed to Banpresto.

User-tested build dated September 29, 2026. The official repository is
[MiSTer-devel/Arcade-Guardians_MiSTer](https://github.com/MiSTer-devel/Arcade-Guardians_MiSTer).

## Changes in 1.4

- Correct fractional loading-map zoom/phase and fixed-position border bypass
  without an additional per-tile renderer cycle.
- Apply the Stage 1 fire-background IRQ-62 change on the following row pair,
  correcting the visible background chunk boundary.
- Preserve buffered companion identity when live packed-list records are
  reused during the flame-kick transition, fixing its corrupt frame.
- Add complete map-draw, all-1,536-address seed and actual kick DMA/pixel
  regressions. No temporary diagnostic pixels are included.

The focused RTL suite passed. Normal-mode rendering matched v1.3.0 for
180,400 clocks and 40 completed rows. Native capture recorded 886 consecutive
intro frames without gaps; the corrupt kick color was absent and all 291
checked green-character frames matched the normal baseline exactly. A further
296-frame Stage 1 capture kept the HUD visible. The user confirmed the build
before release. Exact PCB sprite-overload behavior remains unverified.

Quartus Prime Lite 17.0 compilation completed with zero errors and positive
timing margins: +0.805 ns system setup, +0.277 ns HDMI setup, +0.245 ns minimum
hold, and zero reported total negative slack.

## Changes in 1.3.0

- Shortened startup with direct DDR ROM staging, 16-bit transfers, and FPGA RAM
  clearing. The game's displayed success messages no longer mean that the
  original full CPU self-test loops were executed; see `README.md` for details.
- Preserved completed video lines during display-list transfers and restricted
  scroll-history replay to the relevant packed display-list data.
- Expanded the private display-list capacity and guarded against sprite-list
  overflow. Exact original-board overload behavior remains unverified.
- Replaced the loading gradient with a black screen until the game starts.

See `CHANGELOG.md` for the complete version history and `README.md` for the
existing validation results and limitations.

## Current staged files

- `releases/Arcade-Guardians.rbf`
- `releases/Guardians (Denjin Makai II).mra`

The RBF is byte-for-byte identical to the user-tested
[v1.4 release](https://github.com/kandowontu2/Arcade-Guardians_MiSTer/releases/tag/v1.4),
SHA-256 `da1e85d386d8df0c822aae81006f39905b66fa7263d3165a64fc021a54b22de4`.
The release folder contains only this undated RBF/MRA pair. The ZIP installs
`_Arcade/cores/Guardians.rbf` and `_Arcade/Guardians (Denjin Makai II).mra`.
Older dated builds remain available in Git history. Both MRAs
retain the stable `Guardians` identifier, horizontal rotation and Shot button
label; project links point to the official repository. ROM assembly is unchanged.

Follow the file-copy instructions in `README.md`. `SHA256SUMS.txt` contains
current hashes with paths relative to the repository root. Game ROMs are not
included.

## Historical notes: 1.2.1 — September 6, 2026

The following highlights and exact timing/test results describe the earlier
1.2.1 release; they are not newly measured 1.3.0 results.

- Added a mappable controller Pause button, assigned to Y by default. Pause
  freezes the CPU, TMP68301 timers, and X1-010 playback state while retaining
  a live video raster and MiSTer OSD access.
- Expanded horizontal CRT positioning to a 32-pixel range so narrow analog
  displays can reveal and center the full picture.
- Made native-sync Cabinet vertical sizing the default for reliable CRT lock.
  Retimed PVM sizing remains available for monitors with a sufficiently wide
  horizontal-lock range and now emits the polarity expected by MiSTer's video
  pipeline.
- Confined Stage 1's heat/rowscroll effect to its floating background layer;
  foreground players, enemies, and objects no longer wobble over the affected
  region.
- Matched raster replay to the DX-101 private display list's rewritten packed
  descriptor pointer, fixing the post-effect upper-background truncation.
- Raised the renderer clock to 68.75 MHz, added graphics-row DMA, and expanded
  the completed-line reservoir for stable rowscroll-heavy scenes.
- Corrected MiSTer's video-stage alignment and scandoubler line-store stride
  for reliable HDMI and analog/scaler-backed output.
- Added optional horizontal/vertical size and position controls, PVM/cabinet
  vertical-sizing modes, 180-degree rotation, and a +50% CPU Turbo option.
- Moved all twelve cheats into the MRA's standard `<cheats>` block. MiSTer now
  supplies selected 16-byte codes to a generic FPGA read-override engine with
  68000 big-endian byte, word, and long-word handling.
- Accelerated direct MRA loading by packing four graphics words per handshake.
  The SDRAM controller issues four valid WRITE commands under one active row
  and auto-precharges only the final word.
- Implemented the DX-101's global half-scale mode for the stage-map/loading
  screen. The map and preview now match the original board composition while
  fixed-position gold frame graphics retain their native size.
- Removed the diagnostic loading grid. No Linux helper, downloader, external
  cheat file, modified ROM, or preprocessing script is required.
- Passed the focused RTL regression suite and a clean Quartus Prime Lite 17.0
  build with zero timing violations: +0.497 ns overall worst setup slack,
  +0.194 ns worst hold slack, +2.956 ns recovery slack, and +0.760 ns removal
  slack.
- The game path was verified on a DE10-Nano with a cold MRA boot: the original
  game reported ROM checksum and RAM access OK before displaying correctly
  decoded intro, loading-screen, and live-gameplay graphics. The replacement
  MRA cheat loader and matching engine add focused simulation coverage.
- Normalized the repository and Quartus project to the `Arcade-Guardians`
  layout. Version 1.4 again uses fixed-name release artifacts, with exactly
  one RBF and one MRA in `releases/`.

## Credits

- Core RTL, MiSTer integration, tests, and documentation: OpenAI Codex
- Hardware testing, direction, game validation, and release: kandowontu
- Original game: Winkysoft, under license to Banpresto
- Original P-FG01-1 board: its original engineers and hardware designers
- fx68k 68000-compatible core: Jorge Cwik
- MiSTer framework: Alexey Melnikov, Till Harbaum, Sorgelig, Ludvig Strigeus,
  Kitrinx, Mike Simone, Grabulosaure, bellwood420, and the wider MiSTer-devel
  community
- MAME hardware-documentation references: Luca Elia, David Haywood, Manbow-J,
  and Olivier Galibert
- Cheat address/value definitions: pasky13 via Pugsy's MAME Cheat Collection
- MRA cheat-engine model: Martin Donlon and Kitrinx; adapted for the Guardians
  68000 bus by OpenAI Codex

The modeled devices are the Toshiba TMP68301, NEC DX-101 / Allumer X1-020,
and Seta X1-010. Intel/Altera-generated PLL IP retains its generated notices.

See `CREDITS.md` for project, framework, processor-core, MAME
hardware-reference, original-game, cheat-reference, and FPGA-IP attribution.
