# Interim Mac build — 2026-09-24

## Active goal — approved wording

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
