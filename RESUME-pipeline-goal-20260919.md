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
  Copying is complete. Both images were 2,146,461,696 bytes and matched SHA-256
  `224c5be7d031c4c5448745d29ce9717c22bcc310361888bb0e20f2c521c83e2a` before test boot.
  The original remains preserved/unmounted; only the disposable test copy is used.
  Resets/recovery on that copy are authorized without repeated approval.
- Test copy: `/media/fat/games/MacQuadra800/QuadSquad8-pipeline-test-20260919.hda`.
  Disk manifest: `scratch/hardware_pipeline_baseline_20260919/disk_manifest.txt`.
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


Refill-load hardware comparison is complete: five valid candidate Mix scores
0.922 / 0.926 / 0.924 / 0.926 / 0.925 (median 0.925) vs baseline median 0.927.
No useful gain; no observed timer outlier. Candidate booted and shut down cleanly.
Hardware is at clean halt on the disposable disk; preserve the original.
See `scratch/hardware_pipeline_baseline_20260919/candidate_results.md`.

A reproducible, hash-verified exact Permute kernel diagnostic is now available:
`scripts/cpu/profile_permute.py`, with `verilator/tb_cpu_permute.sv`. It checks
8,660 recursive calls and unchanged array/guards through actual wombat_cpu
MMU/cache/store-buffer wiring with controlled RAM latency (not real SDRAM).
Results and the rejected ~1% data-line-buffer experiment are recorded in the
pipeline design document. Next hypothesis: cross-line stack-store cache
invalidations. The retained-data-line prototype is archived in scratch only.


Next hardware candidate: `AP040_EXPERIMENTAL_XSTORE`, selected in the QSF with
register pipeline still disabled. It merges already-qualified posted stores
across both cache lines instead of invalidating both sets. The 26 existing CPU
checks, new 100-case cache coherence/error bench and silicon first-100 corpus
pass. New bench is wired into run_tests.sh (now 27 checks). Exact Permute at
controlled RAM latency 3 improves 2,157,673 -> 1,588,970 cycles; with register
pipeline also enabled it is slower (1,680,485), so leave the pipeline off.
Details and source-identity logs are in docs/CPU_PIPELINE_REWRITE_20260919.md.
Full-machine Quartus build is the next gate; once running, freeze all RTL/QSF/
QIP/SDC until it finishes and archive both cross-domain timing reports.


## XSTORE fit complete; hardware trial active

Full-machine build **c328ae7**, seed 21, completed successfully. Build and crossing
report commands both exited zero. RTL freeze has ended; reports and unique RBF
are archived in `scratch/xstore_fit_20260919/`.
Artifact: `MacQuadra800_xstore_c328ae7.rbf`, SHA-256
`e7d26efcb9ac22b7ef4cb2b284b405ba32fdedc3012c2d87ef4bb57af00fa4d3`.
Fit: **36,871 ALMs (88%)**, 25,889 registers, 491 RAM blocks, 43 DSP.
Worst setup **+0.068 ns**, hold **+0.243 ns**; CPU setup **+0.979 ns**,
SDRAM setup **+0.800 ns**; sys->ram **+1.514 ns**, ram->sys **+0.979 ns**.
Cache arrays retain block RAM inference. QSF only received a fit-history comment
following completion; the archived artifact remains the c328ae7 build.

Operator `/root/mister_operator` received the follow-up task to copy/hash/load
this unique RBF, obtain five valid Mix runs with Main/CFG/33MHz/32MB unchanged,
report invalids and per-test values, then cleanly shut down. Evidence directory:
`scratch/hardware_xstore_20260919/`. Await results; last measured Mix is 0.925.
Original disk must remain preserved. Do not infer 1.8 from kernel simulations.

During the freeze, `scratch/towers_probe_20260919/` is an isolated testbench-only
probe of the original Towers bytes, intended to check another call-heavy kernel
without changing any Quartus source. Both variants pass count/list/guard checks: baseline 34,118,877 cycles vs XSTORE
29,647,247 at controlled RAM latency 3 (13.11% fewer). Source identity and logs
are archived there. This is not a hardware score.


Next candidate is XSTORE+LEA displacement overlap, register pipeline still off.
Correctness/kernel results are in the design doc's LEA section. QSF selects both
macros for its full fit. XSTORE hardware series is still on the prior c328ae7
artifact; do not mix candidates in that five-run series. First completed XSTORE
screenshot shows Mix0.993; await operator's validated final report.


## Active Quartus flow: LEA candidate 94d922f

Unit `q800-lea-fit-20260919` is ACTIVE, launched at 13:50 EDT. **Freeze RTL/QSF/
QIP/SDC until it finishes.** Committed source: `94d922f3c50ca4a3e19cccfd7152650c29bab5e4`.
Launcher and automatically archived output: `scratch/lea_fit_20260919/`.
Intended artifact `MacQuadra800_lea_94d922f.rbf`. Same new-artifact-mtime check,
source checksums, build.exit/cross.exit, unique RBF hash and crossing reports as
the completed XSTORE flow. Inspect area/timing/RAM/crossings before deploy.
Only docs and isolated scratch fixtures may change during the flow.

XSTORE operator remains active. Four completion screenshots were present at
13:50; five valid runs and clean halt still pending. Do not interrupt or load
the LEA build before the current series completes. Current hardware artifact
is c328ae7, not the newer working-tree candidate.


XSTORE hardware five-run result is now available: **0.993,0.997,0.997,0.997,0.997**,
median **0.997**, mean **0.9962**, no invalid timer outliers. +7.78% median vs
refill-load candidate0.925. This is the latest measured hardware result; 1.8 is
still unmet. Operator is finishing shutdown, adding all per-test seconds and
clarifying that its report's disk hash is the PRE-BOOT copy identity. Report:
`scratch/hardware_xstore_20260919/xstore_results.md`. LEA fit94d922f remains active;
all five frozen source checksums were verified OK at13:51EDT.


XSTORE shutdown confirmed: `scratch/hardware_xstore_20260919/final_halt.png`.
Operator clarified its mistaken wording "Main stopped": Linux MiSTer PID10520
and remote PID763 remain running, only the Mac guest halted. Original image
remains unmounted/untouched. Operator is now available for the LEA trial after fit.

During the LEA source freeze, a scratch-only P2 `(An)` load pipeline prototype
was built at `scratch/pipeline_load_p2_20260919/`. Read README.md there. Directed
ordering/cancellation/fault tests pass at4latencies; independent768-retirement,
192-load oracle passes all An/Dn/BWL combinations under CE/WB stalls. Premature
read negative control fails as required. The14720register compatibility oracle
passed all6schedules and both forwarding negative controls (register_gate.log). This prototype is NOT
integrated or fitted, and does not establish any performance gain. All fitted
sources remain unchanged. LEA unit `q800-lea-fit-20260919` is still active.


## LEA fit completed; hardware trial now active

Unit `q800-lea-fit-20260919` completed successfully (build.exit=0,cross.exit=0).
**Source freeze has ended.** Full archive `scratch/lea_fit_20260919/` contains
`MacQuadra800_lea_94d922f.rbf`, SHA-256
`d3bd1b96b48f95b9b3b665d1c74a8e973eb7cf54e9efac18943f5cbafbf4d04c`.
36,997 ALMs88%,25,920 registers,491RAM,43DSP; worst setup +0.311ns and hold
+0.238ns; CPU +1.025ns, SDRAM +0.555ns; sys->ram +0.555ns, ram->sys +1.025ns.
Cache cdata0–3 remain inferred block RAM. After flow end QSF received only the
required fit-history comment; artifact remains the committed94d922f build.

Operator received follow-up to copy/hash/load LEA candidate from the XSTORE clean
halt and obtain five valid Mix runs, all ten tests, iteration1, preserving Main,
CFG,33MHz,32MB and disposable disk. Evidence `scratch/hardware_lea_20260919/`.
Then cleanly halt Mac and leave Linux MiSTer/remote services running. Await its
first/final scores. Latest accepted result is still XSTORE median0.997; 1.8 unmet.

Next independent CPU work: integrate/test the scratch P2 load prototype through
existing core memory/exception sequencing, with request PC/opcode metadata and
page-split/MMU/error/IRQ coverage, then measure against current production path.
Do not infer speed from the standalone correctness tests. Prototype source has
NOT been promoted; only scratch has the load ports. Its compatibility bench
explicitly ties off the new ports because the existing testbench uses `.*`.


## Latest state: LEA hardware complete; P2 load integration checked

LEA94d922f hardware scores1.000/1.005/1.005/1.006/1.005, median1.005, mean1.0042,
all valid. Operator confirmed clean guest halt, Linux Main/remote still running,
original disk untouched/unmounted. No Quartus flow is active. Operator idle.

The P2 load prototype is now integrated in source behind
AP040_EXPERIMENTAL_PIPELINE_LOADS plus AP040_EXPERIMENTAL_PIPELINE, both off in
QSF. Existing memory/page-split/fault sequencing is reused. A CE-paused return
initially used the wrong RF port for partial Dn merge; fixed by pipe_rf_owner
covering load_active and return. Corrected14suites+14720snapshots+IRQ replay and
first100silicon pass;192load combinations, odd/pagecross reads and precise bus
fault pass all3modes. New load IRQ test passes3injections/3kills with exact replay.
See design doc P2 section, `scratch/p2/identity.json`, `scratch/p2/direct/` and
`scratch/p2/load/`. Runner now includes directed programs with forced admission;
new combined-feature IRQ-only run is at `scratch/p2/irq.log` (session10141).

Performance is NOT a gain: normal lookahead Permute1,668,981cycles admits0loads;
forced decode1,929,759cycles admits10,078loads vs production1,577,469cycles.
Do not fit/deploy this pipeline as a speed candidate. Next measure forced
register-only vs forced P2, then reduce load request/return handoff cycles and
extend d16 operands so ordinary mixed streams can remain in the pipeline.


Final combined-feature directed rerun passed with strengthened monitor:
all_loads1161commits/585pipeline loads (195 per phase,192combinations+3edge reads),
fault3pipeline loads with6cancelled records. Logs `scratch/p2/direct/*_combined.log`.
New combined-feature IRQ gate also passed (scratch/p2/irq.log). No test/build
process is intentionally left running; hardware operator finished at clean halt.


## P2 load handoff follow-up

Registered load requests now supply the existing data-cache hint and can issue
through the aligned in-place path. Ordinary read acknowledgements forward into
pipeline WB directly; split reads retain the buffered return. The pipeline
buffers responses when CE is paused or WB cannot advance.

Final combined gate passed in `scratch/p2/direct_gate.log`: 14,720 oracle and
shared-state snapshots, six stall schedules and negative controls, all 14 prior
real-core suites, both directed load programs, and both precise IRQ/replay tests.
Current-source first-100 silicon comparison passed (1,900 field groups, zero real
differences) in `scratch/p2/direct_corpus.log`. Standalone response tests passed
at delays 0/1/3/8, including CE pauses, WB stalls, cancellation and fault handling;
the independent 768-retirement/192-load oracle passed (`scratch/p2/response_unit/`).

Forced-load Permute at latency 3 improves from 1,929,759 to **1,899,527 cycles**
with 10,078 loads. Matched forced register-only control takes 1,849,139 cycles;
production XSTORE+LEA takes 1,577,469. Thus this removes about three cycles per
load but remains slower overall. Pipeline macros remain off in QSF; no new
hardware performance claim or full-machine pipeline fit is made.

Latest accepted hardware Mix remains median **1.005** across five valid LEA
runs. The 1.8 goal remains unmet. A/UX compatibility is pending: its image and
backup named in the notes are absent from MiSTer and the searched local fixture
paths; the user has been asked for their location.


## Fetch capacity and pipeline exit measurements (43c6903)

An isolated scratch sweep enlarged the single branch-refill sector while keeping
its replacement, context and invalidation rules. Production RTL was unchanged.
Exact Towers at controlled latency 3 passed moves/list/guard checks for all sizes:

| Sector bytes | Cycles | Reduction vs 32 bytes |
| --- | ---: | ---: |
| 32 | 27,509,911 | baseline |
| 64 | 27,509,907 | negligible |
| 128 | 27,473,039 | 0.13% |
| 256 | 27,228,991 | 1.02% |
| 1024 | 26,688,870 | 2.98% |
| 4096 | 26,454,839 | 3.84% |

Artifacts, reproducible generators, source hashes and logs:
`scratch/brf_capacity_20260919/`. These are simulation capacity probes, not
correctness-qualified hardware candidates or strict bounds on other buffer
organizations. The gain does not justify prioritizing this design over pipeline
coverage; no sector enlargement was promoted and no Quartus flow was launched.

A current-source Permute admission profile counts each drained exit with a
resident unsupported next opcode, distinguishing an empty-fetch exit. Normal
lookahead: 56,236 issues, zero loads, 1,668,981 cycles. Dominant exits are indexed
PEA 0x4870 (20,156), LEA d16(A7),A7 0x4fef (5,039), BRA 0x603c (3,620).
Forced decode: 83,646 issues, 10,078 loads, 1,899,527 cycles; additionally MOVE.W
(A0),(A1) 0x3290 causes 10,078 exits and MOVE.W D0,-(A7) 0x3f00 causes 8,659.
Both modes have one empty-fetch exit and pass the exact kernel checks.
Artifacts and source hashes: `scratch/p2/admission/`.

This identifies memory destinations, stack pushes and control flow as major
barriers to sustained overlap. Merely adding more register instructions or
(An) loads will not remove them. Next substantial pipeline work should cover
resident extension words and ordered stores, beginning with indexed PEA or
register-to-stack MOVE; preserve precise faults and commit A7 only at successful
store completion. The old fast paths must remain available outside ownership.

Hardware operator's read-only check shows the Mac safe-shutdown screen on the
disposable slot-0 image; screenshot `scratch/hardware_lea_20260919/status_boot_now.png`.
No input, reload or disk changes were performed. Latest accepted Mix remains
1.005 median; 1.8 and the missing A/UX regression remain outstanding.
