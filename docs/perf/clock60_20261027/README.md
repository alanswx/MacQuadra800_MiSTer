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
| 60z | 78d4fa1 | -1.245 / -58.1 | -1.488 | -1.179 | **-0.425 / -10.9** | | | -1.531 (53: -1.174, 54: -1.683, 55: -0.992) |
| 61a | ebc9409 | -0.642 / -14.8 | -1.258 | -1.213 | -1.039 | | | -0.991 (53: -0.729 / -9.6, 54: -0.852, **55: -0.574 / -7.4**) |
| 61b | 91aaa48 | -1.879 / -82.6 | -0.720 / -5.7 | -1.228 | -1.457 | | | -0.282 / -0.54 (53: -1.505, 54: -1.161, **55: -0.131 / -0.25**) |
| 61c | 7ea5e47 | -1.182 / -7.9 | -1.713 | -1.320 | -0.849 | | | **-0.378 / -3.4** (53: -2.221, 54: -1.192 / -4.4, 55: -1.292) |
| 61d | ba9575d | -1.464 / -21.6 | -0.773 / -6.3 | -1.275 | -1.340 | | | -0.996 (53: -1.390, 54: -1.142, **55: -0.627 / -17.6**) |
| 61e | 362a75e - 6550325 | | | | | | | -0.831 / -7.7 (55: -0.895 / -6.6) |
| 61f | 794e0be | | | | | | | (seeds 56-63: **58: -0.399 / -0.40**, 57: -0.322 / -1.2, 56: -0.415 / -2.1, 62: -0.768, 60: -1.053, 61: -1.157, 63: -1.381, 59: -2.048) |
| 61g | 4541732 | | | | | | | (seeds 52 55-58 64-66: **64: -0.191 / -3.6**, 55: -0.620 / -33.1, 52: -0.766, 57: -0.838, 56: -1.158, 58: -1.239, 66: -1.474, 65: -1.646) |

(slack / TNS in ns on the 60 MHz CPU clock.)  60y (HDMI met on six of
eight seeds) came out behind 60x: its leading families were the line-state
port's read address chosen by the tag compare (53f4f5e), FADD's sign test
into a_m (c548747) and EX's ALU result into AG's address (f539800).
60z's seed 49 is the best single fit yet, -0.425 ns with the HDMI domain
met (+0.119); the batch's others sit at -1.0 to -1.7, led by the stall
cone from AG's interlock (cc6ebd5, d1ab8be, 81aac5f) and the line-state
port's address (53f4f5e, not in 60z).
61f (794e0be, eight new seeds) has three fits within half a nanosecond,
HDMI met on all three: seed 58 at -0.399 ns on a single endpoint family
(+0.111), seed 57 at -0.322 (+0.283) and seed 56 at -0.415 (+0.476);
HDMI missed on seeds 59 and 62.  Seed 58's one family was the bit field
tail's displacement select into AG's address adder and DC1's stale test
(ac7264e), seed 57's the FPU interface's decode and kill through EX's
hold into the integer forwarding enable (ae30b01), seed 56's WB's
maintenance decode through its hold and commit into the back file's
write select (4541732).  Seed 58 also missed hold on the general[0]
clock by -0.319 ns (one endpoint), the first hold miss in these
batches.  The FPU's FPSR/FPCR enabled-exception OR through the
interface's hold into AG (seed 62, 249 endpoints) stays: the FPSR's
exception byte is written on the clock the result reaches F_WB, so a
registered OR would be a clock late (probed in simulation).
61g (4541732: the fixes for 61f's three best seeds) came out behind
61f on the same seeds (56: -1.158, 57: -0.838, 58: -1.239) and missed
HDMI on five of eight; its best, seed 64 at -0.191 ns (HDMI -0.270),
leads with EX's memory flag into DC1's A and RSTO's busy flag through
WB's hold and the stall chain into the skid's load enable (f8df34e).
Seed 55's leaders were the queue head's extension word through D1's
length into the consume count (3eb1101, 374 endpoints), the bit test's
size compare into Z (c0beff0), AG's register-file read into DC1's B
(5fd21f7), the bit field extract kind (ac23b2c) and the microcode ROM
through the memory EA select into the index read address (c3ab2dc);
seed 52's the slow path's fault mask into the queued records' return
stack kind (38c780c) and the FPU's FPSR into the register file's bank
select.  These were fixed in that order.  The FPSR family is now
registered after all (f096729): not from the live registers, which are
written on the clock F_WB begins, but from their next values, through
which the state machine's 75 writes now go.
61d (ba9575d) has HDMI met on six of eight seeds again (39,651-39,753
ALMs, 95 %), its best -0.627 (seed 55); 61e is an A/B of HEAD without
the dual read ports (6550325 reverted, seeds 52 and 55): -0.831 / -0.895
against 61d's -0.996 / -0.627, and HDMI -0.17 / -0.26 against -0.08 /
+0.19 -- no evidence against the ports, which stay.  The leaders now
differ on every seed and none recurs: EX's other written value
(d70202f), D1's redirect target (794e0be), the snoop's freeze through
WB's store answer into DC1's hold and the ATC's set, the FPU's FPSR
through the interface's hold into AG's advance, and AG's index register
read through the bank select.
61c (7ea5e47: the 61a and 61b fixes, the dual read ports) came out
behind 61b, and its HDMI domain missed on seven of eight seeds (-0.005
to -0.43, against three in 61b): ALMs 40,091-40,116 of 41,910 (96 %).
Its leaders were new: EX's FPU-held broadcast into ex_as and the second
slot's operands (14bca8c, ba9575d), the divide's suppression decode
(2aaf84b), the engine's lookup way (ee83050), FMOVE.L's rounding
increment (bd624e9), and single paths of the engine's state into the
records' hit clears (m3.x.hit) and its line-state decisions (f_set).
61b (built at 91aaa48, before the 61a fixes) holds the two closest
fits so far, both with HDMI met: seed 55 at -0.131 ns, TNS -0.25
(+0.074), and seed 52 at -0.282, TNS -0.54 (+0.220).  Seed 55 failed
only on the companion's emit into AG's read address (cq_u.op ->
rra0_q, through a register the fitter retimed back across the pairing
test), which 6550325 shortens by the take's select; seed 52 on the ATC
hit into DC2's copy of the line (360d5c5).  The others lost to
the stall chain from WB's store answer and DC2's write wait into the
register file -- the reason for 6550325 and 7ea5e47.
61a is the tightest batch yet: four of eight seeds within -0.86 ns
(60z had one), the best seed 55 at -0.574 with HDMI met (+0.134; seed 42
+0.269).  Its leading families: the scan's port set still chosen by the
push decision (04d7a53), the slow unit's operand selects into the shifter
and CHK2's compare (a9d4fe9), DIVx.W's overflow test into the forwarding
enable (df4fb00), the store data's op decode (2015ae2), AG's load capture
(36b02f8), the ATC hit vector into DC1's hit (51f542a), F_NORM2's zero
test (5fb0a60) and the decoder's push into every record bit; the FSAVE
word select (fd00be9) was already gone after ebc9409.
60x was the best batch before 61a: five of eight seeds within -0.8 ns, and its best seed (52) has the
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
| 81aac5f | AG's registered read addresses select on AG's take last | same |
| cb75289 | an extended source's unsupported test registered with r_din | same |
| 6e8560b | the single/double store's denormal test on the biased exponent | same |
| 42e7468 | the store's overflow test selected by the rounding's carry (t_fpu 684-687) | same |
| 4fbb198 | CRR's write kill from the latched word's control-register slots | same |
| d1ab8be | front-file port 1's address and data for AG's second slot without AG's advance | same |
| 148834a | the companion's pairing tests from the uop before a pointer load replaces it | same |
| cc6ebd5 | AG's write interlock with its DC1/DC2 waits registered a clock ahead (t_await) | same |
| ebc9409 | a load handed to AG's index in one select of the aligned word (t_await 8, 9) | same |
| cf51675 | EX's divide-by-zero exception from md_z, not the divisor's zero test | same |
| 44ef7f1 | MOVEM's base/index-in-list tests as record flags from D1 | same |
| fd00be9 | FSAVE's frame words registered | FSAVE +1 clock per word (t_fpu +1.6 %) |
| 91aaa48 | ASR's sign ORed in after a logical shift | same |
| 04d7a53 | the CINV/CPUSH scan's port set before the push decision | same |
| df4fb00 | DIVx.W's 16-bit overflow registered with the quotient (t_integer 192-207) | same |
| a9d4fe9 | the slow unit's A and B operands registered as the uop enters EX | same |
| 2015ae2 | EX's store data selected by forms registered with the uop | same |
| 36b02f8 | AG's load capture at the base/index registers' last select (t_await 10-24) | same |
| 51f542a | DC1's hit with the ATC's hit vector at the last gate | same |
| 5fb0a60 | F_NORM2's zero test registered in F_NLZ (t_fpu 688-693) | same |
| 50e32fb | D1's record slots loaded by the pop and the count; push only counts | same |
| 3efc3d0 | the target words' hit and the target's increment per BTB slot | same |
| efe4846 | fpif's exception by each sub-operation's conditions, without the hold | same |
| 90cf62b | FMOVEM's register-read hold from the list at the dynamic slot | same |
| 5aa68f8 | E_S_XL2 registers the part's translation whatever the walk decision | same |
| ace5b33 | F0's next address with F1 there chosen by the I-cache tag compare last | same |
| 03b7e21 | the exception entry's pending flag a flip-flop of its own | same |
| d5a3a46 | the stack register SR selects as a flip-flop written with SR | same |
| 6550325 | with the skid, AG's base and index read at the next head's and the held uop's registers (two read ports more per file) | same |
| 7ea5e47 | DC2's wait for a RAM write to its set registered a clock ahead | same |
| 360d5c5 | DC2's copy of the line by a way encoded with the ATC's hits last (t_mmu 215-222, t_dualmmu 5) | same |
| 5f1c4fc | AG's run-time transfer cancel registered for the uop in AG | same |
| 2aaf84b | a divide's write suppression for EX's forwarding enable without the op decode | same |
| 14bca8c | the slow unit's registered A without the word sign extension | same |
| ee83050 | the engine's lookup hit and way with the ATC's hits last (t_dualmmu 6) | same |
| ba9575d | an FPU uop with a register result broadcasts from flip-flops | +1 clock per such uop: t_fcmp +5.2 % (+2.2 % at 60 MHz), t_fpu +0.5 % |
| bd624e9 | F_PACKI's rounding increment from an incrementer of its own | same |
| 0c5ad66 | the walk's dirty-descriptor push without a second f_set load (t_twdirty) | same |
| d70202f | EX's other written value by classes registered with the uop | same |
| 794e0be | D1's redirect target and the BTB entry's kind and target loaded every clock | same |
| f2415d4 | the FPU broadcast's flags cleared by EX's next uop, not by the kill and the advance | same |
| 44ba7e2 | the redirect address loaded every clock, the redirects' own loads taking precedence | same |
| ad54a8f | WB's store answer from a snoop-freeze flip-flop of its own | same |
| ac7264e | AG's bit field tail flag and bf_nb's 3 from flip-flops | same |
| ae30b01 | the forwarding enable's integer side without the FPU's hold and kill | same |
| 4541732 | WB's RESET and maintenance flags registered with the uop | same |
| ca7442b | DC2's store merges by byte picks registered from DC1's address | same |
| 7a33740 | the BTB write's index, tag and slot loaded every clock | same |
| 169b9e3 | the shift funnel's input by a form registered with the uop | same |
| 15a1ef9 | the second slot's A, held and taken, formed apart with the stall last | same |
| aacccd6 | the known-target JSR by the operation word and the EA kind (t_jsrk) | same |
| 521bc8f | the line-state update's read at WB's set from a copy of its own (one MLAB copy more) | same |
| 05a2a47 | F_PACKS's rounding stickies straight from the shift register | same |
| a282987 | FC_DISP's store result forms registered with the command words | same |
| 9b99d83 | FMOVEM's slot logic from the queue head, without exception mode's zeroing | same |
| f8df34e | the skid's uop loaded on every clock the skid is empty | same |
| 3eb1101 | each queued word's length as an extension word, formed as it enters (24 flip-flops) | same |
| 38c780c | a faulted record's return stack kind zeroed by the sequencer from dexc | same |
| c0beff0 | the bit test's Z from a bit select of each width, the size last (t_btst) | same |
| 5fd21f7 | AG's register-file read ports 3/4 addressed by their own copies | same |
| ac23b2c | the bit field extract kind registered with EX's uop | same |
| c3ab2dc | the memory operand's EA chosen flat from the microword's selectors | same |
| f096729 | the FPU's enabled exception test registered from FPSR and FPCR's next values (FPU differential bench: five seeds against the committed FPU) | same |

From 5988c36 on the self-tests also run in the 60 MHz build's own CPU
configuration -- the Quadra's parameters plus the skid
(`DEFS="+define+AP_FPU_PIPE=0 +define+AP_LOOP_PRED=0 +define+AP_EARLY_RES=0
+define+AP_S1C=3'b011 +define+AP_SKID=1"`) -- beside the default one;
both pass at every commit above.
