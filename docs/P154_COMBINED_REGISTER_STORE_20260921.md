# P154 combined register-store candidate

Unqualified scratch extension of P153 with the separately qualified P141 prefetch-qualified register MOVE store. Source `scratch/p154_combined_register_store_20260921/ap040_core.v`, SHA256 `838e6ff59e9c9a68c8d887ae5865dac8ec0b1c2b1122c626f4f404a98f5107f7`. Patch `scripts/cpu/combined_prefetched_store.patch` applies to P153.

Root manually composed P139/P140/P141's final behavior with P153: the S_PIPE_START register source selection is disjoint from P146's S_MRD memory source selection; memory issue accepts both contexts, while preserving FPU store hints and the successful-read guard. P141's epf_ready_pc2 qualification remains present to avoid its earlier prefetch regression. No production HDL change while P150 is fitting.

Original Whetstone/Dhrystone screens against P153 with explicit P120/P136 are queued. No gain, correctness, FPGA or hardware claim for this combined variant yet. Require full integration and directed register-store/handoff interaction checks before promotion.

Original Whetstone completes25,330,407 loop/25,331,035 returned cycles, saving26,247 cycles (0.104%) versus P153. Root verified all three captures and non-core identities against P153 and rehashed every source (`scratch/whetstone_full_p154_20260921/root_audit.txt`). This retains the small standalone register-store gain in the combined CPU. Dhrystone and full combined integration remain pending. Distinct FMOVEM ordering passed as recorded in the P153 document; it is not a substitute for register-store tests.
