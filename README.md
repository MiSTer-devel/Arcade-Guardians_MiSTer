# Guardians / Denjin Makai II for MiSTer

Version 1.0 is a native FPGA implementation of Banpresto's 1995 arcade game
*Guardians / Denjin Makai II* for the MiSTer DE10-Nano platform.

The core loads an original `grdians.zip` set directly through its MRA. It does
not need a Linux helper, a preprocessing script, or modified ROM files. No
copyrighted game ROMs are included in this repository or its releases.

## Install

1. Copy `Guardians_20260809.rbf` to `/media/fat/_Arcade/cores/`.
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
Service Mode DIP remains available as well.

## Implemented hardware

- Toshiba TMP68301-compatible 68000 subsystem and interrupt/timer behavior
- NEC DX-101 / Allumer X1-020-compatible sprite and tile renderer
- Seta X1-010-compatible 16-voice PCM sound
- Direct MRA assembly of the 2 MiB program, 32 MiB graphics, and 1 MiB sample
  regions
- Original 304 x 232 raster at approximately 60 Hz
- MiSTer scaler, HDMI, analog video, audio, controller, DIP, reset, and OSD
  integration
- Atomic DX-101 display-list buffering with bounded descriptor traversal

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

The final 1.0 build closes timing. The core clock has +2.999 ns setup slack and
+0.243 ns hold slack; all reported timing domains have non-negative slack.

## Tests

The focused RTL test suite uses Icarus Verilog 11 or newer:

```powershell
./sim/run_unit_tests.ps1
```

Set `IVERILOG` and `VVP` to full executable paths if they are not on `PATH`.
The suite covers video timing, DDR access, SDRAM DMA, graphics arbitration,
DX-101 rendering, sprite-list buffering, and TMP68301 behavior.

The 1.0 candidate was also verified on a DE10-Nano with the release MRA and an
unmodified ROM set. Long-run validation covered two complete attract-mode
gameplay sequences without the previous descriptor collapse, stripe corruption,
or raster loss.

## Source and licensing

This repository intentionally contains only the buildable core, required MiSTer
framework files, focused tests, MRA, and documentation. Quartus databases,
captures, ROMs, diagnostic binaries, abandoned experiments, and local deployment
tools are excluded.

Core RTL is distributed under GPL-3.0-or-later. Bundled upstream components keep
their original notices and terms. See [`CREDITS.md`](CREDITS.md) and
[`LICENSE`](LICENSE).
