# P152 FMOVEM acknowledgement completion

Scratch candidate over P148, preserved by `scripts/cpu/fmovem_ack_completion.patch`. Source: `scratch/p152_fmovem_ack_20260921/ap040_core.v`; SHA256 `aa7ca0fae53bdf91566df76ab86005cd4c4d8b4672a19570a87f039f0a2469e7`. Root verified that applying the patch to P148 reproduces this exact source. Production HDL remains frozen for the P150 seed25 fit.

Successful ordinary FMOVEM reads capture the acknowledged longword directly into fpb and return to S_FPU_MVM2; successful stores also return directly there. This skips S_FPU_MVM3's copying/no-op cycle. FP register commit still occurs only after all three longwords. Existing error priority and split-transfer completion paths remain in place. This changes completion timing, not the memory request ordering.

Original Whetstone with P120 pipeline, explicit P136 cache and latency3: 25,507,011 loop / 25,507,639 returned cycles, versus P148 25,840,508 / 25,841,136. The reduction is 333,497 cycles (1.291%). Root compared all three captures byte-for-byte, every non-core identity field, and rehashed all recorded sources. Evidence: `scratch/whetstone_full_p152_20260921/root_audit.txt`. This is a simulation result; Whetstone has no independent numerical oracle here.

Full CPU integration, original Dhrystone and directed FMOVEM load/store value, fault and split checks are pending. Luna is running these checks. No FPGA fit or hardware Speedometer qualification is claimed.

Root audited the P152 store-fault suite using explicit P120/P136: MMU off/4K/8K each pass nine cases over three bus phases, with source hashes revalidated. Cases cover ordinary extended postincrement/predecrement stores and FMOVEM stores faulting on each of three longwords, checking completed prefixes, FP0 preservation, address rollback and exception frames. Evidence: `scratch/p152_store_faults_{off,4k,8k}_20260921/root_audit.txt`. FMOVEM read faults and split success remain separate pending gates.
