# P179: the memory-to-memory MOVE's destination at the source read's acknowledge

First step of "address calculation in decode" (the idea list after P174's
hardware Mix 1.460, `docs/PERFORMANCE_MEASUREMENTS.md`).

## What the profile showed

An instrumented Whetstone bench (`scratch/p179_ea_decode_20260922/tb_cpu_whetstone_ea.sv`,
per-opcode and per-predecessor counters for S_EA_DISP / S_EA_D16 / S_IMMF)
on P174: S_EA_DISP 1.12M clocks, 652k of them entered from S_MRD -- the
destination of a memory-to-memory MOVE (`2F10` MOVE.L (A0),-(A7), `2F20`,
`30DF`, `209F`, `22D8`) started through `ea_start` after the source read,
costing S_EA_DISP + S_PIPE_DEA.  The direct handoff (`move_store_read_ready`,
the store issued in the read's acknowledge clock) existed, but it missed on
every one of these:

- 435k + 109k + 30k: the read was acknowledged in its first S_MRD clock, and
  S_MRD's destination-base preselect only lands on its second -- port A still
  held the source base; and a register write was landing (the source's own
  (An)+/-(An) update, or a retiring instruction's), which the gate refused
  even though it was not the destination base.
- 251k (after the first fix): `2F10` whose read was issued by the retire
  lookahead (`retire_move_read`, from S_PIPE_REGS): mem_issue's preselect
  tests the registered p_src/dst_mode_r, which on that edge are still the
  retiring instruction's.
- 316k: d16(An) destinations, which the direct path did not cover (they went
  through ea_start's inline extension pop to S_PIPE_DEA).

## Change (`rtl/ap68040/rtl/ap040_core.v`)

1. `mem_issue` selects a MOVE's simple destination base ((An), (An)+, -(An),
   d16(An)) onto port A on the source read's issue edge, as it already did for
   the indexed mode.
2. The `retire_move_read` site does the same from the new record's
   `n_dst_mode_r`/`n_dst_rn_r`.
3. `move_store_read_ready` and the two inline d_ack paths block only on a
   write landing on the destination base itself (`dst_base_landing`), not on
   any register write.
4. `move_store_read_ready` covers d16(An) with the displacement at the queue
   head: address `rf_rdata_a + sxw(epf_data[epf_head])`, the word popped in
   the acknowledge clock (as the fallback's inline path already did, so the
   fault/restart point is unchanged).

## Results (sim, latency 3, against P174)

| fixture | P174 | P179 | |
|---|---:|---:|---:|
| Whetstone loop | 24,886,003 | 24,347,556 | -2.2 % |
| Towers | 19,495,571 | 19,229,324 | -1.4 % |
| Quick Sort | 152,808 | 150,514 | -1.5 % |
| Dhrystone loop | 102,604,350 | 101,804,359 | -0.8 % |
| Permutations (lat 0), Queens, Puzzle, Sieve, Bubble, Int. Matrix | | | unchanged |

All oracles and negative controls pass (`scripts/cpu/speedometer_suite.sh`),
Permutations/Queens array and guard checks pass, and the AP68040 self-test
suite passes (`rtl/ap68040/tb/run_tests.sh`).  Expected Mix effect is small
(~+0.01); the larger EA items are next: PEA d16(An) (`486E`, four clocks:
S_EA_DISP, S_IMMF, S_EA_D16, S_PEA1 -- ~650k Whetstone clocks), MOVE
#imm,d16(An) and LEA d16(An) (S_IMMF + S_EA_D16), and the FPU's (An)/d16(An)
operands through S_FPU_DEC -> S_EA_DISP.

Timing: item 4 puts an adder (port A + the queue head) in front of the
in-place store issue.  Not yet fitted.
