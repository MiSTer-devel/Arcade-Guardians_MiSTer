# Changelog

## 1.0.0 - 2026-08-09

- Initial public release.
- Added direct, script-free MRA loading from an unmodified `grdians.zip` set.
- Implemented the TMP68301-compatible CPU subsystem, DX-101-compatible video,
  X1-010-compatible PCM audio, player controls, DIP switches, and service mode.
- Added SDRAM graphics streaming and DDR3-backed program/sample storage.
- Fixed registered descriptor-read latency, DX-101 register `0x26` display-list
  packing, atomic list-buffer transactions, and startup list termination.
- Fixed intermittent stripes, missing sprite segments, clipped frame regions,
  and delayed display-list collapse observed during long hardware runs.
- Added focused RTL tests and reproducible Quartus 17.0 project files.

