# AP68040 area: hoisting the multi-site tasks out of the state case (2026-09-15)

Alan's checkpoint 15 (`167c5e8`) is the fastest CPU we have (Speedometer
4.02 CPU Mix 0.855 on his trimmed profile against 0.4635 for the 164a376
era), but in the full-feature MacQuadra800 it synthesizes to 64,723 ALUTs
(an estimated 41,919 ALMs on a 41,910-ALM device), 2,196 ALUTs more than
the store head we gated on 2026-09-12.  This note records how the core was
brought back under the device without removing anything, as pure RTL
restructuring: same instruction behaviour, same cycle counts.

## The mechanism

`ap040_core.v` is one 8,500-line `always @(posedge clk)` block with a
197-state `case (state)`.  Its helper tasks are inlined by the synthesizer
at every call site.  A task such as `fetch_next` (the retire boundary:
interrupt/trace sampling, the pop into decode, the demand fetch through
`issue_ifetch`) writes some sixty registers and is called from eighty arms,
so each of those registers gets an eighty-way enable tree, plus one copy
per site of whatever combinational work the body does (the refill-buffer
seed compare, the queue-head mux, `t0_special`).  Quartus does not fold
those trees; Alan had measured the same effect the other way round (the
record handover inlined at 83 sites cost 8,400 ALMs).

The cure is the pattern Alan already used for `rd_queue_pop`: the call
site only raises a blocking *carrier* (and loads the task's arguments into
carrier registers); one arm after the case statement performs the body
once, keyed on the carrier.  Nonblocking semantics make this exact as long
as no arm writes one of the body's registers *after* the call on the same
execution path (the inlined body would have been overridden there; the
hoisted body overrides instead), and as long as the blocking carriers the
body sets (`epf_pop`, `epf_issue`, `epf_flushed`, `rd_queue_pop`,
`brf_seed_*`) are consumed only by code that runs after the hoisted arm
(the lookahead arm, the seed-data block, the fill engine, the queue
bookkeeping).

`scripts/cpu/audit_task_sites.py CORE.v TASK` walks every call site forward
through its block structure and lists such later writes; the simulation
gates (`scripts/cpu_gates_wsl.sh`: the AP suite, `bench_loop`, the
first-100 silicon corpus) are the arbiter.  Every step below is cycle
identical unless stated: `bench_loop` 94,368 / 95,166, corpus 33,335,739
cycles, 0 REAL diffs.

Order of the hoisted arms after `endcase`, which matters because some of
them feed each other:

```
mem_issue            (mrd/mwr)        -- sets mem_req, must precede exc_now's mem_req <= 0
immf_now             (immf)
fetch_next_body      (fetch_next)     -- sets rd_queue_pop for the lookahead arm
go_pc_now            (go_pc)          -- its trace/address-error cases feed exc_now
exc_now              (exc, go_illegal, go_priv, the FPU go_fp_*)
lookahead arm        (Alan's: descriptor / record / short-Bcc dispatch)
decode_dbcc_brf_now  (decode_dbcc_brf) -- the lookahead arm is its last caller
brf_seed_data, fill engine, queue bookkeeping (Alan's)
```

## Steps and their synthesis cost (full-feature MacQuadra800, Analysis & Synthesis)

| step | what | ALUTs total | core own | est. ALMs |
|---|---|---:|---:|---:|
| checkpoint 15 as merged | `167c5e8`, Alan's wiring | 64,723 | 26,701 | 41,919 |
| R1 `fetch_next` (80 sites) | `retire_req`, `fetch_next_body` | 60,199 | 22,564 | 38,754 |
| R2 `mrd`/`mwr` (80 sites) | `mgo_*`, `mem_issue` | 60,306 | 22,379 | 38,818 |
| R3 `exc` (39 direct + 90 through `go_illegal`/`go_priv`/`go_fp_*`) | `xgo_*`, `exc_now` | 59,165 | 21,369 | 38,222 |
| R4 `immf` (50 sites) | `igo_*`, `immf_now` | 58,786 | 20,921 | 37,951 |
| R5 `go_pc` (12 sites) | `pgo_*`, `go_pc_now` | 57,329 | 19,578 | 36,952 |
| R6 `decode_dbcc_brf` (7 sites) | `dgo_*`, `decode_dbcc_brf_now` | 56,595 | 18,679 | 36,504 |

Cumulative: -8,128 ALUTs (-12.6 %), the core's own logic 26,701 -> 18,679
(-30 %), an estimated 5,400 ALMs freed; the CPU hierarchy 40,819 -> 32,762
ALUTs.  The FPU (7,056), ALU (2,644), MMU (1,349) and cache (1,816) are
untouched.

For reference, the store head we ship today is 62,527 ALUTs / 41,116
fitted ALMs (98 %).

R2 is area-neutral (the core's own logic shrinks by 185 ALUTs, the
neighbours grow by as much) but removes the per-site early-issue copy of
the address and data mux onto `mem_addr_q`/`mem_wdata`, which is on the
hint-to-acknowledge path Alan measured as the design's worst; it is kept
for the fit's timing.

## What the audit found that was not a hoisting matter

- The sites that override the entry state right after an exception call
  (`S_FSCC1` and `S_FDBCC` delaying a BSUN/TRAPcc entry behind an FPSR
  write, the retire body's trace) keep the inline body (`exc_now`).
- Alan's reduced decode body (his `reduce_decode_body.py`, checkpoint 15)
  left `case (d_op8_6[1:0]) default: go_illegal; endcase` behind for the
  SBCD/PACK/UNPK register forms: every one of them raised an illegal
  instruction that the decode record's apply, running last in the arm,
  then overrode -- while the exception's queue flush still happened.  With
  the exception entry deferred, that override was gone and the integer
  self-test tripped on `SBCD`.  The artefact is removed (the record owns
  those forms), and `apply_record_decode` now cancels a pending body
  exception explicitly (`xgo = 0`), which states the invariant the code
  already relied on: the record wins over the reduced body.  That also
  drops the spurious flush on those instructions.

## Gates run on the result

(filled in as the steps land)
