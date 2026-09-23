# P180-P182: PEA d16, FPU (An), and the MOVE store's hint at the read's predicted acknowledge

Continues P179 (`docs/P179_MOVE_DESTINATION_AT_READ_ACK_20260922.md`).  All three are
sim-measured against the oracle suite (`scripts/cpu/speedometer_suite.sh`), the
AP68040 self-tests, and the Permutations/Queens/Dhrystone/Whetstone runners in
`scratch/p179_ea_decode_20260922/`.

## P180: PEA d16(An) as LEA

PEA d16(An) (`486E`, Pascal's `PEA -x(A6)` for every VAR argument) went S_DECODE ->
S_EA_DISP -> S_IMMF -> S_EA_D16 -> S_PEA1 -> push.  Under `AP040_EXPERIMENTAL_LEA` it
now requests its displacement from decode like LEA (popped inline when queued) and
S_EA_D16 issues the push itself (`pea_d16_push`: forwarded base `rf_capture_a`,
forwarded A7 `dbg_a7_wb`, in the in-place whitelist and on the push hint).  S_PEA2
still writes A7, so the restart point is unchanged.

Whetstone -0.3 %, Dhrystone -0.9 %.  It saves 372k Whetstone clocks of states
but 300k come back as S_FETCH/S_MWR/S_MRD waits: the instruction stream and the
one memory port are the limit, not the EA states.

## P181: FPU (An) source through S_FPU_AN

A memory-source FPU operation with (An) (`F217` FMOVE/FADD.X (A7)...) went S_FPU_DEC ->
S_EA_DISP -> S_FPU_EA.  (An)+/-(An) already used S_FPU_AN; mode 010 now does too
(`fp_ea_pd`/`fp_ea_pi` stay 0, and `fp_adj` is only read under them).  Whetstone -0.3 %.

## P182: the MOVE destination store's hint in the source read's predicted acknowledge

After P179 most memory-to-memory MOVE stores issue in the source read's acknowledge
clock, but 1.22M of Whetstone's 1.48M two-clock stores were exactly those: nothing
hinted them (the MOVE store hint lives in S_PIPE_DEA, which they now skip), so the
cache took its two-clock registered path.

The hint bus repeats a held request (`mem_req ? mem_addr_q`), and **the cache indexes
its RAMs by the hint bus alone**.  P182a let the store's address (`move_store_read_addr`)
take the hint bus in the read's first S_MRD clock.  Whetstone fell 4.7 % -- and Towers
failed its oracle (29 bytes wrong): when the read was not acknowledged in that clock,
its registered lookup (C_LOOK, and the bypass tag check) read the *store's* row, and
with stack data in one page the tag compare "hit" the wrong line.  Whetstone has no
numerical oracle; its 4.7 % was largely that corruption.

P182 as kept:

- core `hint_move_store` = `move_store_read_ready && m_issued && mrd_fresh &&
  mrd_hinted && mem_fast_ready && !ifr_hint_now`, all registered-derived: `mrd_fresh`
  (first S_MRD clock of this read), `mrd_hinted` (the hint bus carried this read's row
  and word when it issued -- a false match only costs a held clock), `mem_fast_ready`
  (the cache's registered `fast_accept`/`fast_hit` terms: C_IDLE, no ack_r/invalidate
  pending, idle read and hint tag valid), and no fetch owning the hint bus.  The live
  acknowledge is never in it.
- core output `mem_hint_away` (= `hint_move_store`) -> cache `c_hint_away`: the cache
  holds a cacheable read's or bypass's C_IDLE acceptance for that clock (the RAMs are
  reading another row); the read is level-held and re-hinted from the next clock.
  The idle-read hits need no guard: they check the index their read was made at.
- cache output `c_fast_ready` -> core `mem_fast_ready`.

| | P181 | P182 |
|---|---:|---:|
| Whetstone loop | 24,200,361 | 24,034,597 (-0.7 %) |
| Towers | 19,229,324 | 19,081,977 (-0.8 %) |
| Quick Sort | 150,514 | 149,368 (-0.8 %) |
| Dhrystone loop | 100,904,386 | 100,704,393 (-0.2 %) |
| Permutations, Queens, Puzzle, Sieve, Bubble, Int. Matrix | | unchanged |

One-clock stores on Whetstone 725k -> 1.36M; the cost is ~70k reads that were
predicted and still missed their first clock (four-clock reads 228k -> 300k).

Cumulative P174 -> P182 (latency 3): Whetstone 24,886,003 -> 24,034,597 (-3.4 %),
Towers -2.1 %, Quick -2.2 %, Dhrystone 102,604,350 -> 100,704,393 (-1.9 %).

## What the profiles say next

Whetstone memory visits after P182 (`MHIST` in
`scratch/p179_ea_decode_20260922/l_whet/run.log`): 517k three-clock reads remain (341k of them un-hinted pipeline
reads issued from S_PIPE_START right after a store, whose hint the held store's
repeat displaced), 825k two-clock stores (MOVEM, JSR, FPU stores, and the MOVE stores
whose read was not predicted).  The general form of P182 -- the next request hinted in
every predicted acknowledge clock, with the cache holding un-repeated lookups -- is
the "memory states are not states" item; P182 is its first instance.
