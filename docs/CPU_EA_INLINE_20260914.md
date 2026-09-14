# Inline extension words and direct d16(An) reads (2026-09-14, candidate)

Builds on the fast-read candidate (`CPU_FAST_READ_20260914.md`). Core only
(`ap040_core.v`).

## Why

The Speedometer profile shows the operand pipeline's most common shape for
a memory operand: `S_PIPE_START -> S_IMMF` 29.7 M times (the extension
word), `S_IMMF -> S_EA_D16` 20.9 M, `S_EA_D16 -> S_PIPE_SRD` 16.7 M,
`S_PIPE_SRD -> S_MRD`. A `move.l d16(An),Dn` therefore costs decode,
pipe start, immediate fetch, EA add, read issue, and two clocks of
`S_MRD`. The pipe-start state already has an inline path that consumes
the extension word from the queue (`ext_inline`), but the profile shows
it taken only a quarter of the time. An instrumented boot run counted the
refusals: of 1.46 M chances, 504 k were refused because a queue fetch was
outstanding (`epf_pend`), 85 k because an acknowledge landed that cycle,
60 k because the word was not in the queue yet. The `epf_pend` guard
dates from when a data transfer could follow immediately and overlap the
fetch on the bus; today `mrd`/`mwr` refuse to issue and `S_MRD`/`S_MWR`
hold while a fetch is pending, so the guard only delays the EA arithmetic.

## What

1. `ext_inline` in `ea_operand_start` no longer requires `!epf_pend`.
2. For mode `101` (d16(An)) with the word inline, a **source** operand
   issues its read from `S_PIPE_START` directly (`mrd` to `S_PIPE_SDONE`,
   port B pointed at the destination register as `S_PIPE_SRD` would), and
   a **destination** operand records `dst_addr` and goes to `S_EXEC` (or
   reads first when read-modify-write), skipping `S_EA_D16` and
   `S_PIPE_SRD`/`S_PIPE_DEA`.
3. The pipe-start address hint computes the same sum (`hint_d16_addr =
   An + sxw(ext)`) under the same qualification, for the source case and
   for the read-modify-write destination case, so the read that follows
   hits the idle read and (with the fast-read candidate) completes in one
   clock: `move.l d16(An),Dn` is now decode, pipe start, one clock of
   `S_MRD`.

## Results so far

- AP suite 11/11; corpus gate 33,964,466 cycles (baseline 33,932,693,
  +0.09 %: the payload's timing changes with the earlier EA computation),
  0 REAL diffs.
- Latency fixture 1,940 -> **1,901** clocks PASS.
- Sieve sweep (cycles; fast-read candidate in parentheses): offset 0
  545,343 (567,807, -4.0 %), 6 538,284 (555,588, -3.1 %), 16 600,552
  (608,727, -1.3 %), 30 568,348 (582,631, -2.5 %); arrays and guards
  PASS. The kernel has no d16 source reads: this is the relaxed guard
  letting the indexed-mode EA work overlap outstanding fetches.

### Rebased on the accepted tree (the fast-read candidate failed timing)

The fast-read cache change under this candidate fails timing by 6.6 ns
(`CPU_FAST_READ_20260914.md`), so the core change was rebased alone onto
the level-offer checkpoint (`/tmp/ea1-cand.*`, only `ap040_core.v`
differs). Gates on that tree: AP suite 11/11, corpus identical, latency
fixture 1,983 -> **1,944**, Sieve (level-offer checkpoint in parentheses)
offset 0 553,009 (575,473, -3.9 %), 6 545,972 (563,258, -3.1 %), 16
608,223 (616,415, -1.3 %), 30 576,031 (590,305, -2.4 %), arrays and
guards PASS.

Pending: boot A/B, simulated Speedometer, fit, hardware.

### Boot A/B of the combined tree (fast-read + this), for reference

Same bracket: opcode dispatches 72,300,926 (fast-read) -> **76,466,746**
(+5.76 %; +8.71 % over the level-offer checkpoint's 70,341,042), 5.493
clocks per dispatch, same frame, no faults. The combined tree cannot be
fitted (fast-read timing); the rebased candidate's own boot A/B follows.

### Fits (seed 22)

- Extension-word only, with the combinational loop: closes (+0.722 ns
  clk_sys, +0.458 ns HDMI, 38,457 ALMs) but the loop makes it invalid.
- Extension-word only, loop removed: **fails clk_sys by 2.797 ns** (TNS
  -332). Worst paths `core|rr_b` -> register file port B -> ALU (`bm`,
  `ShiftLeft`, result select) -> `Mux4178`/`always2` -> `epf_head`: the
  DBcc decrement's result deciding the taken branch, whose direct refill
  dispatch rewrites the queue head. A pre-existing near-critical path
  (about 29 ns) that this placement routed with a 7.8 ns hop; the lean
  stack with the same core closed it at +0.187 ns at the same seed.
  Structural remedy if the seed walk fails: take the DBcc counter compare
  off the ALU result path (compare the register value against 0 directly,
  the decrement result is only written back), or register the decision.
- Lean stack (`CPU_IMM_DIRECT_20260914.md`): clk_sys +0.187, clk_ram
  +0.523, HDMI **-0.572** (TNS -1.019), 38,872 ALMs; seeds 23 and 21
  running.
