# P109 quick memory arithmetic at read acknowledgement

Isolated over P108b. Production unchanged during the active fit.
Candidate scratch/p109_quick_rmw_ack_20260921/ap040_core.v; unapplied
scripts/cpu/quick_rmw_read_ack.patch.

Dhrystone P106 spends39.52% of its measured cycles in CODE6's string
routine bucket. Its strcpy executes ADDQ.L #1,12(A6) for every byte copied.
P109 lets an ordinary successful ADDQ/SUBQ memory operand read feed the
shared ALU and prepare the existing ordered store immediately, skipping
DDONE/EXEC. The request still obeys mem_issue ownership and waits to issue
after the read response. Read errors and split reads retain existing paths.
The payload select uses registered state/operand fields, not acknowledgement.

This moves an ALU path onto the read response and may hurt timing. No timing,
performance, fault or correctness qualification yet. It must preserve store
fault CCR/rollback, IRQ/trace ordering, sizes, flags and MMIO accesses.

## Original workload screen

Candidate SHA256 b91c964d126464adbee9f0111dfcf4c1ae539ff011e806c69223991e23a1b76e,
with P105 pipeline 9b0e3e00e544e05c29c9b46611a1d2cad9f5aaba144b58d753d889ac22786dbc.
Against P108b, the original 50,000-iteration Dhrystone loop falls from
123,104,496 to 121,404,444 cycles (1.381% fewer). Root verified identical
fixture, ROM, latency, flags, non-core RTL and all five output captures.
The independent derived end-state checker also passes. Artifacts:
scratch/dhrystone_full_p109_500m_20260921.

Whetstone falls from 29,050,125 to 29,048,277 cycles (0.00636% fewer),
with identical captured stack/globals/code and supporting identities.
Comparison: scratch/p109_quick_rmw_ack_20260921/whetstone_compare.
This is principally a Dhrystone improvement; neither measurement predicts
an equivalent percentage gain in the complete hardware Benchmark Mix.

## Fault repair test

scripts/cpu/quick_rmw_restart.py exercises ADDQ/SUBQ #1, B/W/L, indirect,
postincrement, predecrement and d16 addressing. Invalid MMU pages induce
read faults; resident write-protected pages allow the read then fault the
store. It checks stacked CCR/PC/fault address, format-7 frame, address-register
rollback, unchanged data before retry, page repair/PFLUSHA/RTE, exactly one
exception and the final arithmetic result, flags and address update.
P109 passes all 48 cases in three bus phases each; root inspected the logs
under scratch/p109_quick_rmw_ack_20260921/quick_rmw_restart.
Baseline comparison and broader integration/corpus are still being checked.
This matrix does not cover A7, split operands, IRQ/trace or MMIO side effects.
No FPGA fit or hardware result exists for P109 yet. Production remains P108b.

## Promotion for FPGA evaluation

P108b baseline also passes the 48-case repair matrix in all three bus phases.
Extended integration passes, including existing exception, MMU, cache, FPU,
load/store/PEA, trace, IRQ/replay and ownership checks. These broad tests do
not replace the missing quick-arithmetic-specific boundary checks above.
First-100 corpus passes 1,900 field groups with zero differences in
28,482,938 cycles; root verified candidate and experimental pipeline hashes.
Evidence: /tmp/cpu-corpus100-gate.Aw34Uf and
scratch/p109_quick_rmw_ack_20260921/integration.

After P108b's complete fit/STA/archive wrapper terminated and no Quartus
process remained, the exact screened P109 core was applied for FPGA
evaluation. quick_rmw_read_ack.patch is now historical/APPLIED.
No hardware performance claim is made for P109.
