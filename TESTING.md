# Guardians MiSTer 1.2 - validation checklist

Extract the archive directly to the root of the MiSTer SD card. It installs:

- `_Arcade/Guardians - Denjin Makai II (P-FG01-1 PCB).mra`
- `_Arcade/cores/Guardians_20260824.rbf`

Place a legally obtained, unmodified `grdians.zip` at
`games/mame/grdians.zip`. No ROM files are included in this archive.

Please test the following areas:

1. Time the MRA launch and confirm that no gradient/test grid appears while the
   ROM is sent.
2. Confirm the game's startup self-check reports `ROM CHECK SUM..OK` and
   `RAM ACCESS..OK`.
3. Open the MiSTer OSD and check the General, Player 1, and Player 2 cheat
   pages. Cheats default to Off. Try each option independently.
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

When reporting a problem, include the display connection (HDMI/direct analog,
scaler/scandoubler settings), MiSTer.ini video options, SDRAM module, controller,
the exact scene, and a short video or screenshot when possible.

Release RBF SHA-256:

`fc239d4881134f726097e73f0f6cd8564c941c9d9588238964f8e2791dca6876`
