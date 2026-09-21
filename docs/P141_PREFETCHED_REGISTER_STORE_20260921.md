# P141 prefetch-qualified register store

Unqualified isolated follow-up over P140, core SHA256 `29d6e2363edc4993be137ac632427199ac5efcea1daea719b9818ec66e54bbc9`, source `scratch/p141_prefetched_register_store_20260921/ap040_core.v`, patch `scripts/cpu/prefetched_register_store.patch`.

P140's Whetstone screen returns identical captures and unchanged non-core identities but takes 26,285,658 loop clocks versus P137's 26,243,771 (41,887 more). Root profile comparison finds 115,058 fewer S_EXEC clocks and 39,809 fewer S_MWR clocks, offset by more fetch (+67,257), immediate fetch (+49,815), decode (+42,127), and EA work. This suggests earlier data-port occupancy can disrupt instruction prefetch; the profile does not prove causality.

P141 requires epf_ready_pc2 before using P140's early register-store preparation. It retains the original S_EXEC path when the next two instruction words are not ready. Screen P120/P136 original workloads against both P137 and P140; no benefit or correctness claim yet. All prior store forwarding/flags/fault/side-effect and full integration gates remain required. Production HDL unchanged.

Completed workload screens with P120/P136:

| Workload | Loop clocks | Returned clocks | Loop clocks saved vs P137 |
|---|---:|---:|---:|
| Whetstone | 26,217,517 | 26,218,145 | 26,254 (0.100%) |
| Dhrystone | 105,754,254 | 105,755,144 | 299,996 (0.283%) |

Luna verified all eight capture files and every non-core identity against P137; the root independently checked Whetstone captures/identities and reran the Dhrystone numerical checker (PASS, 50,000 iterations). Detailed evidence is in `scratch/p141_workload_audit_20260921.md` and the two `scratch/{whetstone,dhrystone}_full_p141_20260921` directories. These are small simulation gains, not a measured Speedometer Mix improvement. Full integration and directed store checks remain pending; production sources are unchanged while the P130 fit runs.

Full integration completed in `scratch/p141_full_integration_retry_20260921`. Root independently verified all 22 program and four IRQ/replay logs, HANDOFF accounting, every actual source hash and exact oracle trace equality. All eight workload captures and non-core identities are also root-verified. Dedicated actual early-store path coverage and directed fault/side-effect checks remain pending. The first integration attempt stopped before program tests due to an incorrect pipeline filename; only the corrected retry is accepted evidence.

The initial directed MOVE matrix reports 64 cases per core in three bus phases, but dedicated fast-path coverage remains incomplete. Root found the focused tracing sampled blocking mgo carriers at the same clock edge as the CPU and requested stable post-edge observation. The A7/partial-write program passed architectural checks without entering the fast path. Revised cached-loop stimuli and explicit coverage assertions are in progress; the earlier report does not qualify those fast-path cases.

Root-authored 15-case cached matrix now passes on P137 and P141 in all three bus phases. Per-case checks assert memory guards, CCR and An results; A7 byte pre/post updates and source/base aliasing are included. The corrected stable-edge monitor reports per-phase `classes=fff a7=11 alias=7 fallback=4 early=105`, with fatal coverage assertions executed before the success marker is accepted. Both ordinary-sequencer and explicitly enabled-pipeline P141 runs pass. Reproduction artifacts: `scripts/cpu/prefetched_store_matrix.s`, `scripts/cpu/prefetched_store_coverage.patch`; compile patched scratch bench with `-DP141_TRACE -DAP040_ALU_MOVE=0` for P141 (MOVE opcode constant matches ap040_defs.svh), omit P141_TRACE for baseline. Exact source lists and feature flags are archived in `scratch/p141_register_move_store_checks_20260921/REPRO_COMMANDS.md`. Existing 64-case write-fault/repair matrix passes on both cores; that matrix is not claimed to exercise every fault through the accelerated path. No FPGA or hardware result for P141.
