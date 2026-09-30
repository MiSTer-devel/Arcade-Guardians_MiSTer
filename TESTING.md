# Arcade-Guardians MiSTer 1.4 - validation checklist

The MiSTer-devel installation uses:

- `_Arcade/Guardians (Denjin Makai II).mra`
- `_Arcade/cores/Guardians.rbf`

For a manual installation, copy `releases/Arcade-Guardians.rbf` under
that distribution filename. Keep `<rbf>Guardians</rbf>` in the upstream MRA.
The release ZIP already has the correct folder layout and undated filenames.

Place a legally obtained, unmodified `grdians.zip` at
`games/mame/grdians.zip`. No ROM files are included in this archive.

Please test the following areas:

1. Time the MRA launch and confirm that no gradient/test grid appears while the
   ROM is sent; the fast-boot path should show black until the
   game begins drawing. Measure the interval after transfer completes as well
   as the total launch time.
2. Confirm the game's startup self-check reports `ROM CHECK SUM..OK` and
   `RAM ACCESS..OK`. In the fast-boot path, these are supplied
   success results after MRA validation and FPGA RAM clearing, not the full
   original CPU self-test loops.
3. After the startup self-check completes, open the MiSTer OSD's **Cheats**
   menu. Cheats default to Off. Try each option independently, then disable it
   and confirm normal behavior resumes.
4. Exercise Start, Coin, Service, both players, and analog-stick directions.
5. Check native output, forced scandoubling, HQ2x/scanline effects, and any
   analog video chain available to you. Scandoubler effects must not freeze.
6. Check horizontal/vertical size and position, PVM/cabinet sizing, and
   180-degree rotation. Geometry Off must retain native timing.
7. Watch all three intro segments, including the green character and flame
   kick. There should be no repeated/stretched rows or isolated corrupted
   kick frame. Check that the map preview stays inside its fixed border. In
   Stage 1 after the explosion, the background chunk boundary near native row
   62 must not cut a line short. Heat distortion should affect its intended
   background layer without wobbling actors or truncating the image.
8. Try Turbo CPU both Off and On. Video cadence and audio pitch should remain
   unchanged.
9. Map Pause in the MiSTer controller menu and confirm that it freezes game
   logic and sound while leaving the video raster and OSD responsive. Press it
   again to resume.
10. Let the attract-mode demo play through busy combat. Health bars, avatars,
    scores and hit counters must stay visible while characters and the
    background continue drawing.

When reporting a problem, include the display connection (HDMI/direct analog,
scaler/scandoubler settings), MiSTer.ini video options, SDRAM module, controller,
the exact scene, and a short video or screenshot when possible.

Release hashes are recorded in `SHA256SUMS.txt`.

## Recorded v1.4 validation

- Full focused simulation suite passed, including all 1,536 buffered seed
  addresses and actual kick DMA/descriptor/pixel output.
- Normal-mode baseline comparison: 180,400 identical clocks, 40 completed rows.
- Quartus 17.0: zero errors; +0.805 ns system setup, +0.277 ns HDMI setup,
  +0.245 ns minimum hold, and zero reported total negative slack.
- Intro: 886 consecutive native frames, zero counter gaps, no diagnostic
  markers, and no pixels in the previously corrupt kick color. All 291
  checked green-character frames matched the normal baseline exactly.
- Stage 1 fire: 296 consecutive native frames, zero counter gaps, HUD retained,
  and no diagnostic strip. User confirmation preceded publication.
- RBF SHA-256:
  `da1e85d386d8df0c822aae81006f39905b66fa7263d3165a64fc021a54b22de4`.
