# Arcade-Guardians MiSTer 1.3.0

Native MiSTer FPGA core for Winkysoft's 1995 arcade game
*Guardians / Denjin Makai II*, licensed to Banpresto.

Released September 25, 2026. The official repository is
[MiSTer-devel/Arcade-Guardians_MiSTer](https://github.com/MiSTer-devel/Arcade-Guardians_MiSTer).

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

- `releases/Arcade-Guardians_20260925.rbf`
- `releases/Guardians (Denjin Makai II).mra`

The repository's pending metadata and packaging corrections retain the original
1.3.0 binary contents. Both MRAs now identify the game as horizontal, label the
third gameplay action Shot, and link to the official repository. These changes
do not constitute a new core build or hardware test.

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
  layout. That release used fixed-name artifacts, superseded by the dated
  filename listed above.

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
