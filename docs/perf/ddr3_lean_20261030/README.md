# Lean DDR3 core at 54 MHz, 2026-10-30

Question: can the DDR3 VRAM (16-bit colour, the 16"/21" monitors) sit
close to the dual-issue memory checkpoint's size?  At 54/27/81 MHz the
checkpoint (6bfd9c0 + clock plumbing, branch dual-memory-clk54) is 35,258
ALMs (84 %) and the 20261027 release core (ccbf914) 38,370 (92 %).

Per-entity difference, release core minus checkpoint, both at 54 MHz
(fit reports of q800_r54_s55 and q800_m54_s70):

| entity | ALMs |
|---|---:|
| vram_ddr3 | +1,904 |
| wombat_store_buffer, f2sdram terminator, dafb, sysmem | +396 |
| ap68040_fpif + ap040_fpu (FP store/FMOVEM stages A-F) | +792 |
| line-state MLAB copies for the 16 KB caches | +372 |
| iosb, ncr53c96, adb, hps_io (placement) | -431 |

The BRAM framebuffer is 497 of 553 M10Ks; the DDR3 VRAM build uses 332.

## Builds (branch dual-memory-ddr3-lean)

1. b06c1b6: ccbf914 with the FP store work (dc0a345, 55f12e3, b03911f)
   reverted and CSB back to 7 (8+8 KB caches).  The CPU is 6bfd9c0's plus
   b27f8fa (posted VRAM store release), 00a6b46 and 0766b3f.
   `run_tests.sh` on it: 225 of 225 and the decoder check pass.
2. b48a3f4: vram_ddr3's write FIFO data in RAM (eight 16x8 arrays, one
   write port, read at the head; Quartus put them in M10Ks with its own
   read-during-write bypass registers) and the burst scanner from a
   per-slot "address follows the previous slot" bit.  Lockstep bench
   (old and new module, one DDR3 model with random BUSY and read gaps,
   random posted/handshake/read traffic): no mismatch on any output over
   six 400k-clock seeds; a planted bug in the sequence bit gives 148,886.

| build | seed | ALMs | M10K | CPU | HDMI | CPU hold |
|---|---|---:|---:|---:|---:|---:|
| b06c1b6 | 55 | 37,268 (89 %) | 328 | +0.948 | +0.441 | +0.116 |
| b06c1b6 | 70 | 37,256 (89 %) | 328 | +0.169 | +0.637 | +0.172 |
| b48a3f4 | 41 | 36,499 (87 %) | 337 | +1.072 | +0.508 | +0.203 |
| b48a3f4 | 55 | 36,477 (87 %) | 337 | +0.345 | +0.437 | +0.114 |
| b48a3f4 | 72 | 36,484 (87 %) | 337 | +0.605 | +0.382 | +0.173 |
| b48a3f4 | 70 | 36,579 (87 %) | 337 | -0.026 | -0.210 | +0.250 |

Step 1 saves about 1,110 ALMs against the release core, step 2 about 780
more: 36,500 ALMs, 1,240 above the checkpoint with the DDR3 VRAM, four
monitors, the store buffer and the ROM cache in.  Seed 41's rbf (md5
2a480467, stamp 261030) is on mister192 as
`_Development/MacQuadra800_ddr3lean54mhz_s41_261030.rbf`.
