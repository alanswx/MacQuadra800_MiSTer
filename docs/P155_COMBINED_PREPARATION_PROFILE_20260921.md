# P155 combined CPU preparation profile

Observation-only bench for the original Whetstone fixture on P153/P120/P136. Source `scratch/p155_combined_profile_20260921/tb_cpu_whetstone.sv`, SHA256 `8f90c0b9edf890364b514210994f6ec3205791cd6eff83c98839844bf728197a`. Patch `scripts/cpu/combined_prepare_profile.patch` applies to the standard Whetstone bench.

Retains P142's exclusive ordinary operand-memory phase partition and accounting assertion, and adds instruction-opcode occupancy for S_PIPE_START(slot0), S_DECODE(slot1) and S_PIPE_REGS(slot2). These counters identify frequently occupied preparation states after the combined changes. They do not prove those cycles can be removed, and all counts cover the same boot/fixture execution window as the standard bench.

Measurement is queued with Luna. Require identical25356654 loop/25357282 returned clocks, all three captures and non-bench source identities against the uninstrumented P153 screen before interpreting counts. No measured result yet. Production HDL remains unchanged during P150 fitting.

Measurement completed with exactly25,356,654 loop/25,357,282 returned cycles. Root verified all three captures, non-bench identities and every source hash versus P153 (`scratch/whetstone_p155_combined_profile_20260921/root_audit.txt`). Operand-phase accounting assertion passed.

Largest S_PIPE_START opcode occupancies:2f10=320,820;206e=165,540;2f20=160,410;2d6e=130,760;2d7c=86,484;30df/20df/209f=85,540 each. These preparation costs remain after the combined completion/decode changes. Ordinary operand return S_PIPE_SDONE still costs304,901 unissued-setup clocks,250,948 prefetch-wait clocks and986,331 issued-wait clocks. Ordinary FPU operand return S_FPU_RD has152,648 unissued-setup clocks. Next inspect source-address preparation/admission and FPU operand issue ownership; none of these counts is itself a removable-cycle guarantee.
