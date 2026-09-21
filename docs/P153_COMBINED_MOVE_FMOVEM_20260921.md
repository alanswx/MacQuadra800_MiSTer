# P153 combined MOVE and FMOVEM CPU candidate

Unqualified scratch integration of P152 FMOVEM completion, P146 memory-to-memory read/write handoff and P149 refill memory MOVE decode. P152 already includes P137/P143/P148; P141 register-store changes are not included. Source `scratch/p153_combined_cpu_20260921/ap040_core.v`, SHA256 `1bc6ede374d0943d9e48f9cb11566582fdd1d776c1d70d7cb8e713c25e063192`. Patch `scripts/cpu/combined_move_fmovem.patch` applies to P152.

P146's memory-issue patch conflicted with P143's FPU store hints in context. Root retained both hint_st_fpu/hint_st_fmovem and added P146's successful read-to-write exception to the occupied-port guard. The ALU data selection, ordered handoff and P149 refill decoder otherwise use their separate candidate changes. An intermediate partially applied scratch file was not tested or accepted.

Original Whetstone/Dhrystone screens with explicit P120 pipeline and P136 cache are queued. Separate-candidate gains do not prove combined performance or correctness. Full integration and directed interaction checks remain required; production HDL remains frozen for P150. No FPGA/hardware claim.
