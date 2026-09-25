# Arcade: Guardians / Denjin Makai II for MiSTer

Version 1.3.0 is a native FPGA implementation of
Winkysoft's 1995 arcade game,
licensed to Banpresto,
*Guardians / Denjin Makai II* for the MiSTer DE10-Nano platform.

The core loads an original `grdians.zip` set directly through its MRA. It does
not need a Linux helper, a preprocessing script, or modified ROM files. No
copyrighted game ROMs are included in this repository or its releases.

## Install

1. Copy `Arcade-Guardians.rbf` to `/media/fat/_Arcade/cores/`.
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
| Shot | X |
| Pause | Y |
| Start | Start |
| Coin | Select |
| Service | R |

Player 1 and Player 2 controls are supported. The core OSD also exposes the
game's DIP switches and a **Test / service mode** switch. The MRA's original
Service Mode DIP remains available as well. Directional input accepts both the
mapped D-pad and each player's left analog stick, with a signed dead zone.
The mappable **Pause** control freezes the CPU, board timers, and X1-010 sound
state while keeping the video raster and MiSTer OSD alive. Press Pause again
to resume exactly where the game stopped.

The **Scandoubler Fx** menu leaves the original 15-kHz analog RGB timing intact
when set to **None**. MiSTer's `forced_scandoubler=1` setting and the menu's
HQ2x/CRT choices produce 31-kHz output for computer CRTs and VGA displays. CRT
Geometry is automatically bypassed while one of these digital line effects or
forced scandoubling is active so the MiSTer scandoubler always receives the
native uniform pixel stream.

The **CRT Geometry** OSD page provides independent **H Size**, **H Shift**
(up to 32 pixels in either direction),
**V Size**, and **V Shift** controls, plus normal/180-degree rotation. All
geometry is disabled by default, so the native raster is unchanged unless the
option is explicitly enabled. Cabinet mode is the default and retains native
sync timing while using a photometric vertical resize for broad CRT
compatibility. The optional PVM mode retimes the line cadence for unique-line
vertical sizing and is intended only for monitors with a sufficiently wide
horizontal-lock range.
The vertical range is approximately +/-3.5%, deliberately kept within a useful
15-kHz adjustment envelope while fitting beside the core's full M10K usage.

**Turbo CPU (+50%)** raises the 68000-compatible CPU from 16.667 MHz to 25 MHz
to reduce computation-driven slowdown. Raster timing, hardware timers, video,
and X1-010 audio remain at PCB speed, so Turbo adds processing headroom rather
than globally fast-forwarding the game. Turbo is off by default.

The ordinary MiSTer OSD includes a standard **Cheats** menu populated from the
MRA's `<cheats>` block. It provides infinite credits and time plus per-player
lives, energy, power, invincibility, and an always-available special attack.
Every cheat is off by default. MiSTer downloads only the selected 16-byte codes
to a generic FPGA read-override engine, so disabling a cheat immediately
restores the underlying ROM or RAM value. No external cheat file, alternate
ROM, downloader, or helper script is required.

## Implemented hardware

- Toshiba TMP68301-compatible 68000 subsystem and interrupt/timer behavior
- NEC DX-101 / Allumer X1-020-compatible sprite and tile renderer
- Seta X1-010-compatible 16-voice PCM sound
- Direct MRA assembly of the 2 MiB program, 32 MiB graphics, and 1 MiB sample
  regions
- Eight-entry graphics-loader queue feeding four-word transactions with four
  standards-compliant SDRAM WRITE commands under one active row
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
- A 68.75-MHz internal renderer, open-page graphics DMA, and thirteen-line
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
quartus_sh --flow compile Arcade-Guardians
```

The v1.3.0 release build closes all analyzed setup, hold, recovery, and
removal timing classes; exact results are recorded in its GitHub release notes.

## Tests

The focused RTL test suite uses Icarus Verilog 11 or newer:

```powershell
./sim/run_unit_tests.ps1
```

Set `IVERILOG` and `VVP` to full executable paths if they are not on `PATH`.
The suite covers CRT geometry syntax, analog-stick conversion, video timing,
DDR access, registered
SDRAM DMA capture, four-command loader writes, graphics-stream packing,
MRA cheat-code syntax and big-endian CPU byte lanes, graphics arbitration,
DX-101 rendering, loading-screen
global zoom and fixed-position bypass, sprite-list
buffering, native raster/prefetch wrap, 9-bit sprite and floating-layer Y
wrapping, per-line rowscroll replay, circular object spans, raster look-ahead
gating, and TMP68301 behavior.
The raster tests also cover ordinary line matches, held-line re-entry, and
rejection of re-arm writes for future lines. Renderer checks also cover the
normal and 180-degree coordinate origins without altering native sync timing.

The game hardware path was verified on a DE10-Nano with the MRA and an
unmodified ROM set. Validation included a cold MRA boot, successful ROM
checksum and RAM-access self-tests, correct intro graphics after four-word
SDRAM loading, the correctly scaled stage-map/loading screen, and the Stage 1
post-explosion sequence. The replacement build adds the MRA cheat interface;
its loader, code matching, big-endian byte lanes, and MRA format are covered by
focused simulation and a clean full Quartus build.

The v1.3.0 fast-boot path differs from the original power-on sequence:
the FPGA clears work and auxiliary RAM before the 68000 starts, then supplies
the verified program checksum and skips the long destructive RAM exercise in
the streamed program image. The original ZIP and MRA CRC checks are unchanged.
The game still displays `ROM CHECK SUM..OK` and `RAM ACCESS..OK`, but these
labels no longer mean that the 68000 executed the full original test loops.
This patch is confined to startup; it is not a gameplay turbo mode. ROM
loading displays black, not the former diagnostic gradient. The v1.3.0 MRA
stages ROM #0 directly in MiSTer's DDR and replays it through the existing
loader; older streaming MRAs remain supported. The
core's graphics and game-data storage layout is unchanged. On the tested
MiSTer, remote launch-to-new-command-FIFO time fell from 22.3 seconds to 5.4-5.5
seconds; total first-screen time improved by roughly 17 seconds. This timing
is a local measurement, not a guaranteed transfer speed on every setup.

The DX-101 list copy now uses the CPU-side sprite-RAM port while the 68000 is
held. The renderer keeps its own read port and does not discard a scanline at
each copy. Native-resolution MiSTer captures verified the flame-kick intro
without the former horizontal bands, including the first striped frame and
the later full-screen fire. The history collector now excludes tilemap writes
from packed-list scroll replay. These captures do not establish exact
original-PCB sprite-overload behavior.

Sprite-list overflow is protected against corruption of the base-list headers.
Exact original-PCB sprite-overload behavior has not yet been established: the
FPGA renderer currently stages at most 128 visible descriptors per scanline,
and the available DX-101 reference does not specify a matching hardware limit.
This is not a claim of 1:1 overload or flicker behavior.

## Source and licensing

This repository intentionally contains only the buildable core, required MiSTer
framework files, focused tests, MRA, and documentation. Quartus databases,
captures, ROMs, diagnostic binaries, abandoned experiments, and local deployment
tools are excluded.

Core RTL is distributed under GPL-3.0-or-later. Bundled upstream components keep
their original notices and terms. See [`CREDITS.md`](CREDITS.md) and
[`UPSTREAM.md`](UPSTREAM.md) for exact source provenance, and [`LICENSE`](LICENSE).

## Repository and releases

The repository follows the MiSTer arcade-core layout: the repository and
Quartus project use the `Arcade-Guardians` name, while `releases/` contains the
dated `Arcade-Guardians_20260925.rbf` and its matching
`Guardians (Denjin Makai II).mra`. Distribution removes the `Arcade-` filename
prefix, so the MRA uses the stable `Guardians` identifier to find the core.
Build databases, game ROMs, local packages, and diagnostic artifacts are
deliberately excluded from version control.
