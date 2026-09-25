# Pipeline fault and IRQ baseline

Evidence root: `scratch/interim_pipeline_baseline_20260924/`. Paths below are relative to that root. This validates the four-way 55ed03e baseline, not subsequent ALU-sharing changes.

Source snapshot: `git archive 55ed03eb901f1ed1222bc599ee59a9ff104bb544` (55ed03e production source; later checkout changes during test setup were docs-only). Snapshot files and generated tests are under `tree/`; original regression outputs are copied under `evidence/`. Core SHA-256 `a309fd758e9f38f08be9bfa4fe6e707f18e81cf195757740809b6c82d39b3dc0`; integer pipeline SHA-256 `1b27a6b9d472cc57a288f8e0a1050648c197b9699939713327feaf56a389a846`; testbench SHA-256 `0ebe0e951c6119710828ed35808371da1994e7f1fb770179d93654a155799fc3`.

Tools: Icarus Verilog 12.0; VASM `/home/alans/mister/MacQuadra800_fixtures/wombat-vasm/vasmm68k_mot`. Tests run serially from the archive snapshot. Short `/tmp` output directories were needed because the bench's `$value$plusargs` path buffer truncated an initial long path. The first such run is preserved in `evidence/path_failure/`; it is a harness path failure, not an RTL result. All final artifacts were copied into `evidence/`.

## Results

- `pipeline_memmove_faults.py` exact production flags: `AP040_EXPERIMENTAL_{XSTORE,LEA,PIPELINE,PIPELINE_LOADS,PIPELINE_STORES,PIPELINE_PEA,PIPELINE_P6}`, `AP040_PIPELINE_COMPARE`, `AP040_PIPELINE_MEMORY_ENTRY`, `AP040_PIPELINE_EARLY_DRAIN`. PASS all seven bus-fault scenarios across phases 0/1/2. Destination and extension cases each report `MOVE_ACK shortcuts=3 expected=3`; all other required counts are 0. Run: `evidence/ipb55d_memmove/`.
- Same MOVE fault runner with `--source-extension d16`, same exact production flags. PASS all seven scenarios. `early_reads=3 expected=3` for the source and destination d16 cases; non-extension cases correctly require 0. Destination/extension acknowledgements remain 3. Run: `evidence/ipb55d_memmove_d16/`.
- `pipeline_p6_faults.py` original flags include test-only `AP040_PIPELINE_FORCE_DECODE` and omit `COMPARE`, `MEMORY_ENTRY`, and `EARLY_DRAIN`; it PASSes all three cases, with `INDEXED FAULT launches=3`, but is not production pipeline-entry coverage. Run: `evidence/ipb55d_p6/`.
- Scratch-only `pipeline_p6_faults_production.py` changes only that flags list: enables all production flags above and removes `PIPELINE_FORCE_DECODE`. PASSes movea-word, move-word, and store-word bus faults. Each reports `INDEXED FAULT launches=3`; handoff monitor reports loads=3 or stores=3, cancelled=6, commits=0 (the expected faulting operations do not retire). Run: `evidence/ipb55d_p6_prod/`.
- `pipeline_compare_faults.py` exact production flags. PASS indexed CMP and TST fault cases; both show three indexed fault launches and six cancelled slots. Run: `evidence/ipb55d_comparefaults/`.
- `pipeline_branch_boundaries.py` exact production flags, no force-decode override. PASS odd target address fault, taken/not-taken trace boundaries, and IRQ-at-load-request case. Each case commits three fixture operations; IRQ case records three injections. Run: `evidence/ipb55d_branchbound/`.
- `pipeline_handoff.py --only-irq --memory-entry --p6 --loads --stores --pea --xstore --lea --compare --early-drain`: common compile has all production flags. As written, test-specific IRQ monitors add `PIPELINE_FORCE_DECODE` for memory-entry overlap and load/store/PEA IRQ builds. PASS: overlap 3 injections/6 killed, load 3/3, store 3/3 with three stores, PEA 3/6 with three stores. Run: `evidence/ipb55d_irq/`.
- `pipeline_read_completion_irq.py` exact production flags plus its built-in test-only `PIPELINE_FORCE_DECODE` admission override. PASS read-ack IRQ boundary: 3 injections and 3 cancels. Run: `evidence/ipb55d_readirq/`.

No production sources or build files were edited for these tests. Coverage limitation: this establishes directed bus-fault and IRQ paths on the real CPU bench; it is not a full pipeline fault matrix or hardware test. In particular, `pipeline_p6_faults.py`'s original `FORCE_DECODE` mode alone would not establish production memory-entry P6 behavior, which is why the production-flags variant is also preserved.


## Corrected dependency/drain monitor

`scripts/cpu/pipeline_drain_edges.py` previously counted final retirement
only in `pipe_owner`, missing direct memory-read retirement in `S_MRD`.
Its original coverage assertion fails on the unchanged 55ed03e baseline.
The corrected test includes `pipe_read_retire`, enables the production
COMPARE macro, and separately verifies indexed MOVEA writes c080 to A2
before TST.L (A2) launches a read at c080. The dependency token is reset
between bench phases and consumed after each dependent read. DBcc, CMP,
and JSR following-instruction coverage and the next-edge idle assertion
remain required.

Both baseline and the scratch common-ALU prototype pass all three phases
at 742/1086/1086 cycles, with 12 drain edges and three instances of each
required dependency/boundary. A deliberate c081 expected-address mutation
fails on the actual c080 read, demonstrating the new address assertion.
This is a test-harness correction; the common-ALU prototype is not promoted.

Evidence: scratch/alu_owner_{baseline,shared}_20260924/regress/drain_final/
and scratch/alu_owner_shared_20260924/regress/drain_negative/. Corrected
script SHA256: 89a8c4363e00d614d08d733db86a160776e03116c826d3271bbc345f11080a25.
