# Memory-destination fast path and wide branch refill seed (2026-09-14, candidate)

Builds on checkpoint 7 (`CPU_IMM_DIRECT_20260914.md`). Core only.

## Why

`move.l Dn,d16(An)` ran decode, pipe start, `S_PIPE_SREG` (read the
source on port A), `S_PIPE_DST`, `S_EA_DISP`, immediate fetch, `S_EA_D16`,
`S_PIPE_DEA`, `S_EXEC`, then two clocks of `S_MWR`: eleven states for a
store. The Speedometer profile has 6.85 M `S_PIPE_SREG` entries and
10.8 M `S_EA_DISP -> S_PIPE_DEA` transitions (simple address-register
destinations) per run.

## What

1. Decode places the ports: for MOVE with a register or immediate source
   and a memory destination, port A takes the destination base and port B
   the source register; the `Dn,<ea>` ALU groups point port B at `Dn`
   (port A already holds the `<ea>` base). `S_PIPE_START`'s register-source
   branch, when the ports are so placed, captures the source from port B
   (`rf_capture_b`) and calls `ea_operand_start` for the destination at
   once, skipping `S_PIPE_SREG`, `S_PIPE_DST` and the register-select cycle.
2. `ea_operand_start` resolves `(An)`, `(An)+` and `-(An)` destinations
   in place (address, register update and undo record as `S_EA_DISP` did),
   landing in `S_EXEC` or, for a read-modify-write, issuing the read with
   the matching pipe-start hint; `S_EA_DISP` and `S_PIPE_DEA` are skipped.
   With the d16 direct path from checkpoint 7, `move.l Dn,d16(An)` is now
   decode, pipe start, execute, store.
3. The taken-branch refill seed grows from a fixed four words to every
   valid word from the target to the sector end, up to the queue's eight.
   The trace of the Sieve inner loop showed why: once the store sequence
   got short, the speculative prefetch had no idle slot left and the loop
   took demand fetches (`S_FETCH`, `S_IMMF`) for its remaining words; a
   whole-body seed removes them.

## Results so far

- AP suite 11/11 after each step; corpus 33,816,420 cycles (-0.44 %), 0
  REAL diffs; latency fixture 1,922 -> 1,916.
- Sieve (checkpoint 7 in parentheses), steps 1+2 only: offset 0 528,776
  (520,590, +1.6 %), 6 520,879 (-1.5 %), 16 583,843 (-1.4 %), 30 549,556
  (-1.5 %). With step 3: 0 523,834 (+0.6 %), 6 **504,402** (-4.7 %, bus
  requests 81 k -> 32 k), 16 577,938 (-2.4 %), 30 564,506 (+1.2 %). The
  alignments that regress do so on instruction supply, not on the
  stores; net across the four, -1.3 %.

Pending: boot A/B, simulated Speedometer, fits (seeds 23 and 22),
hardware. Tree `/tmp/md-cand.*`.

### Boot A/B (done, holds) and a synthesis surprise

Boot A/B: 74,480,527 -> **80,431,347** dispatches (+8.0 % over checkpoint
7), 5.222 clocks per dispatch, the same "Starting up" frame with the
progress bar further along, no faults.

Both fits (seeds 23 and 22) failed before placement: "Fitter requires
5073 LABs", 50,381 ALMs needed (120 %). Synthesis shows the core's own
logic at 43,873 LUT-equivalents against 27,032 in checkpoint 7 with one
register more, so it is a combinational blow-up. Restructuring the
EA-start task to one expansion per call site and one read issue per
expansion (`/tmp/md3-cand`, identical Sieve cycles) changed nothing
(43,873). The remaining suspect is the wide refill seed: `issue_ifetch`
is expanded at several call sites, each now carrying eight 16-way word
muxes from the refill buffer. Two synthesis-only builds are attributing
it: A = everything but the wide seed, B = the wide seed alone.

**Attribution (synthesis-only builds):** A = everything but the wide seed:
core 26,540 own LUT-equivalents; B = the wide seed alone on checkpoint 7:
**43,805**. `issue_ifetch` has eight call sites, and each expansion
carried eight 16-way, 16-bit word muxes from the refill buffer. Fix
(`/tmp/md4-cand`): the task only counts the valid words and raises a
request; one shared block at the end of the always block (after the
line-offer and acknowledge ring writes, so the seed lands last) performs
the eight muxes once. Core own logic **25,683**, estimate 37,650 ALMs,
below checkpoint 7's 27,032 / 38,588, because the old per-site four-word
seeds went with it. Sieve cycles identical to the unhoisted candidate,
AP suite 11/11, latency fixture 1,916, corpus 33,709,922 cycles, 0 REAL
diffs. Fits at seeds 23 and 22 and the boot A/B running.

Boot A/B of the hoisted-seed tree: byte-identical to the unhoisted one
(80,431,347 dispatches, 5.222 clocks per dispatch, same frame).

### Fit (done, closes at seed 22)

Seed 23 failed in routing at 38,146 ALMs; **seed 22 closes**, tree
`/tmp/MacQuadra800_md4_v512s22.*`: 38,094 ALMs (91 %), all 39 TNS zero,
worst setup +0.253 ns (clk_ram), HDMI +0.491 ns, clk_sys +0.712 ns, worst
hold +0.253 ns, no Critical Warnings. RBF SHA256
`9fdfc2345023a6bd852102574ca00add6cfd4d78b922416bddaeec7a4d749624`
(4,421,744 bytes); core `c2adc1ac...`, cache, MMU and `wombat_cpu.sv`
unchanged from checkpoint 7. RTL identical to the boot-simulated tree.
Seeds 24 and 21 still running as spares. Hardware run in progress.

### Hardware (done, three valid runs) — accepted 2026-09-14

`/media/fat/_Unstable/MacQuadra800_md4_v512_seed22_20260914.rbf` through
the lifecycle guard (dry-run, deploy, restore all exit 0), fresh alert
each run, no anomaly:

| Test | run 1 | run 2 | run 3 |
|---|---:|---:|---:|
| KWhetstones/sec | 490.967 | 492.989 | 493.307 |
| Dhrystones/sec | 8946.645 | 8950.331 | 8949.514 |
| Towers (s) | 1.378 | 1.377 | 1.379 |
| Quick Sort (s) | 0.913 | 0.912 | 0.912 |
| Bubble Sort (s) | 1.007 | 1.006 | 1.007 |
| Queens (s) | 0.730 | 0.730 | 0.730 |
| Puzzle (s) | 2.064 | 2.064 | 2.082 |
| Permutations (s) | 2.052 | 2.051 | 2.052 |
| Integer Matrix (s) | 1.453 | 1.444 | 1.445 |
| Sieve (s) | 1.620 | 1.619 | 1.618 |
| **CPU Mix** | **0.706** | **0.708** | **0.707** |

Mean **0.707000**, **+3.32 %** over checkpoint 7 (0.6843) and +52.5 % over
the source-only 0.4635. Every test faster: Dhrystones +7.9 %, Towers
-4.8 %, Sieve -4.7 %, Bubble Sort -3.9 %. The boot simulation's +8 %
dispatches overstated the benchmark gain: boot code is store-heavy in a
way the CPU Mix is not. Evidence `scratch/perf_md4_seed22_20260914/`.
Seed 21 also closes (+0.270 ns HDMI). Board restored to MENU, Main and
disposable disk verified.

**Simulated Speedometer (probe run, results captured 18:15):** CPU Mix
**0.723** (KWhetstones 531.0, Dhrystones 8972.4, Towers 1.387, Quick Sort
0.928, Bubble Sort 1.028, Queens 0.739, Puzzle 1.930, Permutations 2.111,
Integer Matrix 1.339, Sieve 1.636); profile 1,094,144,167 cycles, 5.185
clocks per dispatch. Hardware measured 0.707: the simulator reads 2.3 %
high, as before.
