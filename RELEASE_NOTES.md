# Guardians MiSTer 1.1

Hardware-fidelity and stability update for the native MiSTer FPGA core for
Winkysoft's *Guardians / Denjin Makai II*, licensed to Banpresto.

Highlights:

- Restored the intro firewall's per-line raster distortion by replaying the
  game's completed DX-101 rowscroll writes and correctly re-arming held-line
  raster interrupts.
- Restored missing top background chunks with the DX-101's 9-bit vertical
  coordinate ring for sprites and floating tilemap windows.
- Replaced synthetic MAME raster dimensions with the game's programmed
  410x258 timing while retaining MiSTer's HDMI, analog RGB, scandoubler, and
  video-effect paths.
- Added D-pad-priority left-analog-stick movement for both players.
- Hardened SDRAM graphics capture with registered input data.
- Passed the focused RTL regression suite and a clean Quartus Prime Lite 17.0
  build with positive setup and hold slack.
- Verified the final release RBF on a DE10-Nano through the included MRA,
  including the Banpresto logo, firewall sequence, scrolling gameplay,
  controls, and audio.

Install the RBF and MRA using the paths documented in the README. ROM files are
not included. See `CREDITS.md` for project, framework, processor-core, MAME
hardware-reference, original-game, and FPGA-IP attribution.
