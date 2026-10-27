# 66/33/99 and 60/30/90 fits of the DDR3-VRAM core, 2026-10-27

66/33/99 is `pipelined-040-ddr3-vram` with `CPU_AP68040_2X`; 60/30/90 is
branch `pipelined-040-ddr3-fast60` (a474308's `CLK_60_30_90` time bases
cherry-picked onto this branch, 239964f).  Quartus 17.0, misterubuntu.
"fix" = with 0766b3f (EX opcode classes registered).

| fit | seed | settings | CPU setup | CPU TNS | CPU Fmax | ALMs |
|---|---:|---|---:|---:|---:|---:|
| 66 ctrl | 41 | recipe | -2.841 | -2414 | 55.58 | 38,171 |
| 66 fix | 41 | recipe | -2.664 | -2174 | 56.13 | 38,869 |
| 66 fix | 41 | HIGH PERFORMANCE EFFORT / SPEED / AUTO FIT | -2.958 | -1937 | 55.22 | 38,899 |
| 60 ctrl | 41 | recipe | -1.905 | -281 | 53.85 | 38,596 |
| 60 fix | 41 | recipe | -1.942 | -581 | 53.74 | 38,637 |
| 60 fix | 38 | recipe | **-1.422** | -162 | 55.29 | 38,613 |
| 60 fix | 40 | recipe | -1.539 | -138 | 54.93 | 38,661 (HDMI -0.266) |
| 60 fix | 41 | HIGH PERFORMANCE EFFORT / SPEED / AUTO FIT | -1.950 | -179 | 53.72 | 38,635 |

The CPU clock sits at 54-56 MHz however the tools are set; neither target
closes by seed or settings.  Older RTL (2026-10-24, before DDR3 VRAM and
16 KB caches) reached -0.729 at 60 MHz, so today's additions cost about
0.7-1.2 ns of CPU-clock slack.

## Where the paths are (`*_top100.txt`, 100 worst CPU-clock pairs)

No single cone: each fit's worst 100 spread over 4-6 families, and moving
one (0766b3f took the EX stall compare off the critical list) exposes the
next.  The recurring ones:

- **EX result -> next uop's operand** (`ex_u.cond` / `ex_ld` / `ex_b` ->
  ALU compares -> `fwe` (front write enable) -> `bcast` -> `dc1_a` /
  `dc1_a1` / `ag_a1q`): the same-cycle forwarding of an EX result into the
  operand latches two stages back; 60-80 of 100 at 66 MHz.
- **Register-file write select** (`be|rff|lvt`).
- **Front end**: `xw_ph` / DMU `m2.r.msz` -> microsequencer `c_emit` /
  `step` -> decoder `fire` / `consume` -> fetch-queue pointer add -> queue
  LUTRAM read -> predecode -> decoder attribute ROM address (60 MHz worst,
  -1.94 ns, 16 levels).
- DMU `m2.sfast` / `m2.x.pa`, the FPU's `a_e` / `fpsr`.

## Next

Each family needs a pipelining change that costs a cycle somewhere (a
forwarding bubble, a decode-to-fetch handshake one clock later), so each
change should be judged on CPU-clock slack and on the microbench / adapter
cycle counts together.  Order by share of the worst 100: the EX->operand
forwarding first, then the front-end consume chain.
