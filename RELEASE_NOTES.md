# Guardians MiSTer 1.1.1

Renderer-performance, video-output, and Stage 1 raster-effect update for the
native MiSTer FPGA core for Winkysoft's *Guardians / Denjin Makai II*, licensed
to Banpresto.

Highlights:

- Confined Stage 1's heat/rowscroll effect to its floating background layer;
  foreground players, enemies, and objects no longer wobble over the affected
  region.
- Matched raster replay to the DX-101 private display list's rewritten packed
  descriptor pointer, fixing the post-effect upper-background truncation.
- Raised the renderer clock to 75 MHz, added open-page graphics DMA, and
  expanded the completed-line reservoir to thirteen logical rows for stable
  rowscroll-heavy scenes.
- Corrected MiSTer's video-stage alignment and scandoubler line-store stride
  for reliable HDMI and analog/scaler-backed output.
- Removed the diagnostic loading grid and retained the stable ROM loader.
- Passed the focused RTL regression suite and a clean Quartus Prime Lite 17.0
  build with zero timing violations and +1.211 ns worst setup slack.
- Verified the exact release RBF on a DE10-Nano with a cold MRA boot and the
  Stage 1 post-explosion gameplay sequence.

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

The modeled devices are the Toshiba TMP68301, NEC DX-101 / Allumer X1-020,
and Seta X1-010. Intel/Altera-generated PLL IP retains its generated notices.

Install the RBF and MRA using the paths documented in the README. ROM files are
not included. See `CREDITS.md` for project, framework, processor-core, MAME
hardware-reference, original-game, and FPGA-IP attribution.
