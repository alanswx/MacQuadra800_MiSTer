# CPU pipeline, the increments on the sequencer (2026-09-17)

Branch `CPU-pipeline` (cut from `add-CPU-fixes` at 3aa7953, the vendored
CPU with Adam Polkosnik's fixes, Speedometer 4.02 Mix 0.855 on the .143
box).  The plan being executed is Alan Steremberg's
`docs/CPU_PIPELINE_PLAN_20260915.md` and its hand-off
`docs/CPU_PIPELINE_REWRITE_HANDOFF_20260915.md` in `../quadra800_alan`
(branch `cpu-fastread-20260915`): a six-stage engine (IF/ID/EA/RD/EX/WB
with the present state machine kept as a side engine for MOVEM, RTE, the
bit fields, CAS, exceptions and the FPU) preceded by three increments on the
sequencer that are worth having in any case.  The user's decision on
2026-09-17: the increments first, each on hardware, and the engine after.

This note records the increments as they land: what each one is, why it is
safe, what it costs, and what every gate said.  The area rule for the
branch is that the core must not grow: every increment that adds logic is
paired with one that removes it.

## Where the numbers come from

- `scripts/cpu_gates_wsl.sh <ap68040 dir> <label>` (WSL): the AP suite
  (23 legs), `bench_loop` with the per-state profile, the new `pipe_bench`
  (below), and the first-100 silicon corpus (every register and memory
  field compared; "REAL diffs: 0" is the correctness bar, the cycle count
  the first performance signal).
- `rtl/ap68040/tb/asm/pipe_bench.s` (new): 1,000 iterations of a compiled
  call pattern, BSR.W to a subroutine that does LINK/MOVEM push/MOVEM
  pop/UNLK/RTS, then an ALU producer followed by a short Bcc taken every
  other iteration to a target 36 bytes away (outside the 32-byte refill
  sector), closed by DBcc.  It verifies its checksum.  Phase 0 (fast
  memory) is the number quoted; the per-state histogram (`+prof`) says
  which state each increment changes.
- Hardware: Speedometer 4.02 on the .143 box, Mac OS 8.1 from
  `QuadSquad8.hda`, driven by the Opus operator (`scratch/pipeline_*/`).

## The increments

### 1. One-clock data-cache hit on a dedicated hint bus (86b6b04)

Alan's AP68040 `6e65192` ("dovr"), the RTL of the plan's step 1, applied
unchanged (it applies cleanly to the vendored tree), plus his wrapper
wiring (`b546572`).  The core's address hint leaves the request bus:
`mem_hint_addr`/`mem_hint_instr` carry the next access a cycle early, the
MMU translates the hint through its hit copy and the TTRs into a
registered physical tag and a registered "cacheable, readable, nothing
moved" verdict, the cache indexes its idle RAM reads by the hint alone,
and a settled data read whose request is the registered hint is
acknowledged combinationally in the request cycle.  Instruction fetches
keep the registered acknowledge (their consumer is the fetch queue's ring
write, which failed timing by 7 ns once).  `mem_addr`/`mem_instr` now
carry only registered state, which is what makes the hoists of item 2
fittable.

Alan never closed a seed on it (0 of 13 at 92-93 % on his diet base;
the seeds that routed missed the 33 MHz CPU clock by 1-2 ns).  The
vendored core fits at 89 %, so it gets its first fit here.

| gate | before | after |
|---|---:|---:|
| AP suite | 23/23 | 23/23 |
| bench_loop phase 0 / 1 | 94,368 / 95,166 | 81,600 / 82,398 (-13.5 %) |
| corpus-100 | 33,335,739, 0 diffs | 33,335,739, 0 diffs (identical, as in Alan's port) |
| synthesis ALUTs (full design) | 56,965 | 57,273 (+308), +172 registers |

Fit and hardware: see "Builds" below.

### 2. R5/R6: go_pc and decode_dbcc_brf hoisted (fe6f226)

The two carrier hoists of `docs/cpu-area-consolidation.md` that the
vendored tree had left out (`c789ffe`, `923c544` of the old submodule, the
early-data form): go_pc's twelve sites and decode_dbcc_brf's seven raise a
carrier and the body runs once after the state case, the target formed
from registers by the current state.  They were excluded because on the
shared address bus the CPU clock missed by 0.6-1.7 ns through the hint
adder cone; step 1 moved that cone off the request path.  Synthesis
measured them at about -1,300 ALMs on the 2026-09-15 tree.

Gates: cycle-identical to step 1 on every count (a pure restructuring).

### 3. The redirect states hint their target (d028821)

Bcc.W/.L, DBcc, BSR and JSR after their push, JMP, RTS/RTD/RTR put the
target they are about to hand to go_pc on the hint bus in the redirect
cycle, so the demand fetch presented in the next cycle finds the cache's
idle read on its line: a hinted two-clock instruction read instead of a
three-clock lookup, one cycle off every taken branch, call and return
whose target is not in the refill sector.  Bcc.B was already hinted from
S_DECODE.  A state that does not redirect after all has hinted an address
nothing requests.  This is the "cheapest first step" of the plan's item 2.

| gate | before | after |
|---|---:|---:|
| bench_loop phase 0 / 1 | 81,600 / 82,398 | 81,202 / 82,000 (-0.5 %) |
| pipe_bench phase 0 | 149,182 | 147,682 (-1.0 %); S_FETCH 8,629 -> 6,131 |
| corpus-100 | 33,335,739 | identical, 0 diffs |

### 4. Stack pops and MOVEM transfers issue in place and hint themselves (3aac77e)

`mem_issue`'s in-place whitelist (the states that claim the port while
entering S_MRD/S_MWR, removing the request-setup cycle) grows from the
operand pipe's three read states and S_EXEC's write to RTS's pop from
S_DECODE, RTD/RTR's from S_RET1, UNLK's read from S_UNLK1, MOVEM's loads
from S_MOVEM_LOOP and its stores from S_MOVEM_RD; each of those states
hints the read's address as a data hint in the same cycle, so the read is
acknowledged in the cycle it is presented (the one-clock hit).  Alan
withdrew the same sites in 2026-09-14 because every in-place site was a
source on the `mem_addr_q` mux of the hint-to-acknowledge path; on the
hint bus that mux is a register input.  A version that only hinted without
the whitelist was cycle-identical to item 3: the whitelist is what matters.

| gate | before | after |
|---|---:|---:|
| bench_loop | 81,202 / 82,000 | unchanged (no pops in the loop) |
| pipe_bench phase 0 | 147,682 | 137,684 (-6.8 %); S_MRD 13,350 -> 7,352, S_MWR 67,088 -> 63,088 |
| corpus-100 | 33,335,739 | 33,300,912 (-0.1 %), 0 diffs |

Per iteration of pipe_bench that is exactly the six reads (RTS, UNLK, four
MOVEM loads) and four MOVEM stores each losing one cycle.

### 5. Forward taken Bcc.B at the lookahead site (77aa72a)

The lookahead arm resolves a short Bcc at the queue head on the retiring
producer's flags; a taken branch whose target is in the refill sector
dispatches from the buffer, and until now a target outside the sector fell
back to S_DECODE (an inlined go_pc there cost Alan 700 ALMs).  With go_pc
hoisted (item 2) the arm raises the carrier instead and `go_pc_t_early`
selects `rd_bcc_t` for the lookahead states, so the demand fetch goes out
at the end of the producer's retire cycle; go_pc_now and exc_now move
after the lookahead arm so the carrier is consumed in the same cycle
(nothing the arm writes is written by either when they fire together: a
retire that pops never carries an exception).  A flag-free hint of
`rd_bcc_t` while a producer retires with a short Bcc at the head makes
that fetch a hinted one.  Alan's bracket estimate for forward taken
branches: up to 19 M of 1,043 M cycles.

The first version redirected from acknowledge cycles too and made the
corpus 1.3 % slower (33,746,157 cycles): a redirect the fill engine issues
a cycle later does not adopt the target's sector, and every later branch
into it pays a demand fetch (the rule Alan's control-flow trims learned).
The landed form redirects from the arm only when the port is free in that
cycle; S_DECODE a cycle later usually finds it free.

| gate | before | after |
|---|---:|---:|
| AP suite | 23/23 | 23/23, no go_pc early-target mismatch |
| bench_loop | 81,202 / 82,000 | unchanged |
| pipe_bench phase 0 | 137,684 | 137,184 (the 500 taken forward branches, one cycle each) |
| corpus-100 | 33,300,912 | 33,300,804, 0 diffs |

### 6. MOVEM loads retire on the read acknowledge (384d8f0)

The S_MRD acknowledge arm handles `r_m_ret == S_MOVEM_LD` as it already
handles S_UNLK3: the loaded value lands (or is held for the base/index
register, exactly as S_MOVEM_LD does), the address steps, the loop
continues next cycle.  S_MOVEM_LD stays for the byte-split path.  A
resident MOVEM load is now two cycles per register where it was four this
morning.

| gate | before | after |
|---|---:|---:|
| pipe_bench phase 0 | 137,184 | 133,186 (the four loads per iteration) |
| corpus-100 | 33,300,804 | 33,082,368 (-0.66 %), 0 diffs |

### 7. The pushes issue in place (BSR.B, BSR.W, JSR, PEA, LINK)

The write whitelist of `mem_issue` grows from S_EXEC and S_MOVEM_RD to the
five push sites; a posted store needs no hint, so each push simply loses
its request-setup cycle when the port is free.

| gate | before | after |
|---|---:|---:|
| pipe_bench phase 0 | 133,186 | 127,186 (S_MWR 63,089 -> 56,090) |
| corpus-100 | 33,082,368 | 33,021,428 (-0.18 %), 0 diffs |

### 8. MOVEM stores from the loop, LINK/PEA on the acknowledge

Port A is selected one register ahead (at loop entry for the first, in
the loop for each next one, a second `ffs16` over the remaining mask), so
S_MOVEM_LOOP issues the store itself and S_MOVEM_RD is no longer entered.
The S_MWR acknowledge arm writes A7 and retires for `r_m_ret == S_LINK4` /
`S_PEA2`.  Every folded state stays for the byte-split path.

| gate | before | after |
|---|---:|---:|
| pipe_bench phase 0 | 127,186 | 122,190 (four MOVEM stores and the LINK per iteration) |
| corpus-100 | 33,021,428 | 32,991,462 (-0.09 %), 0 diffs |

Across items 3 to 8 pipe_bench went from 149,182 to 122,190 cycles
(-18.1 %) and the corpus from 33,335,739 to 32,991,462 (-1.03 %), every
row still matching silicon field for field.

### 9. Unconditional transfers redirect at the pop, from the queue words (2026-09-18)

The plan's item 2 asks for a branch target cache consulted on the queue
head before decode.  For the transfers whose target is *in the queue
words* -- BRA.W/.L, BSR.W/.L, JSR and JMP abs.W, abs.L and d16(PC) --
a table would only predict what the head and the one or two words
behind it already say exactly, so this increment computes the target
from them instead (`bd_t = pc + 2 + sxw(w1)`, `{w1, w2}`, or the absolute
word) and needs no prediction, no mispredict path and no storage.  The
table proper is left for the forms it can help (Bcc.W/.L, JSR/JMP (An),
RTS), see below.

At the retire that pops one of these opcodes with its extension words
resident (`rd_queue_pop && bd_ok`, a new arm after the lookahead arm),
`dispatch_branch` pops the words with the opcode, as the record's
immediate forms do, and enters the branch state directly (S_BCC_EXT with
`imm`/`br_base`/`br_long`, or S_JSR1/S_JMP1 with `ea_addr`), skipping
S_DECODE and the extension states; and when the port is free, the target
is even and not the fall-through, and T1 is clear, it raises `sgo` and
`issue_ifetch(bd_t)` runs once after the case, with `bd_t` on the hint
bus in that cycle (`hint_bd`, registered-only select) so the fetch is a
hinted two-clock read.  The branch state then does exactly what it did:
`finish_bcc`/`go_pc` from S_BCC_EXT or S_JMP1, the push from S_BCC_EXT or
S_JSR1 (now from the forwarded `dbg_a7_wb`, because the state runs while
the retiring instruction's A7 write may still be landing).  Its
`issue_ifetch` finds the stream already at the target and issues nothing.
Two folds collect the cycles: `go_pc_now`'s plain path dispatches the
target word at once when the stream is at `t` with the word resident
(instead of S_FETCH popping it a cycle later; this also serves any
redirect whose target happens to be the queue head), and the S_MWR
acknowledge arm raises `go_pc(br_tgt)` itself for a BSR/JSR push whose
stream is already at `br_tgt` -- the deferred-issue problem that kept
Alan from folding S_BSR_PUSH/S_JSR2 into the acknowledge does not arise,
since nothing is issued.  `go_pc_t_early` gains the S_MWR arm
(`r_m_ret != S_NEXT ? br_tgt`, the lookahead's store-retire go_pc keeps
`rd_bcc_t`).

Why it is safe: every term of the dispatch and the hint is registered
queue data, `pc`, `epf_count` and the state; the ALU flags never enter.
The early fetch is speculative in the same sense as the fill engine's
own: a fault on it is recorded (`epf_err`) and re-raised on demand, an
odd target skips it and lets the state raise its address error, a trace
or interrupt at the branch's own redirect takes the exception path with
the stream flushed, and a store into the fetched window flushes it.
`sys_retire` states and `aux_we` cycles are excluded, S_DECODE never
dispatches this way (its `rd_ir` is `ir`), and the conditional forms are
untouched.  The new `t_branch_early` leg of the AP suite checks each
form after a register producer, a store, a load, LEA, NOP and another
branch, the pushed return address and A7 (including an A7 write landing
on the dispatch edge), T1 and T0 trace frames, the three odd-target
frames, a level-2 interrupt swept over every cycle of the BSR.W and JSR
windows, CINV-disciplined self-modifying displacements, and a target
that is already resident; it passes on the pre-change core with the
same expectations.

Per transfer with the port free (cycles from the pop of the branch to
the target's first decode; the push holds the port two cycles, the
hinted fetch two): BSR.W 8 -> 6, JSR abs.L 9 -> 6, JMP abs.L 6 -> 3,
BRA.W 5 -> 3.  The new `branch_bench` (BSR.W, JSR abs.L, JSR d16(PC),
BRA.W, JMP abs.L per iteration, with JSR (An) and a Bcc.W as controls)
measures 11 of the 13 cycles predicted per iteration.

| gate | before | after |
|---|---:|---:|
| AP suite | 23/23 | 24/24 (t_branch_early added; 58,322 -> 58,216 cycles) |
| bench_loop | 81,202 / 82,000 | unchanged |
| pipe_bench phase 0 | 122,190 | 120,194 (-1.6 %): S_FETCH 6,131 -> 4,135, S_DECODE 18,516 -> 17,517, S_MWR 57,096 -> 59,095 (the push waits for the fetch) |
| branch_bench phase 0 | 129,778 | 118,784 (-8.5 %): S_FETCH 23,214 -> 20,236, S_DECODE 22,016 -> 18,016, S_BSR_PUSH 1,000 -> 1, S_JSR2 3,000 -> 2,000 |
| corpus-100 | 32,991,462 | 32,980,201 (-0.03 %), 0 diffs |

Left for the table: Bcc.W/.L (the condition needs a prediction and a
mispredict path that re-arms the fall-through), JSR/JMP (An) and other
register-indirect forms, and RTS, whose pop read competes with the
target fetch for the one port -- the exact alternative there is to issue
the pop read from the retire that pops the RTS (one cycle, no
prediction).  BRA.B/BSR.B after a non-producer retire can take the
lookahead arm's go_pc with no flags (cond 0000), a one-line change.

### 10. DBcc dispatched from the pop into S_DBCC1 (2026-09-18)

The same dispatch for DBcc: at the retire that pops a DBcc whose
displacement word is resident, `dispatch_dbcc` pops both words, sets
`br_base`/`imm`, selects Dn on port A and enters S_DBCC1, which reads
the settled port a cycle later exactly as it did after S_DECODE; the
state's target, condition, count, refill dispatch and exit are
untouched.  The one hazard is a retiring arm writing that Dn on the
popping edge (`MOVE.W #n,Dn / DBcc Dn`: the write lands while S_DBCC1
reads the port): `rfw` now raises a blocking carrier (`rfw_now`,
`rfw_now_a`) and the dispatch is refused when it names the DBcc's
register, leaving S_DECODE's path.  This is the "DBcc resolved in
decode" item of the plan with the two-word pop accounting borrowed from
increment 9.  Besides the decode cycle, the pop's `epf_issue` keeps the
fill engine off the port in that cycle, so S_DBCC1 finds the port free
for its refill dispatch: before, a fill let out at the pop made the
decode cycle's inline displacement pop fall to S_IMMF and cost a third
cycle on some loop closures.

`t_branch_early` gains a DBcc section: the counter written just before
the loop, the counter written by the very instruction that pops the DBcc
(the hazard, both the word and the ADDI long form), the condition true
with no decrement, loops after a store and a load retire, the exit
falling through to the right word, the odd-target address error and the
T0 trace at the target.  It passes on the pre-change core with the same
expectations.

| gate | before | after |
|---|---:|---:|
| AP suite | 24/24 | 24/24 (t_branch_early 60,132 -> 60,020 cycles) |
| bench_loop phase 0 | 81,202 | 68,354 (-15.8 %): one cycle per closing DBcc |
| pipe_bench phase 0 | 120,194 | 118,696 |
| branch_bench phase 0 | 118,784 | 117,286 |
| corpus-100 | 32,980,201 | 32,979,913, 0 diffs |

### 9b. Build 7 and the early fetch's target (2026-09-18)

Build 7 (increment 9 alone, 8a9b392) routed at 36,388 ALMs but missed
the CPU clock by 1.575 ns: rr_a -> register file -> the ALU's shifter
and zero compare -> flags -> the lookahead carrier -> a mux between
`go_pc_t_early` and the early fetch's `bd_t` -> the refill-seed count ->
`epf_ftail`, 31.2 ns (`scratch/pipeline_b7/worst_detail.txt`).  The
early fetch had given `issue_ifetch` a second target next to the shared
early-target wire, and the synthesizer selected between the two on the
carriers -- one of which, the lookahead arm's, comes from the flags.
Rule 3 of the branch, once more.

The fix makes the retire cycle's arm of `go_pc_t_early` the queue head's
own target (`rd_is_bcc ? rd_bcc_t : bd_t`, a registered opcode select)
and points the early fetch at that wire, so the seed cone has one
target and the carriers only enable it; a simulation check in
`dispatch_branch` reports any cycle where `bd_t` and the wire differ.
Since a state with its own arm of the wire can also retire into a pop
(a not-taken Bcc.W or FBcc, a DBcc or FDBcc exit), the early fetch is
skipped in those four states (the branch state issues the fetch itself,
as in build 6); the dispatch into the branch state still happens.
`!mem_ack` leaves the enable as well: the request is held until its
acknowledge, so `!mem_req` already covers that cycle.

The same commit shortens the cone itself.  Every redirect site computed
its refill test (four valid words from the target) and its seed count
(up to eight) by selecting and counting the sector's valid bits in an
eight-step chain from the target's sector word; now `brf_run[k]`, the
valid run from word k to the sector's end capped at eight, is computed
once from the registered `brf_valid` alone, and the four sites (the
`issue_ifetch` expansions, `brf_refill_hit`, S_DBCC1's inline test)
read one 16-way mux on the target word: `refill_hit = run >= 4`,
`brf_seed_n = run`.  Exactly the old values by construction (the old
loop counted consecutive valid words within the sector up to eight, and
`k <= 12` with four valid words is `run >= 4`).

Gates: identical cycle counts to increment 10 on every bench (no bench
pops a call in the four excluded states), corpus 32,979,913 with 0
diffs.  Build 7b is this commit cherry-picked onto increment 9 alone.

### 11. S_FETCH's resident pop hands the target to the dispatch chain (2026-09-19)

**WITHDRAWN 2026-09-18 (4abb118)**: build 9 (with 11 and 12) gave impossible
Speedometer times in 2 of 5 Mix runs, build 13 (without them) none in eight;
statistical evidence, no mechanism found, and the pair was worth only +0.4 %.
The text below is the record of what was built; the tests stay in the suite.

The first instruction after a redirect whose word is already in the queue
(a refill-buffer seed, a line offer that beat S_FETCH) went through
S_DECODE unconditionally.  S_FETCH's resident pop now raises
`rd_queue_pop` like a retire's pop, so the descriptor (allowed from
S_FETCH: no fetch slot to protect), the record, and the transfer and DBcc
dispatches apply to it; not the forwarded word (`rd_ir` is the ring) and
not the handler's first word.  Cycle-identical on every bench (resident
targets are rare there); a variant that also applied the record inside
go_pc_now's resident dispatch duplicated two dispatch bodies for no shown
gain and was dropped.

### 12. The loop-top record cache (2026-09-19)

**WITHDRAWN 2026-09-18 (4abb118)**: build 9 (with 11 and 12) gave impossible
Speedometer times in 2 of 5 Mix runs, build 13 (without them) none in eight;
statistical evidence, no mechanism found, and the pair was worth only +0.4 %.
The text below is the record of what was built; the tests stay in the suite.

Every closing branch of a tight loop -- a taken DBcc, Bcc.B or Bcc.W
whose target sits in the refill sector -- dispatches the target word
from the buffer straight into S_DECODE (`decode_dbcc_brf_now`), so the
loop's first instruction paid the decode cycle on every iteration even
when the record or the descriptor could have entered its pipe state
directly (it could not: the record decodes the queue head, and the head
in that cycle is the branch).  One entry now keeps the decode of the
last instruction that entered S_DECODE from a refill dispatch (`trc_*`:
the descriptor's fields or the record's value/valid pairs, captured
after the case when S_DECODE runs with `trc_cap`), keyed by the word's
address, its context and the sector's generation.  The next refill
dispatch to the same word replays it: `apply_cached_desc` /
`apply_cached_record` write exactly what `dispatch_reg_decode` /
`apply_record` would, the immediates come from the sector's words
(`brf_word`), and the queue bookkeeping consumes them with the opcode.

The entry follows the buffer.  `brf_gen` counts every re-adoption of
the sector and every invalidation (`epf_flush`, a CPU write into the
sector, a new tag from a fetch or a line offer), and a hit requires the
generation it was captured under: an entry can only replay the very
fetch it was decoded from, so a rewritten word (CINV-disciplined, as
always) is refetched, re-decoded and re-captured before it can be
replayed.  Hazards are the ones the record already has at a retire: a
base register written on the dispatch edge is caught by the pipe
start's own landing-write check, the descriptor captures from the
forwarded ports.  The hit compare sits on the early-target wire next to
the seed count and only enables register writes, so it does not lengthen
the seed cone.

`t_branch_early` section J: loop tops of the record class closed by
DBcc, by a Bcc.B at a producer's retire and by a Bcc.W; a descriptor
loop top; loop tops with an immediate (both record forms); the base
register written by the producer that resolves the branch; and the loop
top rewritten between two runs of the same loop.  It passes on the
pre-change core.

| gate | before | after |
|---|---:|---:|
| AP suite | 24/24 | 24/24 (t_branch_early 62,698 -> 61,9xx) |
| bench_loop phase 0 | 68,354 | **56,108 (-17.9 %)**: one cycle per iteration of the inner loop |
| pipe_bench / branch_bench | 118,696 / 117,286 | unchanged (their loops span sectors; no refill dispatch) |
| corpus-100 | 32,979,913 | 32,962,768 (-0.05 %), 0 diffs |

What it costs: about 190 flops for the entry and a second write source on
the pipe registers.  MOVEQ, register shifts and `#imm,Dn` at a loop top
are not cached: in S_DECODE the descriptor leaves those to the body.

### 13. The one-clock posted store (2026-09-19)

Stores were 12 % of the Speedometer bracket at 3.3 cycles each; a posted
store's floor was two port cycles, the request and the registered
acknowledge on admission (Alan's write-path checkpoint).  The read side
has had a one-clock hit since step 1: the address goes out on the hint
bus a cycle early, the MMU registers a verdict with its translation, and
the cache acknowledges the request in its own cycle from registers only.
This increment gives stores the same three parts.

- **The core hints its stores** (`hint_store`): `dst_addr` from S_EXEC
  for the memory-destination classes, `A7 - 4` (forwarded where the
  state may run while an A7 write lands) from the five push states,
  `mm_addr` from the MOVEM loop, `m_addr_r` from S_MWR's own issue; all
  registers, taking precedence over the fetch hints in those states.
- **The MMU's write verdict** (`hq_wok`, `m_hint_wmatch`): the hint's
  page carries no accumulated write protection (entry bit 0, or the
  TTR's W bit for a transparent hint) and its modified bit is already
  set (entry bit 1: the first write to a page must walk to set M), on
  top of the read verdict (translated, cacheable, not supervisor-only,
  the MMU quiet).
- **The cache's store fast lane** (`fast_store`): a data write in
  C_IDLE with nothing owed whose request is the registered hint with the
  write verdict, and which the platform posts -- judged on the hint's
  registered physical tag (`c_post_ok_hint`, a new input beside the live
  `c_post_ok`, which carries the MMU's live translation and may not
  qualify a same-cycle acknowledge) -- is acknowledged in the request
  cycle.  The admission does everything it did on that same edge
  (captures the copy it drains from, sets `post_active`, books the
  hit-update); a fast-acknowledged store is always posted, whatever the
  live predicate says, so the two paths cannot disagree.  Every term is
  a register or the MMU's registered verdict, as for `fast_hit`.

The CPU-only suite had never exercised posting: its wrapper tied
`c_post_ok` low ("no store queue below this bench").  It posts now, as
the MiSTer wrapper does, which needed three bench adaptations, each a
property of posting itself rather than of this change: the bench's
magic-register page is its I/O and is never posted (its bus-error target
lives there); the FC check attributes a bus cycle to the store that
posted it, not to the exception processing the core may have entered by
the time it drains (the cache exports `c_posting` for that); and the
double-fault bench, which bus-errors an exception frame's stack write,
keeps stores unposted through the wrapper's new `AP040_POST_STORES`
parameter (a promise-never-faults store cannot carry that fault, on the
board or anywhere).  With posting alone the benches move a lot and not
uniformly (pipe_bench 118,696 -> 110,696, branch_bench 117,286 ->
119,284, corpus 32,962,768 -> 32,249,564, 0 diffs): the bench's memory
is a 16-bit bus with a seven-cycle write, so every store's drain
dominates and the reads behind it wait.  On that model the fast lane
changes nothing (the earlier acknowledge only moves the wait to the
next access), so its gain is a hardware measurement; the suite is its
correctness gate, and `t_mmu`'s write-protect, modified-bit and
first-store-faults cases are exactly the ones a wrong write verdict
would break.

| gate (posting on) | posting alone | with the fast lane |
|---|---:|---:|
| AP suite | 24/24 | 24/24 |
| bench_loop phase 0 | 55,916 | 55,914 |
| pipe_bench phase 0 | 110,696 | 110,696 (the bench's drain dominates) |
| branch_bench phase 0 | 119,284 | 119,284 |
| corpus-100 | 32,249,564, 0 diffs | 32,248,984, 0 diffs |

### 14. A read may pass one queued store (2026-09-19, the plan's item 3)

`wombat_store_buffer` let no direct transaction start until its queue
was empty: a cache miss or a bypass read behind two posted stores waited
for both to reach the SDRAM, about 50 M cycles of the bracket by Alan's
profile.  A read whose 16-byte line differs from the one queued write
may now take the bus ahead of it (`pass_ok`), and wins over that write's
drain when both are eligible in the same cycle, since the CPU waits on
the read and not on the write.  The drain of a head starts the cycle
after its capture, so in practice the read passes the second of two
queued stores once the first has landed.  A read of the queued store's
own line still waits (a fill must see the store), non-qualified writes
still wait (a device register write still sees every earlier RAM store
landed), and a full queue always drains first, so a third store stalling
the CPU is never starved by a stream of reads -- the failure mode of
Alan's four-entry read-around (`CPU_SB4_20260915.md`).  Instruction
fetches pass like any read: a store into the fetched line is a
same-line read and waits.

Gate: the buffer's Verilator unit bench with a new T4 (the pass and its
completion, the passed store draining after it, same-line reads waiting
both after the drain started and right after a capture, the full queue
draining first): ALL TESTS PASSED.  The CPU-only suite has no store
buffer; the hardware run is the gate, as for increment 13.  Build 11.

**The hole in it (found 2026-09-18 by inspection, cf06fe6).**  `pass_ok`
compared the first 16-byte line of the read with the first line of the
queued store, and neither transfer has to sit inside one line.  The
cache posts a store that straddles two lines UNSPLIT (its "complex
write": a long at $xD-$xF or a word at $xF; 68k stacks are only
word-aligned, so a long push at $xE is ordinary Mac code) and clears
BOTH cache lines.  The next read of the second line is therefore a miss,
its fill passed the queued store, read the SDRAM before the store's tail
bytes had landed, and the cache kept the stale bytes after the store
drained: silent corruption of up to three bytes, visible only to a later
read of that line.  The mirror case is a bypass read that straddles two
lines passing a store queued to its second line: wrong data straight to
the core.  Build 12 was fitted from the tree with the hole.  The fix is
exact and costs two LUTs: a crossing store is never passed and a crossing
read never passes (`xfer_cross`, a 4-bit offset and a size each, the
queued one from registers).  Unit bench T5 fails on the old RTL at its
first check and passes now: a read of a crossing store's second line,
a crossing long read and a crossing word read against a store queued to
their second line, and the control that a non-crossing word at $xE still
passes.  The lesson for the next store-path change: every address compare
below the cache has to be read against "misaligned word/long transactions
appear here unsplit" in `wombat_cpu.sv`'s bus contract.  Build 13 =
build 12's tree + this fix.

**It was build 12's boot hang.**  Build 12 on hardware stopped at the bare
grey screen before the pointer (measurements section 21).  The
full-machine simulation, three trees from the same fast-boot ROM and disk:
build 8 (control) and build 13 (build 12 + this fix) both replace the grey
screen with the Happy Mac at frame 480 with identical frame hashes; build
12 is still at the bare grey screen at frame 840.  The ROM's start-up code
pushes longs on a word-aligned stack with the caches it has just enabled,
which is exactly the crossing-store-then-fill shape.  (The harness had to
be repaired first: it had not been built on this branch since the MLAB
regfile and the hint bus renamed the signals its debug panels read,
8359fa3.)  An early-boot hang is seconds of machine time, a few minutes
in the sim: for a store-path or cache change, run the three-tree frame
comparison (`scratch/pipeline_b12/simtree.sh`) BEFORE the fit.

### 15. BRA.B from any retire (2026-09-19)

The lookahead arm resolved a short branch at the queue head only at a
flag producer's retire, because it judges the condition on that
producer's flags.  BRA.B's condition is always true, so the arm now
fires for it from any retire (`rd_is_bra`), with the same guards, from
a state without a target arm of its own on `go_pc_t_early` (the
not-taken Bcc.W/FBcc and the DBcc/FDBcc exits, a LINK/PEA retire from
S_MWR keep S_DECODE's path) and not after a system retire; `hint_bra`
puts the target on the hint bus in that cycle for the states `hint_ftb`
does not cover.  One cycle per BRA.B after a LEA, an UNLK, a MOVEM, a
bit operation or any other non-producer.  Cycle-identical on the
benches and the corpus (none has that shape), 0 diffs, suite 24/24.

### The build-9 finding in simulation (2026-09-19)

A new suite leg, `t_loops_irq`, runs checksummed loop workloads of every
shape the record cache replays (a signed bubble sort with data-dependent
branches, DBcc loops whose counter is the loop top's index or whose base
is written by the closing instruction, immediate and descriptor loop
tops, nested loops sharing the one entry, a body longer than the seed, a
Bcc.W loop with a memory top, and the memory-destination tops: the Sieve
shape `clr.b 0(a0,d0.w)`, fills with (An)+, memory-to-memory moves, ADDQ
to memory, a store of the counter) once quietly and again under 400
level-2 interrupts at rotating intervals, comparing the checksums.  It
passes on the head (with 11 and 12; 152,240 cycles) and on the bisect
tree (without; 152,966).  The CPU-only simulation does not reproduce the
board fault; what it lacks is the real memory path (the store buffer,
the SDRAM bridge and its 33/99 MHz crossing).  Build 7b also had "loops
that did not run" readings, build 8 none; build 10's request-handoff
crossing margin is +1.270 ns where build 8 had +2.513, and the crossing
note (`docs/sdram-open-row-crossing.md`) records real PLL skew the
constraints do not model.  Build 12, the bisect, decides between the
two.

### Withdrawn: RTS/RTD/RTR from the pop (2026-09-18)

A `dispatch_ret` that popped RTS/RTD/RTR into S_RET1 (or issued the pop
read in the popping cycle when the port was free and no A7 write was
landing) passed every gate and was cycle-neutral on every bench: the
common epilogue pops the RTS in UNLK's acknowledge cycle, where the port
is busy, so S_RET1's issue a cycle later is exactly S_DECODE's; only an
RTS behind a register producer with the port idle gains its cycle.  It
adds a second data-issue site for a gain the benches cannot show, so
the RTL was withdrawn; its test section (RTS after an A7 write and
after UNLK, RTD with and without a landing A7 write, RTR, the odd
return address with A7 backed out) stays in `t_branch_early`.

## Builds

| build | content | seed | ALMs | timing | rbf | hardware |
|---|---|---:|---:|---|---|---|
| step 1 | 86b6b04 | 21 | 37,439 (89 %) | met: CPU +0.036, HDMI +0.056, RAM +0.775, hold +0.187 | d157f555 (`scratch/pipeline_step1/`) | **Mix 0.877** (0.875/0.878/0.879, +2.6 % over 0.855), CQD 0.643, FPU 0.464, 8.1 boot <= 123 s, clean shutdown |
| build 2 | 77aa72a (items 1-5) | 21 | 36,330 (87 %) | failed to route (congestion) | none | |
| build 3 | 5206845 (items 1-8) | 21 + FITTER_AGGRESSIVE_ROUTABILITY_OPTIMIZATION | 36,010 (86 %) | routed; CPU clock -3.760 (state -> hint mux -> cache fast-hit select -> ALU -> lookahead -> seed -> epf_ftail, a false path) | not deployable | |
| build 4 | 31445e5 (+ cache fast-hit from the registered hint) | 21 + the switch | 36,326 (87 %) | routed; CPU clock -2.362: A7 bank -> port A -> shift count -> the ALU's ROXx modulo divider -> flags -> lookahead -> the carriers' target mux -> seed -> epf_ftail | not deployable | |
| build 5 | 24579aa (+ constant-modulus ROXx count, one shared redirect target) | 21 + the switch | 35,926 (86 %) | routed; CPU clock -1.042 (HDMI +0.341, RAM +0.408): ATC RAM -> walk decision -> cache inv_wren -> fast_hit -> c_rdata -> ALU -> lookahead -> seed -> epf_ftail | 595297fb (`scratch/pipeline_b5/`) | PROBE on hardware: 8.1 boot <= 84 s, liveness OK, **Mix 0.900/0.902/0.902** (+2.8 % over step 1, +5.3 % over 0.855) |
| build 6 | c84a5e7 (+ fast_hit qualified from registers only) | 21 + the switch | 35,797 (85 %) | CPU +0.139, RAM +0.445, HDMI -0.001 (one `sys_top` video register) | cda6ba11 (`scratch/pipeline_b6/`) | **Mix 0.900/0.902/0.903**, CQD 0.660, FPU 0.464/0.467, 8.1 boot <= 85 s, clean 46 s shutdown, no artefact in any captured frame |
| build 7 | 8a9b392 (+ increment 9) | 21 + the switch | 36,388 (87 %) | routed; CPU clock -1.575 (HDMI +0.333, RAM +0.538): rr_a -> regfile -> ALU shifter and zero compare -> flags -> the lookahead carrier selecting between go_pc_t_early and the early fetch's bd_t -> seed count -> epf_ftail (`scratch/pipeline_b7/worst_detail.txt`); rule 3 again, from a second issue_ifetch target | not deployable | |
| build 7b | 8a9b392 + 788ab35 (the shared early-target wire, the valid-run seed count; increment 9 alone otherwise) | 21 + the switch | 35,807 (85 %); synthesis 55,143 ALUTs (-455 vs build 7) | **met on every clock**: CPU +0.580, HDMI +0.364, RAM +0.527, hold +0.147, TNS 0 | 9e3b7d9d (`scratch/pipeline_b7/`) | **Mix 0.905/0.908/0.907** (+0.55 % over build 6, +6.0 % over 0.855; Dhrystones +1.8 %, Permutations/Towers -1 %), CQD 0.662, FPU 0.468/0.464, 8.1 boot <= 97 s, clean 47 s shutdown, no artefact; two non-reproducing short last-test timings excluded (section 18 of `docs/PERFORMANCE_MEASUREMENTS.md`) |
| build 8 | 78ba885, the branch head (increments 9 + 10 + 788ab35) | 21 + the switch | 35,952 (86 %); synthesis 55,424 ALUTs | **met on every clock**: CPU +1.114 (the branch's best), HDMI +0.217, RAM +0.914, hold +0.258, TNS 0. The twelve worst CPU-clock paths are all the SDRAM bridge's clk_ram -> clk_sys line handoff (`sdram_beat32 line_done_handoff -> line_data`, +1.114); no core path is among them (`scratch/pipeline_b8/worst_paths.txt`). The clk_sys -> clk_ram handoff toggle has +2.513 | 69c53878 (`scratch/pipeline_b8/`) | **Mix 0.905/0.908/0.908** (mean 0.907, flat against build 7b: Speedometer's loops close with Bcc, not DBcc), **CQD 0.666** (+0.6 %, all depths), FPU 0.468/0.465, 8.1 boot <= 101 s, clean 47 s shutdown, no artefact, no short timing in six series (section 19) |
| build 9 | 4931e19, the head (increments 11 + 12 on build 8) | 21 + the switch | 36,400 (87 %); synthesis 56,024 ALUTs | **met on every clock**: CPU +1.007, HDMI +0.477, RAM +0.697, hold +0.249, TNS 0 | f061d1fc (`scratch/pipeline_b9/`) | **A FINDING**: 2 of 5 Mix runs with impossible loop-test times (Bubble Sort 0.022 s, Quick Sort 0.273 s, Dhrystones 17712/s), mid-series; the valid runs Mix 0.911/0.910/0.911 (+0.4 %), Sieve +2.0 % slower, CQD 0.668, FPU 0.470/0.468; clean boot and shutdown (section 20). Increments 11-12 held out; build 12 bisects |
| build 10 | 7f69882 (+ increment 13, the one-clock posted store) | 21 + the switch | 36,428 (87 %); synthesis 55,999 ALUTs | **met on every clock**: CPU +1.145 (the branch's best), HDMI +0.251, RAM +0.445, hold +0.252, TNS 0; clk_sys -> clk_ram request handoff +1.270 (build 8: +2.513; the 2026-09-02 fault's build: +0.276), clk_ram -> clk_sys +1.145 (`scratch/pipeline_b10/cross_*`) | 28a7e6dc (`scratch/pipeline_b10/`) | run dropped (fewer builds); a bisect point |
| build 11 | 83ab536, the head | | not built. Its launcher was stopped in the wait-gate after build 9's finding, but only the outer shell died: the inner `build_only.sh` kept waiting and started the flow at 05:54 when the other session's fit ended -- on the worktree, which had been at build 12's commit since 05:35. What it built is build 12 (below) | | | |
| build 12 | 78ba885 (build 8) + 13 + 14 + 15, WITHOUT 11 and 12 (bisect; the worktree's detached edca43e, verified clean and by content before the rbf was staged) | 21 + the switch | 36,071 (86 %); synthesis 55,480 ALUTs (build 8 + 56: increments 13-15 cost almost nothing; the record cache was the 550) | **met on every clock**: CPU +1.241 (the branch's best), HDMI +0.412, RAM +0.806, hold +0.198, TNS 0; clk_sys -> clk_ram request handoff **+1.384** (build 10 +1.270, build 8 +2.513), clk_ram -> clk_sys `line_done_handoff -> line_data` +1.241 = the CPU clock's worst path again (`scratch/pipeline_b12/cross_*`) | 555a954b (`scratch/pipeline_b12/`) | **DOES NOT BOOT**: the ROM clears the screen to the grey dither and stops before the pointer, the Happy Mac or any disk access; identical frames from +56 s to +858 s, `write_bytes` flat, no series run (section 21). One of 13/14/15 breaks early start-up with every clock met: logic, not timing. The bisect question about 11/12 is unanswered |
| build 13 | build 12's tree + cf06fe6 (increment 14's line-crossing hole closed); the worktree's detached 4d09389 | 21 + the switch | 36,089 (86 %) | **met on every clock**: CPU +0.772, RAM +0.668, HDMI +0.527, hold +0.204, TNS 0; clk_sys -> clk_ram request handoff **+0.727** (build 12 +1.384: a two-LUT change re-placed it), clk_ram -> clk_sys +0.772 (`scratch/pipeline_b13/cross_*`) | fde49a3c (`scratch/pipeline_b13/`) | full-machine sim first: build 12's tree sits at the bare grey screen through frame 840 (the hardware hang, reproduced), build 13's shows the Happy Mac at frame 480 exactly like the build-8 control (`scratch/pipeline_b13/sim_*.png`): **the line-crossing hole was the boot hang**. ON HARDWARE (section 22): boots (Finder <= 100 s), **Mix 0.9285, mean of EIGHT valid runs** (0.926/0.928/0.929 x6; +2.4 % over build 8, +8.6 % over 0.855; Sieve +6.0 %, Permutations +3.7 %), **0 anomalous values in 11 series**, CQD 0.670, FPU 0.466/0.468, clean 47 s shutdown. Increments 11-12 reverted on this evidence (4abb118); the branch head's RTL is this build's |

(filled in as each build completes; the seed ledger is also in the `.qsf`.)

Outcome of the day: the shipped core measured 0.855; step 1 alone 0.877
(+2.6 %); all eight increments 0.902 (+5.5 %), on a core 1,347 ALMs
smaller than the shipped one (35,797 against 37,144) with the 33 MHz CPU
clock met.  The fitter's aggressive routability optimization is now part
of the committed recipe: without it build 2 failed to route at 87 %, with
it builds 3 to 6 routed at 85 to 87 %.  Three timing fixes were needed
once the hint bus existed, all exact: the cache's fast hit qualifies and
selects from its registered copy of the hint (the analyzer follows the
core's combinational hint mux otherwise), the ROXx count modulo is a
constant-modulus chain instead of a 33-bit divider, and the two hoisted
redirect bodies share one state-selected target so the branch lookahead's
flags only gate an enable.  The HDMI miss of 0.001 ns sits on the
framework's own video register and is judged at the display; the release
gate (A/UX 3.1 at 32 MB, CD audio by ear) has not been run on this branch.

Outcome of 2026-09-18: increment 9 (the unconditional transfers redirect
at the pop, the plan's item 2 in its exact form) measured 0.907 on build
7b (+0.55 % over build 6, the gain in the call-heavy tests) once its
early fetch shared the redirect target wire and the refill seed count
came from precomputed valid runs; that restructuring also gave the CPU
clock +0.580 ns and then +1.114 ns of margin (builds 7b and 8) against
build 6's +0.139, and the worst CPU-clock path is now the SDRAM bridge's
crossing rather than anything in the core.  Increment 10 (DBcc from the
pop) is exact and gated, cut the directed loop bench by 15.8 %, and is
flat on the Speedometer Mix (Pascal loops are Bcc loops); it shows in
CQD (+0.6 %).  Build 8 = the branch head: Mix 0.907, CQD 0.666, every
clock met including HDMI, 35,952 ALMs.  An RTS/RTD/RTR-from-the-pop
increment was tried and withdrawn as cycle-neutral.

## Not done, and why

- The plan's item 3 (reads passing pending stores): Alan's four-entry
  queue experiment (`CPU_SB4_20260915.md`) lost, and his conclusion was
  that the fix is a cache fill that yields the bus between beats, a
  cache/store-buffer change with a boot-level risk.  Left for a session
  with the full-machine sim in the loop.
- The two-sector refill buffer (`CPU_BRF2_20260914.md`, corpus -10 %,
  +2,300 ALMs) exists only as a /tmp candidate on Alan's box; it would be
  a rebuild.
- The six-stage engine itself (the plan's item 4, "months").
