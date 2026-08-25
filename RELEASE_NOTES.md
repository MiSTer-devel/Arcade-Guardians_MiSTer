# Guardians MiSTer 1.2

Native MiSTer FPGA core for Winkysoft's 1995 arcade game
*Guardians / Denjin Makai II*, licensed to Banpresto.

Highlights:

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
- Added three standard MiSTer OSD cheat pages. General cheats provide infinite
  credits and time; Player 1 and Player 2 each have independently selectable
  lives, energy, power, invincibility, and always-special options.
- Accelerated direct MRA loading by packing four graphics words per handshake.
  The SDRAM controller issues four valid WRITE commands under one active row
  and auto-precharges only the final word.
- Implemented the DX-101's global half-scale mode for the stage-map/loading
  screen. The map and preview now match the original board composition while
  fixed-position gold frame graphics retain their native size.
- Removed the diagnostic loading grid. No Linux helper, downloader, external
  cheat file, modified ROM, or preprocessing script is required.
- Passed the focused RTL regression suite and a clean Quartus Prime Lite 17.0
  build with zero timing violations and +0.845 ns worst setup slack.
- Verified the exact release RBF on a DE10-Nano with a cold MRA boot. The
  original game reported ROM checksum and RAM access OK before displaying
  correctly decoded intro, loading-screen, and live-gameplay graphics.

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

The modeled devices are the Toshiba TMP68301, NEC DX-101 / Allumer X1-020,
and Seta X1-010. Intel/Altera-generated PLL IP retains its generated notices.

Extract the archive directly to the root of a MiSTer SD card. ROM files are not
included. See `CREDITS.md` for project, framework, processor-core, MAME
hardware-reference, original-game, cheat-reference, and FPGA-IP attribution.
