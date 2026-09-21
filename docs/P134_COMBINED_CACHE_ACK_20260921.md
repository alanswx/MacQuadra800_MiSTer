# P134 combined cache acknowledgement screen

Unqualified isolated composition: P126 instruction/spanning acknowledgements, P130 registered-state spanning data selection and P131 ordinary data lookup acknowledgement. Core P109 and pipeline P120 remain explicit. Cache source `scratch/p134_combined_cache_ack_20260921/ap040_cache.v`, SHA256 6c66510e571f4fbc0ac8fe8f45cc38fc07d8506f3d6bddbb4072d7a4104fb4d6. Unapplied patch `scripts/cpu/combined_cache_ack.patch` applies over production P130.

The instruction, spanning-data and ordinary-data lookup states are disjoint. The common C_LOOK completion suppresses the registered acknowledgement if either ordinary instruction or data early acknowledgement fired. Data and spanning data muxes use registered transaction state; all existing request, snoop and error acknowledgement guards remain. No gain is assumed additive.

Original workload screens are running/queued against the isolated P126 and P131 results. No production promotion, combined correctness qualification, fit or hardware claim yet. The independent P130 seed-24 FPGA flow keeps production sources frozen. P131 targeted coverage audit is still being completed in parallel.

Original workload screens completed: Whetstone 27,165,355 loop / 27,165,983 returned; Dhrystone 112,554,337 / 112,555,228. Versus P131 this saves 466,189 / 249,972 loop clocks; versus P126 it saves 316,787 / 2,000,062. Root verified all three/five capture files and non-cache identities and ran the independent Dhrystone checker successfully. Full combined regression remains in progress. The agent initially reported the P131 Dhrystone difference as 250,036; subtraction of the recorded loop counts gives 249,972.
