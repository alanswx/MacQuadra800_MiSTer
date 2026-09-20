# Latest: P70 qualified and promoted for the next fit

P70 = P64 64-byte MOVE core plus P59 shortdivider. Fullintegration77746exit0,
first1001900groups0diffs /tmp/cpu-corpus100-gate.WgStgM, Quick163503/175283/198660
lat0/3/8 sorted/guardsPASS. Noother CPU change. NoQuartus beforepromotion.
Build wrapper scratch/p70devdivide_fit_20260920/run.sh, planned userunit
q800-p70devdivide-fit-20260920.service. Commit then launch; verifylive.
P67failed routing, no freshRBF. MiSTer safehalt onP64median1.131. Cheapoperator
must monitorP70 and awaitroot artifactreview beforedeploy. FullguestP67sim
PID2547288 stillbootinglocaldisk; screenshotf847MacOSStartingup reviewed.
P73scratch128-byte buffer/shared two-line selection retains8seedports; alloffset
independent17,536-caseoraclePASS. Quick74121/Bubble2725pending. No P73fit yet.
P72sixseedwordsscreenQuick166812/178583/201953, Bubble3454620; gainlost likeP71,
sessions30498/56969exit0, not promoted. P73 uses P67 core/baseline divider.

# Current status: P67 fit failed routing; P70/P72 isolated tests active

P67 is no longer an active FPGA build. No fresh bitstream. See final entry.
MiSTer safehalt after five valid P64 runs, median1.131. Local fullguest sim live.

# Latest transition: P67 promoted for development fit

P64 complete: artifact `scratch/p64devmove_fit_20260920/MacQuadra800_p64devmove_7952a01.rbf`,
SHA f2e82be0096b553150ef3bace8888f6a5454947a6d75f6ae954be6c69cec60cc,
4512768 bytes. Root-reviewed fit39302ALMs94%, CPU-.068ns (TNS-.068), HDMI+.288,
SDRAM+.278, holdminimum+.245; sys→RAM+1.892/RAM→sys+.421; healthy inferred
cache tag and register RAM. source/cross/detailedSTA all0; wrapper terminal,
no Quartus process before next source mutation. Cheap operator assigned P64
experimental hardware trial, same33MHz32MB disposable, five fresh pairs.

P67 full integration79688 collected exit0; all gates now passed. Promoted core
SHA e2c0baba83bb7eb8ac1e9de1bab14ef2dbc49a4a9fe1dbd400c82498dab0a0ec:
P64 MOVE plus128-byte refill, P63ALU/pipeline, baseline divider, noP66change.
CD/Ethernet remain omitted, seed22 unchanged. Next sole flow wrapper
`scratch/p67devrefill_fit_20260920/run.sh`, unit
`q800-p67devrefill-fit-20260920.service`. Launch after this commit; verify live.
No P67 FPGA or hardware performance result yet. Freeze inputs while active.
P66 remains unapplied alternative timing patch. P63/full and P63dev records
now reviewed including configuration and clean shutdown; medians1.129/1.122.

# CPU performance continuation — 2026-09-20

This is the current continuation index. The long historical log is
`RESUME-pipeline-goal-20260919.md`; experiment details and commands are in
`docs/cpu-pipeline-compare-20260919.md`. Inspect live processes before relying
on these observations. The 1.8 hardware goal remains unachieved and active.

## Current production and build

**LATEST ACTIVE BUILD:** user unit q800-p64devmove-fit-20260920.service,
wrapper2490271,quartus_sh2490301,quartus_map2490413 atlaunch. Commit
7952a01e6b5667a2c1e9bef133f74faa63b2a677; archive scratch/p64devmove_fit_20260920.
P64 MOVE optimization, P63 ALU, baseline divider, seed22, CD/Ethernet omitted.
Preflight passed and synthesis active. Freeze RTL/QSF/QIP/SDC. Cheap operator
monitors it while testing archived P63devnocdnet on hardware; never mix artifacts.
All earlier ACTIVE statements below are historical and superseded by this one.


**Current (supersedes older state below):** the sole ACTIVE flow is user unit
`q800-p63devnocdnet-fit-20260920.service`, wrapper2438580, quartus_sh2438602,
quartus_map2438691 at launch. Commit29190feddc3cded8f88956d6332188e53e22fb78,
archive scratch/p63devnocdnet_fit_20260920. Exact P63 CPU, CDROM_OFF and
ETHERNET_OFF enabled, seed22; development-only. Preflight passed and synthesis
is live. Freeze RTL/QSF/QIP/SDC until the entire wrapper ends.
Full-feature P63 completed; GPT-5.6-luna operator owns five-run hardware
qualification of its archived 6fbe313 RBF, and monitors the new build during
waits. Do not deploy mutable output_files or the new development artifact
without root review. Root verified full-feature P63 timing miss and authorized
experimental testing under the persistent user/BUILD.md policy.


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


## Latest user steering: temporary CD and Ethernet omission

User proposed disabling Mac features temporarily and specifically Ethernet.
Next planned development build keeps P63 CPU unchanged and sets CDROM_OFF=1
and ETHERNET_OFF=1. Do not interrupt or modify current full-feature P63 fit.
Prepared UNAPPLIED scripts/cpu/development_no_cd_ethernet.patch; NOT launched
scratch/p63devnocdnet_fit_20260920/run.sh (exact P63 preflight and both feature
flags required, DEVELOPMENT ONLY labeling). See
`docs/CPU_DEVELOPMENT_FEATURES_20260920.md`. Both features must be restored
and full hardware validation repeated before final acceptance. P64 stays a
subsequent one-at-a-time CPU experiment. Cheap operator has been notified.


## P63 terminal, hardware assigned; development profile promoted

Full-feature P63 fit SUCCESS, build.exit1 solely timing gate, source0/cross0.
Artifact4555188bytes, SHA5dafc05bb5a47a3c6cbb31ef5e0e7f826d8aa32a9ed110d1c3af27532b1cf587,
archive scratch/p63subset_fit_20260920/MacQuadra800_p63subset_6fbe313.rbf.
41,174ALMs98%; CPU-1.709ns,HDMI-.213,SDRAM+.478,holdmin+.242,
crosssysram+2.325/ramsys+.827. Root verified and assigned cheap operator
/root/fit_and_hardware_operator five-run experimental hardware gate on this
exact archived RBF; timing miss does NOT bar user-authorized experimentation.
Operator owns hardware access. No score yet. Original disk remains untouched.

Both development feature macros now applied in QSF, exact P63 CPU unchanged.
Next sole build wrapper scratch/p63devnocdnet_fit_20260920/run.sh; commit/push
before launching q800-p63devnocdnet-fit-20260920.service. P64 still unapplied.
Current QSF is development-only and must restore CD/Ethernet before release.


Detailed timing follow-up: archived P63 .sta.rpt has summaries, not individual
failing CPU paths. Do not infer its path from P39 or from the partial current
database. After p63devnocdnet's COMPLETE wrapper ends, and before any next flow,
run quartus_sta -t scripts/cpu/timequest_worst_paths.tcl
scratch/p63devnocdnet_fit_20260920/cpu_timing. The script now accepts an output
directory (default scratch/cpu_timing) and leaves unrelated root worst_paths.txt
and worst_detail.txt untouched. Cheap operator notified to capture this then.


P63 hardware update: root reviewed ALL five fresh all10/iteration1 start and
completion pairs under scratch/hardware_p63subset_20260920. Mix1.126,1.129,
1.130,1.129,1.130 =>median1.129,mean1.1288; no apparent timer anomalies.
Table now in docs/PERFORMANCE_MEASUREMENTS.md, marked closure pending until
operator supplies remote-copy/config/disposable identity and clean shutdown
for root review. Do not call release-qualified: CPU/HDMI timing still fail.
Do not attribute gain solely to ALU subset (P52/P57 changes also present).
Devnocdnet remains a separate active build; no hardware score yet.


P65 larger-refill experiment prepared in scratch while cheap operator owns
hardware/build monitoring. Exact128-byte P52→P47 delta on P63/P57core; noP64
MOVE change, baseline divider, P63ALU/pipeline. Core SHA213efb3eaed8990a24c3315cc3bc2816b7b2725f8c588fb4d1db2ee7040921d7.
Unapplied scripts/cpu/refill128_subset.patch; scratch/p65_refill128_subset_20260920.
Bubble latency3 3456612→3270270 (-5.39%cycles); Quick170140/181911/205281 at
latency0/3/8 (-364 each vsP63), output/guards PASS. Prefix42770patterns PASS,
upper/crossing SMC PASS. Fullintegration session39775 and first100 session12640
RUNNING; inspect full.log/corpus.log. NoP65fit/hardware; production frozenP63dev.


Latest transition: P63 full-feature five pairs and shutdown_attempt.png root
reviewed, median1.129; remote hash/disposable confirmed by operator. Cheap
operator now assigned P63devnocdnet hardware trial, archive29190fe RBF
SHAf877992fd51c01324393ccf36ead3d6c678e24b7e1c2f771a859106301a405ed.
That flow COMPLETE,source/cross/detailedSTA0;fit39411ALMs94%,CPU-.862,
HDMI-.268,SDRAM+.796,holdmin+.172,cross+1.229/+1.259. No development score yet.

P64 MOVE patch now promoted (previous fullintegration/corpus/targeted gates
passed); current core SHA609b1687e27b5da1096d6b1c990027b46d27f00272ce1d96b45ef6ed97a2f980.
CD/Ethernet remain omitted. Launch after commit as sole user unit
q800-p64devmove-fit-20260920.service via scratch/p64devmove_fit_20260920/run.sh.
P65 remains separate scratch; first100 PASS1900groups0diffs
/tmp/cpu-corpus100-gate.n4wqdQ, fullintegration39775 still running atlastcheck.

P65 final qualification: integration39775 and first10012640 collected exit0;
full.log ends PASS real-core pipeline ownership integration. First1001900groups
0diffs /tmp/cpu-corpus100-gate.n4wqdQ. P65 remains P63-based, not P64-based;
noP65FPGA or hardware result. Development fit-time comparison: P63full24m54
versus P63dev21m56 (~3min/12% faster this pair), not a general guarantee.


## P66: isolate queue branch targets from the decode-state selector

Unapplied candidate `scripts/cpu/queue_branch_target.patch`, based on P64
core SHA `609b1687e27b5da1096d6b1c990027b46d27f00272ce1d96b45ef6ed97a2f980`.
Candidate core SHA `3935c0c9df415a560c9a50c3deacad0f85538414b9feb0934a02e5da3530c5ed`;
P63 pipeline/ALU and baseline divider remain unchanged. No P65 refill change.

The P63 development fit's worst CPU path starts at state[2] and passes through
opcode selection and branch-target arithmetic into epf_data, missing by 0.862 ns.
P66 derives lookahead branch opcode/target directly from the instruction queue.
The shared early-target selector already handles S_DECODE separately, and bd_ok
excludes S_DECODE. All bd_* consumers were inspected for this qualification.
This removes an unnecessary state dependency; actual area/timing benefit is
unmeasured until a separate Quartus fit. It does not claim a cycle-count gain.

Validation on the isolated candidate:
- Full integration PASS (`scratch/p66full`), including branch_early, exceptions,
  MMU/cache, restart, pipeline faults, interrupts, and replay; no saved-log
  early-target consistency diagnostics. Prototype oracle: 14,720 snapshots.
- Original QuickSort kernel PASS sorted permutation and guards, exact P64
  cycle counts 167015/178786/202156 at memory latency 0/3/8.
- Immutable first-100 corpus PASS: 100 rows, 1900 field-groups, zero differences;
  `/tmp/cpu-corpus100-gate.Vo0SmS`. This is not the full CPU corpus.

P64 development build remains active and its RTL is frozen. P66 is a saved,
simulation-qualified patch only; no P66 FPGA or hardware result exists.


Latest scratch work: P67 combines current P64 MOVE with the existing P65
128-byte refill patch, applied with zero fuzz (three expected line offsets).
No P66 timing change. `scratch/p67_move_refill128_20260920` contains core and
logs; production remains frozen P64. Quick session71688, full integration79688,
Bubble then coherence42693, first10078472. Quick log already reports all three
PASS with counts166651/178422/201792 (364 cycles below P64 at each latency);
collect process exit before final qualification. Other results pending.
P63dev five benchmark start/completion pairs root-reviewed, median1.122;
shutdown and persisted identity report pending with cheaper hardware operator.
P66 commit2b4f4e6 pushed; all its simulation processes collected exit0.


P67 interim qualification update: Quick71688, corpus78472, Bubble/coherence42693
collected exit0. Core SHAe2c0baba83bb7eb8ac1e9de1bab14ef2dbc49a4a9fe1dbd400c82498dab0a0ec.
Quick166651/178422/201792; Bubble3270270lat3, sorted/guardsPASS. Upper/crossing
self-modifying-code cases PASS3patcheseach. First100PASS1900groups0diffs,
/tmp/cpu-corpus100-gate.2VUHij. Independent diff against P65 contains only the
P64 d16 MOVE change. Integration79688 still active, through branch_earlyPASS;
collect final result before considering promotion. Prefix log at
scratch/p67_move_refill128_20260920/prefix.log. P64 build still fitting, source
manifest unchanged; no candidate promotion or new Quartus flow launched.
Prefix86843 collected exit0: 42,770 patterns across 64 words PASS.


P67 sole fit launched successfully: unitq800-p67devrefill-fit-20260920.service,
wrapperPID2526067,quartus_sh2526089,map2526182. Build commitc95dced. Confirmed
live synthesis after launch; freeze production inputs until complete wrapper.
Cheap operator running P64hardware; saved boot/desktop/Speedometer screenshots
exist under scratch/hardware_p64devmove_20260920, not yet root-reviewed.
Profiler-only change now gives register/admission counts; see comparison doc.
P66 timing candidate not applied: P64's worst path shifted to MMU→epf_data,
so its former state→branch-target path is not established as the current limit.


## P68 screen: admit register MOVEA with a supported successor

Scratch-only `scratch/p68_movea_entry_20260920/ap040_core.v`, based on P67.
The memory-entry policy additionally permits `(ir & 16'hf1f0)==16'h2040`
when pipe_next_supported. No datapath or instruction semantics change.
Quick latency0/3/8 PASS166502/178273/201656cycles versus P67
166651/178422/201792: only149/149/136cycles saved (0.084% atlat3).
Bubblelat3 unchanged3270270, sorted/guardsPASS. Quick pipeline issues rise
7285→13079 but increased entry/drain work absorbs almost all retirement savings.
Atlat3 register-state occupancy falls33047→27253 while pipeline ownership grows;
this illustrates why occupancy alone cannot predict performance gain.

No promotion or FPGA build: gain is too small to prioritize over the current
larger-refill fit. These kernel checks are a performance screen, not full CPU
qualification. No full integration/corpus/hardware claim for P68.


Full-guest profiling setup started: immutable `git archive c95dced` under
`scratch/p67_fullguest_20260920/tree` (not a worktree), current P67 core hash
verified; build session57503 active, logbuild.log. MatchingAP040/CACHE/CD/ETHERNET
flags captured inidentity.json; vendored untracked sim/mac copied. Disposable
87MBlocal MacQuadra800-Speedometer402-profile.hda copied torun.hda, never edit
fixture. Buildscript and runscript beside it; runscript NOT YET STARTED. Collect
buildsession before starting simulator. It uses fastbootROM solely skipping RAM
test; simulation is profiling evidence, never a hardware Speedometer score.
Control regularfilecontrol.txt accepts appended PS/2 scan-code down/up, wait,
shot, profile start/stop, quit. Runscript sets --cpu-profile workload.tsv and
--speedometer-observe speedometer.jsonl; screenshotframes500/1500/3000/5000/7000,
maxcycles12G. Boot guest, launch original Speedometer, select genuine Whetstone
workload including SANE/mathcalls, bracket it; never substitute math stubs.
P64hardware root reviewed first3pairs1.127/1.131/1.132; remaining2/shutdown with
cheap operator. P67FPGA remains live fitting. No new FPGA source changes.


P64 hardware complete/root reviewed: all5pairs1.127/1.131/1.132/1.131/1.131,
median1.131mean1.1304, noexcludedtimers,33MHz32MBdisposable,remotehashverified,
shutdown.pngsafehalt. Measurements table committed. Cheap operator now monitors
P67through wholewrapper and then detailedSTA, must waitrootreviewbeforedeploy.
Fullguest sim build57503collectedexit0; simulator nowlive asuserunit
q800-p67-fullguest-profile-20260920.service PID2547288. Bootlog progressed190M
halfcycles atlastcheck, screenshots scheduled. Original profilingdisk preserved.
P69scratch applies existingP59shortdivider atop P67(nootherchange):
scratch/p69_refill_divshort_20260920. Quick33749counts163139/174919/198296PASS
atlat0/3/8; fullintegration19078 and first10090842 running. Collectexit/results.
NoP69FPGA source promotion or hardware result; productionstillfrozenP67.


## P69: shorter divider on the MOVE/refill candidate

Scratch-only `scratch/p69_refill_divshort_20260920`, current P67 core plus
previously qualified P59 divider (existing `scripts/cpu/divider_short.patch`).
Divider SHA `1f1df9410c86354d50dd46318d84395d67fc932ac9c1672cb40a9c5014a37a17`;
core remains `e2c0baba83bb7eb8ac1e9de1bab14ef2dbc49a4a9fe1dbd400c82498dab0a0ec`.
It skips eight restoring rounds when the absolute dividend's upper32bits are
zero and divisor nonzero; it retains the baseline path otherwise.

Quick original kernel PASS163139/174919/198296cycles atlatency0/3/8, versus
P67's166651/178422/201792 (about1.96% fewer atlat3); sorted permutation and
byte guards PASS. First100 PASS100rows1900groups0differences,
`/tmp/cpu-corpus100-gate.8nLP7c`. Quick33749/corpus90842collectedexit0.
Full integration19078stillactive, through FPUPASS atlastcheck; complete it
before promotion. Existing standalone24,567-case divider oracle qualification
is unchanged; this run checks composition with the larger refill/MOVE core.
No P69 FPGA fit or hardware result. P67production remains frozen during fit.

Fullguest simulator verifiedlive PID2547288, +ram default0 maps32MB. Bootshot
scratch/p67_fullguest_20260920/tree/verilator/screenshot_f333.png shows gray
startup framebuffer, not desktop; ~300Mhalfcycles after~5minwall. Do not call
this a boot gate or Whetstone profile yet. Simulatorcontrol appendshot works.


P69 final simulation qualification: integration19078collectedexit0, full.log
endsPASSreal-corepipelineownershipincludinginterrupt/replay. Together with
Quick/corpusresultsabove and unchangedP59divideroracle, candidate ready for
separate fit when P67wholewrapperanddetailedSTAterminal. Prepared but NOT
LAUNCHED scratch/p69devdivide_fit_20260920/run.sh; requires P67core plus
P59dividerhash1f1df9410c86354d50dd46318d84395d67fc932ac9c1672cb40a9c5014a37a17.
No productionmutation yet; P67stillactive. Fullguest simulator has advanced
pastgrayROMscreen intoSCSIdiskactivity, notyetdesktop/profiledworkload.


## P67 fit failed routing; follow-up screens

P67 wrapper terminalexit3/sourcecheck0, nofreshRBF/STA/crossreports. Placement
completed, routing terminated due congestion (16618/188026/170143),41,185ALMs98%,
25,347registers,483RAMblocks,41DSP. No Quartus process remains. Do not use the
old output_files RBF or timing reports as P67 evidence. P69's simulation-qualified
128-byte combination inherits this area concern and is not queued unchanged.

P70 uses P64's fitting64-byte core SHA609b1687e27b5da1096d6b1c990027b46d27f00272ce1d96b45ef6ed97a2f980
plusP59shortdivider. Scratch p70_move_divshort_20260920; Quick89458exit0:
163503/175283/198660lat0/3/8,sorted/guardsPASS. First10070943exit0:1900groups0diffs,
/tmp/cpu-corpus100-gate.WgStgM. Fullintegration77746stillrunning. Prepared
scratch/p70devdivide_fit_20260920/run.sh, NOT LAUNCHED or promoted.

P71 scratch128-byte buffer with seed count capped4 and only4queue seed ports:
Quick167139/178910/202280 andBubble3454620lat3PASS. Almost all P67's Bubble gain
lost (P67=3270270;P64=3456612), with Quick slower than P64. Not promoted or
fully qualified; no area claim without synthesis. Sessions26303/74803exit0.
P72 scratch variant caps seed6/6ports, sameP67base/no shortdivider. Screening
Quick30498 andBubble56969active; logs underp72_refill128_seed6_20260920. No fit.
FullguestP67simulation remainslive independently of failedFPGAfit; snapshot
sources immutable, useful for profiling only. Latestshotf847 notyetreviewed.


## P73: share adjacent-line selection, retain all eight refill words

Unapplied `scripts/cpu/refill_shared_seed.patch` is relative to P67's128-byte
core, NOT currentP70's64-bytecore. P73coreSHA
`a4875880f4ddc1d66e55187763019a0f3d64cf23b6bbd45430b69bcd050ac3e2`.
It selects two adjacent16-byte lines into256bits, aligns at the target word,
and writes the same eight queue positions under the unchanged valid-count mask.
The wrapped line at the128-byte boundary is not consumed beyond that mask.
Baseline divider925bbea... remains paired; Quick/Bubbleidentity files checked
beforeproductionchangedtoP70shortdivider. This is an area/routing experiment;
no savings claim exists without Quartus evidence.

Quick lat0/3/8 exactly166651/178422/201792 andBubblelat3exactly3270270: identical
toP67 and preserving its5.4%Bubble gain. Sorted/guardsPASS; sessions74121/2725exit0.
New reusable `refill_seed_alignment.py` extracts the candidate seed block and
compares with independently indexed16-bit words across64offsets,alllegalcounts
0..8,32random buffers, and unchanged masked queue positions:17,536casesPASS.
OriginalP67alsoPASS; intentionally reversed shift fails atoffset1,n1,word0.
Upper/crossing instruction-coherence3patcheseachPASS. First10029767exit0:
1900groups0diffs `/tmp/cpu-corpus100-gate.EOuMAA`. Fullintegration4418active;
finish beforepromotion. Sources/logs under scratch/p73_refill_shared_seed_20260920.

P70launched userunitq800-p70devdivide-fit-20260920.service,wrapper2576384,
buildcommit9a76b04,verifiedactive. FreezeproductionRTLthroughwholewrapper.
Cheapoperatorassignedmonitoring. P67fullguestlocal simprogressed1.09Ghalfcycles;
MacOSstartupscreenreviewed, notyetdesktop. Existing timerobserverQueens/Sieve
only. Profiler totaldispatch toggle/state/cachecounts usable; opcodehistogram
reads legacyir even duringpipeline dispatch and must NOT be treated as exact
pipeline opcode attribution. No workload profile has been collected yet.


P73 final qualification: integration4418collectedexit0, full.log endsPASS
real-corepipelineownershipincludingfault/interrupt/replay. All planned simulation
gates complete with baseline divider. Prepared NOTLAUNCHED wrapper
scratch/p73devshared_fit_20260920/run.sh with exactcorehasha4875880...and
baseline925bbea...divider. Area/timingunmeasured; waitP70completebeforepromotion.
P67fullguest screenshotf1520reviewed: Finder menu bar visible, desktop icons
stillloading; no profileyet. Existing sim_speedometer README warns historic
keyboardsequence previously openedPrinceofPersia and wasrejected. Use live
screenshots/manualnavigation, notprefixreplay. Appendedwait33Mthen shot tolocal
controlfile; simulatorremainslive, P70Quartusremainslive.
