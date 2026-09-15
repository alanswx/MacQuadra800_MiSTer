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
