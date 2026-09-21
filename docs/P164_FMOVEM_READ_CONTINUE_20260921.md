# P164 FMOVEM read continuation

Unqualified experiment over P162. Source `scratch/p164_fmovem_read_continue_20260921/ap040_core.v`, SHA256 `c550c7f2c5b1672459b0ae011853ad77b7dab6848c1aa65158384bd275209553`; patch `scripts/cpu/fmovem_read_ack_continue.patch` applies to P162.

At a successful first/second ordinary FMOVEM read acknowledgement, capture the word as before and queue the next longword read instead of returning through S_FPU_MVM2. Third-word handling retains S_FPU_MVM2 and its register commit, address advance and mask walk. Store handling and split fallback are unchanged. Memory issue still uses the existing dispatcher and guards.

P161/P151 profile measured549,604 clocks in S_FPU_MVM2 and69,857 setup clocks for its memory-return context, which includes both reads and writes. Those aggregate counts motivate screening but do not predict this read-only change's benefit. Original Whetstone screening against P162/P151 is next; no correctness, performance, fit or hardware claim. Production remains frozen for P150.
