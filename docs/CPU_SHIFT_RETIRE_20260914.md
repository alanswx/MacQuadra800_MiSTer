# Register shifts retire in one cycle (2026-09-14, candidate)

Builds on checkpoint 10 (`CPU_BRANCH_LOOKAHEAD_20260914.md`) plus the
fast-flag ALU output of `/tmp/bl5-cand` (same behaviour as checkpoint
10, the branch lookahead is refused after producers whose flags are not
on the fast path). Core and ALU.

## Why

`ASL.L #2,D0` (E588) alone is 1.4 % of the Speedometer dispatches and
register shifts are 2.0 %; each ran decode, pipe start, register capture,
execute (`EK_SHIFT` setup), `S_SHIFT` (one ALU call that already
composes the whole count) and `S_SHIFT_WB`: six states for a shift.

## What

1. `S_PIPE_REGS` retires a register-destination shift with a nonzero
   count in place: the ALU sees the register on its `b` operand
   (`alu_dst` now also selects `rf_capture_b` for `shift_fire`) and the
   count on `shcnt` (the immediate in `src_val`, or `Dn` on port A), and
   the result and flags are written as `S_SHIFT`'s barrel path wrote
   them. A zero count keeps the `S_SHIFT` path for its special flags.
   Decode -> pipe start -> retire: three states instead of six.
2. The lookahead descriptor covers register shifts (`Exxx`, size not 11),
   immediate count as a quick source, register count on port A; the
   dispatch sets `exec_kind` (`EK_SHIFT`) and `sh_rox`. A retiring shift
   is also a producer for the descriptor dispatch (not for the branch
   lookahead: shift flags are not on the ALU's fast path).

## Results so far

AP suite 11/11 (the integer suite covers the shift flags); corpus
33,723,250 cycles, 0 REAL diffs; latency fixture 1,916; Sieve identical
to checkpoint 10 (no register shifts in its kernel). Boot A/B, simulated
Speedometer and fits (seeds 20, 21) running. Tree `/tmp/sa-cand.*`.

### Boot A/B: the full candidate crashes; localized to the descriptor class

The full candidate double-faults 724 M cycles into the boot. Halves: the
retire fold alone boots normally (75,247,767 dispatches, checkpoint 10's
frame); the descriptor class alone double-faults after 110 M cycles. An
instruction trace of the two halves diverges at a `beq` after
`and.b d5,d4 / ror.l #4,d5 / tst.b d4`, with identical instruction streams
before it, so a lookahead-dispatched rotate leaves a wrong value. A
register-annotated trace is running to name the instruction; the
register-capture fallback in `S_PIPE_REGS` has meanwhile been changed to
the forwarded ports (`/tmp/sa4-cand`), since a lookahead dispatch now
reaches it one cycle after its producer's write.

Note: the fast-flag variant's seed 22 fit failed by 12.6 ns through two
10-12 ns routing hops on ordinary nets (a routing collapse, not logic);
it wants another seed, not a change.

**Root cause (register-annotated traces from reset, first difference at
instruction 125):** `move.b ($1e00,A1),D2` then `lsl.w #8,D2`. The shift
is dispatched by lookahead in the move's retire cycle and reaches
`S_PIPE_REGS` one cycle later, while the move's write to D2 is still in
flight (`rf_we`); the fallback there captured `dst_val <= rf_rdata_b`,
the unforwarded port, and shifted the stale D2 (Z set instead of clear).
The full candidate hits the same stale capture on the zero-count
fallback (`move.l d2,d0 / lsl.l d4,d0` with d4 = 0). Fix (`/tmp/sa4-cand`):
the fallback captures through `rf_capture_a`/`rf_capture_b`, which
forward the write landing in that cycle; the ALU-retire and shift-retire
paths already did.

Boot A/B of the fixed candidate (`/tmp/sa4-cand`): 75,280,762 dispatches
(+0.2 % over checkpoint 10's 75,109,516), same frame, no faults. AP suite
11/11, corpus 33,723,250 cycles / 0 REAL diffs, latency fixture 1,916.
Fits (seeds 20, 21) and simulated Speedometer running.

### Fits of the fixed candidate

Seed 20 (`/tmp/MacQuadra800_sa4_v512s20.*`): 39,102 ALMs (93 %), setup
slack **-18.715 ns**, TNS -3,140 ns on clk_sys. The worst paths run
`rr_a[*]` / `state[5]` -> `mem_wdata[25]` with a single 25.4 ns hop into
the `mem_wdata[25]` register's enable: a routing collapse of the kind seen
on the fast-flag seed 22 fit, not a logic-depth problem (the same logic
closed at seed 20 in checkpoint 10 with 0.2 ns less ALU work). Seeds 21,
22 and 24 launched in parallel; the first that closes with all TNS zero is
the deployment candidate.

### Simulated Speedometer and fits

Simulated CPU Mix **0.762** (checkpoint 10 simulated 0.752, +1.3 %);
bracket 1,030,590,631 cycles against 1,036,898,471 (-0.6 %).  Seed 24:
timing failed only on the HDMI clock (-0.473 ns, one path, CPU clocks
met; 39,023 ALMs).  Seeds 21 and 22 were stopped after two hours in routing: the core's
fit was already proven inside the 16 KB cache build (seed 20, timing
met), and the hardware measurement comes from the stacked builds.  The candidates built
on this one (`CPU_CACHE16K_20260914.md`, `CPU_CTRL_FLOW_20260914.md`,
`CPU_BRF2_20260914.md`) carry it to hardware as a stack; the 16 KB cache
build (this core plus the caches) closed at seed 20.
