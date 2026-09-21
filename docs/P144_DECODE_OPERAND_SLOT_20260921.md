# P144 reserve the decode slot before simple MOVE reads

Unqualified isolated P137 core candidate, SHA256 `46f27819f6039f3cc32289f25259041b860cb0a6120f27e61e08d6666ea43433`, source `scratch/p144_decode_operand_slot_20260921/ap040_core.v`, patch `scripts/cpu/decode_move_operand_slot.patch`. P120 pipeline/P136 cache; does not include P141 or P143.

P142 measures 160,422 unissued setup and 129,399 prefetch-wait clocks for MOVE.L (A0),-(A7). The current prefetch admission guard excludes EA states but permits S_DECODE to start a speculative fetch immediately before a simple MOVE source issues. P144 suppresses that speculative slot for MOVE B/W/L with source (An), (An)+ or -(An), only when at least two words are already queued. No demand fetch, operand request, exception, architectural update or completion logic changes. The tradeoff is less prefetch run-ahead; the benchmark must establish whether it helps overall.

Workload screens and correctness gates pending; no measured gain or production promotion.

Whetstone screen takes 26,244,409 loop / 26,245,037 returned clocks, 638 more than P137. Root verified all captures and non-core identities. Setup and issued memory clocks are unchanged; the entire delta is additional prefetch wait. This does not support this decode-stage policy for Whetstone. Dhrystone screen pending.

Dhrystone is unchanged at 106,054,250 / 106,055,140 returned clocks. Root verified all eight workload captures and every non-core identity. Parked: no workload gain.
