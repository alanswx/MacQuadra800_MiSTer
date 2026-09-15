# A pipelined execution engine for the AP68040: plan (2026-09-15)

Target: Speedometer 4.02 CPU Mix 1.9 at the 33 MHz bus clock, which is
about 2.2 clocks per dispatch on that mix (checkpoint 14: 4.9).  The
sequencer with every incremental lever taken lands near 1.3
(`CPU_DECODE_HISTOGRAM2_20260915.md`); the rest is only reachable by
overlapping fetch, decode, address generation, the operand read, execute
and writeback every cycle, as the MC68040 does.

## What is kept

The MMU (ATC, hit copies, walker), the caches (16 KB, line offers,
crossing reads), the store buffer, the bus adapters, the FPU and the
multiplier/divider, the exception model (restart on access error, the
frame formats validated by the corpus), and every gate: the AP suite,
the corpus, the boot A/B, the simulated Speedometer, the hardware run.

## Stages

1. **IF**: the fetch queue and refill buffer as today, delivering up to
   two words per cycle to decode; a small branch target cache (8 to 16
   entries of `pc -> target`) redirects fetch at decode time for taken
   Bcc/BRA/DBcc/JSR/RTS (RTS through a 4-entry return stack), replacing
   the 63 M demand-fetch cycles.
2. **ID**: the combinational decoder from the decode-overlap work
   (`CPU_DECODE_OVERLAP_PLAN_20260915.md`), producing one record per
   cycle with register selects, ALU op, EA mode, immediates, and the
   class.  Register file with two read ports plus forwarding from EX and
   WB.
3. **EA / read**: address generation (base + displacement/index) and the
   data-cache request in the same cycle for the simple modes; the cache
   answers a hit the next cycle (the one-clock hit of
   `CPU_FAST_READ_20260914.md`, now on a dedicated hint bus with its own
   MMU copy).  Misses and bypasses stall this stage only.
4. **EX**: the ALU, shifter, flags; multi-cycle units (MUL/DIV, FPU)
   hold the stage; stores issue here with the data and are posted.
5. **WB**: register write, flag commit, the retire point for exceptions
   and interrupts (the restart model needs the pre-instruction state:
   the WB stage keeps the undo records per instruction instead of the
   `u_rec` slots).

Instructions the sequencer handles as special states (MOVEM, RTE,
exceptions, MOVEC, CINV, bit fields, CAS, MOVE16, MOVEP) run in a
"microcoded" side engine that takes over the pipeline for their
duration, which keeps the corpus behaviour without pipelining them.

## Budget

Area: the current core is 25.6 K ALMs including the 4.6 K FPU; the
pipeline must fit the same envelope, which it can because the 6,800-line
state machine (about 18 K ALMs) is what it replaces.  Timing: every
stage boundary is a register; the 30 ns budget per stage is generous
next to today's hint-to-acknowledge path (30.8 ns in one cycle).

## Order of work

1. Area diet and decode overlap on the sequencer (steps A to C of the
   overlap plan): the decoder and the hazard rules are the ID stage's.
2. The branch target cache and return stack on the sequencer (measurable
   alone, about 40 M cycles).
3. The one-clock data hit on a dedicated hint bus (measurable alone).
4. A new branch of the submodule with the five-stage engine, the side
   engine for the special instructions, and the same gates; the corpus
   first (it compares every register and memory field), then the boot,
   then Speedometer.

Each step lands on hardware before the next starts; each is its own
checkpoint.  Steps 1 to 3 are weeks; step 4 is months.

The self-contained hand-off version of this plan, written for an
engineer or LLM session without this project's context (the machine as
it is, the interfaces to keep, the stages, hazards, exceptions, the
gates and their commands, the order of work and the rules learned), is
`docs/CPU_PIPELINE_REWRITE_HANDOFF_20260915.md`.
