# CPU performance task list and recovery record

Last updated: 2026-09-12. This is the authoritative CPU-speed queue and the
first file to read after a power loss or a new session. Measurements and
screenshots remain in `docs/PERFORMANCE_MEASUREMENTS.md`.

## Current checkpoint and hardware access (2026-09-12)

**Latest tested CD-ROM-off checkpoint: compact shared decode, Speedometer 4.02
CPU Mix 0.447 / 0.447 / 0.447.** Parent visually verified all three, recovering
the missing local second capture from MiSTer's archive. This is +2.87687% over
0.4345 and +10.37037% over the full-feature 0.405 reference. Seed 23 fits at
37,959 ALMs, 4,111 LABs (80 free), setup +0.330 ns / hold +0.227 ns, zero TNS.
Compared with register dispatch it saves 171 ALMs and 13 LABs. Active CPU,
integer tests and simulator profiling/control now match the validated isolated
sources; final active-tree CPU checks passed. No commits/pushes yet. Main and
golden disk remain unchanged; MiSTer is restored to MENU. Details and the exact
RBF/source identities are in `docs/CPU_SHARED_DECODE_CHECKPOINT_20260912.md`.

The committed full-feature reference scores 0.405 in Speedometer 4.02 CPU
Benchmark Mix. The hardware-tested register-ALU capture/retirement experiment
scores 0.423 and 0.424 (average 0.4235, +4.57%) in a temporary CD-ROM-off build.
It is recoverable in the AP stash named "validated reg-ALU capture retirement,
CD-off hw 0.4235"; it is not yet a committed replacement for the reference.

The register-dispatch layer passes all eleven CPU suites, the full-machine
compile/link, and the identical first-100 corpus: 34,941,315 clocks versus
35,370,929 (-1.21%), with zero real architectural differences. Seed 22 fits at
38,130 ALMs and 4,124 LABs (67 free), with worst slack +0.076 ns and zero
negative-TNS groups. Clean-disk Speedometer 4.02 repeats now score 0.434 and
0.435: mean 0.4345, +2.5974% versus 0.4235 and +7.2840% versus 0.405.
This is the previous hardware-validated CD-off checkpoint, preserved for recovery.
An earlier impossible-negative timing run is excluded. The disposable was
restored after testing. A four-site immediate-register bypass saved zero corpus
clocks and was removed. Recovery: `RESUME-cpu-cdoff-regalu.md`; latest evidence:
`docs/CPU_OPTIMIZATION_LOG_20260912.md` and
`scratch/perf_regdispatch_cdoff_seed22/verified_run{1,2}.png`.

The preceding memory-ALU-only experiment measured:
34,838,648 corpus clocks (-0.294%), all eleven suites and 1,900 field groups
passing, full-machine compiled. Seed 22 is timing-clean at 37,782 ALMs but 4,152
LABs (39 free); plausible 0.439/0.440 runs coexist with invalid timing runs.
This intermediate experiment was superseded by the accepted compact build.
A larger shared-decode/forwarding
prototype is isolated under /tmp, passes all eleven suites and the first-100
corpus, and reduces focused-loop cycles 122,788 -> 109,788 (-10.59%). Its corpus
gain is only 9,188 clocks (-0.0264% versus memory-ALU); fit is timing-clean but
uses 41,509 ALMs and 4,190 LABs (one free). It had one coherent 0.447 hardware
run and two invalid runs; the compact variant below supersedes it.
A separate compact-control variant passes all eleven suites and full-machine
compile and identical corpus/loop checks. It fits 37,952 ALMs/4,111 LABs (80
free), but seed 22 misses SDRAM setup by 0.039 ns: do not deploy. Same-RTL seed
23 now passes all timing at 37,959 ALMs/4,111 LABs, +0.330 ns setup and zero
TNS. Compact hardware testing passed with three coherent 0.447 runs; the
intermittent stopwatch anomaly remains open. Historical recovery patch baselines:
`docs/CPU_VALIDATION_UPDATE_20260912.md`. Simulation is not hardware speedup.

The user explicitly released the FPGA after Apple-II on 2026-09-12; Mac CPU
hardware testing may continue. Obey any later user reservation.

Follow `AGENTS.md` and `docs/AGENT_TESTING_WORKFLOW.md`: Astra owns architecture,
code, diagnosis, and acceptance; Luna runs established tests and Speedometer
with exclusive FPGA ownership. Use concise handoffs and return evidence to
Astra instead of supervising each GUI action with expensive model turns.
Test agents must now use `scripts/cpu_benchmark_core.sh` for deployment/cleanup;
ad-hoc core loading and disk overwrites are prohibited after a tester attempted
to load the Main executable as an RBF. Parent recovered unchanged Main and Menu;
the guard's real restore path was verified successfully.

The area narrative below records earlier checkpoints; use this current
snapshot and the ordered Priority 3 roadmap for new pipeline work.

## Immediate answer: should area be reduced?

**Completed; the recovered headroom is now buying speed.** Reducing ALM/LAB
use did not directly increase emulated CPU throughput. The FPU and two DAFB
reclaim passes lowered the timing-clean design from 40,738 to 36,592 ALMs and
from 4,182 to 4,080 LABs. The CMP checkpoint then reached 36,446 ALMs and 4,063
LABs, leaving 128 LABs free. The accepted inline-retirement front end consumes
36 of those LABs and improves Speedometer CPU PR by 4.62%. Resident-immediate
consumption then adds 233 ALMs but recovers seven LABs relative to that fit and
improves CPU PR by another 2.07%. The trade remains worthwhile: the current fit
adds a DBcc-only resident-target dispatch for another 0.88% CPU PR and is
37,063 ALMs and 4,122 LABs, with 69 LABs free. Profiling then identified
instruction fetch as a broad dynamic cost rather than another isolated opcode
family. The accepted one-longword sequential I-cache lookahead adds 294 ALMs
and 30 LABs, reaches 37,357 ALMs and 4,152 LABs (39 free), and improves the
hardware CPU benchmark average by 2.71% and CPU PR by 1.21%. Integrating the
upstream cache-race and packed-decimal FPU-frame fixes is cycle-neutral; its
timing-clean seed-33 placement uses 37,131 ALMs and 4,118 LABs (73 free).
The first staged-overlap probe, an exact `ADD.L Dn,Dn` predecode, was rejected:
it cost 271 ALMs and 23 LABs for only +0.60% CPU PR and +0.18% CPU benchmark
average. The accepted lookahead is the first profile-directed overlap step;
with 73 LABs free, the next speed change must either be very compact or be
paired with another area reclaim.

LAB availability remains the more urgent number. The MLAB-backed FPU register
bank recovered 1,380 ALMs but only six LABs. Explicit CPU/scanout copies of the
DAFB palette then moved the unintended 6,144-flop read mirror into three more
M10Ks, recovering another 2,833 ALMs and 77 LABs. Continue toward the initial
practical milestone of **100 LABs and 1,000 ALMs** relative to the old ADD
checkpoint, without disabling the MMU, FPU, caches, video, audio, or other
machine features. Combining the 17 DAFB timing words in one MLAB then saves 67
ALMs and 16 LABs against the same-seed palette control. The milestone is met:
the accepted seed-28 fit is 4,146 ALMs and 102 LABs below the old seed-27 ADD
checkpoint. The accepted CMP fit extends that cumulative result to 4,292 ALMs
and 119 LABs, with 128 LABs free.

The pre-reclaim seed-27 hierarchy report says where to work:

| hierarchy | fitted ALMs needed | implication |
|---|---:|---|
| complete design | 40,738--40,755 | 97%; fitting is the constraint |
| `wombat_cpu` | about 24,783 | about 61% of the whole FPGA |
| `ap040_core` | about 23,565 | primary target |
| core sequencer/decode excluding named children | about 15,947 | best first area target |
| `ap040_fpu` | about 5,209 | second target; preserve 040 behavior |
| `ap040_alu` | about 1,559 | investigate sharing after decode |
| `ap040_mmu` | about 756 | relatively small |
| `ap040_regfile` | about 436 | low priority; asynchronous ports buy speed |
| `ap040_cache` | about 366 plus M10Ks | already mostly in block RAM |

That report estimated roughly 493 CPU ALMs could be recovered by denser packing,
but also reports roughly 799 ALMs unavailable to that hierarchy. This reinforces
that routing/packing structure matters alongside raw Boolean count.

## Accepted checkpoint: preserve this

- Parent repository branch: `cpu-sdram-handoff-seed15`
- Parent remote: `https://github.com/alanswx/wombat33_MiSTer.git`
- Parent RTL commit: `c6c6d91` (`Integrate upstream AP68040 correctness fixes`)
- AP68040 branch: `wombat-upstream-fixes`
- AP68040 remote: `https://github.com/alanswx/AP68040.git`
- AP68040 commit: `299cb36` (upstream cache race and FPU frame fixes)
- Quartus seed: 33
- Exact preserved build:
  `/home/alans/builds/wombat33_cpu_upstream_fixes_seed33_20260905`
- MiSTer RBF:
  `/media/fat/_Unstable/Wombat33_CPU_upstream_fixes_seed33_20260905.rbf`
- MD5: `6147a2cc478f084c1ea77c2bb418811a`
- SHA-256: `cc1088e7639bf0662a4a6d59558fe77c333ff8e5037c6251c55117f59df25a68`
- Quartus: 37,131/41,910 ALMs; 4,118/4,191 LABs; zero setup/hold TNS
- Setup slack: +0.145 ns overall/CPU, +0.911 ns SDRAM, +0.482 ns HDMI
- Hold slack: +0.244 ns overall, +0.434 ns CPU, +0.256 ns SDRAM
- Controlled performance baseline: CPU 5.195, Graphics 6.074, Disk 0.680, Math
  34.011, Old PR 7.437, New PR 2.362
- Controlled CPU benchmark average: 13.588, up 2.71% from 13.230
- Integrated hardware: Mac OS full-color boot and all six Speedometer groups
  passed as a functional soak; no new performance delta is claimed
- Focused `bench_loop`: 160,650 cycles, 0.376% below the DBcc checkpoint
- First 100 SingleStepTests rows: 32,841,589 cycles, 1,696 field groups,
  zero real differences

The performance-control fallback remains parent `f846901`, AP68040 `8951fd2`,
exact build `/home/alans/builds/wombat33_cpu_icache_lookahead_seed32_20260905`,
and MiSTer RBF `Wombat33_CPU_icache_lookahead_seed32_20260905.rbf` (MD5
`202f64a6d77495db9f090b57eda9efc8`). Do not overwrite either checkpoint.
Experiments use the disposable remote tree and a separately named RBF. The
disposable Mac disk is always restored from the compressed golden after a safe
guest shutdown.

## Completed 2026-09-05: upstream AP68040 correctness sync

- [x] Replay upstream's NeXTSTEP MMU loadable-kernel-server fault shape,
  including supervisor transparent-translation windows, SRP selection,
  pointer retarget plus `PFLUSH`, and descriptor U/M-bit writeback checks.
- [x] Block ordinary cache reads while a displaced `store_inv_lost`
  invalidation is pending, and retain the local store-hit update plus
  instruction-lookahead invalidation behavior. The directed cache race is T13.
- [x] Prepare the required BUSY frame, packed-decimal operand payload, and
  command-time FPIAR when trapping unsupported packed-decimal FPU operations.
  Upstream FPU test 650 passes in all three memory phases.
- [x] Run the complete AP suite, full-machine Verilator build, first 100 CPU
  rows, all 270 FPU rows, and all 8 save/restore rows. Every differential
  corpus reports zero real differences; the focused and first-100 cycle counts
  remain exactly 160,650 and 32,841,589.
- [x] Reject seed 32 at -0.321 ns CPU setup, then accept seed 33 with zero TNS:
  37,131 ALMs, 4,118 LABs, +0.145 ns setup overall/CPU, +0.911 ns SDRAM setup,
  +0.244 ns hold overall, +0.434 ns CPU hold, and +0.256 ns SDRAM hold.
- [x] Boot Mac OS 7.5.5 in full color and complete every Speedometer group as
  a hardware functional soak. Shut down safely, return to `MENU`, restore the
  disposable disk, and verify both disk copies at MD5
  `0c4f774b4a2eccd5656e92f16119875f` and the golden gzip at
  `671894be51b1cd1e0c0c8fb4ec39173e`.

This sync fixes correctness bugs and does not introduce a performance claim.
Keep the controlled I-cache-lookahead scores as the speed baseline.

## Completed 2026-09-05: sequential instruction-cache lookahead

The measured Speedometer CPU interval showed 167,686,915 raw instruction-fetch
requests and 10.6% cache-state occupancy at the accepted DBcc checkpoint. A
one-longword lookahead now retains the next sequential word on an I-cache hit,
provided it remains inside the current 16-byte line. An exact physical-address
and way match can acknowledge the following instruction request directly from
idle; hits may chain and survive unrelated D-cache traffic. Reset, `CINV`, a
nonmatching instruction request, and every unsafe boundary clear the entry.
There is no speculative bus request and no speculative PC update.

The simulation Speedometer CPU average rises from 13.550 to 13.968 (+3.08%).
The candidate records 96,214,523 lookahead hits, equal to 64.48% of dynamic
dispatches; raw instruction fetches fall to 151,112,038 and cache-state
occupancy falls to 5.7%. Total profiled CPU clocks fall from 1,856.5 million to
1,797.5 million, while clocks per dispatch fall from 12.37 to 12.05.

All acceptance gates pass: the complete AP68040 reset, double-fault, walker
CDC, 16-bit bus-gap, timeout, cache-snoop, integer, and exception suites; the
full-machine Verilator build; the focused loop; and the first 100
SingleStepTests rows. The focused loop saves 606 cycles (0.376%); the
first-100 run remains exactly 32,841,589 cycles with all 1,696 field groups
matching and zero real differences.

Quartus seeds 30 and 31 were rejected for timing. Seed 32 closes every setup
and hold domain with zero TNS at 37,357 ALMs, 4,152/4,191 LABs, 24,026 fitted
registers, and 428 RAM blocks. Against the DBcc checkpoint this costs 294 ALMs
and 30 LABs. The controlled hardware `Run ALL Tests` result is CPU 5.195,
Graphics 6.074, Disk 0.680, Math 34.011, Old PR 7.437, and New PR 2.362. The
CPU benchmark average rises from 13.230 to 13.588 (+2.71%); CPU PR rises 1.21%.

The exact RBF booted Mac OS 7.5.5, completed every Speedometer 3.23 test, and
reached the safe-to-switch-off screen. MiSTer is back at `MENU`. The disposable
and pristine-reference disks both match MD5
`0c4f774b4a2eccd5656e92f16119875f`, and the golden gzip matches
`671894be51b1cd1e0c0c8fb4ec39173e`. See measurement section 32 and the
accepted-checkpoint block above for exact source and artifact identities.

## Completed 2026-09-03: DAFB palette in explicit M10K mirrors

The DAFB palette formerly presented one write port plus independent CPU and
scanout read ports through three arrays. Quartus inferred one 6,144-bit M10K
copy and implemented the second read view as 6,144 flip-flops. The candidate
uses explicit CPU and video mirrors, writes both, and registers the three video
outputs in their own `clk_vid` process. Quartus now infers six simple-dual-port
M10Ks while preserving the existing one-pixel registered lookup.

- Local/remote `rtl/dafb.sv` MD5: `6cea7041a458c2627d26e710ebb17f59`
- Focused independent-clock palette readback/scanout test: pass
- Full-machine Verilator build: pass
- First 100 SingleStepTests rows: 35,196,127 cycles, 1,696 matching field
  groups, zero real differences
- Seed-27 fit: 36,525 ALMs, 4,099/4,191 LABs, 24,187 registers, 428 M10Ks,
  zero setup/hold TNS
- Change from the FPU-MLAB checkpoint: -2,833 ALMs, -77 LABs, -6,056
  registers, +3 M10Ks, +6,144 block-memory bits
- Cumulative change from the old ADD checkpoint: -4,213 ALMs and -83 LABs;
  17 more LABs remain to the 100-LAB milestone
- Setup: +0.447 ns overall, +0.587 ns CPU, +0.552 ns SDRAM
- Hold: +0.244 ns overall, +0.251 ns CPU, +0.442 ns SDRAM
- Exact preserved build:
  `/home/alans/builds/wombat33_dafb_palette_m10k_seed27_20260903`
- RBF: `/media/fat/_Unstable/Wombat33_DAFB_palette_m10k_seed27_20260903.rbf`
- RBF MD5: `c43a310d2c39171e4be7f781904405c4`
- RBF SHA-256:
  `6dbbd34b30d767a32255049cb0e2dad3a9f75dc6454344ac24da9c881d29037c`
- Hardware: Mac OS and full-color video boot correctly. Speedometer 3.23
  `Run ALL Tests` completed: CPU 4.726, Graphics 5.430, Disk 0.683, Math
  31.538, Old PR 6.810, New PR 2.295, FPU average 2.446, and Color average
  1.618. This is no measurable throughput change, as expected for area-only
  work.
- Mac OS reached the safe shutdown screen, the MiSTer returned to its menu,
  and both disposable and pristine disks matched MD5
  `0c4f774b4a2eccd5656e92f16119875f` after the golden restore.

## Completed 2026-09-04: DAFB timing registers in one MLAB

The ten `hparam` and seven `vparam` words are now one power-of-two 32x12
MLAB-backed array. Register selectors `$09` through `$19` retain the same bus
addresses and map contiguously into it. Against the palette-only seed-28
control, synthesis falls 319 cells and the fit saves 67 ALMs, 16 LABs, and 197
registers for 384 additional MLAB bits. The accepted fit is 36,592 ALMs,
4,080/4,191 LABs, 23,944 registers, 428 M10Ks, and 1,664 MLAB bits.

Seed 28 is timing-clean at +0.291 ns setup overall (+0.862 ns CPU/+0.291 ns
SDRAM) and +0.243 ns hold overall (+0.254 ns CPU/+0.433 ns SDRAM), with zero
TNS. Seed 27 is rejected despite its smaller 36,463-ALM/4,070-LAB fit because
SDRAM setup is -0.453 ns with -0.692 ns TNS.

The focused timing/palette test, full-machine Verilator build, and first 100
SingleStepTests rows all pass; the CPU corpus remains 35,196,127 cycles with
1,696 matching field groups and zero real differences. Hardware booted Mac OS
7.5.5 in full color and completed every Speedometer 3.23 `Run ALL Tests`
category. Progress screenshots perturbed Graphics and Disk, so that run is a
functional soak rather than a controlled speed comparison; CPU remained 4.726
and the later untouched Math/FPU/Color results remained at 31.565/2.453/1.613.
Mac OS then reached the safe shutdown screen, the MiSTer returned to its menu,
and both disk copies matched `0c4f774b4a2eccd5656e92f16119875f` after restore.

## Completed 2026-09-04: narrow `CMP.L Dn,Dn` preselection

AP68040 commit `d543f2d` selects both asynchronous register-file ports while
decoding the longword data-register form of CMP and enters `S_PIPE_REGS`,
bypassing only `S_PIPE_START`. All other CMP sizes and addressing modes retain
the original path. Parent RTL commit `b0e6174` records the submodule pointer.

- Complete AP68040 suite and full-machine Verilator build: pass
- Focused `bench_loop`: unchanged at 212,238 cycles; that loop contains no
  eligible CMP instructions
- First 100 SingleStepTests rows: 35,168,444 cycles, saving 27,683 cycles
  (0.0787%), with 1,696 matching field groups and zero real differences
- Same-seed fit versus the timing-MLAB checkpoint: 36,446 ALMs (-146),
  4,063 LABs (-17), 23,938 registers (-6), and 1,664 MLAB bits (unchanged)
- Timing: +0.133 ns setup overall/SDRAM and +1.192 ns CPU; +0.242 ns hold
  overall and +0.245 ns CPU; zero setup/hold TNS
- Hardware `Run ALL Tests`: pass; controlled PR scores are CPU 4.765,
  Graphics 5.394, Disk 0.676, Math 31.480, Old 6.808, and New 2.280
- CPU improves 0.83% from the unperturbed 4.726 control. The small changes in
  non-CPU categories are treated as run variance because the RTL change is
  confined to CPU register CMP decoding.
- Mac OS reached the safe shutdown screen, the MiSTer returned to `MENU`, and
  the disposable disk was restored to MD5
  `0c4f774b4a2eccd5656e92f16119875f`; the untouched golden gzip remains
  `671894be51b1cd1e0c0c8fb4ec39173e`.

This is the new accepted checkpoint. Area trimming is no longer the active
goal. Profile and improve higher-occupancy CPU paths next; do not spend more
builds on unranked opcode-family copies.

## Completed 2026-09-03: first ALM/LAB reclaim pass

The accepted AP68040 commit `8231eec` contains the cumulative structural work
below. Intermediate fits are retained here so future work does not repeat the
same attractive-looking failures.

1. Reset is no longer applied to the instruction/refill payload arrays or the
   four-word MOVEM16 buffer. Their existing count/valid/state controls prevent
   consumption until the payload has been written. Quartus infers `m16buf` as
   a 4x32 simple-dual-port M10K (128 bits). The complete AP68040 suite, focused
   loop at 212,238 cycles, full-machine Verilator build, and first 100
   SingleStep rows at 35,196,127 cycles/1,696 matching field groups/zero real
   differences pass. Seed 27 with the normal speed mapper is timing-clean at
   40,730 ALMs and 4,177/4,191 LABs, only 8 ALMs and 5 LABs better than the
   old ADD checkpoint. Setup is +0.195 overall/+0.377 CPU/+0.312 SDRAM; hold
   is +0.139 overall/+0.250 CPU/+0.434 SDRAM. This is evidence, not yet an
   accepted commit.
2. The FPU now captures FPn once at command dispatch, reuses its existing
   exception shadow for later exception frames, and reuses the corresponding
   unpacked `b_*` operand through arithmetic/compare. This removes a late
   80-bit asynchronous destination-bank read. On its own this lowers the
   synthesis netlist from 80,910 to 80,688 logic cells and the FPU hierarchy
   from 8,462 to 8,226. AP tests, the 212,238-cycle focused loop, full-machine
   Verilator, first-100 CPU, all FPU, save/restore, and integration corpora all
   pass. Its seed-27 fit is timing-clean at 40,044 ALMs but still consumes
   4,189/4,191 LABs; setup is +0.166 overall/+0.742 CPU/+0.672 SDRAM and hold
   is +0.175 overall/+0.175 CPU/+0.431 SDRAM. It proves the logic reduction is
   real but does not by itself improve physical packing.
3. The next extension makes FMOVEM stores reuse the ordinary FP source-bank
   read port. `S_FPU_MVM` selects `fpu_srcr` and the existing `S_FPU_MVM2`
   setup cycle preserves the interface timing; FMOVEM loads retain the
   independent `fm_sel` write port. Exact local/remote hashes are core
   `b376c7fd9df452cce9237c6d21fbdb3c` and FPU
   `7b3bfaa98cb3e73af44ad2ac2399c31b`. Synthesis falls again to 80,475 logic
   cells and the FPU hierarchy to 8,036, respectively 435 and 426 below the
   reset-payload baseline. AP tests, focused loop, full-machine build,
   first-100 CPU (35,196,127 cycles/1,696 matches), all 270 FPU rows (5,000
   matches), all 8 save/restore rows, and all 1,328 integration rows pass with
   zero real differences. The seed-27 fit is timing-clean at 39,873 ALMs but
   still occupies 4,191/4,191 LABs. Setup is +0.091 overall/+0.673 CPU/+0.379
   SDRAM and hold is +0.254 overall/+0.264 CPU/+0.433 SDRAM. The fitter places
   40,650 physical ALMs, calls 1,912 recoverable by dense packing, and loses
   1,135 to packing constraints (115 LAB-wide signal conflicts and 1,020 LAB
   input limits). Keep this as a useful logical-area result, but it does not
   pass the physical-headroom gate by itself.
4. Adding an 8-bit validity mask after reducing the register bank to two read
   views passes every simulation corpus and lowers synthesis to 80,256 logic
   cells, with 7,354 in the FPU. Its seed-27 fit is smaller at 39,735 ALMs and
   4,185/4,191 LABs, but fails timing at -0.033 ns setup overall and -0.205 ns
   SDRAM hold. This is not the accepted form.
5. The accepted form mirrors the 8x80 architectural FP bank into two inferred
   simple-dual-port MLAB memories, giving two asynchronous command-time reads
   and one shared synchronous write. Quartus uses exactly 1,280 MLAB bits in
   eight Memory LABs. Synthesis falls to 79,252 logic cells, 1,469 below the
   prior accepted build; the FPU falls from 8,462 logic cells/2,243 registers
   to 7,091/1,617. The seed-27 fit is timing-clean at 39,358 ALMs and
   4,176/4,191 LABs. It places 40,166 physical ALMs, estimates 1,876 recoverable
   by dense packing, and loses 1,068 to constraints (99 LAB-wide signal
   conflicts and 969 LAB input limits). Setup is +0.290 ns overall/+0.649 CPU/
   +0.591 SDRAM; hold is +0.244 overall/+0.262 CPU/+0.434 SDRAM. Exact source
   hashes are core `b376c7fd9df452cce9237c6d21fbdb3c` and FPU
   `4491c1186f6e7a09b8dbb507d0ca436d`.

   The AP suite, 212,238-cycle focused loop, full-machine Verilator build,
   first-100 CPU corpus, all 270 FPU rows, all 8 save/restore rows, and all
   1,328 integration rows pass with zero real differences. Hardware booted and
   completed Speedometer 3.23 `Run ALL Tests`; the comparable PR scores are
   4.726 CPU, 5.452 Graphics, 0.685 Disk, 31.512 Math, 6.814 Old PR, and 2.301
   New PR. This is no measurable speed change, as expected for area-only work.
   Mac OS reached the safe shutdown screen, the MiSTer returned to `MENU`, and
   the disposable and pristine disks were verified at MD5
   `0c4f774b4a2eccd5656e92f16119875f` after the golden restore.

Rejected tool and structural experiments:

- Removing reset only from `m16buf` reduces the synthesized CPU hierarchy by
  97 combinational ALUTs, but its seed-27 fit spreads 39,805 ALMs across every
  LAB (4,191/4,191) and misses HDMI setup by 0.258 ns. Reject that isolated
  form; the large fitted-ALM swing is placement, not a credible RTL delta.
- FPU-only `OPTIMIZATION_TECHNIQUE AREA` and global `OPTIMIZATION_MODE
  BALANCED` both synthesize the exact same 80,910-logic-cell netlist as the
  normal settings. Reject both as no-ops.
- Routing all 218 sequencer transitions through one explicit `state_next`
  carrier passes the AP suite, focused 212,238-cycle loop, full-machine
  Verilator build, and first 100 SingleStep rows with zero real differences.
  Reject it anyway: Quartus still does not recognize `state` as an FSM, the
  complete synthesis netlist grows by 217 logic cells, and the CPU hierarchy
  grows to 36,505 combinational ALUTs. The working tree has been restored to
  the pre-experiment payload/M10K form.
- Adding a `syn_encoding="onehot"` hint to the existing state register is not
  sufficient either. Quartus still does not extract the main FSM and the
  complete synthesis netlist grows by 61 logic cells. Reject and remove it.
- Global `OPTIMIZATION_TECHNIQUE AREA` produces a smaller synthesis netlist
  (80,166 versus 80,910 logic cells) and a 39,578-ALM fit, 1,160 below the
  accepted checkpoint. Reject it: packing worsens to 4,190/4,191 LABs and the
  seed-27 fit misses setup by 0.342 ns. CPU/SDRAM setup is +0.814/+0.109 ns and
  overall hold is +0.239 ns, but the complete design gate is not met.
- Raising `ALM_REGISTER_PACKING_EFFORT` from `MEDIUM` to `HIGH` is a complete
  no-op for this netlist and seed: 40,730 ALMs, 4,177/4,191 LABs, and every
  reported setup/hold value exactly match the normal-packing fit. Restore
  `MEDIUM`.
- Changing `QII_AUTO_PACKED_REGISTERS` from `NORMAL` to `MINIMIZE AREA` is
  likewise a complete no-op on the accepted FPU-MLAB netlist and seed 27:
  39,358 ALMs, 4,176/4,191 LABs, 30,243 registers, +0.290 ns setup, and
  +0.244 ns hold all match exactly. Restore `NORMAL`; Quartus is already
  applying the useful register packing available to this netlist.
- Replacing reset writes to the 640-bit FP0--FP7 payload with an 8-bit valid
  mask passes the AP suite, the 212,238-cycle focused loop, full-machine
  Verilator, the first 100 CPU rows, all 270 FPU rows, all 8 save/restore rows,
  and all 1,328 CPU/FPU integration rows with zero real differences. It also
  lowers the FPU synthesis hierarchy from 8,462 to 7,835 combinational
  functions. Reject it anyway: its four validity-gated asynchronous read views
  fit at 40,986 ALMs and 4,190/4,191 LABs, versus 40,730 and 4,177 for the
  reset-payload candidate. Timing is clean (+0.147 overall/+0.664 CPU/+0.558
  SDRAM setup, +0.241 hold), but placement density is much worse. A future FP
  register-bank attempt must reduce/stage read ports, not merely remove reset.
- Removing reset from more than 1,000 validity-gated FPU command, operand,
  exception-frame, and writeback payload bits passes the complete AP suite but
  is a synthesis loss. The FPU itself falls from 7,091 to 7,021 ALUTs, while
  the complete design grows from 79,252 to 79,436 logic cells as optimization
  moves into the parent core. Reject it before fitting; removing resets is not
  automatically useful after the architectural FP bank is already in MLABs.
- Mirroring D0--D7/A0--A6 into two asynchronous 16x32 MLAB banks, while leaving
  USP/ISP/MSP in registers, passes the AP suite, full-machine Verilator build,
  the 212,238-cycle focused loop, and first 100 SingleStep rows at 35,196,127
  cycles/zero real differences. Synthesis looks attractive: 78,837 logic
  cells, 415 below the accepted checkpoint, and the register-file hierarchy
  falls from 412 ALUTs/576 registers to 137/104. Reject it after the physical
  gate: seed 27 fits at 39,312 ALMs but consumes 4,186/4,191 LABs, ten more
  than the accepted build, and misses the 99 MHz setup constraint by 0.715 ns
  with -0.965 ns TNS. The four new Memory LABs leave only five LABs free.
  Preserve the flip-flop register file unless a future design adds a staged
  read/bypass architecture and can recover the resulting cycle cost elsewhere.
- Replacing the four parallel ADD/ADDX/SUB/SUBX arithmetic results with one
  op-controlled 33-bit adder passes the AP suite, full-machine Verilator,
  first 100 SingleStep rows, and 2.08 billion cycles of an extended CPU corpus
  before that no-longer-needed run was stopped. The ALU synthesis hierarchy is
  202 ALUTs smaller and the whole netlist is 103 cells smaller, but the control
  depth moves ahead of the carry chain. Seed 27 grows to 39,402 ALMs and
  4,188/4,191 LABs and misses 99 MHz setup by 0.491 ns (-0.897 ns TNS). Reject
  the fully shared form. A narrower ADD/ADDX and SUB/SUBX pair-sharing test may
  avoid the 33-bit add/sub input inversion and is the only sensible follow-up.
- The narrower pair-sharing follow-up passes the AP suite, full-machine build,
  and first 100 SingleStep rows, and makes the ALU hierarchy 137 ALUTs smaller.
  It still grows the complete synthesis netlist by 225 cells (79,477 versus
  79,252) and the core hierarchy by 25 ALUTs as logic crosses the module
  boundary. Reject it before fitting. Keep the four parallel arithmetic
  results; Quartus packs that source structure better in this design.
- Removing reset from the core's validity- and state-gated request, decode,
  exception, effective-address, bit-field, and multicycle payload registers
  passes the complete AP suite, full-machine Verilator build, and first 100
  SingleStep rows. It removes 75 cells from the CPU hierarchy (34,852 to
  34,777), but cross-boundary optimization grows the complete netlist by 31
  cells (79,252 to 79,283). Reject it before fitting and retain the explicit
  architectural reset behavior. Future reset trimming should target one
  fitted register bank at a time and must win at the complete-design level.

## Completed 2026-09-03: narrow `ADD.L Dn,Dn` preselection

The change selects both asynchronous register-file ports in decode and enters
`S_PIPE_REGS`, bypassing only `S_PIPE_START`. It deliberately retains operand
capture and `S_EXEC`. It is accepted at AP68040 `5aa596f` and parent `a267903`.

- Local/remote core MD5: `e41babcaeec22193e03e915ea4da1c1c`
- Full AP68040 suite: pass
- Wombat full-machine Verilator build: pass
- Focused `bench_loop`: **212,238 cycles**, 5.69% below the accepted 225,036
  and 26.80% below the branch-refill baseline of 289,956
- State effect: `S_PIPE_START` falls from 25,669 to 12,868 visits;
  `S_PIPE_REGS` and `S_EXEC` are intentionally unchanged
- First 100 SingleStepTests rows: **35,196,127 cycles**, 1,696 matching field
  groups and zero real differences; 8,516 cycles below the accepted checkpoint
- Exact Quartus tree:
  `/home/alans/builds/wombat33_cpu_adddecode_seed27_20260903`
- Seed-27 Quartus result: **pass**, 40,738 ALMs, 4,182/4,191 LABs, zero TNS;
  setup +0.070 ns overall/+0.772 ns CPU/+0.070 ns SDRAM; hold +0.245 ns
  overall/+0.263 ns CPU/+0.430 ns SDRAM
- RBF: MD5 `cb83d1a71d262a61af9a5508a443506d`, SHA-256
  `512558ea68f5bc5e9dfeb79be9bd0860e44f2d2046e4909bb3c6096c6e24816a`
- Hardware: Mac OS boot and all six Speedometer categories passed; safe shutdown
  screen confirmed; disposable and pristine disks restored/verified at MD5
  `0c4f774b4a2eccd5656e92f16119875f`
- Hardware performance: all six scores are within 0.5% of the predecessor, so
  this is a focused-loop improvement and area-neutral checkpoint, **not a
  measurable Speedometer gain**

## Priority 1: reclaim placement headroom

Treat every item as a separate measured experiment. Preserve the accepted
seed-27 tree and compare both synthesis hierarchy and fitted LAB/ALM totals.

- [ ] Save a machine-readable baseline from the Fitter and Analysis & Synthesis
  resource-by-entity reports. Track ALMs, LABs, registers, recoverable packing,
  unavailable ALMs, M10Ks, DSPs, and per-clock slack after every experiment.
- [ ] Profile `ap040_core`'s self logic. The monolithic sequencer/decode is
  about 15.9k ALMs, far larger than the named ALU, MMU, cache, or register file.
  Use Quartus node/fanout and critical-path reports to rank state-decode cones,
  write-enable muxes, exception controls, EA controls, and duplicated size/mask
  logic before changing RTL.
- [ ] Factor repeated instruction decode predicates, size/byte masks, condition
  evaluation, and destination-write enables into shared controls where Quartus
  is not already sharing them. Verify the post-synthesis netlist actually gets
  smaller; cleaner source alone is not a result.
- [ ] Reduce the number of possible writers and mux inputs for wide stateful
  registers. Consider splitting the giant sequencer into localized register
  update blocks or explicit enables one register group at a time. This is high
  reward and high correctness risk because ordering currently comes from one
  sequential block.
- [ ] Experiment with a hierarchical FSM or selected state encoding. The state
  bits have very high fanout; a local substate can shrink equality decoders,
  while one-hot may trade otherwise idle flip-flops for fewer LUT levels. Keep
  only a result that reduces fitted LABs and retains timing.
- [ ] Look for constant tables or read-only decode/control data that can infer
  MLAB/M10K ROMs. Block-memory bits are only 55% used. Do not move a hot
  asynchronous path into synchronous RAM unless its added cycle is hidden or
  recovered elsewhere.
- [ ] Audit small arrays and refill/prefetch storage for RAM inference. The cache
  data/tags and MMU ATC already use M10Ks; prioritize buffers still implemented
  as scattered registers. The branch-refill sector is hot, so preserve its
  required read bandwidth and zero-extra-cycle branch behavior.
- [ ] Audit the FPU separately. At about 5.2k ALMs it is the largest named child.
  Explore sharing normalization, rounding, shift, compare, and conversion
  hardware across multi-cycle operations. Trading extra FPU cycles for several
  hundred ALMs may be worthwhile only after measuring Speedometer Math and
  retaining the complete FPU/FPSP tests. The first pass moved FP0--FP7 into
  MLABs and removed 1,371 FPU logic cells without adding cycles; the arithmetic
  datapath remains the next target.
- [ ] Review the 436-ALM asynchronous register file only after larger targets.
  Replicated synchronous RAM could cost instruction cycles; do not sacrifice
  the two combinational read ports without an end-to-end throughput win.
- [ ] Inspect low-risk logic outside the CPU if the core alone cannot free 100
  LABs. Framework scaler/audio blocks are individually sizable, but no feature
  may be removed merely to make the utilization number smaller.
- [ ] Evaluate Quartus packing and physical-synthesis assignments on an
  unchanged netlist. Keep tool-setting changes separate from RTL changes and
  require repeatable seed results; fitter-only savings do not excuse negative
  timing slack.
- [x] Milestone gate: recover at least 1,000 ALMs and 100 LABs with all tests
  green before undertaking broader front-end/pipeline work. The accepted
  CMP seed-28 checkpoint is 4,292 ALMs and 119 LABs below the old seed-27 ADD
  fit, leaving 128 LABs free. Same-seed deltas remain the authoritative measure
  for each individual RTL change.

## Priority 2: extend only the proven narrow fast-path pattern

- [ ] Use opcode histograms from the focused bench and a boot workload to rank
  register-register forms. Do not optimize ISA families merely because their
  decode looks similar.
- [x] Extend the proven ADD decode-time dual-register selection to CMP. The
  `CMP.L Dn,Dn` form is accepted at `d543f2d`: it saves 27,683 first-100 corpus
  cycles, improves hardware CPU PR by 0.83%, saves 146 ALMs/17 LABs at seed
  28, and closes timing. Re-run every gate after each family. SUB.L was
  tested and rejected: it saved only 715 cycles (0.002%) in the first 100
  SingleStepTests rows, was absent from the focused loop, and its same-seed fit
  missed 99 MHz SDRAM setup by 0.296 ns with -0.324 ns TNS. AND.L was rejected
  before fitting: it was also absent from the focused loop and saved only 746
  cycles (0.0021%) in the same corpus. OR.L was likewise absent from the loop
  and saved just 39 corpus cycles (0.00011%), so it was rejected before fit.
  EOR.L produced the same 39-cycle result and was likewise rejected.
- [x] Use the full-machine profile and opcode histogram before selecting another
  decode bypass. Over 125 million profiled clocks, the machine retired
  11,126,598 instructions at 11.23 clocks per dispatch. A bounded 71,209-
  instruction trace contains 29,254 `MOVE.L (A1),(A2)+` operations, but only
  1,494 `MOVE.L Dn,Dn` operations. A narrow longword register-MOVE bypass was
  still evaluated because it was low risk: all tests passed and it saved 68,796
  first-100 corpus cycles (0.1956%), but its timing-clean seed-30 fit left seven
  fewer free LABs than the accepted fit and hardware CPU PR moved from 4.765 to
  4.752. With no measurable hardware gain, the RTL was reverted. See
  measurement section 25.
- [x] Test the profiled hot `MOVE.L (An),(Am)+` copy form. The narrow candidate
  preselected the distinct destination address register during the source read
  and retired directly into the ordinary registered write path, removing five
  sequencer states. Directed cache-hot and destination-write-fault/restart tests,
  the complete AP suite, full-machine Verilator, and hardware all passed. Seed
  28 met timing but cost 218 ALMs/16 LABs; the complete Speedometer run scored
  CPU 4.726 versus 4.765 for the accepted checkpoint. It was reverted because
  a boot-hot trace was not representative of the CPU benchmark and the larger
  fit produced no end-to-end CPU gain. See measurement section 26.
- [ ] Rank remaining address-register forms and simple decode bypasses from the
  full-machine profile. Require meaningful dynamic coverage before editing RTL;
  the rejected SUB/AND/OR/EOR and register-MOVE trials show that visual
  simplicity is not enough.
- [ ] Evaluate byte/word register forms separately. Their merge and condition-
  code behavior differs from longword operations and can erase the simplicity
  of the ADD.L path.
- [ ] Extend acknowledgement-time retirement to non-MOVE memory-source ALU
  operations only with a staged operand/result path. Directly placing a full ALU
  and flag calculation on `d_ack` risks both a new critical path and imprecise
  fault/trace behavior.
- [x] Consume immediate operands already resident in the instruction queue.
  The accepted decode-only path removes 12,662 focused-loop cycles (6.79%) and
  93,747 first-100 cycles (0.285%). It preserves extension-word PC accounting,
  refuses an outstanding fill or same-edge `mem_ack`, and suppresses a new
  speculative fill while popping the queue. The initial broader version failed
  exception timing and allowed the MMU walker and CPU bus to overlap; these
  conservative ownership guards fix both failures. See measurement section 28.
- [x] Revisit DBcc with a clearly isolated change. Source-state profiling
  proved every useful resident-refill hit in the focused loop came from
  `S_DBCC1`. The accepted path reuses `issue_ifetch`, saves 12,462 focused
  cycles, raises hardware CPU PR from 5.088 to 5.133 (+0.88%), and avoids the
  generic candidate's 1,222-ALM expansion. See measurement section 30.

## Priority 3: front-end overlap and real pipelining

The core is a correct multi-cycle sequencer, not a throughput pipeline. Narrow
state bypasses shorten individual instruction latency, but do not by themselves
provide the sustained instruction overlap of the real 68040. Reaching the
user's Speedometer 4.02 target of about 1.9 from the measured 0.4345 requires
roughly 4.4x throughput. That target is a benchmark proxy, not proof that every
workload matches silicon; no individual optimization below is promised to
deliver it.

The original `The_68040_processor_I_Design_and_impleme.pdf` describes overlapping
instruction prefetch, PC/decode, effective-address calculation, operand access,
execution, and writeback. The objective is sustained throughput, not executing
all six jobs in one long combinational cycle. Preserve clock timing and
in-order architectural behavior while adding overlap.

### Ordered roadmap: profile, then broaden instruction overlap

1. **Profile today's Speedometer 4.02 CPU interval first.** Use the same ROM,
   restored disk, settings, and all ten one-iteration CPU tests as hardware.
   Record dynamic instruction/addressing-mode mix, clocks per instruction,
   decode/EA/setup occupancy, instruction/data cache hit and miss counts,
   hit-service latency versus external memory waits, port contention, and
   branch/refill stalls. The older 3.23 profile of roughly 12 clocks per
   dispatch is motivation, not a current 4.02 CPI measurement. Rank candidates
   by dynamic coverage and estimated removable cycles before spending area.

2. **Overlap shared decode with the current instruction.** Start with one
   decoded-control register for a broad common subset, reusing the existing
   execution machinery rather than duplicating ADD-only paths. Decode the
   younger instruction while the older one executes, without fetching its
   data operands or causing architectural side effects prematurely. Preserve
   extension-word ownership, instruction PCs, queue flushes, and redirects;
   unsupported or serializing instructions initially drain into the slow path.
   Measure real-application improvement before adding a micro-op queue.

3. **Pipeline common effective-address and operand work.** Cover MOVE,
   arithmetic, compare, and logic across register-direct and common memory
   modes such as (An), (An)+, -(An), displacement, and immediate forms.
   Overlap address calculation and cache-hit operand access with older
   execution instead of only making isolated register loops faster. Start with
   bounded in-order overlap; do not introduce speculative MMIO or out-of-order
   execution. The forwarding/retirement contract in step 5 is a prerequisite
   before younger operand or execution stages can change machine state.

4. **Remove internal cache-hit bubbles.** Separate lookup, translation, and
   CPU/cache handoff costs from genuine SDRAM misses using step 1's profile.
   Faster external RAM cannot remove cycles spent servicing an internal hit.
   Evaluate registered hit paths and reduced serialized lookup stages with
   measured dynamic coverage; revisit parallel ATC/cache work only if its
   benefit justifies area and routing. Keep miss/coherence behavior and the
   passing registered memory completion path intact.

5. **Build forwarding and precise retirement alongside the overlap stages.**
   Specify register RAW/WAW, An auto-update, CCR/X dependencies, stack-bank
   changes, and control-register serialization. Carry each instruction's PC,
   result, flags, pending write, and fault context to an explicit in-order
   completion boundary. Younger instructions must not commit before older
   faults, interrupts, or trace events; flush or drain safely on redirects,
   bus faults, and unsupported operations. Prove restartable writes, snoops,
   and self-modifying code with directed tests before enabling broader overlap.
   This is an enabling correctness requirement, not a final cleanup task.

6. **Tune branches, then assess frequency.** Once common instructions overlap,
   profile taken/untaken branches and refill recovery again. Optimize the
   dynamically important cases without blindly restoring rejected generic
   redirect muxes. Keep 33 MHz as the throughput reference; consider frequency
   increases only after CPI and routing improve, report them separately, and
   retain authentic peripheral/bus timing. A clock increase is supplementary,
   not evidence of a silicon-like pipeline.

### Development headroom and acceptance gates

The user-approved CD-ROM-off SKU is a temporary pipeline-development aid:
keep both hard disks, and leave the active full-feature QSF unchanged.
Matched synthesis estimates save 2,252 ALMs, 1,019 registers, 86,016 RAM bits,
and 23 DSPs. The current fitted candidate still has only 67 free LABs, so
continue measured CPU/control-mux area reclaim where necessary. CD removal is
not a CPU speed optimization. Do not randomly strip MMU, FPU, caches, video,
audio, or other peripherals; restoring or compacting CD support remains a
separate full-feature integration task.

For each bounded stage, preserve a recoverable checkpoint; require directed
hazard/fault/flush tests, all eleven CPU suites, immutable corpus equivalence,
full-machine compile/link, and zero-TNS fitted timing. Track both ALMs and
LABs, resource-by-entity deltas, and per-clock margins. Accept throughput claims
only after reproducible, unperturbed Speedometer 4.02 hardware runs from the
restored disk while hardware access is authorized. Report individual tests as
well as the average; do not infer application gains from a focused loop or
corpus alone.

### Existing completed steps and implementation checklist

The first broad front-end step is accepted. The existing prefetch queue already
held a next-opcode candidate often enough that a new queue was unnecessary:
retiring directly from `fetch_next` into `S_DECODE` removes the standalone
`S_FETCH` boundary whenever that word is resident.

- [x] Remove the normal resident-opcode `S_FETCH` retirement bubble. The
  accepted implementation keeps IRQ/trace checks ahead of dispatch, refuses a
  same-cycle flushed queue, and leaves extension-word and bus-miss paths on
  their existing states. Hardware CPU PR improves 4.62%.
- [x] Cover the direct retirement consumers exposed by the removed boundary.
  `MOVE.L ...,A7` followed by short `BSR.B` and `MOVE An,USP` followed by
  `MOVE USP,Am` each require forwarding from the registered write strobe.
  Directed tests fail without their respective bypass and pass in all three
  memory phases with it.
- [x] Remove the resident-immediate `S_IMMF` bubble from decode. Both one-word
  and two-word resident operands can advance directly to the requested return
  state. Later-state callers retain the old boundary, and any outstanding or
  completing speculative fetch keeps the old path. Hardware CPU PR improves
  from 4.985 to 5.088 (+2.07%).
- [x] Measure the remaining taken-branch/refill boundary. The generic
  `go_pc` bypass removed 12,462 focused cycles (7.17%) and raised hardware CPU
  PR from 5.088 to 5.148 (+1.18%), but cost 1,222 ALMs and 33 LABs, leaving
  only 66 LABs free. It is rejected on performance-per-area grounds and is
  preserved on AP68040 branch `wombat-inline-branch-refill`; see measurement
  section 29. Source-state profiling showed all 12,462 focused direct hits came
  from `S_DBCC1`. The accepted DBcc-only follow-up reuses `issue_ifetch` queue
  seeding, preserves the 161,256-cycle result, passes the AP suite/full-machine
  build/first-100 corpus, and raises hardware CPU PR to 5.133 (+0.88%). Its
  final seed-30 fit is 37,063 ALMs and 4,122 LABs with zero TNS; see section 30.
- [ ] Audit every remaining direct architectural view used in `S_DECODE`
  before removing another boundary state. Register RAW/WAW and CCR operands
  consumed in later states already see committed data; prove this again for
  address auto-update, control-register changes, and any new decode-time
  consumer.
- [ ] Separate architectural retirement from execution before overlapping two
  independently executing instructions. Exceptions, trace, interrupts, bus
  faults, and restartable write faults must remain precise; no later
  instruction may update architectural state early.
- [x] Test a one-entry predecode on a bounded simple-register subset. The exact
  resident `ADD.L Dn,Dn` candidate passes all simulation gates, saves 8.06% in
  the focused loop, and closes seed-30 timing, but saves only 0.0034% in the
  first-100 corpus and improves hardware CPU PR by just 0.60%. It costs 271
  ALMs and 23 LABs, leaving only 46 LABs free, so it is rejected and preserved
  on AP68040 branch `wombat-predecode-regalu`; see measurement section 31.
- [x] Profile the actual Speedometer 3.23 CPU interval before choosing another
  pipeline target. The accepted baseline executes about 150 million dispatches
  at 12.37 clocks/dispatch. Instruction-fetch/cache occupancy was broad enough
  to justify a shared cache optimization, while the focused loop overpredicted
  the rejected ADD predecode by more than an order of magnitude.
- [x] Add one sequential I-cache lookahead word. It hits on 64.48% of dynamic
  dispatches, cuts simulated cache-state occupancy from 10.6% to 5.7%, and
  improves the hardware CPU benchmark average by 2.71%. The exact physical
  match, line-boundary guard, invalidation rules, and directed T12 cache test
  are accepted at AP68040 `8951fd2`; see measurement section 32.
- [ ] If the measured profile supports it, test a shared one-entry decoded
  control register that overlaps generic `S_DECODE` work without duplicating a
  complete opcode-specific execution path. Keep execution and retirement
  in-order, flush on every unsupported or serializing instruction, and prevent
  the younger operation from changing architectural state before the older one
  retires.
- [ ] Consider a small decoded micro-op queue only if one predecode register
  proves useful. Do not build a broad speculative machine; the expected win is
  hiding FETCH/DECODE occupancy, not reimplementing an out-of-order 68040.
- [ ] Revisit CPU clock frequency only after logic/routing headroom and CPI have
  improved. The 33 MHz architectural clock is authentic, and a higher clock can
  mask inefficient sequencing without fixing it or matching real bus behavior.

## Priority 4: remaining memory/cache ideas

The integrated path already measures 52.4 MB/s sequentially and a 304 ns line
fill, inside the real Quadra 800 bandwidth range. The new I-cache lookahead
removes much of the instruction-side occupancy; the remaining profile is now
dominated by data-side `S_MRD`/`S_MWR` activity. First separate internal
D-cache hit/lookup delay from true external misses so an internal CPU/cache
optimization is not confused with already-adequate SDRAM bandwidth.

- [ ] Reduce cache-miss critical-word latency without reviving combinational
  direct acknowledgement. Two broader direct-ack variants froze during the
  hardware Disk test.
- [ ] Evaluate a safe early cache-fill acknowledgement only if subsequent words
  can complete coherently while the CPU continues and redirects/faults remain
  correct.
- [x] Profile D-cache activity and test both a registered hit shortcut and
  earlier data-request issue. The repeat/sequential hit predictor gained only
  0.51% and was rejected. Issuing normal aligned RAM operands while entering
  `S_MRD` is accepted: two cold Speedometer 4.02 runs both score 0.399 versus
  0.394 upstream (+1.27%), while the combined BCD reclaim leaves the fit 184
  ALMs and 9 LABs smaller than upstream. Broad early issue is rejected because
  hardware timer results became invalid; see measurement section 34.
- [x] Test issuing simple `(An)`, `(An)+`, and `-(An)` source operands directly
  from address generation. The focused cached phase improved 8.52%, but the
  hardware average remained 0.399 while the fit cost 264 ALMs and 8 LABs,
  leaving only two LABs free. Rejected; see measurement section 35.
- [x] The two-entry ordered RAM store buffer is already accepted in measurement
  section 11. A follow-up that issues aligned `S_EXEC` writes one AP state
  earlier passes every gate and improves the first-100 corpus 2.85%. It is now
  accepted together with the exact NCR BCD reciprocal conversion: two valid
  hardware runs score 0.405 (+1.50% over 0.399), and the combined seed-21 fit
  is 350 ALMs smaller than the prior checkpoint, although it uses six more LABs
  and leaves four free. See measurement sections 36-37.
- [ ] Consider copyback only with a real dirty-line snoop/writeback design.
  External DMA and the MMU walker's U/M-bit writes must not invalidate and lose
  dirty CPU data.
- [ ] Preserve the passing registered RAM completion path for Disk, ROM, VRAM,
  IOSB, DAFB, and open-bus accesses.

## Rejected paths: do not rediscover these blindly

- A broad direct register-register ALU retirement change combined with further
  DBcc collapsing passed simulation and Quartus timing but froze at the Happy
  Mac. It is rejected. Bisect one opcode family and one removed state at a time.
- Exact `ADD.L Dn,Dn` predecode is also rejected. Its synthetic focused-loop
  saving was 8.06%, but the controlled hardware CPU-average gain was only
  0.18% while the fit consumed 271 ALMs and 23 LABs. Do not widen this path
  until an actual Speedometer CPU-interval profile identifies enough dynamic
  coverage to predict a materially larger end-to-end result.
- Broad direct memory acknowledgement froze during Speedometer Disk even when
  the pre-adapter retained-line bypass was disabled. Preserve registered
  completion and adapter ownership/order checks.
- Quartus placement is highly seed-sensitive. A new failure on an unrelated
  HDMI, SDRAM, or `ir`/exception path is not proof the RTL idea is bad. Record
  the path, walk a small seed set, and accept only a zero-TNS fit.
- Do not disable the MMU, FPU, caches, scaler, audio, or machine peripherals to
  claim an area or speed win. Feature removal is not optimization. The only
  scoped exception here is the user-approved, explicitly labeled CD-ROM-off
  development SKU described in Priority 3; it is not the full-feature reference.
- Do not compare Speedometer 3.23 PR ratios directly with the published
  Speedometer 4.02 real-Quadra Benchmark Mix. Use the same application version,
  disk image, ROM, iteration count, and restored starting image.

## Validation gate for every CPU change

Current 2026-09-12 gate and fixture: use `docs/AGENT_TESTING_WORKFLOW.md`.
Use Speedometer 4.02 CPU Mix, all ten tests at one iteration, verified golden
MD5 16790b0577e13b45782214433d34954b, exclusive FPGA owner, zero-TNS fitted
candidate, two quiet hardware runs, MENU, and disposable restoration. The user
explicitly permits hard-switching this disposable guest before replacing its
image. Preserve Main. Current local toolchain/immutable corpus evidence is in
`docs/CPU_OPTIMIZATION_LOG_20260912.md`.

### Historical gate (superseded fixture and tool paths; retained for provenance)

Run in this order so inexpensive failures stop the experiment early:

```sh
cd rtl/ap68040/tb
bash run_tests.sh

vvp build/tb_prog.vvp +prog=build/bench_loop.hex +prof +memlat

cd ../../../verilator
make -j8

cd ../SingleStepTests/preboot/sim040
CDEFS='-DLAST_TEST_INDEX=99' SIM=verilator \
  VERILATOR=/opt/homebrew/bin/verilator ./run_corpus.sh cpu
```

Then compile on `alans@cottageubuntu` with the candidate source hash and seed
recorded. Require zero setup and hold TNS; record overall, 33 MHz CPU, and 99
MHz SDRAM setup/hold margins plus ALMs/LABs. Preserve timing-clean RBFs with
unique names.

Finally boot the disposable disk on the MiSTer at `192.168.1.75`, run all six
Speedometer 3.23 PR categories, shut down from Mac OS, wait for the safe screen,
return the MiSTer to its menu, and restore:

- disposable: `/media/fat/games/Wombat33/QuadSquad8.hda`
- golden: `/media/fat/games/Wombat33/backup/MacAtrium-7.5.5-fullcolor_speedtest_golden_20260902.hda.gz`
- pristine reference: `/media/fat/games/MacIIvi/MacAtrium-7.5.5-fullcolor_speedtest.hda`
- required restored MD5: `0c4f774b4a2eccd5656e92f16119875f`

Never load a core while the guest is booting or running. It hard-resets the
FPGA while HFS is mounted writable.

The temporary reservation of the MiSTer for another FPGA project was
explicitly lifted again on 2026-09-05. FPGA use is authorized for the continuing CPU
plan until the user revokes it; still perform the timing, safe-shutdown, and
disk-restore gates above before every deployment.

## Working-tree cautions

The parent worktree contains unrelated user work in
`docs/sdram-vram-sharing.md`, `verilator/sim.v`, `verilator/sim_main.cpp`, and
the VRAM/resume documents, plus generated Verilator directories. Do not stage,
rewrite, clean, or delete those files as part of CPU work. The profiler changes
in the two Verilator source files are useful but remain user-owned until handled
separately.

There is no `CLAUDE.md` in this repository or its git history as of this
checkpoint. Do not assume instructions were loaded from one unless it is
restored later.
