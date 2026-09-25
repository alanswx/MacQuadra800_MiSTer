# BRF timing experiments (2026-09-25)

Current status: three full fits failed routing, no new RBF/STA and no timing
pass. The current production CPU is the strictly validated X-default address
form; a one-hot row selector is being screened in scratch. Historical early
payload results below are retained for traceability, not as the current design.
The authoritative next-build plan is in RESUME-timing-closure-20260925.md.

Candidate `6bd3c33` moves the resident-redirect (`dgo`) branch-refill data selector to the early target `dbrf_a_early`. The existing `brf_seed_req` remains the final write enable, and non-`dgo` callers retain the generic seed selector. The final seed write remains after queue append/line-offer writes. The source is committed for a measured full fit; no new hardware artifact has been deployed.

The baseline AP040 core is from commit `165e2a72da8c3d2c4827ec2ddf46c3650b081e64`, SHA-256 `2b92366c91720f49ba7e16b740169b7e6601dc2d833960aa874037b3b265b63e`. The early-payload candidate snapshot SHA-256 is `4c7f8685adeccf3fe2d7b177d0f6b9144391bf4f1f4ef5b491c79e783a5d0e9b`. Both are preserved in `scratch/dgo_brf_early_20260925/{baseline,candidate}/ap040_core.v`.

The existing generic seed test had incorrect dimensions: it modeled 32 longwords/64 halfwords, while the production BRF is 16 longwords/32 halfwords. Before correction it failed on baseline at offset 25, count 8, slot 7. The fixture and runner description now model the actual 64-byte sector. The corrected generic test passes 8,320 cases on both baseline and candidate (32 start positions, legal non-wrapping counts up to eight, and 32 randomized BRF contents). The candidate is run with `dgo=0`, so this checks that the original generic path remains unchanged.

A scratch miter extracts the candidate's actual early-target wires and final seed block and compares them against the generic lane-selector oracle. It passes 55,296 cases across all 32 halfword targets, counts 0–8, and 64 randomized BRF data sets, covering both `dgo` and generic seed paths, lane/sector wrap, masks, same-cycle append priority, and preservation of an append in masked slots. The required `dgo && !brf_seed_req` same-stream no-op was checked separately and left all queue words unchanged. Explicit assertions require the dgo seed carrier address and count to match the early target/run. A lane-select +1 mutation is rejected by the miter.

The full legacy AP040 suite passes on both snapshots with `CPU_TEST_LEA=1` and `CPU_TEST_XSTORE=1`; it includes integer, exception, MMU, FPU, branch-early, IRQ-loop, refill-load, and LEA tests. The active production-pipeline `t_loops_irq.s` fixture also passes all three bus phases on both snapshots, with identical cycle counts (138,988; 161,098; 161,098). Production pipeline macros are enabled by `scripts/cpu/run_directed_fixture.py`. Coverage reports 15,030 dgo dispatches, all 15,030 with seed requests, and 13,796 dgo-plus-fill overlaps on each core. A post-NBA monitor checks actual seeded queue slots against pre-edge BRF data for every overlap: 109,534 slots checked on both cores, all passing. The monitor’s aggregate fill counter does not distinguish acknowledged fetch appends from line offers. Natural no-seed dgo cases were not reached (zero observed); the no-op is covered by the direct miter.

The isolated CPU-only area screen measured 25,514 ALMs on the comparison source and 25,955 ALMs on the early-payload candidate (+441 ALMs), with no RAM/register-count delta. Full-project synthesis estimated 39,075 ALMs versus the tested baseline’s 38,816 (+259); MLAB and block-memory bits were unchanged. The full fit ended in routing congestion after 16m31 (40,865 estimated ALMs, 4,178 LABs); no timing report or RBF was produced. The early-payload candidate is rejected for promotion.

Evidence and test commands/logs are under `scratch/dgo_brf_early_20260925/`. The generic fixture changes are limited to `scripts/cpu/refill_seed_alignment.py` and `scripts/fixtures/tb_refill_seed_alignment.sv`; those bytes were frozen before the current full fit started.

## Follow-up selectors

The extracted miter is now reusable as `python3 scripts/cpu/refill_dgo_seed_miter.py --core <candidate-core> --out <fresh-scratch> --negative-control`. It generates its SystemVerilog and logs under the requested output directory, uses an independent linear-halfword oracle, and rejects the lane-select +1 mutation by the data mismatch diagnostic. The corrected run passes 55,296 cases on both the original early-payload candidate and the later opcode-sharing candidate.

A prior version of the miter sampled the combinational early run count in the same simulation delta as changing its address and falsely failed its carrier precondition. A shell chain then proceeded to the expected-failure negative leg, obscuring that positive failure. The final miter waits for combinational settling and checks positive and negative subprocess outcomes separately. Only the final strict CLI results above are valid miter evidence.

The address-only fallback in `scratch/brf_unqualified_carrier_20260925/ap040_core.v` moves only the `brf_seed_a` assignment earlier; `brf_seed_n` and all seed/write guards remain unchanged. It passes the active loop/IRQ fixture. A simulation-instrumented copy asserts that no clock edge calls `issue_ifetch` more than once and reports the same dgo/seed/append-overlap counts as baseline. Its CPU-only area screen is 25,463 ALMs, 51 fewer than the 25,514-ALM baseline. Root promoted this fallback in commit `1f47e51`; the strict status-aware replay of the full legacy CPU suite passes against the copied, instrumented source tree (`scratch/brf_unqualified_carrier_20260925/legacy_check/strict_replay.log`): `AP68040: ALL TESTS PASSED`, including LEA/XSTORE and the no-duplicate-ifetch assertion through the loop/IRQ fixture. Individual simulator logs are under `legacy_check/strict_logs/`; the three negative controls returned nonzero with the intended `TEST FAILED` diagnostic. The opcode-sharing variant in `scratch/brf_early_shared_opcode_20260925/ap040_core.v` passes the same active loop/IRQ workload and queue-priority monitor; its CPU-only map is 25,782 ALMs. The early-payload and opcode-sharing alternatives are not the current production source.

An independent rerun of the strict CLI on candidate `6bd3c33`, including
the required negative control, in `scratch/root_verified_refill_miter_20260925/`;
both checks passed.


The first X-default legacy run used an overly strict per-program coverage finalizer: `lea_d16` and `lea_fault` correctly issued no BRF seed requests, but the checker treated zero per-program requests as fatal. The old runner also masked simulator exits through `vvp | tee | grep -q`. Those initial logs are invalid suite evidence. The monitor was corrected to assert every observed request/data word while allowing zero requests in an individual program, and both candidates were replayed with status-aware positive and negative predicates. The authoritative X-default result is `scratch/brf_unused_address_dc_20260925/legacy_check_retry/strict_replay.log` (per-test logs in `strict_logs/`); the authoritative address-only result is `scratch/brf_unqualified_carrier_20260925/legacy_check/strict_replay.log`. The updated tracked runner is `rtl/ap68040/tb/run_tests.sh`.

## Current selected form

Commit `a75b300` promotes the unused-address-X core after the address-only plus
SDRAM-ready-bit full fit failed routing congestion. The exact core SHA256 is
`6dface16365ae0c0d820897ffb8dfcfd7ef9161a63f3ed64b273fb7933d47a0f`.
Every `brf_seed_req` assignment pairs with a defined address; the only consumer
is guarded by that request. The unspecified value is a per-edge blocking
temporary, not retained state. Its isolated map is 25,410 ALMs, 8,966 registers,
296,960 block-memory bits and 4,352 MLAB bits. The active pipeline test matches
baseline cycles and checks 15,045 seed requests / 119,313 seeded words. Full
strict legacy replay passes as described above. The combined full fit subsequently failed routing; area savings alone do not
establish routability or timing closure.

## Terminal fit results and later scratch screens

The address-only plus SDRAM-ready fit failed routing (39,875 required ALMs,
4,190 LABs). The X-default plus SDRAM-ready fit also failed routing (40,009
required ALMs, 4,184 LABs). Both source-after manifests passed; neither has
routed timing evidence. Full archives are scratch/brf_addr_tras_seed21_20260925_fit_20260925/
and scratch/brf_dc_tras_seed21_20260925_fit_20260925/.

A scratch mgo_a-default-X experiment passed active pipeline checks on65,370
memory-command entries but increased isolated CPU area76ALMs, so it was
rejected; its stopped legacy replay is incomplete. A scratch one-hot four-row
BRF data selector passes8,320 generic alignment cases and is currently in an
isolated map. Neither is promoted. Consult the handoff and scratch README for
completion status; do not turn a pending screen into a claimed pass.

The one-hot row candidate also passes a no-request hold check with unknown
seed address/count (exit0). Exact commands are in its scratch README; the
source difference is preserved as scripts/cpu/refill_row_onehot.patch against
the current X-default CPU. Full legacy/active regression awaits a useful map.
