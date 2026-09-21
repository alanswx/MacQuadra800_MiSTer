# P139 register MOVE store preparation

Unqualified isolated prototype over P137, core SHA256 `85b628c5c784ba5c99de7426ea919c0c22f6507b51681fd6ca5462e428f9630c`, source `scratch/p139_register_move_store_20260921/ap040_core.v`, unapplied patch `scripts/cpu/register_move_store.patch`.

The existing simple destination EA path reaches S_EXEC after capturing a settled register source. This experiment feeds that source from forwarded port B into the ordinary MOVE ALU and calls the existing ordered store routine in the EA preparation cycle. Existing base-write/aux-write/extension guards remain in force. A speculative store hint uses the same registered operand conditions and EA expression, without adding live acknowledge dependencies. Fallback EA paths retain src_val capture and their original execution stage.

Hypothesis: save a cycle for register-to-memory MOVE through (An), postincrement, predecrement and resident d16(An). Screen with P120 pipeline/P136 cache against P137 loop clocks26,243,771 Whetstone/106,054,250 Dhrystone. No gain or correctness result is claimed. Required gates include register forwarding, same-register source/base updates, partial writes/flags, faults and replay, full CPU/IRQ integration, FPGA area/timing and hardware. Production sources remain unchanged during P130 seed24.
