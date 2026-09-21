# P160 prefetch-qualified ALU address forwarding

Unqualified P159 refinement requiring epf_count>=4 in addition to its existing epf_ready_pc2 guard. Source `scratch/p160_prefetched_alu_read_20260921/ap040_core.v`, SHA256 `efc1576b640d0ad2958d0f1007517d670af59113f4e7fe8e2adeef5c309834c4`; patch `scripts/cpu/prefetched_alu_address_read.patch` applies to P159. This candidate is isolated from the accepted P154 CPU.

Hypothesis: issuing the following memory MOVE early when only two words are prefetched can delay a subsequent multiword instruction. Requiring four resident words may retain forwarding where the queue has more headroom. This is a testable scheduling hypothesis, not a measured explanation for P159's0.833% regression. Original Whetstone screen against P154/P159 with explicitP120/P136 is queued; no gain or qualification claimed. No production HDL changes during P150.
