# Interim Mac build — 2026-09-24

## Active goal — approved wording

The refined goal and completion criteria are recorded in
[docs/INTERIM_BUILD_GOAL.md](docs/INTERIM_BUILD_GOAL.md), updated at the
user's request on September 24. Use that document for the current scope
and follow-on sequence.

Produce a fitted MacQuadra800 build with normal MiSTer functionality,
Ethernet, CD-ROM/CD audio, and disk caching enabled. Preserve CPU
correctness and retain speed enhancements wherever practical. Validate
resource usage, timing, boot/shutdown, and peripheral operation; measure
Speedometer over five valid hardware runs, aiming as close to 1.8 as
possible. Prefer structural area reductions before sacrificing performance.
Report any timing exceptions, feature omissions, or performance losses
explicitly. Report and exclude invalid timer results.

1.8 is a performance target, not a condition that prevents delivery of the
full-feature interim build. Memory-placement analysis and disk profiling
follow as separate phases. User approved this wording in the conversation.
The goal tool cannot edit the stored objective text; use these approved
acceptance criteria alongside the existing active goal.


User priority: fit with Ethernet, CD-ROM/CD audio, disk cache, audio output,
OSDs and Y/C; then review global memory placement, profile disk and plan disk work.
FPGA is available again, but verify guest state before deployment.

Baseline 314d64e: release-lite profile, CACHE_SMALL, CPU SETW=7 (8+8 KB).
Archive: scratch/interim_mac_run2_fit_20260924. Synthesis succeeded;
fitter failed: 42,617 / 41,910 ALMs, 4,305 / 4,191 LABs. No fresh RBF.
The build summary displayed stale timing and RBF from an earlier build;
these are not candidate results. Source manifest check after flow passed.

Validation at baseline: CPU self-tests with LEA/XSTORE enabled passed;
Verilator 5.050 tb_scsi_cache, tb_ncr53c96, tb_easc, tb_line_dma all passed.
Logs copied to scratch/interim_mac_20260924. Default Verilator is too old
for --binary; use /home/alans/verilator5/bin in PATH.

Next controlled experiment: OPTIMIZATION_TECHNIQUE AREA, retaining all
baseline features and CPU logic. Archive tag interim_mac_area. Assess
fresh fit, all timing domains/crossings, and source integrity before hardware.
No claimed performance score for this candidate. Structural area reduction
remains necessary if this experiment cannot fit with acceptable timing.

## Area synthesis result and next candidate

5a16fe7 failed fit at 42,150 ALMs (240 over capacity), saving 467 versus
balanced. Archive scratch/interim_mac_area_fit_20260924; source check passed.
No new RBF or timing result. Next: disable only experimental pipeline
loads/stores; these instructions retain their sequencer implementations.
Keep all restored peripherals and CACHE_SMALL. Full-design area saving and
correctness/performance need fresh verification; prior CPU-only estimate
was 216 ALMs, not a guarantee of fitting. Tag interim_mac_seqmem.

## Concurrent-project authorization and aggressive-area experiment

User explicitly permits separate projects to build simultaneously (2026-09-24);
never kill unrelated Quartus processes. Same-checkout builds remain exclusive.
Seqmem d562e9a failed at 42,180 ALMs, 30 worse than AREA baseline; its six
integer oracle fixtures and negative controls passed. Restore load/store
macros and try AGGRESSIVE AREA mode plus HIGH register packing. No RTL
behavior change from tested 314d64e. Tag interim_mac_aggressive.
MiSTer is in use by user: ask for availability when a candidate is ready.

## Normal-feature target replaces the release-lite target

Latest user goal explicitly includes normal sys/MiSTer features. Prior
release-lite candidates do not fulfill it. Remove the release-lite source
and re-enable bilinear downscaling, adaptive filtering and ALSA; keep
Ethernet, CD, CD audio, SCSI cache, 512x384, OSDs, Y/C, shadowmask, video
measurement and audio filter. Keep CPU SETW=7 and all speed macros.
Aggressive-area/high-packing b421ab7 failed at 42,168 ALMs (18 worse than
balanced-mode/AREA technique). Return to the better synthesis settings.
Tag interim_mac_normal establishes the actual untrimmed resource baseline.
Luna is preparing shared FPU frame sequencing in scratch with correctness
tests; no production RTL edits during this fit.

## Full-feature fit result and structural screens

Normal-feature becb472 failed at 43,806 / 41,910 ALMs (1,896 over),
4,427 / 4,191 LABs. Fitter finished Sep24 16:13:04; flow exit3;
source_check_after.exit=0. Archive: scratch/interim_mac_normal_fit_20260924.
No fresh RBF or STA. Cross-domain timing correctly skipped (exit77).
Synthesis estimated42,349, understating fitter demand by1,457 ALMs.
Do not use the stale P232 artifact/timing printed by the old build wrapper.

After flow termination, build_only.sh was fixed to report only fresh stage
summaries, timing and RBFs. Missing/unparseable fresh timing fails the full
build verdict. Five mocked-flow cases pass via scripts/cpu/test_build_reporting.py:
failed flow with stale output, nominal flow with stale output, absent timing,
negative timing and fresh successful output. These test reporting, not Quartus.

Independent scratch reductions preserve CPU cycles and feature switches:
- BRF banked seed mux: scripts/cpu/brf_banked_seed.patch. Controlled CPU
  baseline becb472 measured29,024 ALMs/8,966 registers; candidate pending.
- FRESTORE and FSAVE sharing: scripts/cpu/{frestore,fsave}_shared.patch.
  Directed frame/resume tests pass as detailed in docs/FPU_FRAME_SHARING_20260924.md.
- Static destination line-fill: scripts/cpu/line_fill_static.patch. Invert
  queue slot mapping so each slot uses one source mux instead of dynamic
  source and destination selections. Exact original/new blocks passed589,824
  comparisons over all fill/tail/count positions and128 random payloads,
  including unchanged slots; planted wrong rotation fails. Evidence under
  scratch/line_fill_static_20260924. Full CPU tests and area still pending.

Luna interim_validation owns BRF regressions and sequential independent
CPU area screens for the frame variants and static line-fill. Nothing is
promoted to production RTL until evidence supports it. No main fit is now
running. MiSTer remains reserved by user; no hardware access.

BRF screen complete:27879 ALMs/8966 regs vs29024/8966 baseline, saves1145.
CPU self-tests and six integer oracles+negative controls pass. Promoted
only the banked BRF mux; source hash and evidence in
 docs/BRF_BANKED_SEED_20260924.md. Next full-feature fit tag
interim_mac_brfbank. Luna owns launch/monitor plus separate area screens.
No performance claim until timing and hardware tests.

## Live BRF fit and next candidate (Sep24 16:24)

Luna launched interim_mac_brfbank from01e7d41 in session82016;
quartus_sh1561502 and fitter1567473 confirmed live. No production RTL
changes while active. Archive scratch/interim_mac_brfbank_fit_20260924.

Static line-fill standalone CPU area screen passed at28853 ALMs/8966 regs,
saving171 versus29024. See docs/QUEUE_MUX_AREA_20260924.md. Luna is preparing
combined BRF+line-fill regressions from01e7d41 plus that patch; instrument
real-cache bench to prove line-offer execution and require identical cycles
against BRF-only. FSAVE, FRESTORE and rotate area screens remain queued.
Rotate single-barrel prototype passes33792 standalone equivalence cases
including all one-hot inputs/shifts; patch tracked but no measured saving.

## BRF full-fit result and controlled packing experiment

BRF01e7d41 full fit failed43,338 ALMs (1,428 over),4,380 LABs, Sep24 16:28:56.
Sourceafter0; build3; cross77. Actual full-design saving468, map estimate
41,471. CPU-only savings are not directly transferable. FSAVE-only grows39
ALMs (29,063) and is rejected. Other structural screens still running.

Next full fit changes only FITTER_AGGRESSIVE_ROUTABILITY_OPTIMIZATION from
ALWAYS to NEVER, tag interim_mac_brfdense. This tests whether forced
routability optimization contributes to post-map packing growth; it is an
inference, not a documented area guarantee. Intel standard-edition guide
https://www.intel.com/programmable/technical-pdfs/683230.pdf describes the
option's routing/speed tradeoff. No RTL, feature, clock or cache-size change.
Luna owns launch and monitoring, plus separate area/regression screens.

## Density result; combined BRF+line-fill promoted

brfdense e5f189e failed43,736 ALMs,398 worse thanALWAYS; sourceafter0/build3.
Finished Sep24 16:37:50. Restore ALWAYS and promote tested static line-fill
on top of BRF (core matches scratch/brf_linefill_20260924/tree). Both full
CPU and6kernel oracles/negatives pass with identical cycles, monitor covers
actual nonzero/wrapped line offers in all6. No new mainfit running.

Remaining workers: interim_validation owns FPUshiftjam map (session92017),
then bitfield rotate_concat area onbecb472. brf_barrel_screen owns line-fill
barrel area; its two BRF barrel forms grew193/121ALMs and are rejected.
alu_rotate_sharing owns shared4-op integer rotate datapath equivalence and
CPU area on01e7d41. No hardware access; user still reservesMiSTer.

## Next full-feature candidate: interim_mac_muxshare

Promoted exact scratch/combined_area_20260924/tree CPU source:
BRFbanked +barrellinefill +sharedALUrotates +bitfieldconcat. CombinedCPUarea
26864/8966regs vsBRF27879/8966, saves1015. Production matches mapped snapshot.
All features unchanged; routabilityALWAYS. Luna interim_validation owns
launch/monitor forinterim_mac_muxshare. Luna alu_rotate_sharing owns final
exactcombinedCPU/six-kernel validation (the prior3-way test omittedbitfield).
Compilation and final regressions may overlap; nohardware untilpassed and
user freesMiSTer. Luna brf_barrel_screen tests combinedlogicalshift+rotate
as a possible later area improvement; notincluded inthisfullfit.


## Latest result: four-way mux-sharing fit

The full-feature `interim_mac_muxshare` build at 55ed03e is terminal:
42,058 / 41,910 ALMs, 4,252 / 4,191 LABs; fitter failed, no fresh STA/RBF.
Source-after check passed. Exact four-way legacy CPU tests and six
production-pipeline Speedometer fixtures passed with unchanged cycles.
See docs/INTERIM_FIT_EXPERIMENTS_20260924.md for evidence and coverage limits.

Luna alu_rotate_sharing is testing/mapping the exact five-way combination
with shared logical/arithmetic shifts. Luna brf_barrel_screen is evaluating
single-ALU ownership in scratch and checking a directed drain-monitor
coverage failure against baseline. Luna interim_validation is reviewing
packing overhead after the terminal fit. No production RTL was changed
following 55ed03e. MiSTer remains unavailable until the user frees it.


## Latest result: shared-shifter fit and validation

Production RTL is 86d48df: five-way candidate, shared logical/arithmetic
shifter added. ALU SHA256 3c7f2f1329d72959718fbf96b8797f8e476123824ce7f328a07e68268903a7b2;
core SHA unchanged a309fd758e9f38f08be9bfa4fe6e707f18e81cf195757740809b6c82d39b3dc0.
ALU differential miter, legacy CPU suite, and all six production-pipeline
fixtures pass; fixture cycles unchanged. CPU-only map 26,722 ALMs.

Full `interim_mac_shiftshare` fit is terminal: 41,764 / 41,910 ALMs but
4,226 / 4,191 LABs (35 too many), build exit3, source-after0, cross/timing77.
No fresh STA or RBF. Retain this best full-feature baseline.

The corrected pipeline dependency monitor was committed at17e9ca1. It
covers direct memory retirement and checks indexed-load A2 forwarding to
TST, including reset/consume of its dependency token and a negative address
control. Separate fault/IRQ baseline evidence on55ed03e is recorded in
docs/PIPELINE_BASELINE_VALIDATION_20260924.md with exact macro limitations.

Luna brf_barrel_screen owns common-ALU area measurement and results;
interim_validation is assigned its production fault/IRQ tests (coordinate
before launch). alu_rotate_sharing is preparing a local-only hardware
validation checklist. MiSTer still belongs to the user until freed.


## Active build: common ALU plus shared shifter

Current production source4f90d5409fbef11f481477035cb298f1fd1ce20b shares the
legacy and pipeline ALU under existing pipe_rf_owner, retaining a separate
legacy fast-operation capability decode. No instruction cycles added.
Core SHA2b92366c91720f49ba7e16b740169b7e6601dc2d833960aa874037b3b265b63e;
pipeline SHA92ea4d96a5b2da0784e65fe2015118e4889353a7df83e4ccca8bf6a1e7059435;
ALU SHA3c7f2f1329d72959718fbf96b8797f8e476123824ce7f328a07e68268903a7b2.

Luna interim_validation launched `interim_mac_onealu` exactly once, session
54089, wrapper1672843 / quartus_sh1672886 / map1673012. Recheck live processes,
not these stale identifiers alone. Archive scratch/interim_mac_onealu_fit_20260924.
Freeze tracked HDL/QSF/QIP/SDC/TCL while this flow runs.

Exact combined contract and drain tests pass; all six Speedometer fixtures
pass with unchanged cycles and all required negative controls. Prototype
without shared logical shifter passed full directed fault/IRQ matrix and
mapped25950ALMs (914 saved versus26864). Exact combined CPU map still pending.
Evidence and limitations are in docs/INTERIM_FIT_EXPERIMENTS_20260924.md.
Hardware procedure: docs/INTERIM_HARDWARE_VALIDATION.md. Do not contact MiSTer
until user says it is free. No fresh RBF from preceding failed full fits.


### Pending test-only patch application after active fit

Exact combined fault/IRQ matrix has now passed; see latest consolidated
experiment notes and scratch/alu_owner_combined_86d48df/RESULTS.md. CPU map
25,865ALMs; full map39,354ALMs. Full fitter1679113 is active (recheck live).
After `interim_mac_onealu` is terminal AND its source-after manifest check
finishes, apply scripts/cpu/pipeline_optional_alu_tb_tieoffs.patch and
scripts/cpu/pipeline_store_oracle_mutation.patch, then commit/push. Both are
already validated together in scratch; do not mutate tracked .sv benches
while the current source manifest is frozen. No synthesizable RTL change
is involved in these deferred test fixes.


## Routing failure and active seed21 experiment

`interim_mac_onealu` at4f90d54 is terminal. Placement succeeded with41,002
ALMs and4,155LABs, but routing congestion (16618/188005/170143) prevented
completion. No freshSTA/RBF. build3/source-after0/cross77/cpu-timing77.
The deferred testbench/oracle patches above have NOW BEEN APPLIED and
committed; do not apply them again.

Current production commit c61087eefd285a32449148721fad2af1ab595416 changes
only fitter seed28 to21 for the FPGA design; CPU/features/SDC unchanged.
Test-only compatibility fixes are included. Luna interim_validation owns
`interim_mac_onealu_s21`, session3447, wrapper1700830/quartus_sh1700873/map1700962
at launch. Recheck live processes. Archive scratch/interim_mac_onealu_s21_fit_20260924.
Freeze tracked HDL/settings until the full flow and integrity check finish.
Luna brf_barrel_screen is investigating actual hold-delay endpoints read-only.
MiSTer remains unavailable until user says it is free.


## Active placement-effort trial after second routing failure

Seed21 trial is terminal:40,997ALMs/4,156LABs, placement successful but
routing congested, noSTA/RBF, source-after0. Shared ADD/SUB scratch candidate
was rejected (+25ALMs); no production arithmetic changes.

Current source24e6b4e311a000f3e0db08bc897867c4e5651ed2 retains seed21 and
raises only PLACEMENT_EFFORT_MULTIPLIER to3.0, supported by installed Quartus17
CycloneV DSE/advisor. CPU/feature/timing settings otherwise unchanged.
Luna interim_validation owns `interim_mac_onealu_s21p3`, session28412,
wrapper1726589/quartus_sh1726632/map1726705 at launch. Recheck live processes.
Archive scratch/interim_mac_onealu_s21p3_fit_20260924. Freeze tracked HDL and
settings through complete flow/source-after check. CPU hashes remain
2b92366c... /92ea4d96... /3c7f2f13... (full hashes above).
Hold-delay review justified no SDC relaxation; related33/99MHz SDRAM crossings
must remain timed. Current goal and hardware availability are unchanged.

## Hardware availability update during placement-effort trial

The user now says: "the fpga is ready when you are - replace whatever is running".
This supersedes the earlier hardware-unavailable status. Deployment remains to
verified mister.local (10.3.89.233), with the disposable test disk and the original
image protected. Wait for the current full flow, source integrity check, and
fresh artifact/timing review before deploying. Fitter PID1730547 was live at
7m13 elapsed when this update was recorded; no fresh RBF yet.

## Placement effort 3.0 failed routing; resume structural reduction

`interim_mac_onealu_s21p3` (source `24e6b4e`) completed in 19m51s.
The report confirms effort 3.0; placement succeeded with 40,997/41,910 ALMs
and 4,156/4,191 LABs, but routing failed (16618/188026/170143/11802).
Average interconnect usage was 55.7%, peak 82.8% (vertical peak 105.5%).
There is no fresh STA or RBF. The post-flow source check passed; crossing and
timing analysis correctly skipped with exit 77. Archive:
`scratch/interim_mac_onealu_s21p3_fit_20260924`.

Restore placement effort 1.0 for subsequent RTL trials. Additional placement
effort did not solve congestion. Next scratch investigation: share the FPU
divider/square-root arithmetic stages without changing their three-digit
iterations or cycle counts. This is an unproven candidate, not integrated RTL.
The latency-increasing one-digit alternative remains deferred.

## Share FPU DIV/SQRT stages without changing latency

The divider and square-root engine now share three 69-bit compare/subtract/
select stages. DIV retains its 65-bit recurrence truncation, initial integer
quotient step, and terminal count 23; SQRT retains its 69-bit recurrence and
terminal count 22. Both still calculate three result bits per iteration.
Final normalization/GRS logic, state, counters, and registers are unchanged.

Candidate FPU SHA-256:
`78f51d66b20c4a28d08f632559fa786d8c8e3a5280c35c7713460834384b0889`.
CPU-only map: 25,676 ALMs / 8,966 registers, saving 189 ALMs versus the exact
combined common-ALU baseline (25,865). No new map warning codes.

Actual-source recurrence miter passed 100,056 comparisons, including random
high bits and directed thresholds; a stage-2 truncation mutation failed with
18,580 mismatches. The full directed CPU suite passed with LEA/XSTORE enabled,
including FPU arithmetic/exceptions, saved frames, and BUSY resume tests.
This is not exhaustive floating-point proof or full-chip timing evidence.
Evidence: `scratch/alu_divsqrt_shared_20260924/RESULTS.md`, `miter.log`,
`negative.log`, and `cpu_suite_evidence/`; CPU map in
`scratch/cpu_area/p_p_divsqrt_shared_86d48df/`.

Promote this validated candidate for a full-feature fit at seed 21, placement
effort 1.0. Feature and timing constraints remain unchanged. A separate fused
borrow arithmetic screen is scratch-only and is not part of this candidate.

## Borrow-derived comparison follow-on, validated but deferred

A separate scratch variant derives each shared DIV/SQRT comparison from a
70-bit zero-extended difference, using the high borrow bit and the low
69-bit result. Exact FPU SHA-256:
`2d53db3ae4a04310add04eeb7919f0219197a98827ed92e410e6d4a4a90f5465`.
The CPU map measured 25,514 ALMs / 8,966 registers: 162 fewer than the
integrated shared-stage candidate, 351 fewer than the common-ALU baseline.
The actual-source recurrence miter passed 100,056 checks; the truncation
negative failed as expected. The fresh full directed CPU suite with LEA and
XSTORE enabled exited 0 with all tests passed, including FPU/frame/resume.
Evidence is in `scratch/alu_divsqrt_shared_borrow_20260924/RESULTS.md` and
`scratch/cpu_area/p_p_divsqrt_borrow_86d48df/`.

Do not integrate while `interim_mac_divsqrt` is running. That full flow is
building source 3791bf6 (FPU 78f51d66...), session 90296, wrapper 1765334,
fitter 1772156. Its fresh full-map estimate is 39,313 ALMs, only 41 fewer
than the preceding full-map 39,354; isolated CPU savings do not transfer
one-for-one to the complete design. Final placement/routing/timing pending.
