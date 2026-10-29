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

## After 4600eb2 (2026-10-27/28)

The same method, one family at a time: read the worst path's cells
(`report_timing -detail full_path`), find the late select or decision in
it, and move it off the path -- register it, select by an earlier signal
whose don't-care cases are provably unused, or let the consumer choose.
Every change below passes the 235 CPU self-test runs (cycle counts
compared with the run before), the dual random test (`run_dualrand.sh 1
120`: ALL SAME, 25,463,374 dual / 27,199,242 single cycles), and the
adapter benches (42,468 / 32,200); where a sim check is named it compares
the new form with the old one every cycle it is used.  On 2026-10-28 the
self-tests were also run in the Quadra's own configuration
(`DEFS="+define+AP_FPU_PIPE=0 +define+AP_LOOP_PRED=0 +define+AP_EARLY_RES=0
+define+AP_S1C=3'b011"`): all pass.

| commit | change | cycles |
|---|---|---|
| 7272f34 | EX's broadcast to younger operands without EX's advance (uops that always write) | same |
| 0267673 | an index that is AG's own second update loaded a clock later | t_ag2x |
| 654684d, 4d17b36 | odd branch / JSR fault address and frame PC registered, chosen at WB | same |
| 5b26005, 90188da | DC1's and the engine's tag compares in parallel with the ATC ways | same |
| 7535daa | the companion's BTB-flag test from pd0.tot | same |
| 8564ef0 | AG's register port 2 address registered | same |
| 4dfc462, c3ddd0a | EX's written value takes the ALU result at its last multiplexer | same |
| c58d3db | WB's fault address formed apart from EX's exception vector | same |
| 54f5425 | FCMP's compares registered the clock before F_WB (t_fcmp added) | same |
| aedb567, 02ab4b4, 718ffda | the split lookup's valid read; an FPU frame PC at WB; a known JSR target by the fast decode; DBcc's write | same |
| 05c737f, 3b36c20 | fpif's result and FMOVEM's slot bit from latched words | same |
| 3b64b62 | AG's incoming index scaled from the register read on its own | same |
| dd96e1d | a dynamic FMOVEM list's adjustment registered | t_fpu +1 |
| 2d413bf | a slow op's shifter result at xs's last multiplexer | same |
| 8c15840 | FMUL by a power of two taken in F_MULT's first cycle | t_fpu +2, t_fpexc +3 |
| efef115 | the FP condition's predicate latched with the command words | same |
| d64792f | the table walk's valid/dirty update addresses its set whatever the dirty bit | same |
| d1af381 | fpif's hold decodes from the latched words, not through CHK's select | same |
| 1aa367a | the second slot's operand A loaded every clock AG does not stall | same |
| 2e1eaaf | the second slot's broadcast without EX's advance | same |
| df6e7ec | the lookup RAMs' and the ATC's set chosen by DC1's hold, not AG's advance | same |
| 2f0bd7d | FRESTORE's frame size registered | FRESTORE +1 clock |
| d1fe42c | a store's FPU register selects set while CHK is in EX | same |
| ec78081 | a refetched record's routine substituted by the sequencer | same |
| cb9d5cf | AG's base/index read addresses registered a cycle ahead | same |
| 8fbc515 | front-file port 1 selected without EX's advance | same |
| 5988c36 | the CPU's skid register at 60 MHz (the Quadra built SKID(0)) | -0.06 %; 2x bench 31,993 |

CPU-clock setup slack, worst / TNS (ns), by batch:

| batch | commit | 42 | 45 | 47 | 49 | 50 | 51 | 52 |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 60k2 | 8564ef0 | -1.057 | **-0.828** | | | | | |
| 60p | 05c737f | -1.561 | -1.043 | -0.876 | **-0.571 / -5.9** | -1.052 | | |
| 60q | 3b64b62 | -1.446 | -1.233 | -1.387 | -1.667 | -1.292 | -1.314 | **-0.852** |
| 60r | 2d413bf | -1.424 | -1.189 | -1.714 | **-0.902** | -1.159 | -2.030 | -1.283 |
| 60s | 8fbc515 | -2.052 | -2.954 | -1.853 | -2.537 | | | **-1.469** (53: -1.818) |
| 60t | 5988c36 (skid) | -2.126 | | | -1.973 | | | **-1.402** |
| 60u | a614639 | -0.836 / -37 | -0.989 | -1.445 | -1.952 | | | **-0.730 / -18.4** (53: -1.331) |
| 60v | 78f5a58 | **-0.907 / -20.8** | -1.274 | -1.457 | -1.519 | | | -1.045 / -12.8 (53: -1.077) |
| 60w | ffe40c3 | -1.159 | -0.919 | -1.504 | **-0.844 / -16.4** | | | -1.593 |
| 60x | 21dfcdd | -0.742 / -6.7 | -0.769 | -1.163 | -1.069 | | | **-0.636 / -8.5** (53: -0.712, 54: -1.736, 55: -1.380) |
| 60y | 77a6df6 | -0.991 / -24.3 | -1.918 | -1.435 | -1.284 | | | -0.989 / -24.9 (53: -1.835, **54: -0.910 / -12.8**, 55: -1.942) |

(slack / TNS in ns on the 60 MHz CPU clock.)  60y (HDMI met on six of
eight seeds) came out behind 60x: its leading families were the line-state
port's read address chosen by the tag compare (53f4f5e), FADD's sign test
into a_m (c548747) and EX's ALU result into AG's address (f539800).
60x is the best batch so
far: five of eight seeds within -0.8 ns, and its best seed (52) has the
HDMI domain met (+0.211; 60u s52 +0.274, 60w s49 +0.406).

(05c737f seed 46: -1.564.)  The best seed of each batch sits near -0.6 to
-0.9 ns while the worst families change from seed to seed: no one family
dominates, which is why the work goes family by family.  Removing the
Ethernet block (ETHERNET_OFF) gained nothing (-1.23 / -1.34), so area is
not the lever; the user's rule since 2026-10-27 is to keep every feature.

The 60s/60t batches came out worse than 60r (TNS -200 to -590 against
-22 to -400).  Their worst families were paths that were there before
and that these fits placed badly -- FSUB's zero test after the
subtraction (fpu.b_m -> the state and acc_hi, -2.5 to -2.95, the worst
of two seeds), FADD's significand-compare swap, and WB's store answer
into the stall chain (wb_u.op / dmu.m4 -> dc1_a1, fv, rff.lvt, md.*,
the exception entry's registers) -- so the next commits went after those:

| commit | change | cycles |
|---|---|---|
| 80d5f7b | EX's operand-is-load-data flags registered with the uop | same |
| a92e75f | the posted VRAM store's answer without the maintenance-op term | same |
| f31ee4d | WB's store-answer record conditions registered as WB's record loads | same |
| 0fdb063 | a suppressible EX write broadcast once EX's own work is done | same |
| 436b4d3 | FSUB's exact cancellation by the operands' equality | same |
| 8c85eae | AG's port-2 address loaded on every clock AG does not stall | same |
| 7d08b7b | the multiply/divide unit's kill off its data registers | same |
| c138308 | the front-valid bits clear the clock after the kill | same |
| a614639 | the exception routine's operands follow the entry values outside their sequence | same |
| 6d0ec93 | FADD/FSUB swap by the exponents alone (t_farith) | same |
| 33b6ede | FDIV by a power of two / equal significands in F_DIVL's first cycle | +1 clock for those |
| 3b51af0, fedd2be | the FPU's shared shifter selected by P2's valid; a register's NaN flag kept with it | same |
| 6a3ff58 | a PC-relative branch's displacement chosen by the routine alone | same |
| 680cc7c | FRESTORE's format check registered with its size | same |
| 8ea715b | DC2's fast-load store hazard registered from the record pairs | same |
| deeae7d | the right shifter's sticky formed beside the shift | same |
| 5ae0ed4 | the normalizer's output at a_m after the FSM's case | same |
| ffe40c3 | DC1's operands loaded as held-or-new by DC1's stall | same |
| 1f5c4c4 | the decoder's displacement-size tests as parallel compares | same |
| 3b753d3, 023a188 | AG's base and index loaded every clock AG does not stall; the index's register read at agx_q's last multiplexer | same |
| 92479ce | FPIAR's value loaded every clock, written only with f_iawe | same |
| 21dfcdd | MOVEM's list-against-the-EA tests as record flags from D1 | same |
| e4c07e1 | F_UNFL's sticky and zero tests registered | an underflow +1 clock |
| 77a6df6 | MOVEM's direction from the operation word, not the ROM's d | same |
| 4416d8d | an EA's AG base and index from the record, selected by the memory EA last | same |
| 3df4e9f | FSUB's sign fold from a flag loaded with r_op | same |
| 327e4b8 | the fetch ring head's next value as a three-bit add | same |
| 941a2d4 | x_go and kill_now selected by WB's advance last | same |
| 6b8d34e | the upd2 merge's base test per EA; MOVEM's index-is-base off areg | same |
| 78d4fa1 | line-state copies (MLABs) at f_set and e_va's set for the engine's decisions | same |
| 53f4f5e | the valid/dirty port's set in the CINV scan and the write hit whatever the compare | same |
| c548747 | an add of two infinities decides on their signs from a register (F_IINF; t_fpu 675-683) | inf +/- inf +1 clock |
| f539800 | the ALU's result as an AND-OR of classes registered with EX's uop | same |
| 0b145bd | the return stack moves on a call or return whatever its exception | same |
| a217510 | the FPU's result enters EX's written value next to last | same |
| b3e011a | a memory bit field's written head from B and the masks' bytes | same |
| 120103a | the FPU interface's fuse and EAL flags registered with EX's uop | same |

From 5988c36 on the self-tests also run in the 60 MHz build's own CPU
configuration -- the Quadra's parameters plus the skid
(`DEFS="+define+AP_FPU_PIPE=0 +define+AP_LOOP_PRED=0 +define+AP_EARLY_RES=0
+define+AP_S1C=3'b011 +define+AP_SKID=1"`) -- beside the default one;
both pass at every commit above.
