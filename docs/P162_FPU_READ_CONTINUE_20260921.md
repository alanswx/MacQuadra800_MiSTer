# P162 ordinary FPU read continuation

Unqualified experiment over P161. Source `scratch/p162_fpu_read_continue_20260921/ap040_core.v`, SHA256 `d2e8306f112e81e96cea56fb4dd4c4e2fedae835bf536cadbe2dcb82ed2a3f50`; reproducible patch `scripts/cpu/fpu_read_ack_continue.patch` applies to P161.

On a successful non-final ordinary multiword FPU operand read, capture the returned word into the existing operand buffer and queue the next longword read immediately. This replaces the intervening S_FPU_RD setup state. FPU register commit, final-beat launch, faults and split transfers retain existing handling. The ordinary memory dispatcher owns request issue; this patch does not bypass its port or page guards. Actual cycle benefit is unknown because missing early hints or port availability can offset the removed state.

Motivation: independently audited P161/P151 profile reproduces25,366,469 loop/25,367,097 returned cycles, all three captures and non-bench identities (`scratch/whetstone_p161_p151_profile_20260921/root_audit.txt`). Memory phase totals include725,237 setup clocks,324,893 prefetch wait clocks and2,382,250 issued-wait clocks. These are aggregate opportunities, not a prediction for this patch.

Original Whetstone screening is running with explicitP120/P151 and the standard bench. No correctness, performance, FPGA timing or hardware claim yet. Production HDL remains frozen for P150. If worthwhile, require multiword value/fault/split coverage, full integration and original Dhrystone before promotion.

Original Whetstone now independently audited:25,267,804 loop/25,268,432 returned cycles, saving98,665 (0.389%) versus P161/P151. All three captures and non-core identities match; all source hashes revalidated (`scratch/whetstone_full_p162_20260921/root_audit.txt`). Directed multiword continuation/fault/split checks, Dhrystone and full integration are in progress. No promotion or hardware claim.
