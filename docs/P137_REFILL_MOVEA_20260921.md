# P137 branch-refill MOVEA decode

Unqualified isolated core prototype over P109, SHA256 `cec3baa1bce99d39439757c6fd409310e642cc27755e4aed19ea46fe6916872f`, source `scratch/p137_refill_movea_20260921/ap040_core.v`; unapplied patch `scripts/cpu/refill_movea.patch`.

Extend the existing branch-refill memory MOVE decode to MOVEA.W/L with (An), (An)+, -(An), and d16(An) sources. It selects the address-register destination, uses long ALU width, preserves CCR, and sign-extends word sources exactly as ordinary decode does. Byte MOVEA remains excluded. Memory issue, base updates, undo, faults and retirement use existing operand paths.

Hypothesis: skip one S_DECODE cycle at eligible resident branch targets. Measure original Whetstone/Dhrystone against P109/P120/P136 cache before qualification. Root verified all eight captured outputs and every non-core source, fixture, ROM, flag and latency identity against P136. Whetstone is unchanged at 26,243,771 loop/26,244,399 returned clocks. Dhrystone improves from 107,504,306 to 106,054,250 loop clocks (1,450,056 saved, 1.349%); returned 106,055,140. The independent 50,000-iteration Dhrystone end-state checker passes. Evidence: `scratch/{whetstone,dhrystone}_full_p137_20260921`. Root verified full integration: 22 CPU and four IRQ programs, balanced accounting, three interrupts per case, required kills and exact store counts, matching reference trace, and all source identities (`scratch/p137_full_integration_20260921/root_audit.txt`). Dedicated coverage of the newly admitted MOVEA path is still pending; no FPGA/hardware gain is established. Required tests include negative word sign extension, unchanged CCR, source/destination aliasing and A7 updates, memory fault restart, trace/interrupt behavior and full integration. Production RTL remains frozen for the active P130 seed24 fit.

## Initial directed branch-refill evidence

A minimal DBRA loop targeting `MOVEA.W (A0),A1` from a negative `$FFF0` word passes all three memory timing phases on P109 and P137 with P120/P136. Root inspected the observation-only instrumented core diff and actual log: 18 entries execute the modified arm with opcode3250. Architectural dumps match byte-for-byte (SHA2563494c4da137b935b133879f9a27ea3ff36904393858b0dd262d0e19f084f8237), including A1=FFFFFFF0 and A0=00002000. Evidence: `scratch/p137_movea_refill_focus_20260921/{baseline_instrumented,p137_instrumented}.log` and matching `.dump.hex` files.

This proves the new path is reached for one word-indirect form, not the whole admitted mode matrix. The program stored MOVE.L values before recording SR, so it does not establish original CCR preservation. A corrected CCR capture and additional modes/alias/A7 cases are assigned. Earlier invalid-hex logs are rejected evidence.

## Root-authored mode matrix

The final 11-case matrix adds explicit expected-value assertions, immediate CCR capture/check, all four admitted source modes in W/L sizes, A7 source postincrement/predecrement, and same-register source/destination aliasing. Root verified all three timing phases pass for P109/P137, identical architectural dumps (SHA2569cf8dc4e3680cf31d000f575b7e5f576b9939331c2c03639eca8bf7c3cca79c5), and actual logged candidate entries for every one of the eight mode/size combinations. Compiled VVP paths confirm the P136 cache. The focused run exercises the ordinary sequencer; the separate full CPU suite covers enabled P120 pipeline integration.

Program and observation-only instrumentation are preserved in `scripts/cpu/refill_movea_matrix.s`, `refill_movea_coverage.patch` and `refill_movea_matrix.md`. Dedicated trace/fault injection at the new branch target is not claimed; existing full regression tests pass. FPGA and hardware evaluation remain pending.
