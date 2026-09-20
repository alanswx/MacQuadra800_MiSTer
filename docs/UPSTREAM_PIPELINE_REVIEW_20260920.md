# Upstream AP040 pipeline review — 2026-09-20

Reviewed `apolkosnik/Minimig-AGA_MiSTer`, branch `ap040-pipelined`, pinned at
`62b1dc864f5fd2975d6ceaf7084221fbc5b52dde` (milestone 83).
Source: https://github.com/apolkosnik/Minimig-AGA_MiSTer/tree/62b1dc864f5fd2975d6ceaf7084221fbc5b52dde

## Recommendation

Evaluate separately before changing the Mac CPU direction. This is a new
six-stage integer pipeline, not a small patch to our sequencer. It is promising,
but neither a bootable Mac replacement nor evidence of a 1.8 Speedometer Mix.
Production RTL and the MiSTer were not changed for this review.

The isolated, ignored snapshot is `scratch/minimig-ap040-eval-62b1dc8`;
the bare review repository is `scratch/minimig-ap040-review.git`. No worktree
was created. These local scratch copies are not part of the committed report.

## What changed

- New `rtl/ap040_pipe` implementation: instruction fetch, decode, effective-address
  calculation, operand fetch, execute, and writeback, with register/CCR forwarding,
  stalls, flushing, and taken-branch prediction/recovery.
- Broad incremental integer ISA and exception/trace work; separate ALU and
  register-file implementations preserve the original FSM CPU.
- Milestone 80 adds variable-latency memory; 81 separates the CPU from its test
  memory and adds a 32-bit transaction interface; 82 connects the original FSM
  CPU's unmodified 16-bit Minimig adapter.
- Latest commit (83) adds a differential test against the FSM. It generates
  16 programs of 96 slots, largely register operations and branches, comparing
  final D0-D7/A0-A6 dumps. It excludes generated memory operands and divides.
  Its printed cycle count waits for BOTH CPUs; it is not a speed comparison.

## Integration gaps checked in source

The new CPU is not referenced by the main Minimig project. MMU/cache and FPU
integration remain on the plan's TODO list. The bus-facing CPU has no external
interrupt input; the 16-bit wrapper ties bus errors off because format-7 access
faults are not implemented. The differential bench supplies PC by parameter and
pokes ISP directly: the pipeline does not load reset vectors. The system wrapper
also documents that vector fetch does not yet consult VBR. ISA gaps remain,
including register-count shifts identified in the new differential test.

The older FSM's OS boots and corpus results must not be attributed to this new
pipeline. The reported 5,250 ALMs, 40.47 MHz and +0.288 ns are upstream standalone
results, not independently reproduced here and not a full Mac fit. Its synthesis
project uses `ap040_pipe_core`, small test memory (`L1_AW=4`), and virtual pins.

## Independent verification

Ran the unmodified upstream Verilator launcher with:

```sh
PATH=/home/alans/verilator5/bin:$PATH python3 scratch/minimig-ap040-eval-62b1dc8/tests/ap040/run_pipe_verilator.py --only bus,bus16,dual --jobs 4 --work /tmp/q800-upstream-pipe-review-62b1dc8
```

Result: **3/3 passed**. Logs are in that work directory. This is a focused smoke
check, not the complete upstream suite, hardware corpus, or Macintosh boot gate.
No upstream performance ratio was measured.

## Next evaluation steps

1. Add an isolated adapter around the 32-bit interface and run our unchanged
   Queens, Bubble, Permute and Towers kernel bytes with their independent output
   checks. Keep unsupported instructions visible as failures; do not replace them
   with benchmark shortcuts.
2. Compare separate completion cycles at identical CPU enables and memory latency.
   Report cache assumptions explicitly: our production path includes MMU/cache,
   while upstream is not integrated with those yet. Sweep latency to distinguish
   pipeline gains from favorable test memory. Use current Mac RTL as the decision
   baseline, not just upstream's older FSM.
3. If results justify migration, enumerate and close the reset, interrupt,
   exception, ISA and MMU/cache gaps; then run our correctness gates and a full
   Mac Quartus fit. Standalone CPU fit cannot establish remaining system area.
4. Only after Mac boot works, measure Speedometer on mister.local using the
   disposable disk and five fresh valid runs. Simulation kernels guide selection;
   they do not establish a Speedometer Mix score.

Current hardware reference: P33 timing-clean median 1.083; P39 experimental median
1.105 with CPU timing failure. See `PERFORMANCE_MEASUREMENTS.md`. Reaching 1.8
requires about 63% above P39, so a larger architectural alternative is worth
measuring, without assuming that pipelining alone provides that gain.
