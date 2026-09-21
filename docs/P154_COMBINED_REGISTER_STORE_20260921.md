# P154 combined register-store candidate

Unqualified scratch extension of P153 with the separately qualified P141 prefetch-qualified register MOVE store. Source `scratch/p154_combined_register_store_20260921/ap040_core.v`, SHA256 `838e6ff59e9c9a68c8d887ae5865dac8ec0b1c2b1122c626f4f404a98f5107f7`. Patch `scripts/cpu/combined_prefetched_store.patch` applies to P153.

Root manually composed P139/P140/P141's final behavior with P153: the S_PIPE_START register source selection is disjoint from P146's S_MRD memory source selection; memory issue accepts both contexts, while preserving FPU store hints and the successful-read guard. P141's epf_ready_pc2 qualification remains present to avoid its earlier prefetch regression. No production HDL change while P150 is fitting.

Original Whetstone/Dhrystone screens against P153 with explicit P120/P136 are queued. No gain, correctness, FPGA or hardware claim for this combined variant yet. Require full integration and directed register-store/handoff interaction checks before promotion.
