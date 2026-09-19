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


## P3: ordered register stores and direct memory offers

The opt-in `AP040_EXPERIMENTAL_PIPELINE_STORES` switch adds MOVE from Dn/An to
(An), (An)+ and -(An), with byte An sources excluded and the A7 byte step kept
at two. The historical load_* interface now carries write/data/CCR fields too.
An updates commit on successful WB; failed stores retain the original An.
MOVE-store CCR is installed at the head-ordered offer, matching the existing
sequencer's access-error frame semantics. Reads/writes reuse mrd/mwr and their
page-split, MMU and format-7 paths; no new cache or store buffer was introduced.

Memory offers now start as older WB commits (or after it), without a separate
registered-request bubble. Pending requests retain their fields until ack.
Interrupt cancellation blocks a younger offer; accepted stores precede the
interrupt boundary. Same-edge older retirement must not overwrite a new memory
operation's fault PC/opcode or store CCR. The directed fault test includes that
WB overlap and matches the previous sequencer's frame/CCR/An/younger state.

Validation on the shortened offer implementation:

- Full combined gate: 14,720 architectural snapshots, six schedules and register
  negative controls, 14 prior real-core suites, both load programs, both store
  programs, and three IRQ/replay tests pass (`scratch/p3/direct_gate.log`).
- Store program covers 320 register-pair/size/addressing combinations plus five
  dependency/odd/page-cross stores in each of three bus modes. Its compact table
  was verified byte-identical to the first passing generated program.
- Independent store oracle: 5,799 retirements, 996 memory requests, all legal
  register pairs/sizes/modes, at delays 0/1/3/8 with and without CE/WB stalls.
  It checks the exhaustive admission map, request PC/address/size/data and all
  register/CCR retirements. Wrong An updates and escaped cancelled-store offers
  are detected by negative controls (`scratch/p3/store_oracle.log`).
- A blocked older WB prevents a younger store; cancellation commits the older
  register while discarding the younger store/register. Accepted-store IRQ
  checks memory, updated An, frame PC and exact replay. Final strengthened run
  has three injections, three kills and three store launches (`direct_irq.log`).
- Previous load protocol cases pass at four delays, including accepted-request
  CE pauses, cancellation drain and fault suppression; the 768-retirement,
  192-load oracle passes (`scratch/p3/load_protocol/`). Pause/flush stimuli now
  wait for clock-edge acceptance, since an unaccepted combinational offer is
  different from the old registered request.
- First-100 silicon comparison: 1,900 field groups match, zero real differences
  (`scratch/p3/direct_corpus.log`, `/tmp/cpu-corpus100-gate.ZN3gpy`).
- Extra store-fault WB-overlap comparison passes in the new pipeline and prior
  sequencer binaries (`scratch/p3/fault_overlap/`). Source hashes: `identity.json`.

Reproduce store oracle:
`python3 scripts/cpu/pipeline_store_oracle.py --out scratch/p3/new_oracle`.
Combined gate: add `--stores` to pipeline_handoff.py's extended/loads/xstore/lea
command. profile_permute.py also accepts --stores; the silicon gate uses
CPU_GATE_PIPELINE_STORES=1 together with CPU_GATE_PIPELINE=1.

Performance remains below the production path. Exact Permute at latency 3:

| Mode | Cycles | Pipeline loads / stores |
| --- | ---: | ---: |
| Production XSTORE+LEA | 1,577,469 | off |
| P2 normal lookahead | 1,668,981 | 0 / 0 |
| P3 normal lookahead | 1,668,978 | 0 / 17,319 |
| P2 forced decode, old offer | 1,899,527 | 10,078 / 0 |
| P3 forced decode, initial registered offer | 1,922,999 | 10,078 / 27,398 |
| Current direct offer, stores disabled | 1,889,449 | 10,078 / 0 |
| Current direct offer, stores enabled | 1,893,750 | 10,078 / 27,398 |

All kernel checks pass. Matched controls show that the shared offer improvement
helps, while store admission itself still costs 4,301 forced-decode cycles and
is effectively neutral with normal lookahead. Do not claim a store speedup from
the older unmatched P2 comparison. Neither pipeline switch nor stores is enabled
in QSF; no synthesis/fit or hardware trial is justified by these results yet.
Latest hardware median is still 1.005; the 1.8 target remains unmet.

Next substantial step: resident extension-word admission and indexed PEA, the
largest remaining measured exit source. Carry variable next-PC through WB/IRQ,
consume an extension only when resident, and fall back to the sequencer for
missing/full-format extensions. PEA needs base/index reads plus the existing
A7 view; forward an older A7 WB before calculating the push address, preserve
CCR, and retain the existing store fault/retirement discipline. Memory-to-memory
MOVE and control-flow exits remain other major barriers to sustained overlap.

No hardware action or Quartus flow was started during P3. Mac remains at the
last confirmed clean halt on its disposable image. A/UX image location and its
hardware regression are still pending; do not treat CPU tests as that gate.


## P4 candidate: resident brief-index PEA, entry only at PEA

P4 adds PEA d8(An,Xn) behind AP040_EXPERIMENTAL_PIPELINE_PEA. Only a resident
brief extension is admitted. Full-format or unavailable extensions stay in the
existing sequencer. Base/index reads share the RF; the existing A7 view supplies
the stack address, with WB forwarding. PEA preserves CCR and commits A7 only on
successful store completion. The ordered P3 memory/fault path is reused.

ID/EX/WB now carry a variable next-PC. The first real-core PEA test caught an
additional old +2 assumption at fetch_next_body reentry, even though the first
Permute run passed. Corrected reentry and IRQ/trace now use retire_next_pc. The
failing trace is archived under `scratch/p4/debug/`; do not accept only kernels
as proof of CPU correctness.

Entry policy was measured on both exact kernels at controlled latency 3:

| Configuration | Permute cycles | Towers cycles |
| --- | ---: | ---: |
| Production XSTORE+LEA | 1,577,469 | 27,509,911 |
| PEA pipeline, unrestricted entry (initial probe) | 1,545,913 | 29,000,193 |
| Supported-successor entry (initial probe) | 1,526,294 | 27,728,229 |
| **PEA-only entry, corrected reentry** | **1,536,353** | **27,509,911** |

The selected policy AP040_PIPELINE_PEA_ENTRY_ONLY retains sequencer entry for
all other instructions, while supported successors may continue in the pipeline.
It saves 2.61% of Permute cycles and exactly preserves the tested Towers count.
The broader policies regress Towers and are not selected. These are kernel
simulations, not Speedometer predictions. Latest accepted hardware Mix remains
1.005; 1.8 is unmet.

Validation evidence:
- Independent PEA oracle: 5,006 retirements / 1,056 pushes, all base/index
  registers, index widths/scales, displacement edges and consecutive A7
  dependencies at four response delays with/without CE/WB stalls. Memory
  requests, all registers/CCR and variable next-PC match. Missing/full extensions
  are rejected. Wrong +2 next-PC and missing A7 forwarding mutations are caught.
  Reproduce with scripts/cpu/pipeline_pea_oracle.py --out NEW_OUTPUT.
- Existing independent store oracle and its two negative controls still pass.
- 14,720 shared-state snapshots and all 14 earlier real-core suites pass using
  the actual PEA-entry policy. They record zero pipeline entries where appropriate;
  do not claim these register-only workloads exercise the new pipeline.
- Forced-admission load/store programs pass. New PEA programs cover 128 base/index
  combinations, full-format/page-boundary fallback, exact user-stack fault
  PC/FA/USP/CCR with younger-state cancellation, and extension fault before push.
  Counts: 336 admitted PEA operations across the three modes for the main program,
  three for the bus-fault case, zero for the expected extension-fallback fault.
- PEA trace test passes all three modes: next PC604, trace address600, preserved
  CCR and correct pushed data. Artifact `scratch/p4/trace/run.log`.
- Four IRQ/replay tests pass (`scratch/p4/irq.log`). PEA has three injections,
  three actual younger cancellations and exactly three store launches. It enters
  through TRAP's architectural prefetch to guarantee resident younger work; the
  initial cold-fetch test had no younger work and correctly failed its coverage
  assertion despite passing guest checks.
- First-100 silicon comparison using PEA-only entry has 1,900 matching field
  groups and zero real differences (`scratch/p4/corpus.log`,
  `/tmp/cpu-corpus100-gate.wPfLp5`).

Individual gate evidence is in `scratch/p4/entry_gate/`, plus the corrected IRQ
and trace runs above. The final consolidated runner completed successfully in
`scratch/p4/final_gate.log`, including all corrected fixtures.
No RTL logic changed after those passing checks; final comments identify the
new file-list inclusion and variable-length admission.

QSF now selects pipeline/loads/stores/PEA/PEA_ENTRY_ONLY alongside XSTORE+LEA,
without forced decode or the broader selective policy. The module is added to
both QSF and files.qip. This is a hardware-trial recipe, not a released artifact.
Next: commit this candidate and run the full Quartus fit, freezing all RTL/QSF/
QIP/SDC until terminal completion. Archive RAM inference, setup/hold and both
clock-crossing reports before handing a unique, hash-verified RBF to the operator.
Mac is at its last confirmed clean halt on the disposable image; do not touch
the original disk. A/UX location/regression and CD-audio release checks remain
pending. No P4 hardware result exists yet.


P4 final consolidated gate exited zero at 15:29 EDT. All four PEA-specific
programs and all four IRQ/replay tests passed in that single run. No Quartus
process was present in the machine-wide process check before build preparation.
A scratch self-modifying-code probe without cache maintenance produced the same
old-instruction behavior in both the prior baseline and candidate; it is not
counted as a passing correctness test or evidence of a candidate regression.


## ACTIVE P4 full-machine Quartus flow — source freeze

Unit `q800-p4-fit-20260919.service` is verified active/running (MainPID1036054,
quartus_sh1036073, quartus_map1036162 at the initial poll). Started 2026-09-19T15:31:14-04:00.
Committed candidate: `6e852a6ff1b7215a9722081ce3195552f3b7c81e`.
**Do not edit RTL, QSF, QIP or SDC until this flow terminates.** No second
Quartus flow may run anywhere on this box. Docs and isolated scratch work are OK.

Launcher/archive: `scratch/p4_fit_20260919/`. The launcher records all tracked
RTL/project checksums, checks them again at completion, saves build.exit and
source_check.exit, archives both cross-domain reports after a new RBF appears,
and names the artifact `MacQuadra800_p4_6e852a6.rbf` with SHA-256. Inspect actual
build/cross/source-check exits, ALMs/registers/RAM inference and all timing reports
before deployment. Never mistake the prior output_files RBF for this candidate.

Final consolidated CPU gate completed successfully before launch:
`scratch/p4/final_gate.log`. No CPU test process is intentionally left running.
MiSTer operator remains idle; no P4 bitstream has been deployed or measured.
Latest hardware Mix median remains1.005. The1.8 goal and hardware regressions
remain open; A/UX disk-location question is still unanswered.


## P4 fit completed; P5 overlap validation — 2026-09-19 15:50 EDT

P4 unit is terminal (MainPID0, ExecMainStatus1): Quartus compilation itself
succeeded, but build_only returned1 for CPU setup -0.357ns. This is a timing
failure, not a placement failure. 38,185 ALMs91%,26,307registers,491RAM,43DSP;
HDMI+.180, hold+.223, SDRAM+.478, sys->ram+.478, ram->sys+.843ns.
Source-check and cross-report exits both0. Cache data/tag M10Ks preserved.
Artifact `scratch/p4_fit_20260919/MacQuadra800_p4_6e852a6.rbf` SHA256
`25c41c76545eb38b767df72145080d19b37577862816fcbb7250f864950ec2be`.
Operator was instructed to run five valid Mix trials on the disposable disk,
labelled timing-marginal under the existing user try-builds policy. Results
pending; this is not release qualified. The original image remains unmounted.
The detailed timing report `scratch/p4_fit_20260919/cpu_setup_paths.txt`
shows state -> pipe_rf_owner -> regfile mux -> legacy ALU -> branch refill
seed -> epf_data. Dedicated pipeline RF read ports are the next timing experiment.
All Quartus processes are terminal; the source freeze has ended.

P5 isolated experiment `scratch/p5_overlap_20260919/` tested waiting for a late
brief-index PEA extension and admitting younger instructions while ordered
pipeline memory owns the sequencer. Retirement ownership stays unchanged;
admission is blocked on a same-edge store invalidating queued code. Page-boundary
and faulted extensions retain the demand sequencer. All variants passed Permute:
baseline1536353, wait-extension1524946, overlap1533168, combined1519907 cycles
at controlled RAM latency3. Combined saves1.07% versus P4; not a hardware score.
Towers remained27509911 cycles, all moves/nodes/list/guard checks passed.
The initial Towers wrapper expected the Permute PASS marker; corrected parser
verified the actual TOWERS32 PASS and simulator exit0 (not an RTL failure).
A scratch generator initially inserted a PEA wire into the disabled-pipeline
branch as well; fixed, and disabled-pipeline compilation now passes.

Combined prototype full gate exited0 in `scratch/p5_overlap_20260919/full_gate.log`:
14720 shared-state snapshots, all earlier real-core suites, forced load/store/PEA
programs, faults, extension fault, trace, four IRQ/replay suites. Production
PEA-only policy earlier targeted tests also passed. The module itself is unchanged.
Profiling the combined variant gives40312 issues,10078 exits, all at opcode4eba
(JSR d16,PC); no empty exits. Artifact `scratch/p5_overlap_20260919/profile.log`.
Next expansion should address call/return or broader memory operands; these small
wins alone are insufficient for1.8. Latest accepted hardware Mix still1.005.


## P5 dedicated RF reads: validated, ready for fit

P5 overlap was promoted in e8f5277. The next candidate also enables two optional
read mirrors in ap040_regfile for the integer pipeline. Sequencer ports now read
rr_a/rr_b directly; pipeline ports read pipe_src/pipe_dst. All four share the
same architectural write, delayed-write bypass, written bits, and banked SPs.
Default EXTRA_READS=0 preserves non-pipeline builds. This removes the state-driven
ownership mux from the measured P4 legacy-ALU path; timing improvement is unproven
until the next fit. Quartus must confirm the extra mirrors remain MLABs.

Validation completed with exit0:
- `scratch/p5_rf_ports_20260919_gate.log`: full extended handoff gate,14,720 shared
  snapshots, all old suites, load/store/PEA fault/trace and four IRQ/replay tests.
- `scratch/p5_rf_ports_20260919/permute.log`:1519907cycles latency3,40312issues,
  20156stores, all call/array/guard checks; identical to the pre-RF-change P5.
- `scratch/p5_rf_ports_20260919/corpus.log`:100rows,1900matching field groups,
  zero differences; `/tmp/cpu-corpus100-gate.xeFext`. Initial invocation omitted
  required fixture arguments and exited before tests; corrected invocation used
  the immutable scripts/fixtures/corpus100 payload and baseline.
- Extended existing tb_ap040_regfile independent architectural model to four
  distinct simultaneous read addresses:16,485cycles,2,110,016readchecks each
  normally and with RAM-collision poisoning (7,697pending words). Both normal
  and extra-port bypass-disabled mutations are detected. run_tests.sh includes
  the new negative control. Logs in scratch/p5_rf_ports_20260919/regfile*.log.

Only nonfunctional unused-port tie-offs were added to the standalone pipeline
instance after its gate compile. No further functional change since validation.
Next: full P5 fit with same seed21 and existing feature recipe, source freeze.
P4 hardware trial remains active with mister_operator; no result accepted yet.


## ACTIVE P5 Quartus flow — source freeze

Candidate `e12d8829ce0afd1a43c0a29a2eebac8f6d6abafa` is committed and verified
running in `q800-p5-fit-20260919.service`, MainPID1078706. Quartus synthesis
has started. Do not edit RTL/QSF/QIP/SDC until this flow is terminal. Only one
Quartus flow may run anywhere on this box. Archive/launcher:
`scratch/p5_fit_20260919/`; expected unique RBF `MacQuadra800_p5_e12d882.rbf`.
Launcher checks source hashes, build exit and crossings and archives reports as
for P4. At completion inspect actual report dates/exits, CPU setup, holds,
SDRAM crossings and RAM inference (especially extra_reads.bank_c/bank_d MLABs).
Do not infer success from service status or an older output_files artifact.
Current root-side CPU validation jobs are all terminal and passed.
Operator `/root/mister_operator` is running the five P4 hardware trials; preserve
that session and wait for its report. Never switch to P5 mid-benchmark.
Latest accepted hardware median remains1.005; goal1.8 and release regressions
are unmet. A/UX-image-location question remains pending.


## P4 hardware finished; isolated P6 call exploration

Operator completed five valid P4 Mix runs1.002/1.006/1.005/1.005/1.004:
median1.005, mean1.0044, no invalid timer result, boot/clean halt passed.
Evidence `scratch/hardware_p4_20260919/p4_results.md` and screenshots. Final
screenshot independently checked. Original disk untouched; disposable selected.
Operator is now idle. P4 remains installed at clean halt and is timing-marginal.
No overall Mix gain versus LEA; Permute alone improved~2%.

P5 fit remains active (q800-p5-fit-20260919.service,MainPID1078706). Preserve
source freeze. No P5 hardware artifact/result yet.

Scratch-only P6 call experiment: `scratch/p6_calls_20260919/generate.py` adds
resident/even-target JSR d16(PC), an ordered return-address push and branch
retirement through go_pc with younger cancellation. Preserve PEA-only entry;
calls may continue an existing stream. Initial Permute result1524943cycles
regresses P5's1519907. A second variant `prefetch.py` issues the target fetch
before the stack push, mirroring the existing sequencer's overlap; it passes
Permute at1516199cycles, only0.244% fewer than P5. All kernel array/call/guard
checks passed. These are NOT correctness-qualified implementations: no new
call fault/trace/IRQ oracle, no fit, no hardware. Do not promote yet. The bench's
old pipe_stores counter counts call offers during prefetch and again at launch;
it is not an exact memory transaction count for that variant.

Current next measurement: forced-admission Towers exit profile in
`scratch/p6_towers_admission_20260919/`, runner run.py, process session66183.
It uses frozen P5 sources, not the call prototype. This is a diagnostic policy,
not the production PEA-entry policy. Check terminal result/summary.txt before
using counts. Aim for broader compiler instruction coverage rather than another
narrow gain. Older Towers current-IR attribution lists MOVEM push/pop~13.6%,
but inspecting current RTL shows load retirement already occurs on acknowledge
and stores issue in-place; do not reimplement those existing optimizations.


### P6 Towers coverage measurements completed

`scratch/p6_towers_admission_20260919/results.log`: P5 forced admission passes
at33,224,878cycles,1,719,589issues,1empty exit. Top exits e588 LSL.L#2,D0=343446,
3270 indexed MOVEA.W=147447,41ed LEA d16(A5),A0=98382,4eba JSRpc=98340.
This forced policy is diagnostic only and regresses production27,509,911cycles.
Normal unrestricted admission baseline also passes:29,000,193cycles,
1,252,397issues,2empty exits; top3270=147447,4eba=98298,e588=97617.
See normal_results.log/normal_summary.txt for full histogram.

Scratch shift/rotate prototype `scratch/p6_shifts_20260919/generate.py` reuses
ap040_alu's barrel shifter and adds immediate/register count decode with explicit
zero-count flags. All eight shifts/rotates and B/W/L encoded. NOT correctness-
qualified beyond kernel results; no exhaustive independent shift oracle yet.
Forced Towers passes32,537,882cycles (2.07% reduction vs matched forced P5),
2,063,089issues. Normal unrestricted Towers passes29,000,193cycles EXACTLY
unchanged vs its matched baseline despite1,350,068issues. Thus the apparent
forced-mode benefit does not translate to normal admission; do not promote
this feature on that evidence. Production PEA-only remains27,509,911cycles.
All kernel runs preserve moves/nodes/lists/guards. Artifacts include source
identity hashes, build logs and all exit counts. Simulator jobs have finished.

Next coverage target from normal-admission evidence: indexed MOVEA.W opcode3270
(147447exits), then indexed/memory-to-memory moves. Simply adding register shifts
or calls does not produce the broad gain required for1.8. The pipeline's drain
and memory-handshake costs need amortization across useful instruction streams.
P5 FPGA fit is still verified active/MainPID1078706; continue source freeze.


## User update: A/UX validation delegated to Dani

User explicitly confirmed on2026-09-19 that they do not have the A/UX disk:
“we can skip it. Dani can check it.” Skip the local A/UX regression for this
work; it is deferred to Dani and must not be claimed as passed. The disk-location
question is resolved, not a blocker. Continue CPU correctness, Mac boot/shutdown,
Speedometer validation and the remaining applicable hardware checks. No message
has been sent to Dani and no A/UX test has been performed.


## P5 fit terminal; hardware trial running

P5 unit q800-p5-fit-20260919.service is terminal/MainPID0/ExecMainStatus1.
Compile and placement succeeded; wrapper1 is HDMI timing miss, not CPU failure.
38,320ALMs91%,26,325registers,491RAM43DSP. CPU+.532ns, internal CPU-to-CPU
worst+.556ns, SDRAM+.665ns, hold+.202ns; sys->ram+1.016/ram->sys+.532ns.
Both new RF banks are512bitMLABs; cache tags/data retain RAM inference.
HDMI misses-.091ns shadowmask.dout[12]->hdmi_osd.nrdout1[12], -.008ns scaler.
Detailed CPU/HDMI reports and cross-domain reports are archived with fit data.
Source-check/cross exits0. Artifact hash independently verified:
`scratch/p5_fit_20260919/MacQuadra800_p5_e12d882.rbf`, SHA256
`4449b3c51a3e991515afe0440ce2da5aeab2d6175fbcda210f344d8841f037b1`.
P5 source freeze has ended. No new full Quartus flow is running. The later
TimeQuest CPU/HDMI extraction completed successfully at16:18:59EDT.

mister_operator is now running P5 five-run Mix validation on the disposable
disk at33MHz32MB, labelled HDMI timing-marginal. No accepted P5 result yet.
Use scratch/hardware_p5_20260919 for evidence. Never switch during timed tests.
Latest accepted hardware median remains1.005 (P4). Local A/UX is waived/deferred
to Dani per user; do not re-request the disk or claim A/UX passed.

## P6 broader indexed-memory experiment (scratch only)

Paths in progression (all under scratch/, no P6 feature is in tracked RTL):
- p6_indexload_20260919: brief indexed MOVEA.W/L and MOVE.L toDn. Normal
  unrestricted Towers28,656,161cycles vs matched P5 unrestricted29,000,193.
  Independent oracle:8,046retirements/3,072loads at delays0/1/3/8 and with/without
  CE/WB stalls. Request addresses/data/size, all RF/CCR and next-PC pass; full
  or missing extensions rejected. Wrong index-word and MOVEA.W sign extension
  mutations detected (oracle.log,negative.log). This does not yet cover faults.
- p6_indexshift_20260919 combines shifts: same28,656,161cycles; no extra gain.
- p6_indexshiftlea_20260919 adds LEA d16(An):27,552,105cycles, nearly production
  PEA-only27,509,911. Shifts now keep LEA in the same supported stream.
- p6_indexfull_20260919 adds byte/word indexed Dn loads and indexed register
  stores, with a fifth RF read bank (third for pipeline). This supplies base,
  index and store source / old partial destination concurrently with forwarding.
  Normal unrestricted Towers26,445,814cycles:3.87% below production,8.81% below
  matched unrestricted P5. All moves/nodes/lists/guards pass.
  Permute1,527,183cycles is0.48% ABOVE P5's1,519,907, so entry policy needs review.

Broader prototype full_gate.py is running (session75172) using scratch core,
module and RF; inspect full_gate.log for terminal result. Expanded load oracle
passes13,166retirements/5,120loads in all8schedules. Store oracle is running
(session79347), same5,120request scope and8schedules, inspect store_oracle.log.
These oracles use default-off shift/LEA parameters, isolating indexed memory;
shift/LEA still need independent coverage before promotion. The full real-core
suite exercises enabled features but is not exhaustive. New precise indexed
fault/trace/IRQ fixtures and a fifth-port collision-isolation test are still due.

Selective-entry performance probes are running: Towers session26461,
selective_results.log; Permute session81905,permute_selective.log. Both use the
existing AP040_PIPELINE_SELECTIVE rule. Read results before choosing policy.
Do not promote the prototype or claim hardware gain until correctness, fit,
RAM inference/timing and hardware runs are validated.


### P6 full gate / indexed fault checks completed

All P6 jobs listed above are now terminal and passed:
- full_gate.py session75172: full extended real-core suite, load/store/PEA,
  fault/trace programs and all four original IRQ/replay checks; full_gate.log.
- Expanded indexed load and store oracles each pass13,166retirements and
  5,120requests across8delay/stall schedules. The store oracle checks actual
  request PC/address/full source value/size, stable offers and all RF/CCR state.
- Selective policy: Towers26,550,438cycles; Permute1,526,387. Unrestricted:
  Towers26,445,814; Permute1,527,183. Existing production/P5:
  Towers27,509,911; Permute1,519,907. Selective trades104624Towers cycles for
  only796Permute cycles; no final hardware recipe selected from this alone.
- New real-core indexed faults (`p6_indexfull_20260919/faults/run.py`):
  MOVEA.W indexed, MOVE.W indexed-toDn, indexed MOVE.W store all pass three
  latency phases. Each has exactly3pipeline faulting launches,6younger cancels;
  exact PC600,FAf140,format7,CCR271f for reads/2718 for store, unchanged A0/A3,
  D1/D2/D3 verified. TRAP architectural prefetch guarantees pipeline admission.

Remaining P6 qualification before promotion: independent shift/LEA tests,
new indexed extension-fault/trace/IRQ cases, fifth-read-port collision isolation,
negative controls for new partial-merge/base-index-store logic, and the silicon
comparison with exact proposed entry policy. New feature fits/hardware tests
have not happened. Do not confuse standalone-memory oracle coverage with these
remaining integration cases. Track-only RTL is still P5; all P6 RTL is scratch.

P5 hardware trial is still in progress with mister_operator; four completion
screenshots were present at the last read-only filesystem check. Original disk
is untouched; A/UX remains explicitly deferred to Dani. No Quartus process was
left active after the completed TimeQuest extraction.


### P5 hardware complete; P6 independent qualification update

P5 five valid hardware Mix scores:1.002/1.005/1.006/1.006/1.006;
median1.006, mean1.0050, no invalid timer results. Boot/clean halt passed;
MiSTer and remote remain running with guest halted. Original disk untouched.
Operator completed; report in `scratch/hardware_p5_20260919/p5_results.md`.
Final screenshot independently inspected. Permanent measurements in section27
of docs/PERFORMANCE_MEASUREMENTS.md. Still HDMI-marginal, not a release.

New P6 checks completed in `scratch/p6_indexfull_20260919/`:
- `alu_oracle/run.py`: independent bit-by-bit shift/rotate and LEA arithmetic,
  all six schedules pass50,408retirements each. Includes CE/WB/input stalls,
  flush/replay, all register pairs and size/count edges, LEA signed d16/A7.
- `rf_check`: five-port oracle passes16,485cycles/2,637,520port checks, both
  normal and collision-poisoned runs (7,697pending words). Disabling fifth-port
  pending-write bypass is detected as expected.
- `boundaries/run.py`: indexed load/store extension fetch faults, trace and
  IRQ cases all pass. Extension faults launch no indexed pipeline requests;
  trace/IRQ each launch3, IRQ kills/replays3younger instructions. Exact frames,
  destination/store memory and no duplicate younger retirement checked.
- `negative_full.py`: six mutations all detected: incorrect partial Dn merge,
  wrong indexed-store base, missing third-operand forwarding, zero-count ROX
  carry, LEA displacement sign and ordinary destination forwarding. These are
  deliberate failures; original unmodified RTL passes the positive oracles.

Silicon first100comparison running in session47453; inspect `corpus100.log`.
Uses copied scratch RTL under `corpus_sources`, unrestricted entry (no PEA-only
or selective macro), pipeline/load/store/PEA and legacy XSTORE/LEA enabled.
P6 scratch core currently hardcodes new feature parameters enabled: convert to
explicit default-off feature flags before promoting and preserve reproducible
runners/fixtures. Still no P6 fit or hardware evidence, no new Quartus flow.
A/UX remains explicitly deferred to Dani and is not a blocker.


### P6 promoted and ready for the single fit

P6 is now tracked behind `AP040_EXPERIMENTAL_PIPELINE_P6`, default off in core;
QSF enables it with unrestricted entry, plus pipeline/load/store/PEA/XSTORE/LEA.
PEA-only admission explicitly matches PEA, not arbitrary two-word opcodes.
No hardware deployment yet. New design/reproduction note:
`docs/cpu-pipeline-p6-20260919.md`.

All promoted qualification terminal PASS:
- `scratch/p6_promoted_gate.log`: independent reference14,720snapshots plus
  full real-core14legacy suites, pipeline memory/fault/trace and4IRQ monitors.
- `scratch/p6_promoted_corpus100.log`: immutable first100,1,900matching field
  groups,0differences; artifacts `/tmp/cpu-corpus100-gate.tyK2py`.
- `scratch/p6_promoted_20260919/`: load/store oracles, fault/boundary runners,
  all6negativecontrols, RF5port normal/poison +3bypass controls. Strengthened
  ALU oracle61,424retirements per6schedules; restores high-bit seed patterns
  per source group. Reproduction scripts are `scripts/cpu/pipeline_p6_*.py`.
- Updated older standalone benches to tie the new optional ports; original
  prototype gate also passed all6schedules and2forwarding mutations.

Next: commit and launch one full Quartus flow, freeze RTL/QSF/QIP/SDC until
terminal, check RFbankE MLAB and cache M10Ks, timing and cross-clock reports,
then have authorized mister_operator run at least5valid hardware Mix trials.
A/UX skipped/deferred to Dani; other hardware regressions still apply.

### P6 full fit ACTIVE — freeze build sources

Committed P6 `d83e2389bbf5bbdf690e7e3d4eab5bb1ec2d64cb` launched at16:44:58EDT
in `q800-p6-fit-20260919.service`, MainPID1166285, active/running confirmed.
Evidence/archive directory `scratch/p6_fit_20260919/`; wrapper `run.sh` records
source hashes, terminal build/source-check exits, cross-domain extraction and
unique RBF/report copies. `quartus_sh` and `quartus_map` were running at last
check. Do not touch RTL/QSF/QIP/SDC or start another Quartus flow until this
service is terminal. Docs and scratch-only research remain allowed. No P6
hardware deployment has occurred; operator remains available, MiSTer halted.

### P6 fit live; P7 scratch stream experiment

Previous turn made progress: promoted/qualified/committed P6 and launched the
single fit. Current fit is confirmed live in the same systemd unit (no restart).
Synthesis succeeded with0errors; fitter physical synthesis is active. RAM Summary
confirms C/D/E512bitMLABs and cache tag M10K. Frozen-source hash recheck passed;
final fit/timing/cross-domain evidence remains pending.

Fixed a reproducibility error in `pipeline_p6_alu_oracle.py`: port-tie cleanup
had also removed the instruction-array expansion on the same line. Restored an
explicit32768→131072entry replacement. The original passing promoted test had
used the expanded fixture; the now-repaired tracked runner was rerun, all six
61,424retirement schedules PASS (`alu_oracle_recheck.log`). No RTL change.

Scratch-only follow-on `scratch/p7_stream_20260919/` adds register TST,
brief-indexed TST/CMP and d16(An) register MOVE loads/stores. Generated from P6
by generate.py; no frozen source edits, no fit or deployment of this prototype.
- Towers25,954,913cycles vs P6 unrestricted26,445,814 (-1.856%). All results,
  lists, nodes and guards pass. Pipelineissues3,315,359,emptyexits4.
- Permute1,552,349 vs P6 1,527,183 (+1.648% regression), all results/guards pass.
- Independent mixed memory oracle passes13,166retirements/5,120requests in all
  8delay/stall schedules, covering CMP/TST/indexedMOVE/d16MOVE semantics.
- Independent d16store oracle: same counts/schedules, all PASS.
- TSTregister+shift/LEA oracle:63,576retirements in6schedules, all PASS.
- Full real-core handoff gate is running session67367; inspect full_gate.log.
  New P7-specific fault/trace/IRQ and mutation controls still required.

A/B variant `scratch/p7_compare_20260919/` disables displacement loads/stores,
retaining only new TST/CMP support. Session56231 runs Permute then Towers;
read permute.log and normal_results.log. This isolates the regression before
selecting a follow-on. Do not promote either P7 variant from kernel scores alone.

### P7 A/B and fault results

The compare-only A/B is terminal: Towers26,004,071cycles (-1.6704% vs P6),
Permute1,527,183 (exactly unchanged vs P6). Both kernels' result/guard checks
pass. Removing displacement MOVE support avoids the +1.648% Permute regression
while retaining most Towers improvement. Prefer further qualification of
`scratch/p7_compare_20260919/` over promoting the broader stream unchanged.

Broader stream's3negativecontrols all detected (`negative.py`,negative.log):
wrong indexed-CMP destination operand, erroneous comparison register writeback,
wrong d16store displacement sign. Exact compare-only variant's indexed CMP.W
and TST.W real-core data-fault fixtures pass (`faults.py`,faults.log), each with
3faulting requests and6younger cancellations, exact PC/address/frame/CCR and
preserved Dn/An values. Full broad-stream gate session67367 still finishing:
legacy14suites and load/store faults passed at last check. It does not replace
new operation-specific extension/trace/IRQ tests or exact compare-only gate.

P6 Quartus unit still live (same MainPID1166285, quartus_fit1174605), currently
physical synthesis/register retiming. Latest frozen-source hash check passes.
No build restart, deployment, or additional hardware result this turn. Goal
remains active: latest hardware median1.006, required1.8not achieved.

Update: broad P7 full_gate session67367 is now terminal exit0. All remaining
PEA/fault/trace and four IRQ/replay checks passed, ending with real-core pipeline
ownership PASS. Exact compare-only integration and new-operation-specific
boundary tests remain pending as described above.
