# Guardians / Denjin Makai II hardware target

The original P-FG01-1 board is part of the newer Seta hardware family.

| Function | Device / mapping |
|---|---|
| Main CPU | Toshiba TMP68301 (68HC000 plus peripherals), 50 MHz / 3 |
| Video | NEC DX-101 / Allumer X1-020 sprite engine, 50 MHz |
| Sound | Seta X1-010, 16 voices, 50 MHz / 3 |
| CRT raster | 410 x 258 total; 304 x 232 visible; 6.25 MHz dot clock |
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

## Video timing and MAME differences

Guardians writes the DX-101 timing registers as horizontal
`002e/0059/0188/019a` and vertical `0003/0014/00fe/0102`. With the video
device's 50 MHz input divided by eight, these values produce approximately
15.244 kHz horizontal and 59.085 Hz vertical timing. MAME currently substitutes
a 512x256 raster at exactly 60 Hz; this FPGA core uses the board-programmed
timing so native analog RGB has the original porch and sync geometry.

MAME also describes the DX-101 register `0x26` list copy/reformat as guesswork.
The FPGA implementation performs a bus-master list transaction: it snapshots
the base headers, packs the referenced descriptors into private sprite RAM,
rewrites their pointers, and holds the 68000 until the transaction finishes.
Copy reads use the CPU-side sprite-RAM port, keeping the renderer's video port
available so a copy does not abort an in-progress scanline. This behavior was
derived from Guardians' live list updates and long-run hardware observation
rather than copied from MAME's transform.

The private header table supports 128 groups. A raw Guardians attract-mode
display list reached 40 groups; an earlier 32-group limit synthesized a false
end marker before the late full-screen overlay, coinciding with complete HUD
dropout while actors and background continued. The 128-group table fits in
logic without another M10K and leaves ample margin over the observed peak.

The renderer implements the color-depth modes actually observed in Guardians
(modes 4 and 5), opaque objects, local/global sizes, floating tilemaps, flips,
and the game's positive-X/negative-Y global transforms. A 60-second register
trace did not observe the DX-101 shadow flag; speculative behavior used only by
other games on the device is intentionally not claimed as implemented.

Guardians also uses raster interrupts to rewrite a packed floating-tilemap
scroll descriptor every two scanlines during background effects. A renderer
that prepares a row before the interrupt handler completes sees a stale scroll
word. The FPGA line queue therefore disables speculative look-ahead while
raster mode is enabled. It also records the final address/data pair for each
even raster position, freezes that history at vertical blank, and replays it
for the corresponding even/odd line pair during the next frame. This preserves
line-scroll effects without racing CPU writes against the video scanner. All
line tags, prefetch positions, queue ages, and vertical wrap operations use the
complete 410x258 raster rather than the older synthetic 512x256 model.

The initial line-zero handler also programs line zero again, briefly disables
the raster timer, and re-enables it. Because the programmed line is still
current, the DX-101 source remains active and the TMP68301 queues another
service after the current handler returns. That second service selects line two
and begins the even-line sequence. MAME models this with a guessed `+0x100`
horizontal timer on its synthetic 512-pixel raster; carrying that delay into
the board's 410-pixel raster makes the chain late or absent. Omitting held-line
re-entry leaves the fire wall and later row-scrolled backgrounds stuck on the
first scroll value.

DX-101 horizontal positions form a signed 10-bit circular coordinate space,
while vertical positions use a 9-bit ring for normal sprites and floating
tilemap windows alike. Guardians makes this observable in gameplay: a floating
background chunk at `0x1f9` is followed by one at `0x039`, exactly 64 lines
later modulo `0x200`. Using a 10-bit vertical interpretation rejects the first
chunk and leaves the upper background black. Visibility and row selection use
the 9-bit vertical ring, while horizontal window traversal retains its 10-bit
wrap.

## Graphics SDRAM interface

The complete 32 MiB graphics region occupies the primary MiSTer SDRAM. A
burst-of-four fetch supplies one eight-byte planar tile row. External DQ is
first sampled into sixteen fixed input registers packed into the Cyclone V I/O
cells, then copied into the selected burst word. This keeps the sample point
independent of internal routing and improves compatibility with different
32/64/128 MiB and dual-SDRAM installations; a second physical module is not
otherwise required or accessed by the core.
