# Core address hints and per-space translation copy (2026-09-13, candidate)

Follows the accepted micro-TLB checkpoint (`CPU_UTLB_20260913.md`).
Candidate only until the hardware section is filled in.

## Why

After the cache-admission and micro-TLB changes a hit still costs 3 clocks
whenever the cache has not seen the index one clock before the request:
non-sequential instruction fetches (short branch targets, line crossings)
and every data read, because the core presents address and request in the
same cycle. The cache keeps only its last idle read, so the address must be
on the pins during exactly the cycle before the request issues.

## What changes

**`ap040_core.v`**: `mem_addr` and `mem_instr` become wires. While
`mem_req` is low they carry a hint; the registered copies
(`mem_addr_q`, `mem_instr_q`) are what every internal consumer reads, and
nothing downstream acts on `c_addr` without `c_req`. Hint priority:

| state | hint | mirrors |
|---|---|---|
| `S_MRD` before issue | `m_addr_r`, data | the non-pipelined `mrd` issue next cycle |
| `S_DECODE` of a short Bcc (not BSR, disp not 00/FF) | `pc + sxb(disp)`, instruction | `finish_bcc` this cycle |
| `S_PIPE_START` with a memory source | port A value, or minus the (An) adjust for -(An), data | the three `mrd` sites there |
| `S_PIPE_SRD`, or `S_PIPE_DEA` with `p_rmw` | `ea_addr`, data | the post-EA source read and the RMW destination read |
| otherwise | `epf_ftail`, instruction | the fill engine's next sequential fetch |

A wrong hint costs nothing: the cache trusts only its index/validity record
and a fresh tag compare. Cost: a 32-bit 5:1 mux, one 32-bit add (Bcc
target) and one subtract (-(An)) on the pins, no new state.

**`ap040_mmu.v`**: the ATC hit copy becomes two entries indexed by
`c_instr`, because a single entry thrashes between the code page and the
data page on every instruction that touches memory.

Candidate tree `/tmp/hint-cand.fRqM8B`: core SHA256 `3a8a60537e2a3856...`,
mmu `a132b7e34e02b34c...`, cache `77882b83...` (unchanged).

## Fixture results

Handoff latency fixture (`/tmp/hint-lat.k4Cere`, program unchanged):

| step | clocks | note |
|---|---:|---|
| accepted cache-early | 2,127 | |
| + micro-TLB (accepted) | 1,992 | fetches 3 -> 2 |
| + hints (fill/Bcc/S_MRD) | 1,950 | line-crossing fetches 2, non-pipelined data 2 |
| + per-space copy | 1,939 | translated data hits stop thrashing |
| + pipe-state hints, space bit fixed | **1,905** | every warm data hit 2 clocks |

Total -13 % against the pre-cache 2,188. The first pipe-state version drove
the space bit as "instruction" during data hints (found by tracing edges
778 to 800); the fix is one line. The fixture's snoop injection used to
trigger on the cache entering `C_LOOK` for a data read, which no longer
happens; the local copy now injects at the admission edge (the collision
that matters for this design), passes, and reports 1,924 clocks with the
forced-miss refill included. AP suite: 11 of 11 on the corrected core.

Pending: full-machine boot A/B, corpus gate, Sieve sweep (TC off, gains
expected this time), matched fit, hardware.
