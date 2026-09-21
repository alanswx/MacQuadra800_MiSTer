# P154 combined register-store candidate

Unqualified scratch extension of P153 with the separately qualified P141 prefetch-qualified register MOVE store. Source `scratch/p154_combined_register_store_20260921/ap040_core.v`, SHA256 `838e6ff59e9c9a68c8d887ae5865dac8ec0b1c2b1122c626f4f404a98f5107f7`. Patch `scripts/cpu/combined_prefetched_store.patch` applies to P153.

Root manually composed P139/P140/P141's final behavior with P153: the S_PIPE_START register source selection is disjoint from P146's S_MRD memory source selection; memory issue accepts both contexts, while preserving FPU store hints and the successful-read guard. P141's epf_ready_pc2 qualification remains present to avoid its earlier prefetch regression. No production HDL change while P150 is fitting.

Original Whetstone/Dhrystone screens against P153 with explicit P120/P136 are queued. No gain, correctness, FPGA or hardware claim for this combined variant yet. Require full integration and directed register-store/handoff interaction checks before promotion.

Original Whetstone completes25,330,407 loop/25,331,035 returned cycles, saving26,247 cycles (0.104%) versus P153. Root verified all three captures and non-core identities against P153 and rehashed every source (`scratch/whetstone_full_p154_20260921/root_audit.txt`). This retains the small standalone register-store gain in the combined CPU. Dhrystone and full combined integration remain pending. Distinct FMOVEM ordering passed as recorded in the P153 document; it is not a substitute for register-store tests.

Original Dhrystone completes104,254,232 loop/104,255,122 returned cycles, saving299,996 cycles (0.287%) versus P153. Root compared all five captures and non-core identities, rehashed sources and ran the independent50,000-iteration checker:PASS (`scratch/dhrystone_full_p154_20260921/root_audit.txt`). Full P154 integration is queued after profiling.

Root audited architectural prefetched-register-store and36-class refill memory-MOVE matrices on P153/P154, explicitP120/P136: all four logs pass and recorded source hashes match (`scratch/p154_directed_interactions_20260921`). These runs have no early-path monitor. A subsequent initial standalone monitor records positive P154 completion but uses an uninitialized class mask, a combined A7 count and an imprecise fallback predicate; it is insufficient for all requested coverage claims. A corrected root monitor with separate A7 bits, before/after-edge fallback and mandatory candidate assertions is being run in fresh output directories.

Corrected standalone monitor now passes: P153 classes000/A7mask00/alias0/fallback12/early0; P154 classesfff/A7mask11/alias21/fallback12/early315 across3phases. Root reviewed both clean logs and all source hashes (`scratch/p154_directed_coverage_root_runs_20260921`). Preserved monitor `scripts/cpu/combined_store_coverage_monitor.sv.inc`, topstore_cov_monitor, plusargrequire_baseline/require_early. This proves both A7 modes and actual registered early-store requests in the same asserted matrix.

Full P154/P120/P136 CPU integration independently audited by root:22programs+4IRQ/replay cases pass, balanced handoff accounting, exact oracle trace and all recorded source hashes match (`scratch/p154_full_integration_20260921/root_audit.txt`). This is the combined CPU's full simulation integration result. P154/P151 cache compatibility remains separate and in progress; no FPGA/hardware qualification.

P154/P120/P151 compatibility full integration independently audited:22programs+4IRQ/replay pass, handoff accounting balances, exact oracle trace matches and every recorded source hash verifies (`scratch/p154_p151_full_integration_20260921/root_audit.txt`). Combined original workload screens remain pending; this is not fit/hardware evidence.

P154/P151 original Dhrystone matches P154/P136 exactly at104,254,232 loop/104,255,122 returned cycles. Root verified all five captures, non-cache identities and source hashes, then independently ran the50,000-iteration checker:PASS (`scratch/dhrystone_full_p154_p151_20260921/root_audit.txt`). Combined Whetstone is the remaining workload screen.
