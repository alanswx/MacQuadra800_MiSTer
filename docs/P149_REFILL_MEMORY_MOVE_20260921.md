# P149 refill decode for memory-to-memory MOVE

Unqualified isolated candidate over P137, SHA256 `0c5b346e2f5f3cdb08defceaffd36b8c92b509f1b86b625127c8468bab8c58dc`, source `scratch/p149_refill_memory_move_20260921/ap040_core.v`; patch `scripts/cpu/refill_memory_move.patch`. Compare against P137 with P120 pipeline and explicit P136 cache. Production remains frozen for P147 fitting.

The existing refill dispatcher recognizes memory-to-register MOVE/MOVEA. Extend it to ordinary memory-to-memory MOVE with simple destination modes 2/3/4 and source modes 2/3/4/5. Decode only the resident opcode and establish the usual operand fields and source register selector, then enter S_PIPE_START. No operand access or architectural address update occurs at refill dispatch. Existing source access, address-update ordering, destination access and fault handling remain responsible for execution.

P142 identifies memory-to-memory MOVE as a hot consumer, but this candidate only helps when that instruction is the resident refill target. No speed claim yet: screen the original Whetstone workload and exact captures before investing in full qualification. If useful, require refill-path coverage across sizes/modes, alias/A7, flags, source/destination faults and IRQ/trace, full CPU integration, Dhrystone and eventual timing/hardware evaluation. This candidate does not include P141/P143/P146/P148 changes.

Initial Whetstone screen has no gain: 26,243,771 loop / 26,244,399 returned clocks, exactly P137. Root verified all three captures and non-core identities match. Evidence: `scratch/whetstone_full_p149_20260921`. Dhrystone is the remaining performance screen; do not promote based on this unchanged result.
