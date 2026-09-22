# RESUME — CPU speed, 2026-09-22 evening (supersedes RESUME-cpu-speed-20260922.md)

Goal unchanged: Speedometer 4.02 Benchmark Mix ~1.9 on the MiSTer (real Quadra 800: 1.897). The
user's ruling today: **get to 1.9 first, then reduce the area to fit CD-ROM and Ethernet back in.**

## Where things are

| build | hardware Mix | note |
|---|---:|---|
| P165b | 1.364 | P162 core + P124 cache, dev profile |
| P171 (`d17f794`, seed 24) | **1.377** | split fetch/data request channels + idle-slot supply policy. Timing -1.231 ns on the CPU clock, ran fine |
| P171b (`74f5ada`, seed 24) | run by the user, "worked" | + forward/refill-buffer fixes, replaceable redirects. -1.324 ns |
| P171c (seed 24) | not measured | OSDs, audio out, Y/C back (`configs/cpu_release_lite.tcl`); 39,070 ALMs, -1.425 ns |
| P174 (`c152ac4`, seed 24) | **not yet run** | one-clock instruction hit. 39,441 ALMs, routes, **-0.920 ns**. rbf `scratch/p174_ihit_fit_20260922/MacQuadra800_p174_ihit_01ebd7b.rbf` |
| P175b (`53f7f53`) | fitting (unit `q800-p175b-fit-20260922`) | instruction hint bus + post-ack fill hold |
| P177 (`57a3356`, HEAD) | not fitted | return-address stack hint |

Simulation ladder (Permute(7) lat 0 / Whetstone / Dhrystone / Queens), against P170 = the last cache on
hardware: P171b 1,175,448 / 25,185,192 / 103,654,322 / 56,261 -> P174 1,132,146 / 24,886,003 /
102,604,350 / 54,785 -> P175b 1,114,950 / 24,690,824 / 100,754,349 / 54,151 -> **P177 1,081,092 /
24,661,704 / 99,604,352 / 53,925** (-14.4 % / -3.9 % / -6.1 % / -5.6 % vs P170). Hardware Mix moved
+1.0 % for P171's -7 % Permute, so expect maybe +3-4 % Mix from P174..P177, not 14 %.

Notes: `docs/P171_SPLIT_REQUEST_CHANNELS_20260922.md`, `docs/P174_FAST_INSTRUCTION_HIT_20260922.md`,
`docs/P175_INSTRUCTION_HINT_BUS_20260922.md`, `docs/P177_RETURN_ADDRESS_STACK_20260922.md`,
`docs/PERFORMANCE_MEASUREMENTS.md` (P171 hardware section).

## Area and the release recipe

The full release recipe (profile off, CD-ROM + Ethernet in) with the P171b CPU synthesizes to **42,379
ALMs** — over the 41,910 device; routing fails from ~39,500 up depending on the seed (P174 routed at
39,441, P174b failed at 39,158, P171c seed 26 routed at 39,141). The dev builds carry
`CDROM_OFF=1 ETHERNET_OFF=1` and `configs/cpu_release_lite.tcl` (shadowmask, IIR audio filter, video
measurement, 512x384 retarget off: ~1,200 ALMs). Getting CD+Ethernet back needs 4,000-5,000 ALMs out of
the CPU (core 15.4k sequencer, FPU 4.6k, pipeline 2.1k + its private ALU 1.0k, cache 1.7k, MMU 1.0k).

Timing: the CPU clock misses by 0.9-1.6 ns on every recent fit, on *different* paths per seed (the
in-place compare-and-branch dispatch through the cache read data; the store buffer's address compare
into the pipeline load ack into the refill seed; the ALU result onto the hint bus into the MMU hint
translation). One was removed (`fast_span_ack` no longer tests `c_req`, `949ac44`); the rest are a
pass of their own. The user's rule: try marginal builds on hardware, note the miss.

## Dani

`upstream/main` merged (`b5850bd`): his `optimize-SCSI` was already in our history; only the 09-19
release commits came over. The PR to him waits for the regression gate (8.1, A/UX 3.1 at 32 MB; CD audio
not applicable without CD) on the FPGA — the user was using it; ask before touching it.

## Tooling added today

- `scratch/p171_split_request_20260922/`: the working copy of the CPU (`ap68040/rtl`, `wombat_cpu.sv`),
  `sweep_policy.sh <tag> "<-D flags>"` (Permute lat 0/3 + Whetstone, `EXTRA_FLAGS` into the verilator
  runs), `sweep_policy2.sh` (Dhrystone on the 500M bench + Queens), `run_suite.sh` (22 programs + 4
  IRQ replays), `handoff/` (pipeline_handoff pointed at the scratch tree).
- `scratch/permute_p171b_phases_20260922/tb_cpu_permute.sv` + `profile.py`: the phase bench with the
  fetch-presentation instrument (FPRES: fast/hinted/un-hinted/seed, data-behind-fetch), the SDONE wait
  reasons, the S_FETCH breakdown, the un-hinted-seed issuing state. `profile_p170.py` runs the P170
  RTL for comparison.
- `scripts/cpu/fit_dev.sh <tag>` via `systemd-run --user --unit=q800-<tag>-fit-<date>`; Quartus
  rewrites the qsf during a flow (it inlined the sourced profile macros once) — clean it after.

## P178 and after (added later the same evening)

P175c halved the mirrors (the full-depth data mirror took Quartus's RAM estimate over the device and it
silently registered the framework's OSD/palette buffers: 84,851 ALMs); P178 is the one-clock hit for a
longword spanning two lines; `sys/sys_top.v` passes `PALETTE=false` without `MISTER_FB` (the dead
scaler palette Quartus kept turning into 6,144 registers whenever a second tag-shaped RAM existed — a
four-run synthesis bisect). Tree HEAD = P177 core + P175c/P178 cache; sim Permute **1,058,070**,
Whetstone 24,354,754, Dhrystone 98,004,234 (vs P170: -16.3 % / -5.1 % / -7.6 %). Synthesis estimate
39,043 ALMs; fit `q800-p178-fit-20260922` -> `scratch/p178_xline_fit_*`.

S_DECODE's 130k clocks on Permute, by opcode: the `4E4x-4E7x` group 56k (LINK, UNLK, RTS — one decode
clock each per call), MOVEA.L Dn,An 20k, MOVEM 17k, MOVE.L Dn,-(A7) 8.7k; by predecessor: after S_FETCH
47.5k, after a store's S_MWR 37.5k, after a read's S_MRD 18.7k. The record dispatch (n_desc_ok) does not
cover LINK/UNLK/RTS/MOVEM/the pushes; adding them is the next sequencer item after the acknowledge-clock
work.

## Where the Permute clocks are now (P177, 1,081,092)

S_EXPERIMENT_PIPE 213k, S_MRD 180k (acknowledge 130k + waits 50k), S_MWR 178k (130k + 39k + 9k
issue), S_DECODE 130k, S_PIPE_START 85k, S_FETCH 72k (69k = the one clock a demand fetch takes; 40k of
them redirects), MOVEM_LOOP 69k, JSR/LINK/UNLK ~19k each. Fetches: 136k, 80 % one-clock, 3.6k
un-hinted. Data-behind-fetch 3k.

Next, in order of value: (1) the acknowledge clock and S_DECODE — the "memory states are not
states" pipelining, weeks; the contained first step is "hint the successor in the predicted
acknowledge clock" (a registered ack-expected flag from the hinted+vouched issue, the cache admitting a
cacheable request only when the hint bus repeats it, the in-place issue allowed in the acknowledge
clock) — P169's source and its addendum describe the trap; (2) the remaining read waits: 16k
line-spanning longwords (2 mod 4 at offset 14), 24k hinted fetches finding the cache busy (`hs_cst`);
(3) area, per the user, after 1.9.
