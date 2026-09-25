# P198-P205: call/return, instruction translation, fetches under stores, FPU paths

Commit `887945b` on top of P197 (`c4a3522`).  Every number is the kernel fixtures (writes latency 1
for Whetstone, `scratch/p198_ret/run_whetstone_wl.py`), not a Mix score.  All six oracle fixtures
(`scripts/cpu/speedometer_suite.sh`), the AP68040 self-tests, Dhrystone, Permutations and Queens
(`--compare --early-drain`, the production macros) pass.

## Where Whetstone's time went (P199, 20.6M clocks)

A per-PC histogram (`PCX` in `scratch/p198_ret/tb_w2.sv`) with the ROM disassembled (capstone)
showed 6.3M clocks in two ROM routines, the SANE-to-FPU glue for add ($408EAA4C) and multiply
($408EAD30): LINK, copy two 10-byte extended operands onto the stack, FMOVEM (A7)+,FP0,
FADD.X/FMUL.X (A7),FP0, FMOVE.X FP0,(A7), copy back, UNLK, RTD #8.  106 clocks per add call.  A
clock-by-clock trace of one call (`WTR`) gave the list below.  Cache misses are not a factor (1,345
data fills per loop).

## The changes

- **P198** (UNLK -> RTS) and **P199** (RTD redirected in its pop's acknowledge, RAS for RTD): from
  `scratch/p198_ret`, see RESUME.  RTD inside P198's handoff made Whetstone worse; RTS only.
- **P200: four instruction translation copies.**  The MMU's per-space copies of the last ATC hit
  held four data entries (by page set) and ONE instruction entry.  A call from user code (page
  $600) into the ROM glue replaced it, so the RAS-predicted return target's hint did not translate
  (`hqi_ok = 0` on 94k of 120k returns) and the return fetch took the three-clock lookup.  Now the
  instruction side has four copies indexed like the data side.  -2.0 %.
- **P201: instruction hits under a posted store.**  `fast_iaccept` required C_IDLE, so the fetch
  after a store (a JSR's target after its push, the next line after LINK) waited for the store's
  C_PASS.  The one-clock instruction hit reads only the instruction mirrors, which no store writes;
  it is now admitted in C_PASS with a posted store under `fast_accept_pp`'s terms (no word-clash
  check needed), with the same line-offer bookkeeping as in C_IDLE.  -1.4 %.
- **P202: F_NORM skipped** for an extended source with the integer bit set (normalized, or an
  infinity/NaN that F_NORM passes straight on).  -0.7 %.
- **P203: FMOVE FPn,(An)** goes through S_FPU_AN like P181's sources.  -0.4 %.
- **P204: ack_r handoffs.**  The cache exports `ack_r` (`c_ack_q`).  Nothing is admitted in an
  ack_r clock (every admission requires `!ack_r`), so the three "next request in the predicted
  acknowledge" hints (P182 MOVE store, P196 read after store, P198 RTS after UNLK) also fire when the
  current access took the registered path and is acknowledged from `ack_r` now.  Unhinted two-clock
  stores 366k -> 194k.  -1.2 %.
- **P205: chained FPU operand beats.**  The S_MRD acknowledge already queued the next longword of a
  multiword FPU operand (and, now, of an FMOVEM load); in the beat's predicted acknowledge clock the
  data hint shows the next beat and the acknowledge issues it in place (`fpu_rd_next` in the
  whitelist and the port condition).  One clock per beat instead of two.  -1.6 %.

## Results

| fixture | P199 | P205 | |
|---|---:|---:|---:|
| Whetstone loop | 20,607,769 | 19,171,712 | -7.0 % |
| Permutations (lat 0) | 972,962 | 955,178 | -1.8 % |
| Dhrystone loop | 91.60M | 90.60M | -1.1 % |
| Towers | 16,555,930 | 16,432,684 | -0.7 % |
| Quick | 143,703 | 143,003 | -0.5 % |
| Queens | 51,653 | 51,546 | -0.2 % |
| Puzzle / Int. Matrix | 22,833,267 / 2,201,790 | 22,785,146 / 2,196,993 | -0.2 % |
| Sieve / Bubble | | | unchanged |

(Towers..Bubble at P205 include P204/P205; the Whetstone column was built up one change at a time:
20,607,769 -> 20,203,670 (P200) -> 19,924,313 (P201) -> 19,787,372 (P202) -> 19,711,132 (P203)
-> 19,473,426 (P204) -> 19,323,608 -> 19,171,712 (P205 operand, FMOVEM).)

## What is left in the glue call (about 95 clocks now)

- `move.l #imm,-4(a6)` right after LINK: 9 clocks (S_FETCH, S_IMMF twice, S_PIPE_START, S_IMMF,
  S_EA_D16, S_PIPE_DEA, S_MWR) -- the queue is starved after the redirect and the next line.
- FPU latency: FADD's F_SRC..F_ADDX before `accepted`, then NORM2/ROUND/WB while the next
  FMOVE.X waits in S_FPU_DEC (0.78M of S_FPU_DEC's 1.29M clocks are `fpu_bg` waits, mostly true
  dependences).  Merging F_EXEC into F_SRC for binary ops with a normal source, and skipping F_SHR
  for a zero exponent difference, are the cheap FPU items.
- Store after store: the second waits for the first's C_PASS (fast_store needs C_IDLE); the fix is
  admitting a posted store in the clock the previous one's `m_ack` arrives.
