# P143 early FPU result and FMOVEM store issue

Unqualified scratch candidate over P137, core SHA256 `9c0cd4a9c7b9c232fb337d1209710756efd233dfe3c6fdf1ad1cb98dcee3a5e7`. Patch `scripts/cpu/fpu_result_movem_store_issue.patch`, source `scratch/p143_fpu_store_issue_20260921/ap040_core.v`. Use P120 pipeline and P136 cache. Production sources remain frozen for the P136 fit.

P142's observation-only P137 profile reports 241,440 setup cycles returning to S_FPU_WR and 104,540 returning to S_FPU_MVM3 (the latter includes reads and writes). This revisits P100's earlier ordinary FPU store optimization on the current baseline and extends the same issue/hint policy to FMOVEM stores. Addresses, transfer index and result data are already settled in these issue states. Existing RAM range, within-page, function-code, prefetch ownership and request-idle guards still qualify early issue; completion, faults, exception suppression and address-register updates retain their original states. No reads or next-transfer acknowledgements are fused.

Whetstone/Dhrystone screens, full integration, directed FPU store faults/partial writes and hardware evaluation remain pending. No performance or correctness improvement is claimed yet.
