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

## Completed full-machine fit

`q800-refill-load-fit2-20260919` completed with both build and cross-domain STA
exit zero. Archived candidate: `scratch/refill_load_fit_20260919/MacQuadra800_refill_load_f7b8e1f.rbf`.
SHA-256 `174967e7be8bfa72a90c96420909274258a49e61357a0af15b99a76c185b24b8`.
36,657 ALMs (87%), setup +0.343 ns, hold +0.214 ns, CPU +0.671 ns,
SDRAM +0.524 ns, crossings +1.290 / +0.671 ns. Reports and manifest archived.
The operator is authorized to copy/deploy this unique candidate after preserving
the disk and collecting five valid installed-core baseline runs, then measure
five valid candidate runs. No Main/CFG/clock changes. Check operator messages
for actual deployment/measurements; do not infer they happened from this note.

## Disk preservation completed

The operator's `scratch/hardware_pipeline_baseline_20260919/disk_manifest.txt`
records matching original/test-copy SHA-256:
`224c5be7d031c4c5448745d29ce9717c22bcc310361888bb0e20f2c521c83e2a`.
Both are 2,146,461,696 bytes. Original was cleanly shut down before copying and
is preserved unmounted. Slot/config originals are saved beside the manifest.
User was told the verified copy is complete. Resets/recovery may use the test
copy without repeated shutdown approval, as explicitly requested by the user.

## Simulation baseline stopped: no valid result

All task-owned `c` simulator/monitor units have been stopped. The historical
keyboard replay was not valid for this startup state: initial keys arrived
before startup finished, and the recovery replay eventually launched Prince of
Persia (screenshot f5311), not Speedometer. `capture.json` records the rejection.
No score/profile was accepted. The HDA was a disposable copy; originals and
hardware were unaffected. Future simulator navigation must be screenshot-driven.
Use hardware for actual scores; do not restart hours of blind replay.

## Next work

The address/quick extension is now implemented experimentally. It passes
**14,720 snapshots of all 16 registers** both standalone and integrated, six
stall/flush/cancellation schedules, exhaustive 65,536-word admission, and two
negative controls (all forwarding off, and An-only forwarding off). All 14
real-core suites plus directed IRQ replay pass; first-100 silicon corpus has
zero real differences. Artifacts: `scratch/pipeline_p1c/` and its
`prototype_extended/`. Reproduce with:

```
python3 scripts/cpu/pipeline_handoff.py --extended --out NEW_OUTPUT
```

Experimental opcode admission now includes register MOVE/MOVEA, quick arithmetic,
ADDA/SUBA/CMPA and ordinary ADD/SUB/CMP with An sources, in addition to P0.
The default hardware build remains pipeline-disabled. Next work is memory
operands and preserving original fast paths for short streams; design contracts
are in `docs/CPU_PIPELINE_REWRITE_20260919.md`.

Historical profile P0 coverage was only 12.64% of observed opcode loads. MOVE
Dn/An, quick arithmetic and address arithmetic are important missing coverage;
memory-read/write states were about 40% of historical clocks. These are old
profile observations, not current hardware speedup estimates. Expand operand
coverage and preserve the old fast paths for short runs. Keep correctness,
timing/area, and actual hardware gain as separate gates.

P1c standalone Quartus fit completed successfully at commit `5e1b158`: **714
ALMs**, 341 registers, no RAM/DSP blocks. At 33 MHz, worst setup is **+12.942
ns**, worst hold **+0.139 ns**. Reports: `scratch/pipeline_p1c/standalone_fit/`.
This is the isolated execution module, not a full-machine pipeline fit.

P1d restores existing sequencer lookahead outside experimental pipeline ownership.
All 14,720 snapshots, 14 suites and precise IRQ/replay pass. Three benchmarks
remain slower than the default core (56,916 / 123,176 / 149,256 cycles), so keep
the experimental pipeline off for hardware. Artifacts: `scratch/pipeline_p1d/`.
The first installed-core screenshot shows Mix 0.924; await the operator's full
baseline/candidate report before accepting or comparing repeated results.

P1d first-100 silicon corpus: 1,900 field groups match, zero real differences
(`scratch/pipeline_p1d/corpus.log`, `/tmp/cpu-corpus100-gate.5OiVFE`).

Installed-core baseline is now complete: five valid Mix runs **0.924, 0.928,
0.927, 0.927, 0.928**, median **0.927**; no invalid timer outliers. Full report:
`scratch/hardware_pipeline_baseline_20260919/baseline_results.md`. Operator was
again told to proceed directly to the archived, verified refill-load candidate.


P1e removes the empty-pipeline S_NEXT bubble by using the normal fetch/IRQ/trace
boundary directly after all stages drain. Descriptor dispatch may run at that
drained boundary; overlapping retirement still cannot pass control to it.
All 14,720 snapshots, 14 real-core suites, directed IRQ/replay and first-100
silicon corpus pass (1,900 matching field groups, zero real differences).
Artifacts: `scratch/pipeline_p1e/`, corpus `/tmp/cpu-corpus100-gate.d4d2eS`.
Cycles: **56,716 / 120,180 / 140,264** for loop/call/branch benches. These remain
slower than the default production candidate; pipeline stays disabled in it.
