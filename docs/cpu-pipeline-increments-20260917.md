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

## Builds

| build | content | seed | ALMs | timing | rbf | hardware |
|---|---|---:|---:|---|---|---|
| step 1 | 86b6b04 | 21 | 37,439 (89 %) | met: CPU +0.036, HDMI +0.056, RAM +0.775, hold +0.187 | d157f555 (`scratch/pipeline_step1/`) | **Mix 0.877** (0.875/0.878/0.879, +2.6 % over 0.855), CQD 0.643, FPU 0.464, 8.1 boot <= 123 s, clean shutdown |
| build 2 | 77aa72a (items 1-5) | 21 | 36,330 (87 %) | failed to route (congestion) | none | |
| build 3 | 5206845 (items 1-8) | 21 + FITTER_AGGRESSIVE_ROUTABILITY_OPTIMIZATION | 36,010 (86 %) | routed; CPU clock -3.760 (state -> hint mux -> cache fast-hit select -> ALU -> lookahead -> seed -> epf_ftail, a false path) | not deployable | |

(filled in as each build completes; the seed ledger is also in the `.qsf`.)

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
