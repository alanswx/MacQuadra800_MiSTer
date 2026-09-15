# One-clock data-read hit on the hinted idle read (2026-09-14, candidate)

Builds on the level-offer candidate (`CPU_LINE_OFFER_20260914.md`). One
cache change, `ap040_cache.v` only.

## Why

The Speedometer profile of the write-path build spends 26 % of all cycles
in `S_MRD` (291 M cycles, 57 M reads, 5.1 clocks each), and 168 M of those
cycles are spent with the cache idle. A hinted read costs two clocks in
`S_MRD`: the core's address hint lets the cache read its tag and data
arrays a cycle early, the request cycle qualifies the settled read
(`idle_hit`) and registers the acknowledge, and the core consumes it the
cycle after. The register between the qualified hit and the core is the
one clock this candidate removes, for data reads only.

## What

`fast_hit = idle_hit && !c_instr`. `c_ack` and `c_rdata` present the hit
combinationally in the request cycle (`ack_r | fast_hit`, `fast_data`
from the same tag compare and word select `idle_hit` already uses); the
idle-admission branch no longer registers a data acknowledge. Instruction
fetches keep the registered acknowledge: their consumer is the fetch
queue's ring write, the path that failed timing by 7 ns once already.

The path added to the 33 MHz domain: settled tag RAM output -> 4-way
compare -> `hit_way` -> data word select -> lane extract -> MMU
pass-through -> core `mem_ack`/`mem_rdata` -> ALU -> register file. The
MMU's request qualification (`pass_ok`, the ATC hit copy) already sits in
front of `rd_accept`, so the request-cycle path now runs from the core's
registered address through translation, tag compare and retirement in one
clock. The fit decides whether that closes; the RTL is otherwise complete.

## Results so far

- AP suite 11/11 after updating `tb_ap040_cache_snoop` T14: a settled data
  read is acknowledged in 1 clock, not 2 (the data checks are unchanged;
  the unsettled read still takes 3).
- Corpus gate: identical cycles, 0 REAL diffs.
- Latency fixture: 1,983 -> **1,940** clocks PASS; 40 data reads at 1
  clock (all hinted warm hits), the rest unchanged.
- Sieve sweep (cycles; level-offer candidate in parentheses): offset 0
  567,807 (575,473), 6 555,588 (563,258), 16 608,727 (616,415), 30 582,631
  (590,305): -1.3 % everywhere, arrays and guards PASS.

Pending: boot A/B, simulated Speedometer, seed-22 fit, hardware.
Candidate tree `/tmp/rd-cand.*`.

### Boot A/B (done, holds)

Same bracket as before (`/tmp/simboot-sb2.*/run` versus `/tmp/simboot-rd.*/run`):
opcode dispatches 70,341,042 -> **72,300,926** (+2.79 %), 5.971 -> 5.809
clocks per dispatch, no faults; the frame differs only in the "Starting
up" progress bar being three pixels further along.

### Fit (done, FAILS timing) — parked

Seed 22, `VIDEO_512_OFF`, tree `/tmp/MacQuadra800_rd_v512s22.*`: clk_sys
worst slack **-6.591 ns**, TNS -4,746.8; every worst path runs from
`core|rr_a[0]` to `core|mem_addr_q[4]` / `core|epf_count[1]`
(`worst_paths.txt` in that tree). That is the register-file read address
-> `rf_rdata_a` -> hint adder -> `mem_addr` mux -> MMU hit-copy compare
and physical-address mux -> cache tag compare -> `fast_hit` -> `c_ack` ->
core `mem_ack` -> next-state logic. Logically a false path (the
acknowledge fires only with `mem_req` set, when the mux passes the
registered `mem_addr_q`), but the hint shares the address bus, so the
analyzer follows it, and the registered acknowledge used to be where it
ended.

Fix, not attempted yet: a separate hint bus. The core drives `hint_addr`
on its own port; the MMU uses it only for the ATC RAM index and the cache
only for the idle RAM reads (page-offset bits, no translation), while
`mem_addr` carries the registered request address alone. The request
cycle path then starts at `mem_addr_q`; registering the hint's translated
tag in the hint cycle would shorten it further (compare `tag_q` against a
registered physical tag and the registered hint address). Ports change in
core, MMU, cache, `wombat_cpu.sv` and the compat wrapper.

The candidate's gains stand in simulation (boot +2.8 % dispatches, Sieve
-1.3 %, fixture 1,983 -> 1,940). Parked until the hint bus exists.

### Hint bus (done in RTL; fit pending)

Implemented on top of the extension-word candidate as `/tmp/hb-cand.*`:

- Core: `mem_addr`/`mem_instr` carry only the registered request;
  `mem_hint_addr`/`mem_hint_instr` carry the hint (the held request while
  a translation walks, so the idle read stays on it).
- MMU: `c_hint_*` in, `m_hint_addr`/`m_hint_instr` down (only the page
  offset is used below), `m_hint_ptag` (the hint translated through the
  hit copy and the TTRs, registered) and `m_hint_match` (the request now
  presented equals the registered hint in address, space and supervisor
  state, and the copy, TC, TTRs, walker, sweep and fill are all quiet).
- Cache: idle RAM reads index by the hint bus while no request is
  presented; `fast_hit` is `idle_hit` with the live tag compare replaced
  by one against `c_hint_ptag`, qualified by `c_hint_match`, data only.
  A data hit the hint does not vouch for keeps the registered acknowledge.
- Wrapper, compat wrapper and the snoop bench carry the new ports (the
  bench ties the hint bus to its request and expects settled data reads
  in one clock).

Gates: AP suite 11/11, corpus identical, latency fixture 1,905 clocks
(38 one-clock data reads), Sieve byte-for-byte the combined tree's cycle
counts (545,343 / 538,284 / 600,552 / 568,348). Fit at seed 22 running.

**Boot A/B of the hint-bus tree:** 74,023,600 dispatches (+5.2 % over the
level-offer checkpoint) against 76,466,746 for the unfittable shared-bus
tree with the same core. The profile showed the loss in `S_MRD` idle
cycles (+10.5 M): the registered hint translation consulted only the hit
copy, so every first access to a page after a copy miss, where the lookup
pipe resolves the request in the same cycle it refills the copy, fell back
to the registered acknowledge. Fixed by letting the hint translate through
the pipe's entry when the hint equals the request being resolved
(`hn_pipe`); the change is in the registered hint path only.

**Bug found 2026-09-14 (fixed in `/tmp/hb-cand` and `/tmp/im-cand`):** the
hint's ATC row was derived from the request bus (`{c_hint_instr, a_set}`
with `a_set` still a function of `c_addr`), so the hit copy compared the
hint's tag against the request's set and matched only when both shared a
set. That, not the pipe, is why the hint-bus tree's boot A/B (74.0 M
dispatches) trailed the shared-bus tree (76.5 M). `hn_set` now comes from
`c_hint_addr`. The latency fixture, which runs with TC on and a single
set, could not see it (40 one-clock reads before and after).

### Hint-bus fit (seed 22): FAILS — router gives up at 93 %

38,856 ALMs needed (accepted build 38,459, +397: MMU 826 -> 902, core
+150 for the extension-word changes and hint mux, cache the rest);
"Fitter failed to successfully route the design", then "Can't fit design
in device". No timing result. Area diet before the next attempt: drop the
128-bit TTR shadow (a one-bit "TTR written this cycle" pulse suffices),
drop the hint-side TTR compare (a TTR-mapped hint then simply keeps the
registered acknowledge), and consider narrowing `hq_addr` to the bits the
match needs. A seed walk is the other lever; routing failures at this
utilization are seed-sensitive.

## Ported onto checkpoint 15 (2026-09-15, `/tmp/dovm-cand.*`)

The hint-bus version (`/tmp/im-cand`, the tree with the ATC-row fix) is
reapplied on checkpoint 15 (decode-record handover, 16 KB caches, the
line-crossing reads): MMU, wrapper, compat wrapper and snoop bench patch
cleanly; the core takes the two hint-bus ports and the registered
request bus; the cache's three conflicting hunks are merged by hand
(`x_set`/`x_row` at `SETW` width, the hint's idle read index and the
crossing read's second-lookup redirect in `tag_ridx`/`rd_row`, the
fast-hit tag compare against the top `TAGW` bits of the MMU's 22-bit
hint tag).  With the area diet the expected fit is checkpoint 15's
38,663 plus about 400 ALMs, the size at which checkpoint 14 routed at
one seed in two.  AP, latency, corpus, Sieve and diet-base fits at seeds
20 and 22 running.

Gates on checkpoint 15: AP 11/11 (the snoop bench's one-clock settled
read included), latency fixture 1,938 -> **1,902**, corpus identical
(33,335,739, 0 real diffs), Sieve 422,007 / 410,671 / 519,654 / 434,671
-> 414,327 / 402,985 / 511,980 / 426,997 (-1.8 %), boot A/B 76,218,560
-> **80,480,432 dispatches (+5.6 %)**, `S_MRD` 144.1 M -> 132.3 M
cycles.  The seed 22 fit needs **38,650 ALMs**, checkpoint 15's own
size (38,663): on the diet base the hint bus costs nothing measurable;
it failed routing at that seed, seeds 20, 21 and 23 running.
Speedometer sim running.

Seed walk of the port: seed 22 failed routing (38,650 ALMs); seed 20
routed (38,737) but the **CPU clock** (`general[0]`, 33 MHz; `general[1]`
is the 99 MHz RAM clock, earlier notes had the two swapped) failed by
2.0 ns, and its worst path is not the new one-clock acknowledge: it is
`dst_addr[31]` into the `mwr` in-place issue and the `mem_addr_q` mux,
with a single 17.4 ns interconnect hop on the first element, a routing
detour rather than logic depth (the logic itself sums to about 14 ns).
The dovg walk showed the same signature (seed 24 -0.56 ns, seed 23
-8.0 ns, seed 20 -1.5 ns on the CPU clock).  Seeds 21, 23, 24, 25
running.

Seed walk so far: 20 (CPU clock -2.0 ns), 21, 22, 24, 25, 26 (routing),
none closed; 23, 27, 28, 29, 30 running.  The failed fits say why
routing is so tight at 92 %: "Design requires adding a large amount of
routing delay for some signals to meet hold time requirements", and the
hold summary charges about 800 to 970 ns of inserted delay to paths
inside the 33 MHz domain itself (the same on the diet base and on the
passing dovi seed 20: 975 and 968 ns), a consequence of the skew across
the 33 MHz clock network (8.6 ns launch against 7.2 ns latch on the
worst path above).  That budget is spent on every build; whether the
remaining routing closes is then the seed's luck, about one in four at
this size.

Seeds 27 and 28 failed routing, seed 29 routed and missed the CPU clock
by 0.95 ns; the worst path there (TimeQuest re-run on the tree) runs
`state[5] -> epf_count -> hint_pipe_dst -> the hint address -> mmu
Equal1 (the hint-equals-request compare) -> lk_fresh -> pipe_ent ->
m_addr -> store_buffer buffer_req -> cache c_ack -> core mwr ->
mem_wdata enable`: the hint bus's own path into the acknowledge through
the MMU's pipe entry (`hn_pipe`, the case where the hint translates
through the request being resolved), about 22 ns of logic before the
hold-fix delay the fitter added on the enable.  The re-run reports the
hold-padded path at -18 ns where the flow's summary says -0.95, so the
re-run's absolute numbers are not trusted, only the path shape.  Seeds
30, 31, 32 and the aggressive-area experiment running.

Correction: the two TimeQuest re-runs above (dovm seeds 20 and 29) and
a third on the passing dovi seed 20 tree produced byte-identical path
tables (-18.7 ns on `state[5] -> mem_wdata[25]`, a 25 ns hold-fix hop
on the enable) although the flow's own summaries say -2.0, -0.95 and
+0.19 ns, so those re-runs did not analyse the fitted netlists and the
path shapes quoted from them, including the "hint through the MMU pipe
entry" reading, are withdrawn.  What stands: the flow's per-clock
summaries (dovm seed 20 -2.0 ns and seed 29 -0.95 ns on the CPU clock,
seven other seeds unroutable), and that dovg, without the hint bus,
failed the same clock on three seeds.  A path report needs the flow's
own STA run with a path table enabled, not a bare `project_open`.

**Simulated Speedometer of the port (dovm): CPU Mix 0.861** against
checkpoint 15's 0.839 (+2.6 %): KWhetstones 625.4/s, Dhrystones
10,693/s (from 9,942), Towers 1.188 s, Quick Sort 0.819, Bubble Sort
0.891, Queens 0.672, Puzzle 1.571, Permutations 1.919, Int. Matrix
1.002, Sieve 1.267 s; bracket 1,003.2 M cycles for 216.2 M dispatches
(4.64 clocks per dispatch, from 4.81).  On hardware that is about 0.88
if a seed closes.

Seed 30 failed routing too (0 of 10; 23 hung silent like dovi's seed 22
and was stopped).  One structural suspect is the request/hint mux the
port left in front of every cache RAM address input (`x_addr = c_req ?
c_addr : c_hint_addr`, about fifty address bits over four data arrays
and the tag array): the core already repeats a presented request on the
hint bus, so `dovq` indexes the RAMs from the hint bus alone, which is
the same value whenever it matters and removes the mux and a fan-in of
the request bus from the RAM address paths.  Behaviour identical by
construction (the boot must reproduce 80,480,432); AP, latency, corpus,
boot and fits at seeds 20 and 22 running, with dovm seeds 31 and 32 and
the aggressive-area experiment still in the walk.
