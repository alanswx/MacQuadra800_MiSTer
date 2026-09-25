# P171 — separate request registers for instruction fetch and data (screened, not promoted)

Source: `scratch/p171_split_request_20260922/` (P162 core + P170 cache tree with the change in
`ap040_core.v`, `wombat_cpu.sv`, `ap040_tg68k_compat.v`).

## What it does

The core's four instruction-fetch request sites (issue_ifetch's immediate branch, the fill engine,
exception_prefetch, S_EPF_GAP) write their own registers `ifr_req/ifr_addr/ifr_size/ifr_fc`; the data
states keep `mem_*`. The wrapper arbitrates the two channels onto the MMU/cache's single port: a
presented request is never switched until it completes; acknowledge and fault (berr folded in) go back
to the presented channel only. The core's "port free" tests split by channel: data in-place issue no
longer waits for `epf_pend`, the fetch sites test `ifr_req/ifr_ack`; the six fetch-queue pop guards
that used `!mem_ack` (a fetch acknowledging in this cycle appends the same words) test `!ifr_ack`; a
queue-fetch fault copies the fetch's registers into `mem_*` for the frame builder; the hint mux hints a
pending data request ahead of an outstanding fetch, and a data hint ahead of the fetch's repeat.

## Result

Correct (Permute(7) PASS, array and guards) and the port contention it targeted is gone (store waits
behind a fetch 68k -> 0, their issue clocks 59k -> 9k). But **1,263,600 -> 1,716,689 clocks (+36 %)**:
S_FETCH 129k -> 260k, every JSR takes the slow redirect (S_JSR2 2 -> 18,739), S_EXPERIMENT_PIPE +70k.
Data-first and fetch-first arbitration give the same number.

The fetch queue's heuristics were tuned around the shared port: the engine refuses to fill while the
core is in a memory or EA state, the target fetch at a pop (`bd_go`, `hint_bd`) goes out only when
"the port is free", and the queue's fill thresholds assume a fetch costs the data side its turn. With the
channels split the engine runs ahead more, a fetch is more often outstanding at the moment a pop wants
its target fetch, and that target fetch then takes the redirect state's slow path. So the split is the
right structure but needs the engine re-tuned with it: target fetches must pre-empt speculative fills
(or the engine must leave the channel free when a pop with a known target is imminent), and the
`state != S_MRD/S_MWR`, `!ea_state` refusals belong to the old port model and should go. That is a
day of measured tuning on the Permute/Dhrystone/Whetstone fixtures, not an increment; the
attribution bench (`scratch/permute_p165_phases_20260921/tb_cpu_permute.sv`) and the state histogram
diff are the tools.

## Diagnosis (later the same night)

Counting fetches: the base issues **127,262** instruction fetches per Permute(7) (326k channel-busy
clocks, 2.6 each); P171 issues **315,192** (736k clocks) -- the same latency per fetch, 2.5x as many
of them, and redirect (seed) fetches 55k -> 160k. `bd_go` (the target fetch at a pop) fires 55k -> 15k
times. So the split channel does not slow a fetch; it lets the engine issue far more of them, and the
line offers and the refill buffer -- which feed the queue eight words at a time and are refused while a
fetch is outstanding -- are starved by the engine's own one-longword fetches. Repeating the presented
fetch on the hint bus until its acknowledge recovered part of it (1.716M -> 1.524M); holding the engine
for one clock after an instruction acknowledge (so the line offer lands) made it worse (1.724M); the
fill threshold made no difference. The re-tuning has to start from the queue's supply policy: with a free
fetch channel the engine should prefer *waiting for the offered line* over issuing, and a pop with a
known target must own the channel. `scratch/p171_split_request_20260922/` holds the last state
(fetch-first arbitration, the hint repeat, the `i_ack_d` hold); the FETCHN/FETCHCH counters in its
`tb_cpu_permute.sv` are the instruments.

## Supply policy and correctness (2026-09-22, daytime)

The 2.5x fetch count had a plain cause: `iline_log` (the line the core matches offers against) was
still taken from the data channel's `mem_addr_q`, so with the fetch's address in `ifr_addr` no line
offer ever matched and every line was fetched a longword at a time.  Taking it from `ifr_addr`, removing
the shared-port refusals (`state != S_MRD/S_MWR`, `!ea_state`) and lowering the fill trigger to two
words gave Permute(7) **1,174,917** clocks at latency 0 / **1,213,764** at latency 3 against P170's
1,263,600 / 1,278,213 (-7.0 % / -5.0 %).  Whetstone, however, came out **25,742,999** against P170's
25,671,327 (+0.3 %): S_FETCH +263k clocks -- the two-word trigger exposes the 2-3 clock issue->offer
latency on the FPU code's long instructions.  The policy work is a sweep (below).

Making the split correct took five fixes; every one is a place where the single-port core relied on
"a data request is never outstanding while a fetch is" or on the fetch living in `mem_*`:

1. **MOVEC to an MMU register under a killed fetch** (`atcprobe`).  The engine now issues right up to
   the MOVEC, so the killed fetch is still on the bus when TC is written; the MMU re-translates a request
   the platform has already accepted and starts a walk against a live 16-bit bus cycle.  `S_MOVEC2`
   waits for `!epf_pend`, as PTEST/PFLUSH already did.
2. **No request gap after a fault** (`mmu`, `movem_restart`, the Whetstone "request changed before
   ack").  When the presented request faulted, the wrapper switched to the other channel in the very
   next cycle; the platform's `c_req` never fell and the MMU's `W_DROP` (which waits for that) never
   returned to idle -- deadlock with the fault frame's store queued behind it.  The arbiter now holds
   `mem_req` low for one cycle after any fault (`flt_gap`).
3. **Fault frame from the stale copy** (`lea_fault`).  The queue-fetch fault handler compared
   `epf_next` with the `mem_addr_q` copy it was itself writing on that edge, and `aerr_start` built the
   frame from the one-cycle-late `mem_*` registers.  `aerr_start` now takes the channel as an argument
   and reads `ifr_*` for a fetch fault.
4. **Bus error folded into the MMU fault**.  `core_flt = (mem_flt|berr) && !sel_instr` made every data
   bus error look like an ATC fault in the SSW.  The wrappers now deliver `core_flt/ifr_flt` (MMU) and
   `core_berr/ifr_berr` (bus) separately per channel.
5. **A killed user fetch running during exception processing** (`mmu`: "handler fetch used FC=2").
   A fetch the platform has not accepted yet is now withdrawn at exception entry (`!ifr_pres`); one
   already on the bus is left to finish under `epf_kill`, as before.

`t_exceptions` 136 (a request timed to qualify inside `MOVE #$2700,SR`) is cycle-tuned to the
shared port: with the immediate already resident the mask is raised before any IPLDLY value can land,
so the test gained a `nop` and uses delay 4 (3-5 pass on P171, 3-7 on the shared port).  A live-level
hold latch was tried and rejected: the bench's own claim model (`tb_qual`) qualifies from the registered
level, and the live latch is a phantom by that definition.

Gates on the corrected sources: `run_tests.sh` 31/31, the 22 pipeline programs, the four IRQ replay
programs (`irq_overlap/load/store/pea`), Whetstone and Permute run to completion.
