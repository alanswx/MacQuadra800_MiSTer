# Instruction line return to the prefetch queue (candidate, 2026-09-14)

Follows the accepted address-hint checkpoint (`CPU_ADDR_HINT_20260913.md`).

## Why: instruction supply is the limiter

Per-instruction cycle attribution in the exact Speedometer Sieve kernel
(fixture `scripts/fixtures/wombat_sieve`, offset 0, accepted RTL):

| instruction | clocks |
|---|---:|
| `move.b #1,(0,a2,d3.w)` / `clr.b (0,a2,d4.w)` | 12 |
| `tst.b (0,a2,d3.w)` | 10.8 |
| `addq.w #1,d3` after the store | 5 |
| `cmpi.w #$1ffe,dn` | 4 to 5 |
| `ble.s` taken | 2 to 3 |
| `move.w`/`add.w` register forms | 1 to 2 |

A register instruction costs 1 clock when its opcode is resident and 3 to
5 when it is not. The prefetch queue drains because the fill engine is
locked out during EA states and while the port carries data, and a
longword fetch supplies at most one word per clock, exactly the rate a run
of one-clock instructions consumes. Folding the post-write `S_NEXT` state
(saves 1 clock per store) only moved the stall onto the following
instructions and lost at two alignments, so it is not adopted.

## What the candidate does

1. `ap040_cache.v`: the four way arrays are word-interleaved (array k holds
   word w of way v where (v + w) mod 4 = k, at index {bank, set, v}). A
   word-wise read addresses array k at way (k - w); a line-wise read
   addresses every array at the hit way and returns the whole 16-byte line
   in one cycle. The one-longword lookahead becomes a 128-bit line buffer,
   valid for any word of the line; a normal or idle-admission instruction
   hit seeds it on its own edge, and the buffer is offered to the core as a
   sideband (`c_line_stb/tag/data`) one cycle after every instruction ack.
2. `ap040_mmu.v`: pass-through of the sideband.
3. `ap040_core.v`: on the strobe, append every word from the fill tail to
   the end of the offered line that fits in the 8-word ring (up to 8), and
   seed the branch-refill sector buffer from the line. Refused while a
   queue fetch is outstanding or issued in the same cycle (its return would
   append the same words again) or after a flush in the same cycle.
4. Wrappers (`wombat_cpu.sv`, `ap040_tg68k_compat.v`): wiring.

Tree: the directory named in `/tmp/line-cand.path`.

## Results so far

- AP suite 11 of 11 after each step; corpus gate 0 REAL diffs.
- Latency fixture: 1,921 -> 1,841 clocks (-4.2 %) with the line append
  (interleaving alone is cycle-neutral, as intended). The fixture's shadow
  probes needed the interleaved index rule (local copy fixed).
- Sieve sweep: mixed (-3 % to +4 % per offset). Per-PC attribution at
  offset 0 shows the register instructions after the store still waiting,
  so the append is being refused in the hot loop; tracing in progress.

## Trace findings and the completed candidate

The first line-return build gained little because two things kept the
offer from landing in the hot loop: a buffer-hit acknowledge raised the
strobe in the same cycle as the acknowledge (the core cannot append then),
and a queue seeded from the branch-refill buffer refused speculative
filling until it starved. Fixing both made every Sieve alignment faster
(-6.1 % overall). Per-instruction attribution then showed the byte store at
12 clocks and the loop branch at 3.6, and the branch's cause: the fill
engine's speculative fetch past the loop end evicted the refill buffer's
sector and occupied the port at the redirect.

Added on top (all in `ap040_core.v`):

1. A memory destination with an immediate or no source starts its EA from
   `S_PIPE_START` (skipping `S_PIPE_DST`, and `S_EA_DISP` for extension
   modes).
2. `ea_operand_start` consumes a resident extension word inline from
   `S_PIPE_START` when the base register is already on port A, going
   straight to `S_EA_D16` or `S_EA_EXTW2`.
3. A completed store with nothing left to do retires straight into the
   next opcode instead of visiting `S_NEXT`.
4. A taken short Bcc whose target window is in the refill buffer decodes
   directly from it, as DBcc does, even with a speculative fetch pending
   (the fetch is killed).
5. The refill buffer keeps the sector of the last redirect: a speculative
   fill into another sector neither replaces its tag nor touches its data
   (touching data with the old tag standing was a real bug, caught by the
   FPU suite). A CPU write into the sector invalidates it.
6. Line offers are identified by the logical line and context of the
   fetch that produced them, recorded on every instruction acknowledge
   (including the exception prefetch's own, which is not a queue fetch;
   missing that was the second bug the FPU suite caught: handler lines
   were credited to the pre-exception sector and an RTE refilled garbage).
   The physical line tag from the cache is no longer compared against the
   logical fetch tail, which would have been wrong with translation on.

Results (core `c8234321...`, cache `6310b9e5...`):

| gate | result |
|---|---|
| AP suite | 11 of 11 |
| corpus | 33,932,693 cycles (-2.3 %), 0 REAL diffs |
| latency fixture | 1,785 clocks (from 1,905; original 2,188) |
| Sieve sweep | 9,893,286 total (-20.2 % vs the accepted 12,394,101), every offset faster |

Sieve per-instruction at offset 0 (accepted -> candidate): byte store 12 ->
9, `tst.b` 10.8 -> 10.8, `addq` 5 -> 2, `cmpi` 4 to 5 -> 3 to 3.5, loop
`ble.s` 2.8 -> 1.9, register forms 1 to 2. Pending: fit, boot A/B, hardware.

## Fit of the first line-return build: timing failed, and why

`/tmp/MacQuadra800_line_seed24.Gz6fOH` (cache `6310b9e5...`, core
`896101c2...`, without the sequencer trims): 37,578 ALMs (+752), 4,116
LABs (75 free), RAM inference unchanged (the 128-bit line buffer is
registers), but **clk_sys setup -7.324 ns, TNS -3630**, HDMI -2.8 ns and
clk_ram -1.45 ns as placement fallout. All 200 worst paths end at
`ap040_core|epf_data[0][13]` and launch from `sr[12]`, `rr_b`, the A7
banks and `dreg`: the register file -> ALU -> pop/flush decision -> line
append word count -> 8-way ring write mux. The append's `room` used this
cycle's `epf_pop`, and its guards used `epf_flushed`/`epf_issue`, all
blocking values decided deep in the state case.

Fix (core `b2afc434...`): the offer is evaluated before the state case from
registered state only (`epf_count`, `epf_ftail`, `epf_fill`, `epf_pend`,
`mem_ack`, `iline_log/super`); a flush or seed later in the cycle overrides
the ring writes by nonblocking order and the merged bookkeeping drops the
count advance when `epf_flushed` is set; the CPU-write invalidation of the
refill buffer is ordered after it so it wins. `room` ignores the current
pop, so up to two fewer words are taken in the pop cycle: Sieve total
9,893,286 -> 10,069,395 (still -18.8 % against the checkpoint), corpus and
fixture unchanged (33,932,693; 1,789). Suite 11 of 11. Fit pending.

## Full-machine results for the final candidate (core `b2afc434...`, cache `48f7497a...`)

Boot A/B (`/tmp/simboot-run-final.q8FdbX`, same bracket as always):
68,299,498 dispatches at **6.149 clocks/dispatch** versus 57,306,687 at
7.329 for the adopted RTL (+19.2 % instructions in the same clocks). Fetch
wait cycles 61.6 M -> 38.7 M, `S_NEXT` gone, `S_EA_DISP`/`S_PIPE_DST`
occupancy down two thirds.

**Simulated Speedometer 4.02 CPU Mix** (`/tmp/simspeedo-final.50eyYG`,
same procedure as `CPU_SPEEDOMETER_PROFILE_20260914.md`; the agent driving
it was cut off by a rate limit after the completion alert, so the bracket
end and the results shot were taken by hand afterwards):

| Test | sim, cache-early RTL | sim, this candidate | hardware, adopted (hints) |
|---|---:|---:|---:|
| KWhetstones/sec | 392.506 | 442.652 | 400.5 |
| Dhrystones/sec | 5474.004 | 7114.237 | 6454 |
| Towers (s) | 1.916 | 1.677 | 1.695 |
| Quick Sort (s) | 1.304 | 1.053 | 1.143 |
| Bubble Sort (s) | 1.547 | 1.151 | 1.306 |
| Queens (s) | 1.059 | 0.860 | 0.930 |
| Puzzle (s) | 2.822 | 2.457 | 2.696 |
| Permutations (s) | 3.058 | 2.552 | 2.594 |
| Integer Matrix (s) | 1.942 | 1.780 | 1.976 |
| Sieve (s) | 2.988 | 2.005 | 2.457 |
| **CPU Mix** | **0.493** | **0.600** | 0.543 |

The simulator's first result tracked hardware within 2 % (0.493 vs 0.485),
so the expectation for this candidate on the board is about 0.59, roughly
+9 % over the adopted 0.543. Profile of the bracket (1,145,798,656 clocks,
6.62 per dispatch, versus 8.05): fetch waits 9.6 % -> 5.4 %, `S_MRD` still
31 % at 6.4 clocks per read (was 7.6), `S_MWR` 11.4 % at 4.2 per write
(was 5.5). Memory access is now 42 % of all cycles and the next target.

### Matched trimmed seed-24 fit of the final candidate (done, timing met)

Tree `/tmp/MacQuadra800_store_seed24.yQloII` (core `b2afc434...`, cache
`365e05cf...`, which differs from the final `48f7497a...` only in which of
two aliased wires carries the simulator probe comment; MMU `29de0a98...`;
QSF byte-identical to the accepted build). Quartus exit 0, log
`output_files/build_20260914_065307.log`.

| metric | hints (accepted) | line return + trims | delta |
|---|---:|---:|---:|
| ALMs (logic utilization) | 36,826 | 38,126 | +1,300 |
| registers | 23,164 | 23,246 | +82 |
| setup slack, clk_sys 33 MHz (CPU) | +1.165 ns | +1.114 ns | -0.05 |
| setup slack, clk_ram 99 MHz | +0.295 ns | +1.011 ns | +0.72 |
| setup slack, HDMI | +0.347 ns | +0.138 ns | -0.21 |

No negative slack in any analysis, all TNS zero, no Critical Warnings in
fit or STA (the one pre-existing map warning only), cache and ATC arrays
still block RAM. The registered append cured the -7.3 ns path completely.
RBF SHA256 `83bb3198688bac4e...`, 4,448,820 bytes. Hardware run in
progress (`scratch/perf_line_seed24_20260914/`).

### Hardware set 1 (two valid runs, one invalid)

Deployed through the guard (dry-run, deploy, restore all exit 0) as
`/media/fat/_Unstable/MacQuadra800_line_trim_seed24_20260914.rbf`. Core
load 07:20:43, run starts 07:24:19 / 07:27:31 / 07:30:35.

| Test | Run 1 (INVALID) | Run 2 | Run 3 |
|---|---:|---:|---:|
| KWhetstones/sec | 408.258 | 409.222 | 409.460 |
| Dhrystones/sec | 7124.479 | 7125.570 | 7126.388 |
| Towers (sec) | 1.621 | 1.622 | 1.622 |
| Quick Sort (sec) | 1.026 | 1.024 | 1.025 |
| Bubble Sort (sec) | 1.128 | 1.128 | 1.128 |
| Queens (sec) | 0.844 | 0.844 | 0.844 |
| Puzzle (sec) | 2.546 | 2.546 | 2.566 |
| Permutations (sec) | 2.449 | 2.449 | 2.449 |
| Integer Matrix (sec) | 0.247 | 1.912 | 1.924 |
| Sieve (sec) | -4098.000 | 2.003 | 2.003 |
| CPU Mix | -32.686 | **0.591** | **0.590** |

Run 1 is the recurring negative-time anomaly (Sieve -4098.000 with a
fresh completion alert; the eight earlier tests in that run agree with
runs 2 and 3 to the third decimal, so the corruption struck during
Integer Matrix and Sieve only). Runs 2 and 3, parent-verified on the
screenshots (guest clock 11:29 and 11:32): mean **0.5905**, **+8.68 %**
over the accepted 0.543333, and within 0.1 % of the simulator's
prediction. A second set of three follows for the three-valid-run rule.
Evidence `scratch/perf_line_seed24_20260914/`.

### Hardware set 2 and decision

Same RBF, guard exits 0. Runs **0.590 / INVALID / 0.590** (run 2 reported
Dhrystones -2147483.648 and negative times for every test: the anomaly
struck before or during its first test). Parent verified runs 1 and 3 on
the screenshots (guest clock 11:43, 11:49). Evidence
`scratch/perf_line_seed24_20260914_set2/`.

Four valid runs across the two sets: 0.591, 0.590, 0.590, 0.590; mean
**0.5903**, **+8.65 %** over the accepted 0.543333, matching the simulator
(0.600, predicted about 0.59 on the board).

**Accepted 2026-09-14.** Cumulative on the trimmed seed-24 profile since
the source-only 0.4635: cache admission 0.485, ATC copy 0.503, hints
0.543, line return **0.590** (+27.4 %).

Anomaly bookkeeping (invalid runs / total, per candidate on the same
board and disk): trimmed source-only 1/3, cache admission 0/3, ATC copy
1/6, hints 0/3, line return 2/6. The pre-existing rate is about one in
five; this candidate's two in six is within that noise but is now
tracked per candidate. Each invalid run shows the Microseconds-based
elapsed times going impossibly negative for whole tests while the guest
otherwise runs normally and the next run is clean.
