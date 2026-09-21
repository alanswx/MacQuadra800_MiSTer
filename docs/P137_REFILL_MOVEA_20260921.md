# P137 branch-refill MOVEA decode

Unqualified isolated core prototype over P109, SHA256 `cec3baa1bce99d39439757c6fd409310e642cc27755e4aed19ea46fe6916872f`, source `scratch/p137_refill_movea_20260921/ap040_core.v`; unapplied patch `scripts/cpu/refill_movea.patch`.

Extend the existing branch-refill memory MOVE decode to MOVEA.W/L with (An), (An)+, -(An), and d16(An) sources. It selects the address-register destination, uses long ALU width, preserves CCR, and sign-extends word sources exactly as ordinary decode does. Byte MOVEA remains excluded. Memory issue, base updates, undo, faults and retirement use existing operand paths.

Hypothesis: skip one S_DECODE cycle at eligible resident branch targets. Measure original Whetstone/Dhrystone against P109/P120/P136 cache before qualification. No speed gain or correctness result is claimed. Required tests include negative word sign extension, unchanged CCR, source/destination aliasing and A7 updates, memory fault restart, trace/interrupt behavior and full integration. Production RTL remains frozen for the active P130 seed24 fit.
