# RTS, LINK, UNLK and JSR without their setup and retire cycles (2026-09-14, candidate)

Built on the shift-retire candidate (`CPU_SHIFT_RETIRE_20260914.md`).
Core only (`ap040_core.v`); script `scratchpad/cf_trim.py`, tree
`/tmp/cf-cand.*`.

## Why

The Speedometer bracket's decode histogram (`CPU_DECODE_HISTOGRAM_20260914.md`)
lists RTS (2.73 M), LINK A6 (2.28 M), UNLK A6 (2.22 M) and JSR abs.l
(1.62 M) among the instructions that always pay the decode cycle.  Each
also spent one or two states doing bookkeeping around its single stack
access:

| instruction | before | after |
|---|---|---|
| RTS | DECODE, S_RET1 (issue), S_MRD setup, S_MRD ack, S_RET2 (A7, redirect) | DECODE issues the pop; the ack cycle writes A7 and redirects |
| LINK.W/L | DECODE, S_IMMF*, S_LINK1 (port A), S_LINK2 (push), S_MWR setup, S_MWR ack, S_LINK3 (An), S_LINK4 (A7) | decode selects port A; S_LINK2 pushes (issued in place) and writes An; S_LINK4 writes A7 |
| UNLK | DECODE, S_UNLK1 (issue), S_MRD setup, S_MRD ack, S_UNLK2 (A7), S_UNLK3 (An) | S_UNLK1 issues in place and writes A7; the ack cycle writes An and retires |
| JSR | EA, S_JSR1 (push), S_MWR setup, S_MWR ack, S_JSR2 (A7, redirect) | S_JSR1 pushes (issued in place) and writes A7; the ack cycle redirects |

(* S_IMMF only when the displacement is not resident in the queue.)
Two to three cycles per instruction, about 16 M cycles of the 1,094 M
bracket if the counts hold.

## What changes

- `mrd`'s in-place issue (previously only from `S_PIPE_START`, `S_PIPE_SRD`
  and `S_PIPE_DEA`) also fires from `S_DECODE` and `S_UNLK1`; `mwr`'s
  (previously `S_EXEC` only) also from `S_JSR1` and `S_LINK2`.  The same
  guards apply (on-board RAM, aligned, no queue fetch or transfer in
  flight).  No other decode-time read exists, so the `S_DECODE` term is
  RTS's alone.
- `S_MRD` acknowledge: `r_m_ret == S_UNLK3` writes An from the read
  data and retires (a sequential `fetch_next`, no redirect).  RTS and JSR
  keep their redirect states (`S_RET2`, `S_JSR2`) one cycle after the
  acknowledge: see "Why the redirects are not folded into the acknowledge
  cycle" below.
- Register writes that now precede the memory access are undo-recorded
  (`u_rec`) so a faulting push or pop restarts with the old value, as the
  post-increment and pre-decrement modes already do: An in `S_LINK2`, A7
  in `S_UNLK1` and `S_JSR1`.  The JSR record must be cleared when the
  push completes: `go_pc` does not clear the records (fetch_next does),
  and the AP `mmu` suite's fetch-fault-at-target test caught the first
  version rolling A7 back past the push when the target fetch faulted.
- `S_LINK1`, `S_LINK3` and `S_UNLK2` are no longer entered.  `S_UNLK3`
  and `S_JSR2` keep their arms: the byte-split path for a page-crossing
  pop or push returns to `r_m_ret` as a state, and the first version had
  removed them (the state machine's default arm is `fatal_halt`, which the
  boot reported as a double fault 216 M cycles in).

## Why the redirects are not folded into the acknowledge cycle

Versions 3 and 4 called `go_pc` for RTS and JSR inside the transfer's
acknowledge cycle.  `issue_ifetch` cannot issue while `mem_ack` is high,
so the redirect was left to the fill engine one cycle later, and the
engine's fill does not carry `epf_pend_seed`: the target line was never
adopted into the branch refill sector, and every later branch into that
sector paid a demand fetch.  Sieve offset 0 showed it (471,147 against
421,997 cycles: the bench's one JSR into the kernel left the kernel's
sector unadopted, so the inner loop's `ble` refilled from memory 8,191
times).  Version 4 made the engine's fill seed the sector for a deferred
redirect (`epf_redir_pend`), which fixed that loop and cut the corpus run
by 9 % (30,671,833 cycles), but made every offset of the Sieve slower
(+6.5 K to +19.6 K): loops spanning two 32-byte sectors now thrash the
single-sector buffer, where the old behaviour happened to keep the sector
of the branch that had issued immediately.  The honest fix is a
two-sector refill buffer (a follow-up candidate, `CPU_BRF2_20260914.md`);
this candidate keeps the old adoption behaviour and redirects from the
state after the acknowledge, giving up one cycle on RTS and JSR.

## Results so far

First version: AP suite failed `mmu` (the JSR undo record, above); fixed.
Second version: AP suite 11/11, corpus 33,731,607 cycles (+8,357 over the
33,723,250 baseline; the corpus has few RTS/LINK, and every stack access
in it now issues a cycle earlier where the fast path applies) with 0 REAL
diffs, latency fixture 1,899 (-17), but the
boot A/B halted at 216 M cycles: the missing `S_UNLK3`/`S_JSR2` arms
above (a traced rerun of the halt is recorded below).  Third version: AP
suite 11/11, corpus 33,731,607 (+8,357), Sieve offset 0 +49 K (the
deferred-redirect adoption above).  Fourth version (`epf_redir_pend`): AP
11/11, corpus 30,671,833 (-9.0 %), Sieve slower at every offset, latency
1,899.  Fifth version (redirects one cycle after the acknowledge): AP 11/11,
corpus **33,690,581** (-32,669, 0 REAL diffs), Sieve byte-identical and
cycle-identical to the base at all four offsets, latency 1,904 (-12).
Boot A/B: **75,469,718 dispatches** (+0.25 % over the shift candidate's
75,280,762), no faults, same frame as the 16 KB cache candidate.  The
seed 20 fit was stopped in favour of the stacked build's.

### Stacked with the 16 KB caches (stack2)

`/tmp/stack2-cand.*` = this core (v5) + `CPU_CACHE16K_20260914.md` v2:
AP 11/11, corpus 33,705,557 (0 REAL diffs), boot A/B **75,717,560
dispatches** (+0.6 % over the shift candidate, +0.8 % over checkpoint
10), no faults.  Simulated Speedometer and the seed 20 fit running; the
hardware step follows the cache-only build's measurement.

### stack2 fit (v5 + 16 KB caches, seed 20): -1.226 ns on the CPU clock

TNS -42.9 ns over many paths, 39,528 ALMs.  The worst path is the
hint-to-acknowledge chain (`pc` -> queue compare -> `issue_ifetch` ->
`hint_pipe_dst` -> `mem_addr` -> MMU `lk_fresh`/`need_walk` -> store
buffer -> cache `c_ack` -> `fetch_next` -> `brf_seed_n` -> nine levels of
`mem_addr_q` mux -> `mem_addr_q` enable), 30.8 ns of data path.  The
four in-place issue extensions (mrd from `S_DECODE` and `S_UNLK1`, mwr
from `S_JSR1` and `S_LINK2`) each add a source to that mux.  Version 6
drops them and keeps the state folds: RTS still issues from decode into
`S_MRD`'s own setup cycle (S_RET1 gone, -1), LINK keeps -2 (S_LINK1,
S_LINK3), UNLK -2 (S_UNLK2, and S_UNLK3 folded into the acknowledge),
JSR is unchanged.

### stack3 (v6 + 16 KB caches v2)

`/tmp/stack3-cand.*`, core a4c0d07c: AP 11/11, corpus 33,738,108 (0 REAL
diffs; the cache base is 33,738,226), Sieve identical to the cache base at
all offsets, latency 2,037 (cache base 2,044).  Boot A/B **75,700,859
dispatches** (stack2 with the in-place issues: 75,717,560, so those were
worth 0.02 % of the boot bracket; cache base 75,584,400), no faults.
Simulated Speedometer and fits at seeds 20 and 22 running.
