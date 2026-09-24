# Arcade-Guardians MiSTer 1.2.1 - validation checklist

Extract the archive directly to the root of the MiSTer SD card. It installs:

- `_Arcade/Guardians (Denjin Makai II).mra`
- `_Arcade/cores/Arcade-Guardians.rbf`

Place a legally obtained, unmodified `grdians.zip` at
`games/mame/grdians.zip`. No ROM files are included in this archive.

Please test the following areas:

1. Time the MRA launch and confirm that no gradient/test grid appears while the
   ROM is sent; the development fast-boot build should show black until the
   game begins drawing. Measure the interval after transfer completes as well
   as the total launch time.
2. Confirm the game's startup self-check reports `ROM CHECK SUM..OK` and
   `RAM ACCESS..OK`. In the development fast-boot build, these are supplied
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
7. Watch the intro, map/loading screens, and Stage 1 after the explosion. The
   heat distortion should affect its intended background layer without
   wobbling players, enemies, foreground objects, or truncating the image.
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
