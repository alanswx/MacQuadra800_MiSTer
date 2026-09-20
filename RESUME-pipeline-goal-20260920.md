# CPU performance continuation — 2026-09-20

This is the current continuation index. The long historical log is
`RESUME-pipeline-goal-20260919.md`; experiment details and commands are in
`docs/cpu-pipeline-compare-20260919.md`. Inspect live processes before relying
on these observations. The 1.8 hardware goal remains unachieved and active.

## Current production and build

Production RTL is **P57**, core SHA256
`660821496a34151ef80502437ebd59b8c35f66b0aa858ac11f0b6b6446ea5063`.
Quartus seed22 build source commit `e5066a280169c7c93dfe171fd1e5674b72a96052`.
Later commits contain tests, documentation, and unapplied patches only.

The sole active flow is the **user** systemd unit
`q800-p57movestore-fit-20260920.service`, wrapper PID2292054,
quartus_sh PID2292088, fitter PID2301048. Query with `systemctl --user`;
a system-scope query misleadingly reports an inactive unit. Last verified
fitter elapsed over20min, with CPU time advancing. No terminal result yet.
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
