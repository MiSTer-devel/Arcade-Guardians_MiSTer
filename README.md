# Guardians / Denjin Makai II for MiSTer

Version 1.1.1 is a native FPGA implementation of Winkysoft's 1995 arcade game,
licensed to Banpresto,
*Guardians / Denjin Makai II* for the MiSTer DE10-Nano platform.

The core loads an original `grdians.zip` set directly through its MRA. It does
not need a Linux helper, a preprocessing script, or modified ROM files. No
copyrighted game ROMs are included in this repository or its releases.

## Install

1. Copy `Guardians_20260823.rbf` to `/media/fat/_Arcade/cores/`.
2. Copy `Guardians (Denjin Makai II).mra` to `/media/fat/_Arcade/`.
3. Put a legally obtained, unmodified `grdians.zip` in
   `/media/fat/games/mame/`.
4. Launch **Guardians / Denjin Makai II** from MiSTer's Arcade menu.

The MRA identifies every required ROM by filename and CRC. MiSTer will report a
missing or mismatched file instead of silently loading an incompatible set.

## Controls and service mode

The default mappings are:

| Game control | MiSTer default |
|---|---|
| Attack | A |
| Jump | B |
| Special | X |
| Start | Start |
| Coin | Select |
| Service | R |

Player 1 and Player 2 controls are supported. The core OSD also exposes the
game's DIP switches and a **Test / service mode** switch. The MRA's original
Service Mode DIP remains available as well. Directional input accepts both the
mapped D-pad and each player's left analog stick, with a signed dead zone.

The **Scandoubler Fx** menu leaves the original 15-kHz analog RGB timing intact
when set to **None**. MiSTer's `forced_scandoubler=1` setting and the menu's
HQ2x/CRT choices produce 31-kHz output for computer CRTs and VGA displays.

## Implemented hardware

- Toshiba TMP68301-compatible 68000 subsystem and interrupt/timer behavior
- NEC DX-101 / Allumer X1-020-compatible sprite and tile renderer
- Seta X1-010-compatible 16-voice PCM sound
- Direct MRA assembly of the 2 MiB program, 32 MiB graphics, and 1 MiB sample
  regions
- Board-programmed 410 x 258 raster with 304 x 232 visible pixels
  (15.244 kHz horizontal, 59.085 Hz vertical)
- MiSTer scaler, HDMI, analog video, audio, controller, DIP, reset, and OSD
  integration
- Atomic DX-101 display-list buffering with bounded descriptor traversal
- Raster-aware DX-101 background rendering with per-line packed-scroll replay,
  a 9-bit vertical coordinate ring for normal sprites and floating layers, and
  10-bit horizontal wrapping
- Held-line DX-101 raster-IRQ re-arming for the game's two-line rowscroll
  effects on the native 410-pixel raster
- A 75-MHz internal renderer, open-page graphics DMA, and thirteen-line
  completion reservoir for stable rowscroll-heavy scenes
- Packed-descriptor raster targeting that confines the Stage 1 heat effect to
  its floating background layer without distorting foreground actors

The memory design places the 32 MiB graphics bus in MiSTer's SDRAM and keeps
program ROM, samples, and selected writable storage in DDR3. See
[`docs/HARDWARE.md`](docs/HARDWARE.md) for the board map and implementation
notes.

## Build

The release was built with Quartus Prime Lite 17.0 for the Cyclone V
`5CSEBA6U23I7`:

```powershell
quartus_sh --flow compile Guardians
```

The 1.1.1 build closes timing with zero violated setup paths; its worst reported
setup slack is +1.211 ns.

## Tests

The focused RTL test suite uses Icarus Verilog 11 or newer:

```powershell
./sim/run_unit_tests.ps1
```

Set `IVERILOG` and `VVP` to full executable paths if they are not on `PATH`.
The suite covers analog-stick conversion, video timing, DDR access, registered
SDRAM DMA capture, graphics arbitration, DX-101 rendering, sprite-list
buffering, native raster/prefetch wrap, 9-bit sprite and floating-layer Y
wrapping, per-line rowscroll replay, circular object spans, raster look-ahead
gating, and TMP68301 behavior.
The raster tests also cover ordinary line matches, held-line re-entry, and
rejection of re-arm writes for future lines.

The 1.1.1 release was verified on a DE10-Nano with the release MRA and an
unmodified ROM set. Hardware validation included a cold MRA boot and the Stage
1 post-explosion sequence; the final build preserves the rowscrolled background
effect without distorting foreground actors or truncating the upper background.

## Source and licensing

This repository intentionally contains only the buildable core, required MiSTer
framework files, focused tests, MRA, and documentation. Quartus databases,
captures, ROMs, diagnostic binaries, abandoned experiments, and local deployment
tools are excluded.

Core RTL is distributed under GPL-3.0-or-later. Bundled upstream components keep
their original notices and terms. See [`CREDITS.md`](CREDITS.md) and
[`LICENSE`](LICENSE).
