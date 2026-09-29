# P260 (two-half SCSI sector buffer) full fit: 583a98c, seeds 31 / 22 / 21 (2026-09-29)

`583a98c` changes only `rtl/ncr53c96.sv`: the 53C96 sector buffer `ncr_sbuf` grows from
256 x 16 to 512 x 16 (two halves, so a platform transfer overlaps the guest).  The `.qsf`
differs from the last clean fit (`f9f6da6`, seed 31, CPU +0.864) only in comments.

**Result: no seed gave a clean fit.**

- **Seed 31 and seed 22:** the Fitter failed. Routing stopped on congestion, with
  warnings 16684 and 16618, then Error 170143 / 11802.
- **Seed 21:** routed, but missed timing on the CPU clock by -0.253 ns and on HDMI by
  -0.535 ns.

There is no releasable rbf. Per the task, no further seeds were tried.

The area and memory are unchanged. The sector buffer is still **one M10K**: 468 / 553
blocks, the same count as before. ALMs are within about 40 of the last clean fit.
The failures look like the placement lottery on a 93 %-full, 98 %-LAB chip, not
growth. The RAM Summary differs from the P253 seed 21 reference in the `sbuf` row only.

## Build

- **Trees:** `git archive 583a98c` into `scratch/p260_quartus_seed{31,22,21}_20260929/tree/`.
  Only `SEED` was edited, for 22 and 21 (`qsf.diff` in each). There are 178 input files
  each (`input_manifest.sha256`).
- **Tooling:** `scratch/p260_fit_tools/` (`setup.sh`, `launch_when_free.sh`, `sta.sh`,
  `extract.sh`), adapted from `scratch/fpu_p258_fit_tools/`.
- **Launch:** `systemd-run --user --unit=p260-seed<N>-20260929 --collect bash scripts/build_only.sh`.
  Each run was launched after two checks, 60 s apart, found no `quartus_*` process.
  The seeds ran one at a time.
- **Run times:** the host was heavily loaded by another session's Verilator `Vemu`
  runs (load average near 20), which stretched the failing seeds.

| seed | window (EDT) | flow | result |
|---:|---|---:|---|
| 31 | 07:20:54 to 09:05 | 103m21s | Fitter placement prep took 1h09m and routing 10m35s, then the Fitter failed on congestion |
| 22 | 09:06:31 to 11:34 | 147m39s | Fitter placement prep took 1h56m and routing 4m55s, then the Fitter failed on congestion (peak interconnect 97.0 % V) |
| 21 | 11:36:04 to 11:56 | about 20m | Fitter OK: placement prep 1m16s, routing 5m29s, peak interconnect 85.6 % / 93.5 % V. Timing not met. |

## Results

| | f9f6da6 seed 31 (last clean) | 583a98c seed 31 | 583a98c seed 22 | **583a98c seed 21** |
|---|---:|---:|---:|---:|
| fitter | OK | **FAILED** (routing congestion) | **FAILED** (routing congestion) | OK |
| ALMs | 39,102 (93 %) | 39,095 * | 39,099 * | **39,139 (93 %)** |
| registers | 24,660 | 24,246 * | 24,246 * | **24,681** |
| M10K | 468 / 553 | 468 / 553 | 468 / 553 | **468 / 553** |
| block memory bits | – | 3,393,507 | 3,393,507 | 3,393,507 |
| DSP | 36 | 36 | 36 | **36** |
| CPU `general[0]` setup | +0.864 | – | – | **-0.253** (TNS -0.264, 2 endpoints) |
| RAM `general[1]` setup | +0.409 | – | – | **+0.499** |
| HDMI setup | +0.110 | – | – | **-0.535** (TNS -3.439) |
| h2f_user0 setup | +2.633 | – | – | +3.395 |
| worst hold | +0.250 | – | – | **+0.191** (CPU, regfile `pend_wdata` → altdpram); HDMI +0.206, RAM +0.428 |
| recovery / removal / min pulse | all positive | – | – | all positive (worst +0.505, CPU VCO pulse width) |
| crossings sys→RAM / RAM→sys | +1.128 / +0.867 | – | – | **+1.630 / +0.858**, 0 violated |
| rbf | md5 `dc281d64` | none | none | 4,462,244 B, **timing-failed, do not flash** |

\* These figures are from the failed placement.

**Seed 21 artifacts** (in the scratch tree only, not staged in the checkout's `output_files/`):

- **rbf:** md5 `61e61048899e1ffa030081b712f2162d`, sha256
  `578ab598e69a6f8e8afb81ba3d3debd0f3e595e6f7c141a10aa68778936d9577`.
- **SOF:** sha256 `0215b94b2bca3a8dcb8235a1f798f3afd5cf5c10af38871d0f45efbe0d51c33a`.

The summaries are in this directory:

- `MacQuadra800_seed21.sta.summary`
- `MacQuadra800_seed{31,22,21}.fit.summary`

**Worst paths at seed 21:**

- **CPU:** `ap040_core|ifr_addr[14]` → `epf_data[1][11]` at -0.253, and `epf_data[2][0]`
  at -0.011. This is the familiar `ifr_addr` → ATC → `epf_data` fetch path, not the SCSI block.
- **HDMI:** the framework's `mask_bypass_rtl_0` shift-tap M10K → `vga_out|din1_rtl_0` at
  -0.535. At least 10 endpoints fail, all on this video-output path.
- **RAM:** `sdram_beat32|wq_wp_handoff[3]` → `a_ram[*]` at +0.499.

The reports are in `scratch/p260_quartus_seed21_20260929/tree/p254_sta/` and `.../tree/scratch/cross_*`.

## Sector buffer in the RAM Summary

**Analysis & Synthesis RAM Summary** (identical in all three seeds):

```
emu:emu|quadra800:machine|iosb:iosb|ncr53c96:scsi|ncr_sbuf:sbuf|altsyncram:ram|altsyncram_qgq2:auto_generated|ALTSYNCRAM ; M10K block ; True Dual Port ; 512 ; 16 ; 512 ; 16 ; 8192 ; None
```

The **Fitter RAM Summary** gives the same row: Single Clock, implementation 512 x 16 / 512 x 16,
8192 bits, **M10K blocks = 1**, MLAB 0.

At f9f6da6 this row was 256 x 16 / 256 x 16, 4096 bits, also one M10K.

The normalised RAM Summary has 99 rows, like the P253 seed 21 reference. The only
difference from the reference is this row. The same 6 instances stay uninferred
(open_row, hparam, vparam, kbdFifo, m16buf, ras).

## .qsf comment line (ready to paste above `SEED 31`)

```
# 2026-09-29: P260 (583a98c, ncr_sbuf 512x16, still 1 M10K; 468 M10K, ~39,100-39,139 ALMs, 36 DSP): seed 31 and 22 FITTER FAILED (routing congestion, 16684/16618); seed 21 routed but CPU -0.253 / HDMI -0.535 / SDRAM +0.499, hold +0.191, crossings +1.630/+0.858 -- no clean seed (docs/perf/p260_fpga_20260929).  SEED 31 kept.
```
