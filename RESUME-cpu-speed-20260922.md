# RESUME — CPU speed, where the clocks go and what is left (2026-09-22, 00:45)

Supersedes the CPU sections of `RESUME-handoff-20260921.md`. Goal: Speedometer 4.02 Mix ~1.9
(real Quadra 800: 1.897, `docs/perf/real_quadra800.jpg`). **Best hardware: P165b, 1.364**
(five valid runs, `docs/PERFORMANCE_MEASUREMENTS.md`, last two sections).

## State

- Tree at HEAD = **P165**: P162 core (the P137..P162 chain) + P124 cache + P120 pipeline, seed 23,
  with the development headroom profile (`configs/cpu_development.tcl`, sourced by the qsf: OSDs,
  audio, IIR, video measurement, Y/C, shadowmask, 512x384 out; ~3,000 ALMs). Without the profile the
  same RTL does not route (P165, 40,003 ALMs, 84 % peak interconnect). With it: 37,045 ALMs,
  CPU clock -0.145 ns (runs fine, as P124 did at -0.188). rbf:
  `scratch/p165b_devprofile_fit_20260921/MacQuadra800_p165b_devprofile_b39fedd.rbf`, on the MiSTer
  as `_Unstable/MacQuadra800_p165b.rbf`. The guest was shut down cleanly to the halt screen; the
  disposable disk `QuadSquad8-pipeline-test-20260919.hda` is slot 0.
- Ladder: P120 1.313 -> P124 1.340 -> P165b 1.364. Whetstones 1141, Dhrystones 15,970.
- **P151 (shared-port cache) is disqualified**: fails the standard `cache_snoop` bench (stale word
  served after a snoop) with the P162 core. `docs/P151_...md`.
- The invalid-timer anomaly persists (one of six P165b runs: the last two tests impossibly short).
  Still open, still unattributed; see the 09-19 hand-off item 2a.

## What the profiles say (all on P165's sources; the Permute numbers are one Permute(7))

Permute: **1,303,949 clocks at memory latency 0, 1,315,902 at 3** (real 040: ~817,000). Memory
latency is already hidden by the caches and the posted store; the cost is the sequencer's own
structure. Budget of the 1.30 M (`scratch/permute_p165_phases_20260921/`, a scratch bench with
per-state phase counters):

| what | clocks | share | mechanism |
|---|---:|---:|---|
| the clock that only observes a data acknowledge (one per read + one per store) | ~260k | 20 % | S_MRD/S_MWR retire on the registered observation of `d_ack`; the 040 overlaps this |
| port turnaround: store waits behind a 2-3-clock-old prefetch (49k events) + the issue clock after it | ~117k | 9 % | one memory port, one request register, a mandatory gap cycle after an acknowledge (the cache cannot tell a new request from the held one) |
| separate fetch and decode clocks for instructions the pipeline does not take | ~265k | 20 % | S_FETCH + S_DECODE |
| registered instead of one-clock acknowledges on stack longwords at addresses = 2 mod 4 (MOVEM 45k, RTS 12k, UNLK 16k) | ~75k | 6 % | `fast_lane` requires an aligned longword; Speedometer's Pascal pushes word-sized arguments, so every callee's stack is misaligned. The one-clock span hit was P135/P136 -- P136 fitted at CPU -5.5 ns without the profile |
| S_EXPERIMENT_PIPE, S_PIPE_START, MOVEM loop, LINK/UNLK/JSR states | rest | | |

Whetstone (`scratch/whetstone_full_p165_20260921/`, 26.31 M clocks): S_MRD 22.6 %, S_MWR 14.6 %,
FETCH+DECODE 14 %, FPU states ~15 % (S_FPU_GO itself 6.3 %). **There are no exception states in the
profile: Mac OS patches the SANE A-traps into JSRs, so the trap path is not the Whetstone cost** --
the SANE package runs as ordinary code with the same memory-state overhead as everything else.

Against the real machine, per test (P120 numbers): Whetstone 54 %, Permutations 57 %, Dhrystone 63 %,
Towers 67 %, Queens 66 %, the loop/array tests 84-95 %. Whetstone alone is 53 % of the Mix gap.

## Increments tried tonight and closed (each screened on Permute at latency 0 and 3)

| idea | result |
|---|---|
| fetch engine yields to a hinted store (`!hint_store`) | byte-identical: the blocking fetch is 2-3 clocks old, issued before the store was visible |
| fetch engine yields to a pipeline store | byte-identical, same reason |
| less eager queue fill (threshold 4 / 2 instead of 6/7) | -0.1 % / +0.1 %: waits become fetch stalls |
| P167: predecrement MOVEM store hint at `mm_addr - size` (the hint was at `mm_addr`, so `movem.l ...,-(a7)` never fast-stored) | latency 0: -0.5 %; latency 3: +0.1 % -- the posted stores fill the two-entry queue and reads wait behind it. Kept in `scratch/p167_movem_predec_hint_20260921/`, not promoted |

The pattern is the other assistant's too (160 increments at ~1 % each): **the remaining cost is
structural, and every increment adds logic to a core that no longer routes without help.**

## What would move the number, in order of value

1. **Overlap the acknowledge clock** (20 %): the memory states must not be states. Retire a hinted,
   MMU-vouched store at its issue (the cache's `fast_store` already makes the acknowledge combinational
   in the request clock; the core needs the verdict one clock earlier -- the S_PIPE_DEA hint already
   exists for MOVE/CLR stores) and let the next instruction's fetch/decode run under a read's
   acknowledge. This is the integer pipeline extended to memory operands. Weeks; it also *removes*
   states, i.e. logic.
2. **Two outstanding transactions on the port** (9 %): a request ID on the core->cache contract so a
   request may follow an acknowledge without the gap cycle, and a data access may be issued while a
   fetch is in flight. Contained to `ap040_core` mem_issue / S_MRD / S_MWR and the cache's admission;
   `tb_line_dma`-style bench against the real cache first.
3. **One-clock misaligned-longword hit** (6 % on stack-heavy tests, more on Towers/Queens): refit
   P136's cache (`scratch/p136_hinted_parallel_span_fit_20260921/` has the source identity) on the
   P162 core WITH the headroom profile -- the only one of the failed cache fits whose failure was
   timing rather than routing, and the profile changes that. One fit, no design work.
4. Area, so that 1-3 fit and so that CD + Ethernet can come back: the pipeline's second ALU
   (~1,000), the R5/R6 hoists (~1,300, on the old submodule's `wombat-area-diet`), SCSI block cache
   (835). Every item in 1-3 must be judged with the profile ON and OFF.

Not worth more time: hint-address and fetch-engine tweaks, queue thresholds, P151 as it stands,
the trap path.

## Tooling that exists now

- `scripts/cpu/fit_dev.sh <tag>`: one guarded fit of whatever is promoted, archived under
  `scratch/<tag>_fit_<date>/` with the identity, fresh reports, rbf + sha256, cross-domain timing.
  Launch it as a user unit (`systemd-run --user --unit=... bash scripts/cpu/fit_dev.sh <tag>`).
- The phase-attribution Permute bench: `scratch/permute_p165_phases_20260921/tb_cpu_permute.sv`
  (build line in this session's history; it is `verilator/tb_cpu_permute.sv` plus counters on
  `dut.core.state`, `m_issued`, `epf_pend`, `d_ack`, `r_m_ret` and the cache's fast-hit terms).
- Hardware: `vmouse.py` at `/media/fat/Scripts/q800tools/`, the Speedometer key sequence in
  `scratch/hardware_p165b_20260921/` order. Five valid runs, invalid ones replaced.
