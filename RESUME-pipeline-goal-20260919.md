# Active performance goal — 2026-09-19

The user requested continued iteration until **at least 1.8 Speedometer 4.02
Benchmark Mix on mister.local**, at the authentic clock. An active Codex goal
records this objective. Do not mark it achieved from simulation or an invalid
timer result. Obtain at least five valid hardware runs; report invalids separately.

## User authorization and hardware

- `mister.local` is explicitly available to this task. The user authorized a
  cheaper-model operator; `/root/mister_operator` (gpt-5.6-luna) handles hardware.
- The original installed Mac core was at a clean shutdown screen. Clicking its
  Restart button led to a black ROM serial diagnostic loop at `408B98F2` /
  `408B9ABC`. Disassembly shows SCC polling and nearby STM/CTE diagnostic strings;
  this was not evidence of normal RAM testing. No experimental RTL had been
  deployed. The user explicitly approved **reloading the same installed core**.
- The user subsequently said **make a copy of the hard drive image so there is
  a known-good working copy and repeated shutdown worries are unnecessary**.
  The operator is instructed to finish boot, cleanly shut down/unmount once,
  preserve the original, and create/verify a disposable test copy. Once that is
  done, resets and recovery of the test copy are authorized without repeated
  shutdown approval. Preserve the unmounted original and never overwrite it.
- Latest user observation: **“i can see it booting now.”** Operator was told to
  let this boot finish before preparing the copy. Do not interrupt that work.
- Intended test copy: `/media/fat/games/MacQuadra800/QuadSquad8-pipeline-test-20260919.hda`.
  Operator must check free space, avoid overwrites, preserve slot/config identity,
  sync and compare SHA-256 hashes after copying, then mount only the test copy.
  Check operator messages for completion; this file does not assert it is done.
- Installed RBF SHA-256 before recovery:
  `5299e49bf64eb3868a88b620e61353bf8ab393d53df93075eb713eb1ca36c1d1`.
  Main: `0ac8b44069a9201723dcdbc3bf3a84e1963d2bec347e5065c2625e71bd3986cd`.
  CFG `40 00 00 00`, Ethernet On; keep this baseline configuration documented.
  Evidence: `scratch/hardware_pipeline_baseline_20260919/`.

## Committed CPU checkpoints

- `99a8402`: P0 independent resident ID/EX/WB Dn pipeline, oracle and fit tools.
- `ca338e3`: simulator keyboard wiring and graceful profile completion fixes.
- `0f98f9e`: P1 real-core ownership with shared register file/SR, serialized entry.
- `9932efb`: overlapping resident issue, precise IRQ/trace cancellation and replay.
  All 8,608 oracle snapshots, 14 program suites, first-100 silicon corpus pass.
  Directed full-pipeline IRQ test checks stacked PC against committed ADD count
  and replay, with 3 injections / 6 cancelled younger instructions.
- The experimental pipeline is behind `AP040_EXPERIMENTAL_PIPELINE`, **off in
  hardware builds**. This version is slower on short runs because it disables
  existing lookahead and pays entry/drain costs. Do not deploy it as a speedup.
  Details and numbers: `docs/CPU_PIPELINE_REWRITE_20260919.md`.
- `7cd5241`: actual default-core candidate, predecode MOVE.B/W/L from simple
  An-based memory operands when installing a branch-refill target. Memory/fault
  paths unchanged. `bench_loop` 68,100 -> **55,916** cycles; call/branch benches
  unchanged at 110,696 / 119,284. Original 25 CPU tests pass plus new 20-case
  refill-load program in 3 bus modes; corpus zero real diffs; DMA zero errors.
- `f7b8e1f`: Linux build wait gate matches process names, avoiding deadlock when
  the parent shell merely contains a later `quartus_sta` command in its text.

## Active full-machine fit

User unit **q800-refill-load-fit2-20260919**, directory
`scratch/refill_load_fit_20260919/`, commit recorded in `commit.txt` (f7b8e1f).
The earlier unsuffixed unit was stopped while waiting, before any Quartus process
started. The replacement is the only flow. Synthesis succeeded; fitter was still
running when this note was written. **Do not change RTL/QSF/QIP/SDC during it.**
The unit runs `build_only.sh`, then cross-domain STA tagged `refill_load_20260919`.
Inspect build.exit/cross.exit, fit utilization, all setup/hold domains, and the
SDRAM crossings; archive reports and RBF before another build. No candidate has
been deployed. Hardware operator must finish preserving disk and baseline first.

## Simulation baseline

`scratch/pipeline_baseline_20260919c/`, simulator user unit
`q800-pipeline-baseline-c-20260919`; monitor is now
`q800-pipeline-baseline-monitor-c2-20260919` with `--profile-start-count 2`.
The old monitor was stopped before profile start. Initial 20-second fastboot
wait was too short: frame1572 was still busy startup; frame2231 remained
MacAtrium. Appended `recovery_control.txt` replays the original navigation after
the first prefix drains and discards its first bracket. `navigation_recovery.json`
records the correction. Do not record any score before reviewing final screens.
The simulator is slow and uses ideal memory/no SONIC plus documented fastboot
ROM; hardware is the performance authority. Keep it for diagnostic profiling.

## Next work

While fitting, a new independent address-register/quick-arithmetic oracle was
prepared in `scripts/cpu/pipeline_address_oracle.py`. It passes **6,048 snapshots
of all 16 registers** against the real core, covering sign extension, full-width
An quick ops, preserved CCR and partial Dn writes. Artifacts:
`scratch/pipeline_address_oracle/`. It does not claim the pipeline supports these
operations yet. This script may still need committing; check git status.

Historical profile P0 coverage was only 12.64% of observed opcode loads. MOVE
Dn/An, quick arithmetic and address arithmetic are important missing coverage;
memory-read/write states were about 40% of historical clocks. These are old
profile observations, not current hardware speedup estimates. Expand operand
coverage and preserve the old fast paths for short runs. Keep correctness,
timing/area, and actual hardware gain as separate gates.
