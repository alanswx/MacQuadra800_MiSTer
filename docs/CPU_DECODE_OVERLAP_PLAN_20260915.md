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
