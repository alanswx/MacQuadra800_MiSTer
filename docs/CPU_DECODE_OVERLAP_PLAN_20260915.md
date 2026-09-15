# Decode overlap on the AP68040 sequencer: design plan (2026-09-15)

Goal: remove the serial `S_DECODE` cycle (130 M of the checkpoint 14
bracket's 972 M cycles, 13.4 %) and the part of `S_PIPE_START` that
only places ports and starts an EA (69 M, of which about half), for a
simulated 15 % and a hardware CPU Mix near 1.0.  Prerequisite: the area
diet (`CPU_AREA_DIET_20260915.md`), because the device is at 94 % and a
registered decoder costs logic.

## What the sequencer does today

Per instruction: queue pop (`fetch_next` pops the head into `ir` and
enters `S_DECODE` directly when the word is resident), `S_DECODE` (the
6,800-line case body sets the `p_*` operand descriptors, ALU op, EA
modes, consumes immediates and extension words, or starts a special
state), `S_PIPE_START` (register ports, direct reads, EA start),
`S_PIPE_REGS` / the read acknowledge (capture, ALU, retire).  The
lookahead descriptor (`rd_*`, an `always @*` over the queue head) already
decodes the covered classes (register ALU, MOVE reg, MOVEQ, `#imm,Dn`,
register shifts, Bcc.B) and `dispatch_reg_decode` enters `S_PIPE_REGS`
straight from a producer's retire cycle, skipping `S_DECODE` for 37 % of
dispatches.

## The change

1. **A decode stage.** The queue head is decoded every cycle by a
   combinational decoder derived from the `S_DECODE` body (the body is
   already a function of `ir`, `d_*` and the queue words; the decoder
   evaluates the same expressions on `rd_ir` = the head).  Its result is
   registered into a "next instruction" record `n_*` (the `p_*` fields,
   `alu_op`, `exec_kind`, `op_size`, `src/dst_mode_r`, `src/dst_rn_r`,
   consumed immediates, the class: pipe, special state, illegal) whenever
   the head is valid and no earlier decoded record is waiting.
2. **Retire hands over.** Every retire site (`fetch_next`, the ALU
   retire, the store retire, `S_LINK4`, the read acknowledges) enters the
   next instruction from `n_*` directly: pipe-class records go to
   `S_PIPE_START` (or `S_PIPE_REGS` when the ports were placeable, as the
   lookahead does now), special-class records to their state, and the
   queue pops the words the record consumed.  `S_DECODE` remains only for
   records the decoder marks "decode in place" (RTE, MOVEC, MOVES, CINV,
   PFLUSH, traps, illegal, FPU, MOVEM, the bit-field group) and for the
   first instruction after a redirect whose decode did not complete.
3. **Hazards.**  Register values: the pipe start reads the forwarded
   ports (`rf_capture_a/b`), and the base-only landing guard (rm3) lets
   the direct read and the hint proceed under a write to another
   register; a write to the base register defers one cycle.  Flags: the
   record carries no flags; Bcc keeps the lookahead's `rd_bcc_fl` path.
   Redirects: any `go_pc`, exception or queue flush invalidates `n_*`
   (the same edge that flushes the queue).  Trace and interrupts: the
   record is dropped when `fetch_next` takes the exception path.  Extension
   words: the record consumes them at decode as `immf`'s inline does; a
   record whose words are not resident waits (no record), which is the
   `S_IMMF` case today.
4. **Pipe start in the decode cycle.** For the d16(An), (An), (An)+ and
   -(An) sources and destinations the record includes the port selects,
   so the address hint goes out the cycle after decode and the direct
   read issues in `S_PIPE_START` as today, or, when the producer's retire
   cycle can place the ports, `S_PIPE_START` is skipped as the lookahead
   does.

## Gates and steps

- Step A: the decoder as a function over the head, checked against the
  `S_DECODE` body by a bench that decodes every opcode in both and
  compares the records (the corpus payload gives realistic streams).
- Step B: hand over at the ALU/store retire only (the lookahead's sites),
  all classes.  AP, corpus, Sieve, latency, boot A/B, Speedometer sim, fit
  walk, hardware.
- Step C: hand over at every retire site.
- Each step is a checkpoint commit when it measures on hardware.

Timing: the decoder's outputs are registered, so the decode logic leaves
the retire-to-dispatch path; the risk is the record's muxes into the
`p_*` registers (one more source each) and the queue pop width.  Area:
the decoder duplicates part of the `S_DECODE` body until that body is
reduced to the decode-in-place set (step C removes it), so steps A and B
need the diet's headroom.

## Step A, first result (2026-09-15)

`scripts/cpu/gen_decode_record.py` rewrites the `S_DECODE` body into a
combinational record over the queue head (`n_*` with per-field valid
flags, `n_next` naming the pipe entry: pipe start, pipe registers,
immediate then pipe start, immediate to register; `n_inplace` for
everything that starts a special state, raises an exception or calls any
other task).  1,106 generated lines, 25 fields.  Under `DECODE_CHECK`
the record computed in the decode cycle is compared with the registers
the body wrote.  Boot A/B with the check on: the machine boots
identically (75,840,887 dispatches, the record is unused), and the only
mismatches (92,335) were the port select of the immediate-to-register
class when the immediate was not yet resident, where the body defers the
select to a later state; the check now ignores that case.  Second
check run over the boot: **0 mismatches** in 75.8 M dispatches; the
Speedometer bracket check is running.

## Step B, first result (2026-09-15)

`scripts/cpu/apply_decode_record.py` adds `apply_record` (every record
field with its valid flag into the `p_*` group, then the pipe entry; the
immediate forms consume their words as the descriptor's immediate class
does) and a new arm of the lookahead block: at an ALU, shift or store
retire, when the head is not a descriptor class, the record is not
in-place and its words are resident, the record is applied instead of
entering `S_DECODE`.  First run: the AP integer and mmu tests and the
corpus (308 diffs) failed on the descriptor-covered register classes.  A
dispatch trace of the integer test showed the mechanism: an ADD applied
by the record was correct, but the MOVE from CCR applied at the ADD's
retire took `sr` before the ADD's flag write landed and read the old
flags.  Any record value taken from the condition codes or the status
register is stale at a producer's retire; the generator now decodes
those instructions in place (MOVE from SR, MOVE from CCR).  Gates
rerunning.

Second run (condition codes in place): the first failure moved from
test 3 to test 207.  A cycle trace: ADDA.L (A1)+,A1 applied at the retire
of MOVEA.L A0,A1 entered `S_PIPE_START` while the MOVEA's write to A1 was
landing, and the pipe start's source-memory path read port A unforwarded
(decode had always selected it a cycle earlier, so a landing write had
always landed).  The apply now defers to `S_DECODE` when the retiring
producer writes the record's base register (`n_base_hazard`, the
memory-source lookahead's own rule).  Third version: AP 11/11; corpus,
Sieve, latency, boot A/B, Speedometer sim and fits running.

Third version (base-register hazard deferred): AP 11/11, corpus
33,348,379 (checkpoint 14: 33,738,108, -1.2 %), latency 2,020, Sieve
identical, boot A/B 75,940,170 dispatches (+0.13 %; 4.1 M of the boot's
57.1 M decode entries removed, most of the saving absorbed by the fetch
and read states in that ROM-heavy bracket).  With rm3's base-only
landing guard on top (`/tmp/dovc-cand.*`): AP 11/11, corpus
33,345,713, latency **1,967**, boot A/B **76,100,398** (+0.34 %).
Speedometer sims and fits on the diet base running for both.

## Step C, first result (2026-09-15)

`scripts/cpu/handover_decode_record.py`: the record is applied inside
`fetch_next`'s pop branch, so every retire site (83 calls in about 40
states) hands the next opcode over when the record covers it; the
producer-side base-register guard goes away because the pipe start's
(An), (An)+ and -(An) source paths now take the base from the forwarded
port (`rf_capture_a`), which is correct under a landing write from any
retire.  AP suite 11/11; corpus, Sieve, latency, boot A/B, Speedometer
sim and fits on the diet base running (`/tmp/dovd-cand.*`).

Step C results: corpus 33,335,739 (0 REAL diffs), latency **1,942**,
Sieve identical, boot A/B **76,218,560** (+0.5 % over checkpoint 14).
The boot's decode entries fall only 57.1 M -> 52.1 M: the descriptor
classes (register ALU, MOVE reg, ADDQ, MOVEQ, register shifts) still
take the decode cycle after every non-producer retire, since
`dispatch_reg_decode` was bounded to the ALU/shift/store producers.
Step C2 (`/tmp/dove-cand.*`) dispatches them from `fetch_next` at every
ordinary retire as well, with both handovers guarded against retires
from the system states (SR, USP, MOVEC, MOVES, CINV, PFLUSH, RTE, STOP,
exception sequences), which can change the A7 bank or an auxiliary
register on that edge.

Step C2 (`/tmp/dove-cand.*`): AP 11/11, latency 1,938, corpus
33,335,739 (identical to step C: the corpus retires almost nothing from
a non-producer into a descriptor class), Sieve identical; boot A/B and
Speedometer sim running.

## Step D: the decode cycle consumes the record (2026-09-15)

The fits of steps B and C fail routing more often than the diet base
(seed 20: 38,981 ALMs against 38,482; dovc seed 23: 38,730): the record
block duplicates the part of the `S_DECODE` body it covers.  Step D
removes the duplicate.  `rd_ir` already selects `ir` in `S_DECODE`, so
the record describes the instruction being decoded there, and the
equivalence check proved it equal to the body for every record-class
opcode.  `scratchpad/step_d.py` (to become
`scripts/cpu/reduce_decode_body.py`) parses the body into its
if/case/begin tree and removes each record-field assignment and each
pipe-entry call (`pipe_go`, `pipe_go_regpair`, `pipe_go_regdst`,
`immf(n, S_PIPE_START)`, `immf_reg`) that lies on no execution path
containing an in-place statement; the in-place paths keep everything.
`S_DECODE` then ends with `if (!n_inplace) apply_record_decode`, which
writes the record fields (after the body, so its values win over the
statements kept for shared prefixes, and the body's own `rr_a` default
stays underneath) and takes the pipe entry through the body's own
`immf`/`immf_reg` inline paths, so the queue ownership rules and the
deferred `S_IMMF` case are unchanged.  378 statements removed, 179 kept
on in-place paths; the body's comments are lost in the regenerated text
(the history keeps them).  Cycle behaviour is unchanged by construction;
the gates check it (`/tmp/dovf-cand.*`).

Step D first results: AP 11/11, latency 1,938, corpus 33,335,739 with 0
real diffs (both identical to step C2, as the construction requires).
Scripts committed as `scripts/cpu/handover_descriptor_all_retires.py`
(step C2) and `scripts/cpu/reduce_decode_body.py` (step D); Sieve, boot
A/B, Speedometer sim and diet-base fits at seeds 20 and 22 running.

## Step C3: one handover site (2026-09-15)

The step C fits answered the routing question: 46,876 / 46,850 ALMs at
seeds 20 / 22 against the diet base's 38,482, over the device.
`fetch_next` is inlined at its 83 call sites, and `apply_record` inside
it became 83 copies of the 25-field record mux into the `p_*`
registers.  Step C3 (`scripts/cpu/handover_single_site.py`, on top of
step D) takes the handover out of `fetch_next` and puts it in the one
lookahead arm after the state case, keyed on `rd_queue_pop`, which only
`fetch_next`'s pop branch sets, so every retire site is still covered
from a single mux: `if (rd_valid && (S_DECODE || rd_queue_pop &&
n_desc_ok)) dispatch_reg_decode; else if (rd_queue_pop && n_apply_ok)
apply_record;`.  AP 11/11, latency 1,938, corpus 33,335,739 with 0 real
diffs (cycle-identical to C2 and D, as it must be); boot A/B,
Speedometer sim and diet-base fits at seeds 20, 21, 22 running
(`/tmp/dovg-cand.*`).

Boot A/B: step C2 (dove) 76,043,525 dispatches in the bracket against
step C's 76,218,560, with fewer decode entries (51.7 M against 52.1 M):
the descriptor dispatch at every retire and the system-state guard on
both handovers were introduced together, and one of them costs more
than the other gains in this ROM-heavy bracket.  Step D (dovf) boots
cycle-identically to C2 (76,043,525, every state count equal), as
required; its Speedometer sim was stopped as redundant.  `dovh` (C3
with the guard removed from the record apply only, the step C
semantics for records) separates the two: AP 11/11, boot running.

Step C3 (dovg) boots cycle-identically to C2 and D (76,043,525).  dovh
(the guard off the record apply) differs from C2 by four records: the
system-state guard is irrelevant; the boot loss is the descriptor
dispatch at every retire.  Against step C the boot profile shows the
rm3 pattern: `S_DECODE` -582 K cycles, `S_FETCH` +401 K, `S_MWR`
+249 K, `S_PIPE_START` -148 K.  The decode cycle after a read or store
retire was the fetch engine's slot and the store drain's slot in this
ROM-heavy bracket.  Whether that holds in the Speedometer bracket
(I-cache resident, RAM stores) is what the dovd (step C) and dove (C2)
Speedometer sims decide; `dovi` (the C3/D structure with step C's
producer-bounded descriptor dispatch) is prepared for either outcome:
AP, corpus and boot running.

dovi: AP 11/11, corpus 33,335,739 with 0 real diffs, boot A/B
76,218,560 dispatches with every state count equal to step C's: the
C3/D structure reproduces step C exactly when the descriptor dispatch
keeps step C's producer bound.  Two exact candidates now exist for the
Speedometer decision: dovi (step C semantics) and dovg (step C2
semantics); the dovd and dove Speedometer sims stand for them, and
diet-base fits of both are running (dovg seeds 20, 21, 22; dovi seeds
20, 22).  The redundant sims (dovf, dovg, dovh, dovi Speedometer; dovb)
were stopped.

## Step D's area, and step E (2026-09-15)

The step C3 fit at seed 21 needed **38,902 ALMs** (diet base 38,482,
step B 38,981) and failed routing: the body reduction recovered
nothing measurable, so the fitter had already shared the record's
expressions with the body's, and the remaining 420 ALMs are the
record's own: its 25 fields as one more source into each `p_*`
register, the immediate mux, the handover arm.  Per entity the core's
own combinational ALUTs are +412 (27,649 against 27,237), registers
equal.

Step E (`scripts/cpu/retire_descriptor.py`) removes the older
register-class descriptor (`rd_valid`, `dispatch_reg_decode`, one more
source into every `p_*` register plus its own field logic), which the
record subsumes: the record block's `if (rd_valid) begin end` guards
are opened so the record decodes those classes from the body's original
leaves, and the single handover arm applies the record alone.  Two
bounds: `c` keeps step C's semantics (the former descriptor classes
hand over at ALU/shift/store producers only, `dovj`), `c2` hands every
record over at every retire (`dovk`).  Their boots should reproduce
dovi's 76,218,560 and dovg's 76,043,525 exactly if the record equals
the descriptor for those classes; a DECODE_CHECK boot on the step C2
core with both guards opened and the descriptor disabled (`dovchk2`)
compares the record with the body's own decode of them.  AP, corpus,
boots and a seed 22 fit of dovj running.

Step E withdrawn: the corpus of both variants hung at `B1C9` (CMPA.L
A1,A0).  The body's register-form leaves were removed when the
descriptor was introduced (submodule commit 9ecf647, "Compact shared
CPU decode"), so opening the guards makes the record decode those
opcodes through the memory-form branches.  Re-creating the leaves from
the descriptor's own fields would merge two mux sources into one and
save little; re-creating them from the pre-9ecf647 body would give
back the logic the descriptor compacted.  The record stays at about
+420 ALMs over the diet base, and the candidates go through a seed
walk instead: dovg (C2 semantics) seeds 20, 22, 23 and dovi (C
semantics) seeds 20, 21, 22 running.
