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
