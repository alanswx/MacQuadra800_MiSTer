# CPU performance continuation — 2026-09-20

This is the current continuation index. The long historical log is
`RESUME-pipeline-goal-20260919.md`; experiment details and commands are in
`docs/cpu-pipeline-compare-20260919.md`. Inspect live processes before relying
on these observations. The 1.8 hardware goal remains unachieved and active.

## Current production and build

**Latest authoritative state:** P57 is terminal routing FAILED. Production now
contains qualified **P63** (P57 core + pipeline ALU subset), source commit
`6fbe31353f03b19ad9ee2440c28847238fb9c852`. The sole ACTIVE user unit is
`q800-p63subset-fit-20260920.service`, wrapper PID2388489, quartus_sh2388510,
quartus_map2388607 at launch. Archive `scratch/p63subset_fit_20260920`.
Preflight hashes passed and synthesis is live. Freeze RTL/QSF/QIP/SDC until
this complete wrapper terminates; inspect the same unit before any action.
The paragraphs below retain the P57 baseline and history.


Prior build RTL was **P57**, core SHA256
`660821496a34151ef80502437ebd59b8c35f66b0aa858ac11f0b6b6446ea5063`.
Quartus seed22 build source commit `e5066a280169c7c93dfe171fd1e5674b72a96052`.
Later commits contain tests, documentation, and unapplied patches only.

The now-terminal P57 flow was the **user** systemd unit
`q800-p57movestore-fit-20260920.service`, wrapper PID2292054,
quartus_sh PID2292088, fitter PID2301048. Query with `systemctl --user`;
a system-scope query misleadingly reports an inactive unit. Terminal FAILED routing congestion, build.exit3, source_check.exit0. No new RBF.
Archive: `scratch/p57movestore_fit_20260920`.

Keep RTL/QSF/QIP/SDC frozen until the wrapper finishes, including cross-domain
STA and archiving. Never run two Quartus flows or use a git worktree. Source
manifest rechecks pass. Fresh synthesis RAM Summary confirms cache tags44,032
bits in M10K and extra register bank E512bits in MLAB.

P52 seed21 is terminal FAILED: placement passed at41,356ALMs99%, routing failed
from congestion. `scratch/p52refill64_fit_20260920/build.exit=3`, source check0.
P47 previously failed placement from excess LAB demand. Neither produced a
new RBF. `output_files/MacQuadra800.rbf` remains the old P39 artifact until a
fresh result is independently verified; never label it P52 or P57 by filename.

## Qualified next candidates (unapplied)

Prefer **P62** as the next MOVE candidate after P57 ends. P62 includes P61;
their patches are alternatives, not cumulative patches to apply together.
P62 core SHA256:
`609b1687e27b5da1096d6b1c990027b46d27f00272ce1d96b45ef6ed97a2f980`.
Exact source: `scratch/p62_move_dispext_20260920/ap040_core.v`.
Reproducible diff: `scripts/cpu/move_displacement_extension.patch` against P57.
It starts a d16 MOVE destination and requests its extension after source-read
success, retaining the existing S_IMMF settling/fault edge. Baseline divider
and pipeline module remain unchanged.

P62 full integration, targeted fault/IRQ/trace/alias/guard/value tests, and
first100 silicon corpus pass (1900field-groups, zero differences;
`/tmp/cpu-corpus100-gate.OaHEoG`). Wrong-base mutation fails actual guest
checks; baseline fails the required direct-entry coverage assertion.

| Original kernel, controlled latency3 | P57 cycles | P62 cycles |
|---|---:|---:|
| Quick Sort | 182,275 | 178,786 |
| Towers | 23,887,160 | 23,444,567 |
| Permute | 1,380,669 | 1,380,669 |
| Bubble | 3,456,612 | 3,456,612 |
| Queens | 65,720 | 65,720 |

All output oracles pass. These are simulation cycles, not hardware Mix scores.
Prepared, **not launched**, wrapper:
`scratch/p62dispext_fit_20260920/run.sh`. It requires the exact P62 core,
unchanged pipeline module, and original divider before starting. After P57's
complete wrapper is terminal, inspect its result, then promote/commit/push P62
and run the wrapper as the sole new user service. If P57 fails again, assess
its actual failure before assuming another near-full layout will route.

Separate qualified divider experiments: P59 skips zero upper dividend bits;
P60 seeds the upper remainder when it is below the divisor. Both pass full
integration, first100, and24,567 independent arithmetic cases with CE stalls
and deliberate wrong-result mutations. Their alternative unapplied diffs are
`scripts/cpu/divider_short.patch` and `scripts/cpu/divider_seeded.patch`.
They are not included in P57, P61, or P62. P59/P60 reduce Quick Sort cycles
about1.9% beyond P57 but have no fit/hardware evidence; broader P60 workload
benefit over P59 is unmeasured. Avoid silently combining candidates before
qualification and measurement.

## Hardware status and next gate

Best experimental hardware P39: five valid Mix runs, median1.105, CPU setup
-3.701ns (not release timing). Best timing-clean P33: median1.083. Details:
`docs/PERFORMANCE_MEASUREMENTS.md`,
`scratch/hardware_p39refill64_20260919/p39refill64_results.md`.

Last root-reviewed MiSTer frame was a safe shutdown screen on P39, at
`scratch/hardware_readiness_20260920/current.png`. Recheck before deployment.
Target only `mister.local` (10.3.89.233), root key `/home/alans/.ssh/id_rsa`,
remote input8182. Existing authorized hardware agent `/root/mister_operator`
is idle. The original `QuadSquad8.hda` must remain untouched; slot0 uses
`QuadSquad8-pipeline-test-20260919.hda`. User authorizes recovery/reloads on
that disposable image. Normal shutdown is preferred; do not restart Main or
remote input under a live guest. Read BUILD.md before hardware work.

For any fresh RBF, inspect exact source/hash, fit/resource/timing reports,
RAM inference and both cross-domain reports before assigning hardware work.
A marginal fit is permitted for experimentation with explicit timing status.
Keep authentic33MHz/32MB configuration, five independently started valid Mix
runs; exclude and report timer anomalies. Capture each fresh Run Set and
completion pair, and root-review screenshots. Dismiss the old completion
modal before Command-B; otherwise stale results can masquerade as a new run.

User deferred A/UX to Dani because the image is unavailable. CD audio still
needs the applicable final release check, including audible confirmation.
Commit/push progress to origin/add-ethernet is authorized; do not force-push.
Leave unrelated untracked worst_detail.txt and worst_paths.txt alone.

## Profiling cautions

Upstream ap040-pipelined evaluation is complete and did not justify import;
see UPSTREAM_PIPELINE_BENCHMARKS_20260920.md in docs. It is a separate CPU
rewrite, not the CPU being built here.

Quick Sort profiling distinguishes actual fetch starvation from productive
S_PIPE_REGS retirement; about7.6% of P57 latency3 cycles are S_FETCH without
an opcode. This is not a global Mac bottleneck measurement.
`docs/SPEEDOMETER_MIX_ANALYSIS_20260920.md` traces the aggregate calculation.
Hardware table integer-kernel numbers are elapsed seconds, not ratings.
Whetstone contributes about27% of the current rating sum; its original SANE
and external math calls must be preserved in any future profiling.


## P63 isolated area experiment (new, unapplied)

P57 fitter PID2301048 last verified live at37m44s, CPU64m06s; same user unit
active. Source manifest PASS. No fresh artifact yet. Prior goal work was a
verified wait; this turn adds independent candidate qualification.

P63 specializes only the duplicate pipeline ALU to its sixteen decoded
operations; legacy ALU defaults unchanged. Scratch:
`scratch/p63_subset_alu_20260920`; unapplied patch
`scripts/cpu/pipeline_subset_alu.patch`. See latest section in
`docs/cpu-pipeline-compare-20260919.md` for qualification and reproduction.
Subset393216 and full2528416 comparisons PASS, six-mode independent P6 and
compare oracles PASS, Quick cycles unchanged at all three latencies. Carry
mutation fails. Area benefit is unmeasured; do not promote based on simulation.
Full integration completed PASS (session47180 exit0), output in
`scratch/p63_subset_alu_20260920/full_gate.log`, fixtures scratch/p63full.
Tracked compare-runner verification session71977 completed exit0, all six modes PASS.
Do not confuse P63 with P62: it is a separate P57-based area experiment.

P63 first100 silicon reference completed PASS, 1900 field-groups/zero differences,
`/tmp/cpu-corpus100-gate.WhYoWi`; session49483 exit0, log in P63 scratch/corpus.log.
Prepared NOT launched P63 wrapper `scratch/p63subset_fit_20260920/run.sh` with
exact ALU/pipeline/core/divider preflight hashes. P57 synthesis pipeline ALU
uses2182 combinational ALUTs; actual P63 savings unmeasured. P57 fitter still
live at41m24s with CPU70m09s. Next action remains inspect terminal P57 result;
P62 is the qualified cycle-reduction option, P63 the qualified area experiment.


## P57 terminal; P63 promoted next

P57 seed22 FAILED routing congestion (16618/188026/170143), placement passed:
41,260ALMs98%,26,039registers,491RAMblocks,43DSP. Source check exit0, no fresh
RBF. Wrapper MainPID0, unit failed, no Quartus processes before promotion.
Output RBF remains stale P39 and must never be deployed as P57.

P63 ALU subset promoted from the exact qualified patch, core unchanged P57,
baseline divider unchanged, seed22 retained to isolate area change.
Build wrapper: scratch/p63subset_fit_20260920/run.sh. Launch as sole user
unit q800-p63subset-fit-20260920.service after commit. Freeze build sources
until that wrapper completes. P62 stays unapplied pending routing evidence.


## Latest: P63 synthesis measured; P64 ready, unapplied

P63 synthesis PASS08:29:39. Pipeline ALU2182→1637 combinational ALUTs (-25%);
pipeline total3764→3183. Actual fitted ALMs/routing/timing still pending.
Same active user unit, fitter PID2397271 replaces synthesis PID2388607.
Source manifest PASS. Synthesis reports copied to P63 archive/synthesis.map.*.

P64 combines exact P62 core with P63 ALU/pipeline, baseline divider; no other
changes. Full integration and first100 PASS (1900groups0diffs,
/tmp/cpu-corpus100-gate.PKVtFj), directed MOVE faults/boundaries/values PASS,
Quick167015/178786/202156 at latencies0/3/8. All sessions terminal exit0.
Artifacts scratch/p64_move_subset_20260920, scratch/p64full, scratch/qk64.
Unapplied delta remains scripts/cpu/move_displacement_extension.patch.
New identity-checked wrapper scratch/p64movesubset_fit_20260920/run.sh is
prepared NOT launched. Old P62 wrapper expects pre-P63 pipeline and must not
be used for this combination. Inspect complete P63 result before next build.


## Monitoring / hardware delegation

User explicitly requested a cheaper model for completion monitoring and MiSTer
tests. GPT-5.6-luna agent `/root/fit_and_hardware_operator` now owns P63 user-unit
monitoring and subsequent hardware operation. It must report the terminal
wrapper/artifact/timing/source checks to root before deployment; root reviews
artifact evidence and every fresh benchmark start/completion screenshot.
Older `/root/mister_operator` is idle and handing over script paths; do not
allow concurrent hardware input. Root reviewed fresh readiness screenshot
`scratch/hardware_readiness_p63_20260920/current.png`: safe shutdown, still P39,
33MHz/32MB, disposable disk selected. Agent must recheck before deployment.
No P63 hardware artifact or score exists yet. Ask the monitoring agent for
terminal evidence rather than duplicating its polling loop.
