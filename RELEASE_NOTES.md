# Guardians MiSTer 1.0

First public release of the native MiSTer FPGA core for Banpresto's
*Guardians / Denjin Makai II*.

Highlights:

- Direct loading from an original `grdians.zip` through the included MRA
- TMP68301-compatible CPU subsystem, DX-101 video, and X1-010 PCM audio
- Player 1/2 controls, coin/start/service inputs, DIP switches, and test mode
- Corrected atomic DX-101 display-list buffering and bounded descriptor handling
- Timing-clean Quartus Prime Lite 17.0 build
- Hardware-verified video, gameplay, input, and sound

Install the RBF and MRA using the paths documented in the README. ROM files are
not included.

