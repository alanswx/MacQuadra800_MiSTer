# P140 issue the prepared register MOVE store

Unqualified isolated follow-up over P139, core SHA256 `5fceaa0a1b6fa1571a2dfd2eee9a7f43d009f921d4a4e6807e54d0a78ba955fd`, source `scratch/p140_register_store_issue_20260921/ap040_core.v`, patch `scripts/cpu/register_store_issue.patch`.

Review found that P139 calls mwr in S_PIPE_START, but mem_issue's existing write-side whitelist does not include that state. Its saved S_EXEC cycle can therefore become an S_MWR request-setup cycle. P140 admits only the guarded reg_move_store_prepare case to existing in-place write issue. The existing RAM address whitelist, function-code handling, memory/prefetch arbitration and within-page size checks remain mandatory. No general S_PIPE_START write admission is added.

Original workload screens with P120/P136 will compare with P137 (26,243,771 Whetstone and106,054,250 Dhrystone loop clocks), alongside P139's preparation-only control. No performance, correctness, FPGA or hardware result is claimed yet. Precise faults, partial writes, register forwarding and same-An side effects need directed verification if the screen improves. Production RTL remains frozen for the live P130 fit.

Whetstone completed at 26,285,658 loop/26,286,286 returned clocks, 41,887 slower than P137 (+0.160%). Root independently verified all three captures and every non-core source/fixture/ROM/flag/latency identity against P137. Dhrystone remains pending. P141 isolates a prefetch-readiness guard to investigate the increased fetch/decode cost.

Completed workload screen: Dhrystone takes 105,854,250 loop / 105,855,140 returned clocks, 200,000 fewer loop clocks than P137 (0.189%). The independent 50,000-iteration checker passes. Luna verified all eight workload captures and all non-core identities against P137. The initial accidental 100M-cycle bench timeout is preserved in `scratch/dhrystone_full_p140_wrongbench_100m_20260921` and excluded; the accepted run uses the original 500M-cycle bench. With Whetstone regressing, prefer screening P141's guarded form. No full integration or hardware qualification is claimed.
