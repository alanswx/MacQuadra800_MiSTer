# Memory-source and branch lookahead (2026-09-14, candidates)

Build on checkpoint 9 (`CPU_STORE_LOOKAHEAD_20260914.md`). Core only. The
decode histogram (`CPU_DECODE_HISTOGRAM_20260914.md`) ranks the remaining
decode payers: conditional branches (15.8 % of dispatches, 98 % through
`S_DECODE`), `MOVE <mem>,Rn` (11.6 %, 90 %), `ALU <mem>,Dn` (4.3 %, 92 %).

## Memory-source lookahead (`/tmp/rm-cand.*`)

The register-only descriptor gains a `rd_mem` class: `MOVE/MOVEA
<mem>,Rn` and `ADD/SUB/CMP/AND/OR <mem>,Dn` with an address-register mode
(`(An)`, `(An)+`, `-(An)`, `d16(An)`, `d8(An,Xn)`) dispatch by lookahead
straight into `S_PIPE_START` with the base register selected on port A.
Guard: the retiring producer must not be writing that base register (its
write lands on the edge the port select does). Lookahead only; `S_DECODE`
keeps its bodies. AP suite 11/11, corpus 33,588,412 cycles, 0 REAL diffs,
latency fixture 1,940 (the fixture's own reads now dispatch a cycle
earlier and lose an idle-read match), Sieve identical to checkpoint 9 (no
such operands in its kernel). Boot A/B, simulated Speedometer and fits
(seeds 21, 22) running.

## Branch lookahead (`/tmp/bl-cand.*`, on top of the above)

A short `Bcc` (8-bit displacement, not BSR) at the queue head is resolved
in the producer's retire cycle on the producer's own flags
(`cond_true_fl` on `alu_fl` when the producer writes flags, on `sr`
otherwise). Taken: the same redirect `finish_bcc` would perform a cycle
later (refill dispatch when the target sector is buffered, `go_pc`
otherwise). Not taken: the word behind the branch is dispatched in its
place (two words popped). Excluded while tracing, with an interrupt
pending, on an odd target, and while a queue fetch acknowledges (its
append shares the ring with a refill seed).

AP suite 11/11; corpus 34,198,108 cycles (+1.8 % on that payload, 0 REAL
diffs); latency fixture 1,940; Sieve (checkpoint 9 in parentheses):
offset 0 **413,317** (452,615, -8.7 %), 6 408,437 (437,148, -6.6 %), 16
503,189 (523,362, -3.9 %), 30 436,936 (469,842, -7.0 %). Boot A/B,
simulated Speedometer and fits (seeds 21, 22) running. Timing concern:
the producer's ALU flags now gate the refill seed's ring writes.

### Boot A/B

- Memory-source lookahead: 80,572,025 dispatches (+0.08 % over
  checkpoint 9's 80,511,177), same frame, no faults.
- Branch lookahead: **75,125,666** dispatches reported, but the run got
  further (the extension icons have appeared on the "Starting up" frame;
  `S_MRD` entries +2.4 %, `S_MWR` +6 %, `S_PIPE_START` +1.8 %, `S_DECODE`
  entries -3.4 %), no faults. The count is low because
  `perf_dispatch_toggle` is a one-bit toggle: a not-taken branch and the
  word dispatched in its place flip it twice in one cycle, which the
  profiler sees as one dispatch. The simulator's dispatch metric therefore
  undercounts by the number of not-taken lookahead branches from this
  candidate on; cycles per test remain the honest measure.

### Memory-source lookahead: fit (closes at seed 21)

Tree `/tmp/MacQuadra800_rm_v512s21.*`: 38,406 ALMs (92 %), all 39 TNS
zero, worst setup +0.157 ns (HDMI), clk_sys +0.213 ns, clk_ram +0.918 ns,
worst hold +0.252 ns, no Critical Warnings. RBF SHA256
`9c184064373684285805dc767f385eaf02820c70b669c8c27bec6e59a38379f5`
(4,436,556 bytes); core `6029226a...`, cache, MMU and `wombat_cpu.sv`
unchanged from checkpoint 9. RTL identical to the boot-simulated tree.
Hardware run in progress.

### Branch lookahead: fit at seed 22 fails clk_sys by 1.264 ns (39,041 ALMs)

Worst paths `sr[13]` / `pc` / `epf_next` -> `epf_data[3]`: the address hint
mux -> MMU lookup pipe and fault decision -> physical address -> store
queue request -> cache acknowledge -> core `mem_ack` -> the lookahead's
`!(epf_pend && i_ack)` term -> refill seed select (`brf_seed_a`) ->
queue ring write, 30.6 ns of data delay. The acknowledge term is dropped
(`/tmp/bl2-cand`): the refill seed is written after the acknowledge's
append in the always block, so a same-cycle append cannot clobber it,
which was the only reason the pulse-era `finish_bcc` excluded it. Fits
(seeds 21, 22) and boot A/B of the revision running; seed 21 of the
original still fitting for the record.

### Memory-source lookahead: hardware — REJECTED

`/media/fat/_Unstable/MacQuadra800_rm_v512_seed21_20260914.rbf`, guard
exits 0/0/0, three valid runs: CPU Mix **0.720 / 0.721 / 0.721**, mean
0.7207, **-0.60 %** against checkpoint 9. Dhrystones +0.8 % and Queens
+0.8 % faster, but Puzzle 2.060 -> 2.115 s (+2.7 %) and Integer Matrix
1.429 -> 1.469 s (+2.8 %) slower; the rest within noise. The decode cycle
it removes was also the idle slot in which the queue fetched ahead of a
memory operand's read; without it the memory-heavy tests starve on
instruction supply. Not adopted; the branch lookahead is rebased on
checkpoint 9 alone (`/tmp/bl4-cand`). Evidence
`scratch/perf_rm_seed21_20260914/`.

### Branch lookahead on checkpoint 9 alone (`/tmp/bl4-cand.*`)

Refill-only taken path, no acknowledge term, no memory-source class. AP
suite 11/11; corpus 33,719,785 cycles (+0.55 % on that payload, 0 REAL
diffs); latency fixture 1,916; Sieve (checkpoint 9 in parentheses):
offset 0 421,997 (452,615, -6.8 %), 6 410,666 (437,148, -6.1 %), 16
519,651 (523,362, -0.7 %), 30 434,666 (469,842, -7.5 %). Fits (seeds 21,
22), boot A/B and simulated Speedometer running.

Boot A/B of the rebased tree: further along than checkpoint 9 in the
same bracket (first extension icon on the frame; `S_MRD` entries +1.8 %,
`S_MWR` +4.5 %, `S_DECODE` cycles -7.4 %), no faults; the dispatch count
(74,987,312) undercounts as explained above.

### Fits of the rebased tree and the fast-flag revision

Seed 21 of `/tmp/bl4-cand` routes at 38,720 ALMs but misses clk_sys by
**0.194 ns on one path**: `rr_b` -> register file -> ALU operand mux ->
shifter -> result select -> zero detect -> flag select -> `rd_bcc_fl` ->
condition -> refill seed select -> `epf_data`, 29.6 ns. The ALU's flag
output arrives at 27.9 ns because it comes through the full result mux.

Revision `/tmp/bl5-cand`: `ap040_alu` exports `fast_flags`/`fast_ok`,
the compare-class flags (ADD, SUB, CMP, MOVE, TST, AND, OR, EOR) taken
directly from the shared adder and the masked operands, identical to
`flags_out` for those operations; the branch lookahead judges the branch
on them and is refused after any other flag-writing producer. Behaviour
identical in every gate (AP 11/11, corpus 33,719,785, fixture 1,916, Sieve
421,997 / 410,666 / 519,651 / 434,666). Fits at seeds 21 and 22, boot A/B
and simulated Speedometer running; the plain tree walks seeds 22, 24, 20.

### Plain branch lookahead: fit closes at seed 20

Seed 24 missed the HDMI clock by 0.041 ns (CPU clock closed); **seed 20
closes**, tree `/tmp/MacQuadra800_bl4_v512s20.*`: 38,692 ALMs (92 %), all
39 TNS zero, worst setup +0.276 ns (clk_ram), HDMI +0.306 ns, clk_sys
+0.768 ns, worst hold +0.259 ns, no Critical Warnings. RBF SHA256
`124240812b6b9a7de8aa7998388e0025c839659b3b65498c1bd34892d35cdb3a`
(4,423,528 bytes); core `1cffa827...`, cache, MMU and `wombat_cpu.sv`
unchanged from checkpoint 9. RTL identical to the boot-simulated tree.
Hardware run in progress. The fast-flag revision keeps fitting as the
robust variant for later checkpoints.

### Hardware, plain branch lookahead seed 20: 1 valid run of 3 — NOT accepted

Run 1: CPU Mix **0.737** (Sieve 1.322 s, Quick Sort 0.864 s, Bubble Sort
0.975 s, Queens 0.716 s, Dhrystones 9144.6), +1.7 % over checkpoint 9.
Runs 2 and 3: the negative-time corruption (Dhrystones 2147483.647,
Towers -9672 s, ...), fresh alerts each time. Two of three is far above
the anomaly's historical rate and it did not occur in any of the five
three-run sets earlier today. Evidence `scratch/perf_bl4_seed20_20260914/`.

Cross-domain timing of this fit (`cross_sys2ram.txt` in the build tree,
`report_timing -from_clock clk_sys -to_clock clk_ram`): the SDRAM request
handoff `sdram_beat32|req_tgl -> req_handoff` has **+0.276 ns** of setup
margin, where checkpoint 9's build has +1.654 ns. `sdram-open-row-crossing.md`
records this family of crossings as placement-dependent with real PLL
skew that the constraints do not model, and names it as the source of an
identical negative-time fault on 2026-09-02. A repeat three-run set on
the same bitstream is running as a second sample; the crossing margin is
measured on every accepted build below to set a deploy threshold.

Cross-domain survey (`report_timing -from_clock clk_sys -to_clock
clk_ram`, worst setup on the `sdram_beat32` handoff, all with three valid
runs unless noted): write-path seed 22 +0.950 ns; level-offer seed 22
+2.102; immediate-dispatch seed 23 **+0.057**; memory-destination seed 22
+0.253; store-lookahead seed 21 +1.654; memory-source seed 21 +0.918;
branch-lookahead seed 20 +0.276 (1 of 3 valid). No correlation: the
margin is not the cause. No crossing from the video or HDMI domains into
the CPU clock appears among the constrained paths (they are cut and
synchronized). Pending: the repeat hardware set, the deterministic
Speedometer simulation of this RTL (a logic fault would reproduce there),
and the fast-flag variant on a different placement.

**Simulated Speedometer of the plain branch lookahead (results captured
20:33):** CPU Mix **0.752** (KWhetstones 533.3, Dhrystones 9173.6, Towers
1.381, Quick Sort 0.889, Bubble Sort 1.007, Queens 0.726, Puzzle 1.925,
Permutations 2.091, Integer Matrix 1.313, Sieve 1.320), every value
plausible, against 0.723 simulated for checkpoint 8 (+4.0 %). The
deterministic simulator does not reproduce the hardware corruption; a
fault that depends on real interrupt timing is not excluded.

### Hardware, repeat set on the same bitstream: three valid runs — accepted 2026-09-14

Set 2 (`scratch/perf_bl4_seed20_20260914_set2/`), guard exits 0/0/0,
fresh alert each run, no anomaly:

| Test | run 1 | run 2 | run 3 |
|---|---:|---:|---:|
| KWhetstones/sec | 492.817 | 495.241 | 495.300 |
| Dhrystones/sec | 9145.812 | 9145.862 | 9141.822 |
| Towers (s) | 1.372 | 1.372 | 1.372 |
| Quick Sort (s) | 0.864 | 0.863 | 0.863 |
| Bubble Sort (s) | 0.975 | 0.975 | 0.975 |
| Queens (s) | 0.716 | 0.716 | 0.716 |
| Puzzle (s) | 2.057 | 2.057 | 2.061 |
| Permutations (s) | 2.033 | 2.033 | 2.033 |
| Integer Matrix (s) | 1.427 | 1.417 | 1.425 |
| Sieve (s) | 1.322 | 1.320 | 1.321 |
| **CPU Mix** | **0.737** | **0.738** | **0.738** |

Mean of set 2 **0.737667**, **+1.75 %** over checkpoint 9 (0.7250) and
+59.1 % over the source-only 0.4635; the four valid runs across both sets
are 0.737, 0.737, 0.738, 0.738. Sieve -6 % (1.405 -> 1.321 s), Quick Sort
-4 %, Bubble Sort -2 %, Dhrystones +1.8 %. Accepted on the same basis as
the ATC-copy checkpoint on 2026-09-13 (one set with invalid runs, one
clean set, consistent valid values). The two corrupted runs of set 1 are
recorded against the open negative-time anomaly
(`SPEEDOMETER_TIMING_DIAGNOSTIC.md`); their rate on this bitstream (2 of
6) is higher than on the day's other builds (0 of 15) and the simulator
does not reproduce them, so the anomaly diagnosis should retest this
build first. Board restored to MENU, Main and disposable disk verified.
