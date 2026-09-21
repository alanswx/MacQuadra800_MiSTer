# P111 retained instruction line acknowledgement

Isolated cache-only candidate over P109; production cache remains unchanged
while the P109 FPGA build runs. Candidate:
scratch/p111_instruction_line_hint_20260921/ap040_cache.v, SHA256
cad1da96dd573665c31d6fb71ae4c1b84b3ef48217a46fa0d951217900a81f27.
Unapplied patch scripts/cpu/instruction_line_hint_ack.patch.

An aligned longword instruction fetch matching an already retained instruction
line may acknowledge using the MMU's registered hint. c_hint_match still
requires the actual request, matching logical address and instruction/data
space, privilege, current TC/TTR settings, a quiet MMU, successful translation,
read permission and cacheability. The retained physical tag is compared with
the registered translated hint tag and low address bits. Invalidate, pending
line assembly, existing acknowledgement and error guards remain. The original
registered instruction path handles requests that fail these qualifications.

The fast path selects the instruction word from registered hint bits. Its
acceptance suppresses the usual registered acknowledgement to avoid a duplicate
response. This may lengthen the cache-to-prefetch-queue path; no timing claim.
Original Whetstone/Dhrystone screening is pending. Cache/MMU permission,
self-modifying code, invalidation, fault, interrupt and full-machine boot checks
are required if its performance warrants further evaluation. No production
promotion or hardware claim.

run_whetstone_image.py now accepts --cache for isolated cache candidates and
records that file's hash in its existing source manifest. The scratch Dhrystone
runner has the same override. Comparisons must hold the core and all other
sources fixed; the core-only Whetstone comparator intentionally rejects this
cache difference and has not been weakened.
