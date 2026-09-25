# P110 register/immediate MOVE store at operand start

Isolated candidate over P109, production frozen for the P109 FPGA build.
Candidate scratch/p110_move_store_start_20260921/ap040_core.v, SHA256
550ea0bb41b3fc24f6921e3f7f4e609f53980ddf9781c5e7a4b9f233c1ab7fd4.
Unapplied patch scripts/cpu/move_store_start.patch.

When ea_operand_start resolves a simple or resident d16 destination for
register/immediate MOVE, both the source and destination address are ready.
P110 issues the existing ordered store here instead of going through S_EXEC.
It uses the same captured register source or immediate and size-dependent
MOVE flags (preserve X, set N/Z, clear V/C). Early issue includes S_PIPE_START;
existing RAM, bus-idle, page-boundary and instruction-fetch ownership guards
still apply. Unresolved destination EAs retain their existing path.

Performance screening and integration are pending. The directed
move_register_restart.py tests data-register/immediate and same-An source
aliasing, destination modes 2/3/4/5, B/W/L where legal, flags, An updates,
write-protection fault frames, rollback and successful repair/RTE retry.
No results yet. No production change or hardware performance claim.

## Initial screen: small improvement, held for now

P109 -> P110 original fixture loop clocks:
- Whetstone: 29,048,277 -> 28,986,315 (0.2133% fewer).
- Dhrystone: 121,404,444 -> 121,254,444 (0.1236% fewer).

Root verified identical supporting identities and captured outputs for both;
Dhrystone also passes its independent derived end-state checker. Root inspected
all 64 directed MOVE store/repair cases for each core: all pass in three bus
phases. Includes data-register and immediate sources plus same-An source/base
aliasing, legal B/W/L sizes, modes 2/3/4/5, normal stores and MMU write faults.
Evidence: scratch/{whetstone_full_p110_20260921,dhrystone_full_p110_500m_20260921}
and move_register_restart directories under each candidate's scratch tree.

Extended integration remains in progress. No FPGA fit is scheduled for this
small gain; candidate stays isolated while instruction-dispatch and
memory-to-memory MOVE profiling looks for a larger opportunity. Production
remains P109. This screen does not qualify IRQ/trace boundaries, A7, split
writes, MMIO side effects, all source values, or timing closure.

Extended integration subsequently passed, including the existing load/store/PEA,
fault, trace, interrupt, replay and ownership gates. It remains an isolated
small-gain candidate; no FPGA build or promotion was requested.
