# Interim Mac build — 2026-09-24

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
