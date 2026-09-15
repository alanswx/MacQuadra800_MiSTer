# AP68040 pipelined execution engine: rewrite plan and hand-off (2026-09-15)

This document is self-contained on purpose: it is written so that an
engineer or another LLM session with no memory of this project can pick
the work up.  It states the goal, the machine as it is today, what must
not change, the design of the new engine, the order of work, every gate
a change has to pass, and the rules this project learned the hard way.
Paths are relative to the parent repository
`/home/alans/mister/MacQuadra800_MiSTer` unless absolute.

## 1. Goal and where we stand

The core is the AP68040, a synthesizable MC68040 (integer unit, MMU,
FPU, caches) driving a Macintosh Quadra 800 on the MiSTer FPGA
(DE10-Nano, Cyclone V 5CSEBA6, 41,910 ALMs).  The bus clock is the
authentic 33 MHz; main memory is 128 MB SDRAM behind a 99 MHz controller
with a 33/99 MHz beat bridge.  The benchmark is Speedometer 4.02's CPU
Mix on Mac OS 8.1 (1.0 = a Quadra 605; higher is faster), measured on
the real board by a scripted agent, three valid runs per bitstream.

| milestone | CPU Mix | notes |
|---|---:|---|
| source as found (2026-09-09) | 0.4635 | |
| checkpoint 14 (2026-09-15) | 0.830 | 16 KB caches, line-crossing reads, control-flow folds |
| checkpoint 15 (2026-09-15) | **0.855** | decode-record handover, `docs/CPU_DECODE_OVERLAP_PLAN_20260915.md` |
| one-clock data hit (simulated, not yet fitted) | 0.861 sim (about 0.88 hw) | `docs/CPU_FAST_READ_20260914.md` |
| user's near bar | > 1.0 | |
| user's target | about 1.9 | 4x the source |

The simulated Speedometer bracket of checkpoint 15 is 1,043.6 M clocks
for 217.0 M instruction dispatches: **4.8 clocks per instruction**.  A
CPU Mix of 1.9 at this clock needs about 2.2 clocks per instruction on
the same mix.  The remaining incremental levers on the present machine
(a sequencer) sum to perhaps 1.0 to 1.1; everything beyond that needs
overlapped fetch, decode, address generation, operand read, execute and
writeback, i.e. a pipeline, which is what this plan is for.

Where the clocks go at checkpoint 15 (Speedometer bracket, per state of
the sequencer):

| bucket | clocks | share | entries | per entry |
|---|---:|---:|---:|---:|
| data reads (`S_MRD`) | 311 M | 29.8 % | 68.5 M | 4.55 |
| stores (`S_MWR`) | 125 M | 12.0 % | 38.3 M | 3.28 |
| register capture/retire (`S_PIPE_REGS`) | 101 M | 9.7 % | 48.1 M | 2.10 |
| decode (`S_DECODE`) | 87 M | 8.3 % | 81.1 M | 1.07 |
| operand pipe start (`S_PIPE_START`) | 74 M | 7.1 % | 74.4 M | 1.00 |
| demand fetch (`S_FETCH`) | 71 M | 6.8 % | 25.6 M | 2.78 |
| execute (`S_EXEC`) | 34 M | 3.3 % | 34.5 M | 1.00 |
| immediate/extension fetch (`S_IMMF`) | 33 M | 3.2 % | 31.3 M | 1.06 |

Inside the data reads (probe on checkpoint 14, similar today): three
quarters are two-clock cache hits, about 16 M are three-clock lookups,
about 47 M clocks are line fills, about 50 M are reads waiting behind
posted stores, 3.8 M line-crossing reads were 10.5 clocks each before
checkpoint 14 served them from the cache.  The archived profiles are in
`scratch/profiles_20260915/*.tsv` (state, clocks, entries per row).

## 2. Repository, tools, gates

### 2.1 Layout

- Parent repo (MiSTer core): branch `profile-speedometer402-20260909`.
  `rtl/quadra800.sv` (machine), `rtl/wombat_cpu.sv` (CPU + MMU + cache +
  store buffer wrapper), `rtl/wombat_bus32.sv`, `rtl/wombat_store_buffer.sv`
  (two-entry ordered RAM write queue), `rtl/sdram.sv`, `rtl/sdram_beat32.sv`.
- Submodule `rtl/ap68040` (remote `alanswx/AP68040`, branch
  `cpu-regalu-capture-retire-20260909`, checkpoint 15 = commit
  `167c5e8`).  Files: `rtl/ap040_core.v` (8,486 lines, the sequencer, 197
  states), `rtl/ap040_cache.v` (1,176), `rtl/ap040_mmu.v` (782),
  `rtl/ap040_alu.v` (379), `rtl/ap040_fpu.v` (2,247), `rtl/ap040_muldiv.v`
  (150), `rtl/ap040_regfile.v` (111), `rtl/ap040_tg68k_compat.v` (472, the
  wrapper used by the CPU-only benches), `rtl/ap040_defs.svh`,
  `rtl/primitives/dpram.v`, `tb/` (benches, `run_tests.sh`).
- Docs: `docs/CPU_*.md` (one note per change, all dated), the running
  task list `CPU_PERFORMANCE_TASKS.md` (checkpoints 1 to 15 with their
  numbers), `docs/PERFORMANCE_MEASUREMENTS.md`, `docs/AGENT_TESTING_WORKFLOW.md`
  (the hardware procedure), `CLAUDE.md` and `BUILD.md` (build and board
  rules).  Generators for the decode record: `scripts/cpu/*.py`.
- Build recipe for CPU work: `configs/cpu_development.tcl` (untracked
  working copy) = the release recipe plus `CDROM_OFF`, `VIDEO_512_OFF`,
  `MISTER_DISABLE_YC`, `MISTER_DISABLE_MT32PI`, `MISTER_DISABLE_SHADOWMASK`,
  `MISTER_BYPASS_AUDIO_FILTER`, `MISTER_DISABLE_AUDIO_OUT`,
  `MISTER_DISABLE_VIDEO_CALC` (`docs/CPU_AREA_DIET_20260915.md`).  The
  diet base fits at 38,482 ALMs (91.8 %); checkpoint 15 at 38,663.

### 2.2 Tools on the build box (Linux)

Quartus 17.0.2 Lite at `/home/alans/intelFPGA_lite/quartus/bin`;
Verilator 5.050 at `/home/alans/verilator5/bin/verilator`; iverilog on
PATH; vasm at `/tmp/wombat-vasm/vasmm68k_mot`; Python 3 (`PATH=/home/alans/anaconda3/bin`
for the corpus gate).  Every long job runs as a transient systemd user
unit (`systemd-run --user --quiet --collect --unit=NAME -p WorkingDirectory=DIR /bin/bash -c '...'`)
so that a tool timeout never kills it; kill processes by pid or by
`/proc/PID/cwd`, never `pkill -f` on a binary name (one such line killed
every simulator on the box each time a run finished, 2026-09-14).

### 2.3 The gates, in order, for every candidate RTL

1. **AP suite**: `cd rtl/ap68040 && VASM=/tmp/wombat-vasm/vasmm68k_mot sh tb/run_tests.sh`
   (11 benches: integer, exceptions, mmu, cache, cache_snoop, fpu, ...);
   "AP68040: ALL TESTS PASSED".
2. **Corpus gate** (single-step test corpus, 100 rows, every register and
   memory field compared, plus total cycles):
   `PATH=/home/alans/anaconda3/bin:$PATH bash scripts/cpu_corpus100_gate.sh <rtl dir> /tmp/wombat-cpu-post-upstream-20260909/SingleStepTests/preboot/sim040/build/cpu.hex /tmp/cpu-corpus100-gate.KKiaVA/results.bin`;
   expect "REAL diffs: 0" and note "CORPUS DONE in N cycles" (checkpoint
   15: 33,335,739).
3. **Latency fixture** (`/tmp/line-lat2.ek7Xsz`: `tb_latency.sv`,
   `program.s`, `run.py`; copy them with the candidate's `rtl/` into a
   fresh dir and `python3 run.py`): "LATENCY_GUEST_PASS cycles=N"
   (checkpoint 15: 1,938; one-clock hit: 1,902).
4. **Sieve sweep** (`scripts/fixtures/wombat_sieve/run.sh` from the tree
   named in `/tmp/line-repo.path`, offsets 0 6 16 30): cycle counts per
   offset, `array=PASS guards=PASS`.
5. **Boot A/B** (full-machine Verilator sim, `verilator/`): 420 M CPU
   clocks of the Mac OS 8.1 boot with the Speedometer disk image; report
   opcode dispatches and the per-state profile (`--cpu-profile`).  The
   launcher pattern is `scratchpad/launch_dovm.sh`-style: copy
   `/tmp/simboot-stack4.UXzM7a` (a built tree), drop in the candidate's
   RTL, `make -j6 V=/home/alans/verilator5/bin/verilator`, run
   `./mq800sim --headless --no-cpu-trace --disk ./run.hda +rom=./rom.hex --control ./control.txt --cpu-profile ./profile.tsv --max-cycles 900000000`
   with `scratchpad/boot_control.txt` ("profile start / wait 420000000 /
   profile stop / shot").  The boot bracket is ROM-heavy; it ranks
   candidates well but under-states benchmark gains.
6. **Simulated Speedometer** (`scratchpad/mq_driver2.sh`, about 2.5 h):
   drives the guest through Speedometer's CPU Mix and screenshots the
   result window; read the Average from the PNG.  This is the number
   that predicts hardware (checkpoint 15: 0.839 sim, 0.855 hw).
7. **Fit**: `bash scripts/build_only.sh --no-wait` in a copy of the
   diet build tree (`/tmp/diet-build-s22.path`) with the candidate's RTL
   and a chosen `SEED`; timing must be met on every clock (the summary
   in `output_files/MacQuadra800.sta.summary`).  At 92 % utilisation
   routing closes on roughly one seed in four; walk six seeds in
   parallel (about 4 GB and 40 to 60 minutes each; a fitter silent for
   more than an hour is stuck, stop it).
8. **Hardware**: three valid Speedometer runs through the lifecycle
   guard (`scripts/cpu_benchmark_core.sh`), by the test agent, following
   `docs/AGENT_TESTING_WORKFLOW.md`; negative or impossible times mark a
   run invalid (a known SDRAM-handoff anomaly, about 1 run in 6) and are
   never averaged.  Placement noise between bitstreams of identical
   logic is about 0.5 %.
9. **Never deploy a bitstream whose exact RTL has not booted in the
   full-machine simulation.**  Commit after each hardware-confirmed
   gain (submodule first, then the parent with the pointer), push both.

## 3. The machine today (what the pipeline replaces)

### 3.1 Interfaces that stay

`ap040_core` ports (see the module header): `clk`, `nreset`, `ce`; the
memory request bus `mem_req`, `mem_write`, `mem_instr`, `mem_size[1:0]`,
`mem_addr[31:0]`, `mem_wdata[31:0]`, `mem_fc[2:0]`, `mem_ack`,
`mem_rdata[31:0]`, `mem_flt` (access error pulse from the MMU); the hint
bus of the fast-read candidate `mem_hint_addr[31:0]`, `mem_hint_instr`
(the next access one cycle early, the held request while a translation
walks); the instruction line offer `mem_line_stb`, `mem_line_tag[31:4]`,
`mem_line_data[127:0]` (the cache offers a whole 16-byte line to the
fetch queue as a level); MMU register outputs `tc_out`, `urp_out`,
`srp_out`, `itt0_out`..`dtt1_out`; the PTEST/PFLUSH/CINV request
handshakes (`pt_*`, `pf_*`, `cinv_*`); interrupts `ipl[2:0]`,
`ipl_autovector`, `berr`; `nmi_ack_toggle`, `nresetout`, `cacr_out`,
`vbr_out`; the debug status words.  The core talks to the MMU
(`ap040_mmu.v`: ATC with a two-entry hit copy, a lookup pipe, the table
walker, transparent translation registers) which talks to the cache
(`ap040_cache.v`: 16 KB I + 16 KB D, 4-way, 16-byte lines, `SETW`
parameter, idle reads set up by the hint, registered acknowledge, line
crossing reads, posted stores with `m_posted`) which talks to the
store buffer and the bus adapters.  The wrapper is `rtl/wombat_cpu.sv`
(and `ap040_tg68k_compat.v` for the CPU-only benches).  One memory port:
an instruction fetch and a data access never issue in the same cycle.

### 3.2 How the sequencer executes an instruction

- **Fetch queue** `epf_*`: 8 words, ring; filled by fetch acknowledges
  (1 or 2 words), by the cache's line offer (up to 8 words), by the
  branch refill buffer seed, and word-wise by the exception prefetch.
  `issue_ifetch(a, s)` arms the stream; `epf_ready_pc` = the head word
  is resident at `pc` in the right space; `epf_fwd_pc` = an
  acknowledge this cycle at exactly `pc` bypasses the ring.  `S_FETCH`
  waits for residency (a demand fetch: 3 cycles from the redirect edge to
  the target's first decode on a hinted hit, 4 through a lookup).
- **Branch refill buffer** `brf_*`: one 32-byte sector with per-word
  valid bits, written by a redirect's own fetches and line offers,
  invalidated by any flush or a CPU write into it.  A taken DBcc or
  short Bcc whose target is in the sector dispatches its first word in
  the redirect cycle (`decode_dbcc_brf`); everything else (BRA, BSR, JSR,
  JMP, RTS, exceptions, targets outside the sector) pays the demand
  fetch.  A redirect issued from inside an acknowledge cycle is deferred
  to the fill engine and must not seed the sector (rule learned).
- **Decode**: `fetch_next` (the retire task, inlined at 83 sites) pops
  the head into `ir` and enters `S_DECODE`, whose 1,000-line body sets
  the operand descriptors `p_src`, `p_dst`, `p_dreg`, `p_sreg`, sizes,
  `alu_op`, `exec_kind`, the EA mode registers, consumes immediates and
  extension words (`immf`, inline when resident), and starts special
  states.  Since checkpoint 15 the same body exists as a **combinational
  decode record** over the queue head (`n_*` fields with valid flags,
  `n_next` = pipe entry, `n_inplace` = needs the special state), generated
  by `scripts/cpu/gen_decode_record.py`, proven equal to the body by a
  differential check over the boot and the whole Speedometer bracket,
  and applied at every retire from the single lookahead arm after the
  state case (`scripts/cpu/handover_single_site.py`; inlining it in the
  83 `fetch_next` sites cost 8,400 ALMs).  A smaller register-class
  descriptor (`rd_*`, `dispatch_reg_decode`) predates it and still
  handles register ALU, MOVE reg, MOVEQ, `#imm,Dn`, register shifts and
  short Bcc at the producer's retire.  The record's rules: a value taken
  from the condition codes is stale at a producer's retire (MOVE from
  SR/CCR decode in place); the pipe start must read the forwarded base
  register (`rf_capture_a`) when a write lands; the descriptor classes
  keep the producer bound because the decode cycle after a read or
  store retire is the fetch engine's and the store drain's slot in the
  ROM-heavy boot (in the benchmark bracket it is worth +0.3 %).
- **Operand pipe**: `S_PIPE_START` (register port selects `rr_a`/`rr_b`,
  direct reads for (An)/(An)+/-(An)/d16(An) sources, EA start),
  `S_PIPE_SRD`/`S_PIPE_SDONE` (source read), `S_PIPE_DST`/`S_PIPE_DEA`/
  `S_PIPE_DDONE` (destination), `S_PIPE_REGS` (capture from the
  forwarded ports, ALU, retire), `S_EXEC`, `S_MRD`/`S_MWR` (the memory
  transaction states, with the address hint driven a cycle ahead so the
  cache's idle read makes the hit a two-clock read; a hinted settled data
  read acknowledges in the request cycle in the one-clock candidate).
- **Retire**: the register write (`rfw`), flags, `fetch_next` with the
  interrupt/trace sampling at the boundary; the lookahead arm then
  dispatches the next instruction from the descriptor or the record when
  it covers it.
- **Exceptions and restart**: the MC68040 access-error model with
  restart; the core keeps undo records (`u0_v`/`u1_v`, `u_rec`) for the
  register side effects of the instruction in flight so a fault can
  restore the pre-instruction state; frames of formats 0/1/2/3/4/7 are
  built by the `S_EXC*` states and validated by the corpus (frame
  contents field by field).  Trace (`tr_t1`/`tr_t0`, `t0_force` for the
  T0 "change of flow" cases) and interrupts are sampled in `fetch_next`;
  an interrupt at the boundary wins over a simultaneous trace (WinUAE
  ordering, visible through nested address errors).
- **Special states**: MOVEM, MOVEP, MOVE16, CAS/CAS2, bit fields, RTE,
  RTD/RTR, LINK/UNLK, MOVEC, MOVES, CINV, PFLUSH, PTEST, STOP, RESET,
  TRAPcc, CHK/CHK2, the MUL/DIV long forms (`ap040_muldiv`, multi-cycle),
  the FPU (`ap040_fpu`, its own sequencer, `S_F*` states, FPU frames and
  the FSAVE/FRESTORE formats), the double-fault halt.
- **Stores**: posted through the cache's `m_posted` to the two-entry
  store buffer; reads wait behind pending stores (about 50 M clocks in
  the bracket); a naive read-around-store bypass starved the drain and
  lost (`docs/CPU_SB4_20260915.md`).
- **Self-modifying code**: a store hitting the fetch queue or the refill
  sector flushes them (`epf_flush`, the flush wins over a pop in the same
  cycle); CINV/PFLUSH/MOVEC flush too.

### 3.3 Timing and area facts

- The design's worst path is hint-to-acknowledge: `rr_a` -> register
  file -> hint adder -> `mem_addr` mux -> MMU hit-copy compare and
  physical address mux -> cache tag compare -> acknowledge -> core next
  state (30.8 ns of a 30.3 ns period in one build).  Every in-place
  issue site is a source on the `mem_addr_q` mux; four of them cost
  1.2 ns.  A combinational data acknowledge on the shared bus failed by
  6.6 ns; the dedicated hint bus moves the arithmetic off the request
  path.  The fetch queue's ring write failed by 7 ns once; instruction
  acknowledges stay registered.
- Area: core 25.6 K ALMs (FPU 4.6 K, ALU 1.7 K, MMU 0.9 K, regfile
  0.46 K, muldiv 0.42 K; the state machine and its operand muxes are
  the rest, about 18 K), cache 1.3 K, the Mac I/O block 3.1 K, the HDMI
  scaler 1.8 K (needed: the hardware runs read its framebuffer), the
  rest of the framework 2.3 K.  479 of 553 M10K.  The device is at 92 %;
  the fitter inserts about 0.8 to 1 us of hold-fix delay inside the
  33 MHz domain on every build (clock-network skew), and routing then
  closes on about one seed in four; fitter effort multipliers do not
  help, area synthesis saves 180 ALMs and does not help.
- Verilator is lenient where Quartus is not (out-of-range bit selects);
  run a synthesis check before trusting new RTL.

## 4. What the new engine must preserve

1. Every port of `ap040_core`, so the MMU, cache, store buffer, wrapper,
   benches and the full-machine simulator are untouched, and the
   hint-bus ports if the one-clock hit has landed by then.
2. The MC68040 programming model as the corpus checks it: every
   register, the SR/CCR, the exception frames field by field (including
   the format 7 access-error frame with its writeback fields), the
   restart semantics after an access error in the middle of an
   instruction, trace and interrupt priorities at instruction
   boundaries, the T0 flow-change cases, the double-fault halt.
3. The memory model as the caches see it: one port; instruction fetches
   and data accesses never in the same cycle; posted stores in order;
   a store to a fetched line flushes the fetch side; CINV/PFLUSH
   semantics; supervisor/user function codes per access; page-crossing
   accesses split into bytes (the core does it, so both halves arrive
   translated).
4. The FPU and MUL/DIV units as they are (they can hold the pipeline).
5. The gates of section 2.3 with their existing pass lines, and the
   corpus's cycle count as the first regression signal.

## 5. The new engine

### 5.1 Stages

```
IF  : fetch queue (as today) + branch target cache + return stack -> up to 2 words/clock to ID
ID  : decode record (generated) + register read (2 ports) + forwarding select + immediates
EA  : address generation (base + displacement/index, post-increment/pre-decrement) + D-cache request
RD  : operand arrives (one-clock hit on the hinted idle read; misses/bypasses stall here only)
EX  : ALU / shifter / flags; MUL/DIV and FPU hold this stage; stores issue here with data
WB  : register write, flag commit, retire point for exceptions and interrupts
```

Six stage boundaries, each a register; a 30 ns budget per stage is
generous next to today's 30.8 ns single-cycle hint-to-acknowledge path,
but the RD stage must not re-create it: the D-cache request in EA uses
the hint bus (address one cycle early) and the acknowledge in RD is the
fast-hit form already written for the one-clock candidate.

### 5.2 Per-stage detail

- **IF**: keep `epf_*`, `issue_ifetch`, the line offer and the refill
  sector.  Add a branch target cache (8 to 16 entries, `pc -> target`,
  tagged by `pc[31:1]`, written when a branch retires taken) consulted
  on the head word's `pc` in IF so a predicted-taken branch redirects
  fetch before decode; add a 4-entry return address stack pushed at
  BSR/JSR retire and popped at RTS decode.  Both are predictions:
  verify in EX (Bcc from the flags, RTS from the popped `m_val`,
  JSR/JMP from the EA) and on a mispredict flush IF..EX and redirect
  through the existing `go_pc` path, which keeps the trace/interrupt
  ordering exactly as today.  Predictions are dropped by any
  `epf_flush`, exception or CINV.  The fetch engine keeps the port rules
  (no issue in an acknowledge cycle unless it carries `epf_pend_seed`;
  a deferred issue does not seed the sector).
- **ID**: the generated record (`n_*`) becomes the ID stage's output
  register set, one record per clock while the head is resident and the
  words it needs are (the record already reports `n_immn`, the
  immediate/extension word count; `NX_NONE` with `n_inplace` marks a
  special instruction).  Register file: two read ports (today's ports
  A/B with `rf_capture_a/b` forwarding) plus a forwarding network from
  EX and WB (the value being written this cycle and the one written
  last cycle); the base register for EA is read here.  Extension words
  of the full EA modes (d8(An,Xn), the 68020 memory-indirect forms) are
  consumed by ID over one or two extra clocks as `S_EA_EXTW*` do today.
- **EA**: base + displacement (sign-extended) + scaled index; (An)+ and
  -(An) update An in EA with the write carried to WB (and an undo
  record until WB, see 5.5); the D-cache request goes out on the hint
  bus in EA and as the registered request in RD.  Page-crossing
  accesses are split here (two requests) as today.
- **RD**: the acknowledge and data; a miss, a fill, a bypass
  (non-cacheable, serialised), a read behind a pending store, or an
  MMU walk stalls RD (and everything behind it); EX and WB keep
  draining.  Read-modify-write instructions read here and write in EX.
- **EX**: `ap040_alu` (unchanged: `alu_op`, sizes, `alu_fl` flags),
  the shifter (register shifts retire in one clock today), MUL/DIV and
  the FPU as multi-cycle holds of EX; stores present address (from EA)
  and data (from EX) to the cache in EX and are posted (the cache's
  `m_posted`) so EX does not wait; a store that cannot post stalls EX.
  Branch resolution and the BTC/RAS check live here.
- **WB**: register file write (one port, or two if the (An)+ update
  and the result land together; today's file has one write port, so
  either add a second or let EA's An update use the write port a cycle
  early when no result writes), flag commit, and the retire point:
  exceptions raised in RD/EX are taken when the instruction reaches WB
  with everything older retired; interrupts and trace are sampled at
  WB boundaries exactly as `fetch_next` samples them now.

### 5.3 Hazards

- Register RAW: forwarding from EX (result) and WB (write data) into
  ID's operand latches and EA's base; the load-use case (a value
  arriving in RD) stalls the dependent instruction in ID one clock.
- Flags: `sr[4:0]` written in WB, read by Bcc/Scc/DBcc/ADDX-family in
  EX: forward the EX-stage flags; `MOVE from SR/CCR` reads the committed
  SR (stall until WB drains, as the record already decodes them in
  place).
- Memory ordering: stores post in order through the store buffer; a
  read to a line with a pending store waits as today (the rule that
  cost 50 M clocks; a safe read-around needs an address compare against
  both buffer entries and must not starve the drain: give the drain
  priority when the buffer is full).
- Structural: one memory port shared by IF and EA/RD; today's priority
  (a data access is known to be coming while an EA is being computed;
  speculative fetches stay off the port then) carries over as the EA
  stage's `ea_state` signal.
- A7 bank switches (SR writes, RTE, STOP, exception entry) and MOVEC
  writes to CACR/VBR/URP/SRP/TC/TTRs drain the pipeline first (the
  `sys_retire` list in the record work is the list of such states).

### 5.4 The side engine for the special instructions

MOVEM, MOVEP, MOVE16, CAS/CAS2, the bit-field group, RTE/RTD/RTR,
LINK/UNLK (already folded to few states), MOVEC, MOVES, CINV, PFLUSH,
PTEST, STOP, RESET, TRAPcc, CHK/CHK2, BKPT, ILLEGAL/A-line/F-line,
exception entry itself, and the FPU's own operand sequencing keep the
present state-machine code, moved behind an interface: when ID sees a
record with `n_inplace`, it drains the pipeline (older instructions
reach WB), hands the instruction to the side engine, which owns the
memory port and the register file until it calls the equivalent of
`fetch_next`, and resumes pipelined issue.  This is the cheapest way to
keep the corpus green: those instructions are rare in the benchmark
(MOVEM is the exception, 12 M clocks, worth pipelining later) and their
exact frame and restart behaviour is the hardest thing to reproduce.

### 5.5 Exceptions, restart and the undo model

Keep the restart model: an access error on an operand access reports
the pre-instruction state, with the MC68040 writeback fields (WB1/WB2/WB3
in the format 7 frame) describing what remains.  In the pipeline the
undo records become per-instruction entries carried with the
instruction from EA to WB (the (An)+/-(An) update, the destination
register capture): a fault in RD/EX marks the entry; when it reaches WB
the entry is unwound and the frame built by the existing `S_EXC*` code
(the side engine).  Younger instructions in the pipeline are discarded
(their register writes never reached WB) and their fetches flushed.
Bus errors on instruction fetch (`epf_err`) are delivered at decode of
the faulting word as today.  Trace: an instruction with T1 set at its
start takes the trace exception at its WB; T0 (change of flow) uses the
same `t0_force`/`flow_t0_pend` classification, computed in ID.
Interrupts: sampled at WB; the interrupt wins over a simultaneous trace
(the existing rule).

### 5.6 Caches, MMU, hints

The D-cache request in EA uses the hint bus of the fast-read candidate
(`mem_hint_addr` = the EA result, one cycle before the registered
request; the cache's idle read indexes by it; the MMU's hit copy
translates it and vouches with `m_hint_match`); the acknowledge in RD is
the one-clock fast hit when the hint held, the registered two-clock hit
otherwise, and the lookup/fill/bypass paths otherwise.  Instruction
fetches keep their registered acknowledge and the line offer.  The MMU's
walker is unchanged; a walk stalls RD.  PFLUSH/CINV/MOVEC to the MMU
registers go through the side engine after a drain.

## 6. Order of work, checkpoints, gates

Each numbered item ends on hardware (three valid runs) and a commit
(submodule, then parent) before the next starts.  Items 1 to 3 are on
the present sequencer and are worth doing in any case; item 4 is the
rewrite.

1. **One-clock data hit on the hint bus** (`docs/CPU_FAST_READ_20260914.md`,
   candidate `/tmp/dovm-cand.*` / `/tmp/dovq-cand.*`): RTL done, all
   simulation gates green, sim CPU Mix 0.861 (+2.6 %); blocked on
   routing (0 of 13 seeds at 38.65 to 38.87 K ALMs, 2026-09-15).  Needs
   either more seeds or area (see section 7).  Fold in the step C2
   descriptor bound (+0.3 %, `dovn`).
2. **Branch target cache and return stack on the sequencer** (about 40
   to 70 M of the bracket's 71 M demand-fetch clocks are after taken
   branches, RTS, JSR): the redirect states already hold the target
   (`br_tgt`, `m_val`, `ea_addr`, `rd_bcc_t`); the cheapest first step
   is to drive the hint bus from them so those redirects take the
   3-cycle hinted path instead of 4.  The BTC proper then issues
   `issue_ifetch(target)` at the lookahead site one cycle before
   `finish_bcc`/`S_BSR_PUSH`; the earlier `go_pc` expansion at that site
   cost 700 ALMs, so the BTC must supply the target as a registered
   value.  The RAS is only useful once RTS can dispatch speculatively,
   which is item 4.
3. **Reads behind pending stores**: an address-compared read-around with
   drain priority (the naive version lost).
4. **The pipelined engine**: a new branch of the submodule.  Order
   inside it: (a) the ID stage from the generated record with a
   lockstep bench: run the new core and the sequencer core side by side
   in the CPU-only harness on the corpus programs and compare every
   retired register write and memory access in order (the corpus's own
   comparison, plus the cycle count); (b) EA/RD/EX/WB for the record
   classes with the side engine handling every `n_inplace` record, so
   the corpus stays green from the first build; (c) forwarding and the
   load-use stall; (d) the BTC/RAS; (e) posted stores in EX; (f) MOVEM
   pipelined; then the full gates (boot, Speedometer sim, fit walk,
   hardware).  Budget: the engine must fit in the 18 K ALMs the state
   machine's dispatch logic uses today, and every stage boundary is a
   register so the 30 ns period is comfortable except on the RD path.

## 7. Rules learned (read before changing anything)

- Fit results are a lottery at 92 %: compare candidates by simulation,
  walk six seeds in parallel, never conclude from one failed seed; a
  ±0.5 % hardware difference between bitstreams of identical logic is
  placement noise (the SDRAM 33/99 MHz handoff is the likely place).
- `general[0]` of the core PLL is the 33 MHz CPU clock, `general[1]` the
  99 MHz RAM clock; the HDMI PLL is the third domain that fails when
  placement is bad.
- Any expression on the hint-to-acknowledge path costs directly; anything
  that adds a source to the `mem_addr_q` mux costs about 0.3 ns each.
- Inlined tasks multiply logic: a task called from many states is one
  copy per site unless the call sits in a single arm keyed on a shared
  flag (`rd_queue_pop`).
- The boot bracket rewards keeping a decode cycle after read/store
  retires (fetch and drain slots); the benchmark bracket does not.
  Decide on the Speedometer sim, not the boot.
- The fitter shares logic the RTL duplicates; removing a duplicate body
  may recover nothing.  Measure area by fitting, not by counting lines.
- The register-class descriptor's opcodes were removed from the decode
  body when it was introduced (submodule 9ecf647); the record cannot
  decode them without it.
- The full-machine harness reads `machine.cpu.mem_instr` from the
  wrapper; if a change turns that wire into a plain alias Verilator
  removes it, patch the harness to read the core's registered flag.
- Board rules (CLAUDE.md): never deploy or reset while a guest is
  running; judge liveness by Main's write bytes and the menu-bar clock;
  always release the mouse button after a menu; hash disks only after a
  clean shutdown; negative-time Speedometer runs are invalid.
- Documentation is part of the work: a dated `docs/CPU_*.md` note per
  change with the design, every gate's number, what was withdrawn and
  why; the task list `CPU_PERFORMANCE_TASKS.md` gets the checkpoint
  entry with the hardware numbers; commit and push after each step.

## 8. Reference documents

- `docs/CPU_PIPELINE_PLAN_20260915.md` (the short form of section 5)
- `docs/CPU_DECODE_OVERLAP_PLAN_20260915.md` (the decode record: steps A
  to E, the withdrawn variants, the equivalence check, checkpoint 15)
- `docs/CPU_DECODE_HISTOGRAM2_20260915.md` (which opcodes pay decode,
  the bracket by state at checkpoint 14)
- `docs/CPU_FAST_READ_20260914.md` (the one-clock hit, the hint bus,
  the seed walk and the timing findings)
- `docs/CPU_XLINE_20260915.md`, `docs/CPU_CACHE16K_20260914.md`,
  `docs/CPU_CTRL_FLOW_20260914.md`, `docs/CPU_BRANCH_LOOKAHEAD_20260914.md`,
  `docs/CPU_SHIFT_RETIRE_20260914.md`, `docs/CPU_LINE_OFFER_20260914.md`,
  `docs/CPU_EA_INLINE_20260914.md`, `docs/CPU_IMM_DIRECT_20260914.md`,
  `docs/CPU_WRITE_PATH_20260914.md`, `docs/CPU_SB4_20260915.md`,
  `docs/CPU_BRF2_20260914.md`, `docs/CPU_AREA_DIET_20260915.md`
- `CPU_PERFORMANCE_TASKS.md` (checkpoints 1 to 15 and what comes next)
- `docs/AGENT_TESTING_WORKFLOW.md`, `CLAUDE.md`, `BUILD.md` (procedures)
