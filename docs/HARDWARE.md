# Guardians / Denjin Makai II hardware target

The original P-FG01-1 board is part of the newer Seta hardware family.

| Function | Device / mapping |
|---|---|
| Main CPU | Toshiba TMP68301 (68HC000 plus peripherals), 50 MHz / 3 |
| Video | NEC DX-101 / Allumer X1-020 sprite engine, 50 MHz |
| Sound | Seta X1-010, 16 voices, 50 MHz / 3 |
| Visible raster | 304 x 232; nominal 60 Hz in MAME |
| Program ROM | `000000-1fffff`, 2 MiB |
| Work RAM | `200000-20ffff`, 64 KiB |
| Auxiliary RAM | `304000-30ffff`, 48 KiB |
| Inputs | DIP at `600000`; players/system at `700000` |
| X1-010 registers | `b00000-b03fff` |
| Sprite RAM | `c00000-c3ffff`, 256 KiB |
| Palette RAM | `c40000-c4ffff`, xRGB555 |
| Extra palette RAM | `c50000-c5ffff` |
| Video registers | `c60000-c6003f` |
| Sample bank registers | `e00010-e0001f` |
| TMP68301 registers | reset location `fffc00-ffffff` |

## MiSTer memory plan

The uncompressed set is 35 MiB, larger than a standard 32 MiB SDRAM module.
The core therefore keeps the complete 32 MiB graphics bus in external SDRAM
and places the 2 MiB program plus 1 MiB X1-010 sample image in MiSTer's DDR3.
The additional 64 KiB palette window, which the game only clears, is writable
DDR3-backed storage. Independent 64-bit line caches hide DDR3 latency from the
68000, sound engine, and that window. Frequently accessed auxiliary tile RAM
remains in on-chip M10K memory. No Linux helper or preprocessing script is
required on the MiSTer; the MRA builds and downloads the layout directly from
`grdians.zip`.

TMP68301 timer 1 models the game's repeating 100 Hz level-4 interrupt setup
(`TCR1=1095`, `MAX1=28b0`, automatic vector `45`).
