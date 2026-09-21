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
