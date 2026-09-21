# P122 instruction lookup acknowledgement

UNTESTED isolated candidate over P113b cache, with P109 core and P105 pipeline. Source: scratch/p122_instruction_lookup_ack_20260921/ap040_cache.v, SHA256 af8f1e79e76f2fa5a6f2f0c618a605e63b63f31d1bc8198f9f218b61da025174. Reproducible unapplied patch: scripts/cpu/instruction_lookup_ack.patch.

A resolved instruction request that hits settled data in C_IDLE, or an ordinary instruction lookup that hits in C_LOOK, acknowledges using the available cache word immediately. The existing line-seed read is retained and its duplicate registered word acknowledgement is suppressed. Crossing and spanning requests, snooped lookups, and error paths retain existing handling. Unlike P111, this targets ordinary instruction cache lookups, not only a hit in the retained instruction line.

The P118 fetch profile motivates this experiment; it does not prove a gain. Original Whetstone and Dhrystone screening is pending. Before promotion this requires instruction coherence and exactly-once acknowledgement tests, request/CE stalls, cache invalidation and snoops, page/extension fault and interrupt/trace coverage, full CPU integration, and FPGA timing/area checks. Earlier acknowledgement may lengthen the tag/data-to-core path. No hardware or performance claim is made.
