# SDRAM bank-ready timing experiment

The ready-bit controller was validated in scratch, then promoted to
`rtl/sdram.sv` in commit `aff6dfd`. The preserved candidate snapshot is
`scratch/sdram_ready_bit_20260925/sdram.sv` (SHA-256
`a7117892cc6b319f5ea3f7a03a91227ff2e63705381e38ee319536768146f7ae`), compared
with the previous tested controller (SHA-256
`f4994aeb153e69c9fd5893acf75c0d5744424f7f23683f89b917f6d921a2e7e0`).

The candidate keeps the three-bit bank-age counters and adds one `ready` bit per
bank. After initialization, the intended invariant is `ready == (bank_age >= 5)`.
Initialization and ACT retain priority over ticks; the ready bit must not permit
PRECHARGE before the existing five-cycle tRAS requirement.

The focused invariant bench passes 87 checks. It covers all eight rank/bank
entries during initialization, every age from zero through seven while
`SDRAM_EN=0`, ACT clearing age and ready, row-conflict waiting through
`STATE_RPRE_RAS`, and initialization priority over concurrent tick/command
activity.

The standard chip-model `tb_sdram` passes on both baseline and candidate with
174 checks, zero failures, and zero protocol errors. Latencies and throughput
match: cold read 6 `clk_sys` cycles, page-hit read 4, buffered line read 1;
64 sequential reads take 5,847 ns and writes 4,757 ns. Minimum ACT-to-PRE is 15
`clk_ram` cycles on rank 0 and 208 on rank 1. Candidate invariant monitoring
observed 9,193 open-bank cycles, of which 9,013 were ready, with no invariant
violation.

The registered-first-miss memory-path test passes 64 integrated reads and 2,048
ordered mixed posted-write/read operations with zero protocol errors.
`tb_line_dma` passes with 20,512 reads, 5,381 stores, 15,374 line acknowledgements,
11,423 DMA beats, and zero errors. The commands, benches, and run logs are under
`scratch/sdram_ready_bit_20260925/`; the contemporaneous review is
`scratch/sdram_ready_bit_review_20260925.md`.

These results verify the exercised cycle-level behavior, not an implementation
benefit. A later standalone Quartus map of the promoted candidate reports 622
ALMs and 966 registers, versus 618 ALMs and 958 registers for the comparison
source; both use 488 MLAB bits (61 cells) and no M10K. The controller source was
promoted with the address-only CPU fallback in commit `aff6dfd`. This small
increase in mapped controller resources is not a fitted timing result, and the
full-fit RAM timing gate remains necessary.
