# 60/30/90 MHz timing work, 2026-10-27

Branch `pipelined-040-ddr3-fast60`.  Each change keeps the CPU
cycle-identical or close to it (the 225 CPU self-test runs; the quadra
adapter benches 42,468 / 32,200 cycles at 1x / 2x unchanged).  Fits:
misterubuntu, the qsf recipe, `CLK_60_30_90`; `scratch/hw/fit.sh` (an
archive of the commit per scratch tree), `scripts/cpu/timequest_families.tcl`
and `path_families.py` for the per-family worst slack.

| commit | change | cycles |
|---|---|---|
| c8a9fed | D1's record FIFO three deep: room is a register, off the sequencer's pop | -0.08 % |
| 2844ae6 | attribute ROM read as words enter the queue; the head's attributes in a register beside qp0 | same |
| 178a519 | DC2's store-hazard byte masks formed in DC1; AG's operands forwarded without EX's exception decision | same |
| 32e1350 | the companion word consumed without waiting for the record's exception | t_early -2..4 % |
| 05eccdd | a slow DC2 job scheduled without waiting for the kill (started killed) | +3..20 cycles in t_mmu/t_atcprobe |
| 771c43c | front file written, EX's operands forwarded, without EX's exception decision | same |
| 740169a | the D-cache engine's lookups compare tags in parallel with the translation (as DC1) | same |
| e91f3df | D1's fire from go \|\| go_part before the exception turns a part into a record | same |

CPU-clock setup slack (60 MHz, general[2]):

| fit | seed 38 | seed 40 | seed 41 | seed 42 |
|---|---:|---:|---:|---:|
| before (0766b3f, `../clock66_20261027`) | -1.422 | -1.539 | -1.942 | |
| c8a9fed | -2.406 | | | |
| 2844ae6 | **-0.986** (TNS -71) | | -2.212 | |
| 178a519 | -1.509 | | | |
| 05eccdd | -1.264 | -1.681 | -1.245 | -1.766 |
| 771c43c | -1.572 | | -2.018 | -1.606 |
| 740169a | -1.254 (TNS -90) | | -1.121 (TNS -93; HDMI -0.18) | -1.475 |

The seed spread (about 1 ns) is as large as any one change, so changes are
judged on three or four seeds.  The worst families move every fit; after
740169a they are, roughly in order: the FPU's internal datapath (a_m ->
a_e, a_m -> dout), EX result forwarding into DC1/DC2's second-slot
operands (ex_u.op/cond -> dc1_a1, dc2_a1), the fetch queue loop (qw, qf,
cnt -> qp0, qb, qw), AG's index path (upd2_reg / uq0.idx -> agx_q: a
register-file read, an adder and the scale in one clock), and the FPU
control registers into EX's hold (fpsr & fpcr -> wb_ok -> stall chain).
That last one cannot simply be registered: the exception bits change in
the clock the FPU's WB state begins (a simulation probe saw it in every
FPU test).

At 66/33/99 the same RTL fits at -2.96 / -3.76 ns (seed 41): not near.
