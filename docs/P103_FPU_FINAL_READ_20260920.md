# P103 final FPU operand acknowledgement screen

Isolated from P102; production RTL is unchanged during its active Quartus flow.
Unapplied patch: scripts/cpu/fpu_final_read_ack.patch.
Candidate: scratch/p103_fpu_final_read_20260920/ap040_core.v
SHA256: 937eb615927a136f756f17183ca9602befcd34fea09b86dd59291856ba5e94ae

On the successful final ordinary S_MRD response returning to S_FPU_RD,
capture the final operand word into fpb and assert the registered FPU request
on that edge. This skips the copying S_FPU_RD cycle. Error handling remains
before successful acknowledgement. Split reads retain their existing return
path. Both fpb and request are registered; the FPU sees the complete operand
when it sees the request on the following edge.

Full original Whetstone, latency 3, compared with P102:
31,784,029 -> 31,640,386 loop clocks, 0.452% reduction.
Stack, globals and CODE3 captures are identical. Image, ROM, flags and
supporting RTL match; comparison.json is under
scratch/whetstone_full_p103_20260920. Numerical oracle remains pending.

Bus-fault and 4K-MMU-invalid-page gates each pass nine cases across three
bus phases: postincrement/predecrement FPU operands and FMOVEM, fault at
each of three longwords. Logs under scratch/p103_fpu_final_read_20260920
(faults.log and mmu4k.log); detailed directories scratch/p103_fpu_faults_20260920
and scratch/p103_fpu_mmu4k_20260920. These check exception entry/rollback,
not RTE retry. 8K faults, complete FPU/CPU integration, fit and hardware tests
have not been run for P103. Do not treat the screen as full qualification.

This is a small optional improvement, not evidence of approaching 1.8 Mix.
Keep it isolated while P102 fits; next larger changes should be justified by
instruction/memory cost attribution, rather than assuming this shortcut scales.
