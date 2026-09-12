# CPU validation update — 2026-09-12

Historical experiment sequence follows. Latest result supersedes the pending
statuses below: compact shared decode produced **0.447 / 0.447 / 0.447** and
was adopted into the active working tree. See
[the compact checkpoint](CPU_SHARED_DECODE_CHECKPOINT_20260912.md).

## FPGA fits

All builds use seed 22, CDROM_OFF=1; active full-feature QSF remains untouched.

| Candidate | ALMs | LABs | Free LABs | Worst setup slack |
|---|---:|---:|---:|---:|
| Accepted register dispatch | 38,130 | 4,124 | 67 | +0.076 ns |
| Memory ALU retirement | 37,782 | 4,152 | 39 | +0.190 ns |
| Original shared decode | 41,509 | 4,190 | 1 | +0.060 ns |

Both experimental fits pass timing with zero TNS. Reduced ALMs alone do not
guarantee improved fit: occupied LABs also matter.

Memory-ALU source SHA-256:
`448ff7c28c8cb8225ab6aae24e52b7856b10fafc0156f4ba17d33850fe566c4e`.
RBF SHA-256:
`f934f456edeaf2dfd74ab86dc62632bd955ba75340d12d1b8d564db8e904df38`.
First hardware pair: one impossible/invalid result; one plausible **0.440**,
visually reviewed by parent. This is not an accepted two-run mean.
Evidence: `scratch/perf_memalu_cdoff_seed22/memalu_run1.png`, `memalu_run2.png`.
Guarded cleanup verified MENU, golden disposable MD5, and unchanged Main.
Repeat validation is in progress, recording a warm-up and two subsequent runs.

Repeat result: warm-up 0.439, measured run 1 0.440, measured run 2 INVALID
(several impossible negative/near-zero timings). Parent visually reviewed both
measured screenshots in `scratch/perf_memalu_parentrepeat/`. This disproves a
first-run-only explanation. Do not accept the candidate or average away invalid
runs; a three-run control on accepted register-dispatch RTL is now assigned.
Run 1 SHA-256 `c9980d6a2b24ccfde13324a0146bd0ca7b55c0305ffef6a7da5146a6ddc223f6`;
run 2 SHA-256 `f3357d594994bc7b28e3f370e2423606ea6592f4bc52320deb30d40f9d411ac1`.
Valid run 1: KWhetstones 354.933, Dhrystones 5001.565, Towers 2.036,
Quick Sort 1.465, Bubble Sort 1.768, Queens 1.149, Puzzle 3.448,
Permutations 3.180, Integer Matrix 2.367, Sieve 3.316. Cleanup verified
MENU, golden disk MD5 and unchanged Main. Benchmark/timing versus CPU cause
remains unresolved; the control is necessary before attributing this anomaly.

Control complete: accepted register-dispatch first two runs score 0.434/0.435,
then its third run is likewise invalid (visually confirmed). Evidence in
`scratch/perf_regdispatch_control/run{1,2,3}.png`. This reproduces the anomaly
without today's memory-ALU change; it does not establish the underlying cause.
Coherent first-two means: memory 0.4395 versus control 0.4345 (+1.15075%);
memory versus 0.405 reference +8.51852%. Treat this as qualified evidence,
not proof of anomaly-free operation. Exact timer-path investigation is saved in
`SPEEDOMETER_TIMING_DIAGNOSTIC.md`. Timing-clean original shared decode is next
for the same three-run hardware sequence; compact seed 22 remains prohibited.

Original shared-decode source SHA-256:
`3188e5b9d24dcb0a5ccc865cdd4d150a40ac5c3ccdb54c0105e466173b7b7b87`.
Fit tree: `/tmp/MacQuadra800_shareddecode_20260912.UuI0ml`.
RBF SHA-256:
`493a045330bf0b8d486f99f28fe25aeb25761ba4c1ed8ed8910a38163ff0e27c`.
All eleven AP suites and full-machine compile pass. Focused phase-1/2 loop drops
122,788 to 109,788 clocks (-10.59% cycles); first-100 corpus is 34,829,460 clocks,
with 1,900 field groups matching and zero real differences. No hardware score yet.

Original shared-decode hardware sequence is now complete: first two runs
invalid, third coherent at **0.447**. No two-run mean is accepted. Third table:
KWhetstones 356.547, Dhrystones 5079.159, Towers 2.019, Quick Sort 1.403,
Bubble Sort 1.764, Queens 1.137, Puzzle 3.393, Permutations 3.153,
Integer Matrix 2.350, Sieve 3.153. Parent visually verified all ten values.
Evidence: `scratch/perf_shareddecode_cdoff_seed22/run{1,2,3}.png`; valid run 3
SHA-256 `a29bf6356b254ff0b5c147096b615f85030d52d25c653e6d3912ca973c043144`.
Guarded cleanup verified MENU, golden disposable, unchanged Main. Compact
seed-23 hardware validation is now assigned with the identical three-run method.
The larger prototype's score does not substitute for testing the compact RBF.

Extended comparison against accepted register dispatch: both original corpus
runs hit the 300,000,000-cycle limit, leaving 406 complete records each. Those
match 7,581 field groups, with seven classified environment reads and zero real
differences. This is partial equivalence evidence, NOT full-suite completion.

## Area refactor

Original shared decode is not accepted as default: only one LAB remains.
Map hierarchy shows +5,514 core-owned combinational ALUTs but only +9 in the ALU;
the main cost is control logic, not a second execution unit.

Separate Astra refactor: `/tmp/ap040-shared-compact.9MZsa0/ap68040`, core SHA-256
`5ab7603019ab43ffb10bcdc5ef80086d2b0a5b515abd7fdd64d9adfaf0d0f3ff`.
It centralizes descriptor dispatch after the state case and removes a global
shared-decode qualifier from unrelated legacy opcode families. Qualified queue
pop ordering, forwarding, flags, coverage, and profiling toggle are unchanged.
Directed integer checks retain identical cycles. Luna owns full regression,
corpus, full-machine compile and an isolated fit. Area savings are unmeasured.
Original fitted prototype and active memory-ALU source are preserved.

Later: all eleven suites and full-machine compile pass. Synthesis estimates
37,494 ALMs versus original shared-decode 41,121 and memory-ALU 37,469.
This encouraging reduction is a map estimate, not final fitted area/timing.

Final seed-22 compact fit: **37,952 ALMs, 4,111 LABs (80 free), 24,363 registers,
462 RAM blocks, 41 DSPs**. First-100 corpus exactly 34,829,460 cycles with 1,900
matching field groups and zero real differences; focused loop 109,788.
Timing gate FAIL: SDRAM setup -0.039 ns/TNS -0.039; CPU setup +0.486, worst
hold +0.240. Quartus flow exit zero does NOT mean timing passed. Do not deploy
RBF SHA-256 `d15459b5e96ec0d6ae2fe9edba008bee26034940dafae3192e9ba8a9d52668c9`.
Build: `/tmp/MacQuadra800_sharedcompact_0nWyIQ`.
Same RTL, unchanged constraints, seed-23 retry prepared at
`/tmp/MacQuadra800_sharedcompact_seed23.Ln2cjL`; only QSF SEED differs.

Seed 23 closes timing: **37,959 ALMs, 4,111 LABs (80 free), 24,355 registers,
462 RAM blocks, 41 DSPs**. Worst setup +0.330 ns (CPU +0.827, SDRAM +0.792),
hold +0.227; all setup/hold/recovery/removal/pulse TNS zero. Parent independently
checked reports and RBF SHA-256
`622667cace5c827770f8a7ec81d35e5b6bab3996e406eae18aaea9fbba4ead6f`.
Hardware acceptance remains pending. Compared to original shared decode,
this saves 3,550 ALMs and 79 occupied LABs without changing tested cycle counts.

Recurring invalid benchmark timings also predate today's work: see
RESUME-open-items.md correctness item 7 and PERFORMANCE_MEASUREMENTS.md's
earlier 0.405 reference. Cause remains unresolved; first-run-only is disproven.

## Recoverable source snapshots

- `checkpoints/cpu-regdispatch-20260912.patch`: accepted RTL from AP HEAD
  `250813f4bcec4467807a754279124b042feeeb89`, source SHA `a433214d9b776f8d4da9c824a39b638226e067c158de81b202ca1c3514a206f2`.
- `checkpoints/cpu-memalu-experimental-20260912.patch`: full CPU/test delta from
  that same AP HEAD, yielding memory-ALU source above.
- `checkpoints/cpu-shareddecode-experimental-20260912.patch`: incremental CPU/test
  delta **on top of the memory-ALU snapshot**, not AP HEAD, yielding original
  shared-decode source above.
- `checkpoints/cpu-sharedcompact-experimental-20260912.patch`: incremental core
  control refactor on top of original shared decode, yielding compact source
  `5ab7603019ab43ffb10bcdc5ef80086d2b0a5b515abd7fdd64d9adfaf0d0f3ff`.

Reconstruct in separate clean trees, never over unrelated dirty RTL.
Parent reconstructed this complete experimental chain from an AP HEAD archive
and verified all three intermediate core SHA-256 identities.
These files are not committed/pushed.

`checkpoints/sim-dispatch-toggle-experimental-20260912.patch` preserves isolated
profiling/trace corrections. It applies to the current dirty simulator source
SHA-256 `c0a33aa5019b18e06252e801531f31a93042360a00d8378414a04a3dcc209023`,
not repository HEAD, and requires toggle-bearing CPU RTL. Do not apply alone
to the active memory-ALU core. Focused observer tests and syntax checks pass.

The combined headless/profile patch and handoff are also preserved under
checkpoints/. Linked simulator at
`/tmp/MacQuadra800_compact_headless_cqHqCr/verilator/obj_dir/Vemu`, SHA-256
`9b126de2411b1391392240a0e919c22cc8475c4e1d5892b5c12eaaaab9d918d0`, passes
both helper tests. A bounded 10M-edge boot smoke exits zero, records 1,000,002
sampled clocks / 266,327 dispatches and writes screenshot_f3.png. Parent viewed
the image: it is black at this early boot point. This proves file output and
profiling integration, NOT Mac desktop readiness or a Speedometer profile.
Longer bounded boot readiness and the new corpus-wrapper gate are assigned.
Xvfb is no longer required for this optional headless path.

Corpus wrapper end-to-end PASS: `/tmp/cpu-corpus100-gate.7wYqvc`, 33.294 s,
34,829,460 cycles, exactly 100 records / 1,900 matches / zero REAL differences.

The first longer headless attempt omitted the +rom option while copying only
the fast-boot filename; stdout explicitly warned that quadra800.rom.hex was
missing. Its advancing invalid PC/black output is a fixture failure, not CPU
evidence. Corrected explicit-ROM run:
`/tmp/MacQuadra800_headless_boot_rom_obZrYZ`, exit zero at 450M half-cycle edges.
DAFB/NCR/SCC activity and ROM execution are visible; frame239 shows a gray
640x480 startup area within the 800x600 buffer. Frame478 has the same hash
`c6940fbc481ff1beb259da0115f23bcb15fd206f975f3964cdaada1ef69525b7`.
No desktop or actual Speedometer profile yet. BERR events occurred without
halting; their cause has not been diagnosed. Do not equate bounded smoke exit
zero with complete guest boot. Heartbeat instr=0 with --no-cpu-trace is only
the disabled trace counter, not proof of no CPU execution.

## Hardware automation

A tester mistakenly loaded the Main ELF as an RBF and restored a disk without
verified MENU. Parent recovered using actual menu.rbf and restarted unchanged
Main. No result from that incident counts. `scripts/cpu_benchmark_core.sh` now
enforces bitstream targets, hashes, MENU-before-restore, and expected Main/core
transitions. Testers must use it and stop on failures, not invent recovery.

A later tester mistook an outer tool completion for a child command's exit,
then restored while navigation was still running. No benchmark was collected.
AGENTS.md now requires polling nested session IDs to actual exit codes before
cleanup. Root resumed setup; the Finder desktop visible during boot was transient
before MacAtrium launched, so readiness requires the final settled application,
not merely a Finder snapshot early in startup.

After visually confirming fresh MacAtrium, use:
`bash scripts/guest/speedometer402_setup.sh --macatrium-ready scratch/perf_NAME`.
This captures stages of the verified Finder route with slower typing. Run Set
is left unstarted; exit zero proves command delivery only. Visually verify the
final screenshot before starting timing. Never invoke from an arbitrary state.

Exact simulator Speedometer profiling remains blocked by unavailable Xvfb and
unresponsive local X11. The shared-decode prototype exports a dispatch toggle;
the old state-based profiler must use that before reporting CPI for bypass RTL.
