# P169 — a hinted store retires in its issue clock (screened, not promoted)

Source: `scratch/p169_store_retire_at_issue_20260922/` (a copy of the P162 core, the P136 cache,
`ap040_mmu.v`, `wombat_cpu.sv` and `ap040_tg68k_compat.v` with the change).

## What it does

The MMU exports `m_hint_wready` (last cycle's data hint translated, writable, modified, nothing moved),
the cache exports `c_store_ready` (idle, nothing owed, no lost invalidate, no snoop landing). When an
in-place-issued, instruction-completing store (`mgo_ret == S_NEXT`) has that vouch and was hinted last
cycle at its own address, the core sets `st_fly` and calls `fetch_next` in the issue clock instead of
entering S_MWR. While `st_fly`, no other request may issue (in-place issue, the S_MRD/S_MWR delayed
issue, the fetch engine, `issue_ifetch`'s immediate branch); `d_ack` clears it. The store cannot fault
by construction (the vouch), and every one of the 10,077 early retires in Permute(7) was acknowledged
in the next clock as predicted.

Two new store hints were needed so the vouch exists a cycle before the issue: the RMW store from
S_PIPE_DDONE (`dst_addr`), and a MOVE's destination store from the EA state that completes the
destination address (S_EA_DISP modes 010/011/100, S_EA_D16, S_EA_EXTW2 with the `hint_ea` adders).

## Results (P162 core + P136 cache, latency 0 / 3)

| | before | P169 |
|---|---|---|
| Permute(7) | 1,215,081 / 1,240,837 | 1,207,523 / 1,233,279 (-0.6 %) |
| Whetstone loop | 25,148,818 | 25,192,897 (+0.18 %) |

## Why it does not pay, and what would

The S_MWR acknowledge clock it removes is also a **retire site** for the record dispatch
(`n_desc_ok`, the Bcc lookahead: `(state == S_MWR) && d_ack && (r_m_ret == S_NEXT)`), which skips
S_DECODE for the next instruction. `fetch_next` from the issue clock goes through S_DECODE, so for a
descriptor-class successor the two paths reach the successor's first execute state in the same clock,
and for a redirect the deferred fetch costs one. The gain appears only when the successor would have
gone through S_DECODE anyway. To make the early retire pay, the issue clock must fire the same record
dispatch the acknowledge clock does -- i.e. `st_early` becomes a retire-site term at the two sites and
in `regs_alu_fire`'s family -- and the pushes (S_JSR1/S_PEA1/S_LINK2, hinted from their EA or dispatch
state), MOVEM stores and the pipeline's stores need their own one-cycle-ahead hints. That is the first
half of "the memory states are not states" and belongs with the pipeline extension, not as an increment.

## A lesson that cost a run

The first version deadlocked Whetstone at `408EDD60`: the early retire's `fetch_next` called
`issue_ifetch`, whose immediate branch tests the *registered* `mem_req` (still 0 in the issue clock)
and overwrote the store's request registers in the same clock -- the store vanished, `st_fly` never
cleared. `!epf_issue` (the blocking flag mem_issue sets) in that branch fixes it. Any future
retire-at-issue must treat "a request was issued earlier in this clock" as a first-class condition.
