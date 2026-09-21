# P145 reserve the retire slot before a resident MOVE source

Unqualified isolated P137 core candidate, SHA256 `2f2a308e430b5d2aecd28c29651cf27050e69b832786fb60031257177ca03ca9`, source `scratch/p145_retire_operand_slot_20260921/ap040_core.v`, patch `scripts/cpu/retire_move_operand_slot.patch`. It does not include P144 or other pending core changes.

P144's decode-slot suppression did not improve Whetstone: 638 additional prefetch-wait clocks, no setup reduction. The hot source can instead arrive through resident record dispatch at a prior instruction's retirement, bypassing S_DECODE. P145 reserves that retire slot only for decoded ordinary MOVE with simple memory source and at least three queued words (opcode plus two following words). The existing epf_issue carrier prevents a new speculative fill on that edge. It does not launch a data access, consume extra words or change operand/exception semantics.

Workload screens and correctness checks pending. This is a scheduling hypothesis, not a demonstrated gain.
