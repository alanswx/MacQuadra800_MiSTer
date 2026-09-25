# Performance work handoff — 2026-09-21

## Objective and hardware evidence

Goal remains Speedometer 4.02 all-ten Benchmark Mix >=1.8 at authentic33MHz, five valid hardware runs, invalid timer results excluded/reported, CPU correctness and required hardware regressions preserved. NOT achieved. Real Quadra reference is1.897. Best measured candidate is P120: median1.313, five valid runs, invalid0 (`scratch/hardware_p120_20260921`). Last verified MiSTer state was safe shutdown; obtain a fresh frame before any load. Target ONLY mister.local/10.3.89.233. Disposable disk is `games/MacQuadra800/QuadSquad8-pipeline-test-20260919.hda`; user permits reloads/resets and skips missing A/UX (Dani will check). Commit/push progress to origin/add-ethernet. User requests Luna for compiles/simulations/hardware.

## Active fit: do not change production HDL

P150 wrapper PID566373; quartus_sh566424; fitter573359. Unit `q800-p150-routing-seed25-fit-20260921.service`; archive `scratch/p150_routing_seed25_fit_20260921`; wrapper `scripts/cpu/fit_cache_response_seed25.sh`. At latest root observation wrapper elapsed1h31m and fitter was live. Revalidate processes, do not infer completion from elapsed time. Root rehashed all157 frozen tracked inputs and confirmed no additions/removals. No build.exit yet. Existing output_files reports can be stale P147 failures; require fresh archived results.

One Quartus flow machinewide, same checkout, no worktrees. Freeze tracked HDL/QSF/QIP/SDC throughout wrapper including reporting. New tracked `.sv` files also invalidate the manifest; use scratch or `.sv.inc` for tests. Source is P109 core/P120 pipeline/P147 cache at seed25. P147 previous fit failed routing congestion at502RAM/40264ALM. Do not kill/restart merely because this fit is slow. Agent mister_operator monitors; no hardware deployment yet.

## Next hardware candidate

Prefer prepared P163 (`scripts/cpu/fit_combined_forward_shared_port.sh`) if P150 cannot supply a usable artifact. It requires deliberate promotion of exact P161 core/P151 cache, keeping P120 pipeline, seed25 and development CDROM_OFF/ETHERNET_OFF. See `docs/P163_COMBINED_FORWARD_SHARED_PORT_FIT_20260921.md`. Not launched; no production source changes. It combines qualified CPU gains with a shared cache RAM port intended to save20M10K; actual RAM inference/savings/timing unproven. P156 isolated-cache wrapper remains diagnostic fallback, not a required preceding build. P162 is experimental and excluded from P163.

P161 core: `scratch/p161_alu_read_dispatch_20260921/ap040_core.v`, SHA a0d6053901b044128d9c6ff1513f19d2cc9318ad3285b1ddd226809022359770.
P151 cache: `scratch/p151_shared_pair_port_20260921/ap040_cache.v`, SHA b8e59ae3ee53141a4709fa9a3bd4a41db80fffbe9d0b1e450b834049382a8836.
P120 pipeline: `rtl/ap68040/experimental/ap040_pipeline_integer.sv`, SHA41539493f5e0506e32af7dd46a7f14e1e22c5cb06e6410d1e29afcd82541df70.

After P150 terminal: review fresh reports, source-after check and artifact; if appropriate promote/commit/push exact P163 sources, verify machinewide idleness, launch once. Inspect RAM summary, CPU/RAM/HDMI/cross-domain timing. Adapt hardware plan to exact artifact/hash, fresh safeoff, same33MHz/32MB configuration and disposable disk. Do not hash a disk while loaded core owns it. CmdB raw48/CmdQ raw16, Command down/up56. No screenshots during timed runs.

## Qualified simulation results

P161/P120/P151: Whetstone25,366,469 loop /25,367,097 returned; Dhrystone104,254,232 /104,255,122. All eight capture files and nonchanged-source identities audited; independent50k Dhrystone checker passes. Accepted directories have `p151b`: `scratch/{whetstone,dhrystone}_full_p161_p151b_20260921`. Full22CPU+4IRQ/replay passes, exact oracle and balanced handoff accounting, all source hashes root-audited: `scratch/p161_p151_full_integration_20260921/root_audit.txt`.

P161/P136 equivalent Whetstone25,247,483 /25,248,111; Dhrystone unchanged. P151 costs118,986 Whetstone cycles but may reduce routing pressure. Simulation counts are not Speedometer predictions.

P161 forwarding-specific values, source bus/MMU faults, successful source splits, destination MMU faults, T1 trace and synchronized IRQ acceptance now pass. Preserve precise scope in `docs/P161_ALU_READ_DISPATCH_20260921.md`. New destination evidence `scratch/p161_dest_fault_root_runs_20260921`: baselineprepared0/errors3/correlated0; candidateprepared24/errors3/correlated3 (same faulting instruction instance). Earlier `p161_dest_mmu_fault_runs` mistakenly reused source-fault assembly and is excluded. IRQ accepted evidence `scratch/p161_irq_pins_runs_20260921`:3injections/3acceptances/0followingreads each core. Synchronizer bypassed deliberately; no post-RTE claim. Initial internal-only injection failed phantom invariant; excluded.

## Current experiment P162 and pending agents

P162 queues next ordinary multiword FPU operand read at successful nonfinal ack, capturing fpb word and incrementing fp_n. Source `scratch/p162_fpu_read_continue_20260921/ap040_core.v`, SHAd2e8306f112e81e96cea56fb4dd4c4e2fedae835bf536cadbe2dcb82ed2a3f50. Patch `scripts/cpu/fpu_read_ack_continue.patch` overP161; docP162.

Initial original Whetstone P120/P151 root-audited25,267,804 /25,268,432, saves98,665 (0.389%), three captures/noncore identities identical (`scratch/whetstone_full_p162_20260921/root_audit.txt`). Not fully qualified. Luna_monitor runs original Dhrystone then full integration. Luna_p105_tests runs continuation monitor then read faults. Format values passed but original final-read monitor does not prove new nonfinal path. Root prepared exact monitor `scratch/p162_continue_monitor_20260921/monitor.sv.inc`, topfpu_continue_monitor, plusargsrequire_baseline/require_continue. Await actual logs/hashes; don't accept merely old formats/faults under renamed directories.

P161/P151 profile independently audited against standard bench: `scratch/whetstone_p161_p151_profile_20260921/root_audit.txt`, using P155 profile bench. Totals/captures match; only bench differs. Aggregate memory phases setup725237/prefetchwait324893/issuedwait2382250/ack5167123. Further optimization should use measured instruction/state costs.

## Evidence and workflow pitfalls

`run_directed_fixture.py` requires nonexistent output directory; explicit core/cache/pipeline and assembly/monitor identities. Reject FAIL/FATAL/ERROR even if vvp exits0. Root reviews assembly and actual changed-path coverage, hashes all sources, compares captures and only excludes intentionally changed source from identity comparison. Full integration is22programs+4IRQ, not merely prototype snapshots. Agent reports sometimes reuse wrong fixtures or stop before requested tests: inspect actual commands/manifests/logs.

Dhrystone runner needs500m bench `scratch/dhrystone_full_fixture_20260921_500m/tb_cpu_dhrystone.sv`; default100m times out. Read-fault generator may default to production P147 cache: pass explicit cache if supported and otherwise report scope exactly. Bench numeric Whetstone oracle remains pending; identical captures are differential evidence.

Leave unrelated untracked worst_detail.txt/worst_paths.txt alone. Source patches/docs/tests are committed and pushed; scratch artifacts are local. Read current git status before editing. Goal stays active; no new hardware score since P120.
