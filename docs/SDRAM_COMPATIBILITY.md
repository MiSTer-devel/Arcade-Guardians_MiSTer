# SDRAM compatibility: Guardians v1.4.1

## Note for MiSTer Pi owners and core developers

Guardians v1.4 showed graphics streaks on Fluxxant's affected MiSTer Pi.
Comparative full-ROM tests isolated a read-capture problem: the falling-edge
sample, retimed to the controller's rising edge (F0), repeatedly reproduced
the correct 32 MiB graphics CRC32 `CA9926D0`; rising-edge capture (R0) did not.
F0 readback matched with both single-word and batched loader writes.

The final private fixed-F0 gameplay test reported:

| Accepted graphics image | R0 CRC (information only) | F0 CRC | Loader writes | Result |
| --- | --- | --- | --- | --- |
| 32 MiB, CA9926D0 | E7BB712B | CA9926D0 | Single word | F0 PASS |

Fluxxant supplied title, character-select, Stage 1 ready, and gameplay photos
and reported clean gameplay. This result validates that private fitted binary
on that affected board. It is not a separate hardware test of the later
diagnostic-free production fit, of SuperStation One, or of every MiSTer Pi.

The v1.4.1 production controller uses Intel/Altera `ALTDDIO_IN` `dataout_l`
for all sixteen SDRAM input bits, shared by normal reads and four-word graphics
DMA. The falling sample is retimed by the primitive before the controller
consumes it. The sampler has no reset or runtime edge selector. The existing
68.75 MHz memory rate, nominal 180-degree forwarded clock, CAS3, BL4 first-word
alignment, ROM layout, loader and renderer remain unchanged. The separate
fixed forwarded PLL output used in the tested candidate is retained. Private
diagnostic menus, CRC sweeps and test screens are not part of the release.

This evidence does **not** show that the RAM module is defective, that a
different ROM is required, or that single-word loading is mandatory. The
ordinary capture registers were already fitted in I/O cells. The exact
electrical cause is not established; external SDRAM I/O paths are currently
unconstrained, and passing internal FPGA timing is not external bus closure.

For another core with similar corruption, compare the accepted upload CRC
against uncached full-memory readback through both capture paths. Keep the
clock, phase and command timing fixed while isolating capture; then test live
game traffic on the affected board. Do not transplant Guardians' first-word
alignment or phase into a different controller without validating its read
latency and fitted timing. Preserve ROM provenance and the exact tested RBF
hash so a later refit is not confused with the measured binary.

## Export and regression notes

Earlier manual uncompressed private exports hard-locked this tester. Standard
compressed Quartus output from the same diagnostic SOF booted and completed.
That identifies an export/configuration-format difference in those tests;
it does not prove that all uncompressed MiSTer cores fail. This release uses
standard compressed assembler/CPF output, not a manually altered bitstream.

The focused production tests cover DMA row boundaries, ordinary reads and
four-command batched writes through both the behavioral sampler and Intel's
primitive model. A 32 KiB pin-level sweep exercises all four banks, 32 physical
rows, normal reads and controller reset. A shortened synthetic DQ window checks that the fixed F0
path remains correct when a rising sample would be stale. Its delay values
are an injected test fixture, not measured board calibration.

The private tested RBF is 4,500,008 bytes, SHA256
`a2f0eb391ceb60e6a96d2aceaad3e1a595add4662b07afb755038b03c7db3884`.
It had +0.372 ns worst internal setup slack and +0.151 ns minimum internal
slack, with 70 simulation reports passing. These figures describe the private
test, not the production release; see the release README for the final fit.

Hardware reports and patient testing: Fluxxant and participants in upstream
issue #1. Direction and release: kandowontu. Sampler primitive: Intel/Altera.
