# P148 current-baseline final FPU read completion

Unqualified scratch candidate over P143; core SHA256 `579a0ce899b614596dc0d9092baaeae3e41548556ce2e7607c33d52d6541395b`, source `scratch/p148_fpu_final_read_20260921/ap040_core.v`, patch `scripts/cpu/fpu_final_read_current.patch`. Use P120 pipeline and explicit P136 cache for comparison to P143. Production sources remain frozen for P147 fitting.

Rebases the earlier P103 idea: capture the final successful ordinary FPU memory operand response into fpb and assert the registered request on that edge, skipping the S_FPU_RD copying cycle. Error handling retains priority and split transfers retain the old path. The FPU sees the complete registered operand with the request on the following edge. No store, arithmetic, or rounding policy changes.

The earlier P103 screen saved 0.452% against its older baseline; this is not evidence of a current gain. First run the original Whetstone workload and compare all captures and non-core identities to P143, then Dhrystone and complete FPU faults/splits/format/CPU integration if worthwhile. No FPGA or hardware qualification.

Original Whetstone screen completed: 25,840,508 loop / 25,841,136 returned clocks versus P143 25,984,144 / 25,984,772, saving 143,636 loop clocks (0.553%). Root independently compared all three captures and every non-core identity field: exact matches. Evidence: `scratch/whetstone_full_p148_20260921`. Full integration, Dhrystone and directed final-read faults/splits remain pending.
