# Area budget — where the ALMs go, and the room for CD-ROM + CD audio

Measured 2026-09-02 on the seed-19 release (`MacQuadra800_20260902.rbf`,
35,512 / 41,910 ALMs = 85 %) and on the builds that followed. Numbers are
"ALMs needed" from the fitter's *Resource Utilization by Entity* table
(`output_files/MacQuadra800.fit.rpt`); the parse recipe is one Python loop
over the rows whose first column starts with `|`.

## 1. The map (release build)

| block | ALMs | notes |
|---|---:|---|
| `ap040_core` (self) | 11,836 | the 68040 |
| `ap040_fpu` | 5,329 | needed by both OSes |
| `ap040_alu` + `muldiv` + `regfile` + `mmu` + `cache` | 3,600 | |
| **CPU total** | **20,889** | 59 % of the device — not ours to trim |
| `dafb` | 2,866 | **now 378, see §2** |
| `iosb` (self) | 820 | |
| `ncr53c96` (controller + one disk target) | 712 | |
| `scc` + 4 UARTs | 636 | |
| `easc` | 332 | |
| `ascal` (framework HDMI scaler) | 1,999 | |
| `audio_out` (framework: IIR filter 419, DC blockers 153, mixers 193) | 937 | |
| OSDs (hdmi 557 + vga 517) | 1,074 | framework |
| `pll_hdmi_adj` + `pll_cfg_hdmi` + `video_calc` + `vga_out` ×2 + `yc_out` + `shadowmask` | ~1,600 | framework |
| `hps_io` | 573 | grows ~200 with VDNUM 1 → 6 |
| `sdram` + `sdram_beat32` + `wombat_bus32` + store buffer | 826 | |
| `alsa` | 276 | framework, HPS audio in |

## 2. What was tried, with measured results

| change | ALMs | timing | verdict |
|---|---:|---|---|
| **CLUT as three true dual-port M10Ks** (`rtl/dafb.sv`, commit `3047610`) | **35,512 → 32,999 (−2,513, 79 %)**; registers 30,750 → 24,560 | met, +0.038 ns | **kept.** The palette planes were plain arrays read from two clocks; synthesis duplicated all 6,144 bits into flops for the readback port. |
| `MISTER_DISABLE_YC` + `DISABLE_ALSA` + `DISABLE_ADAPTIVE` + `DOWNSCALE_NN` | 35,512 → 34,914 (−598) | **missed** by 0.036 ns at seed 19 | not taken: ~600 ALMs for losing YC output and ALSA, and a seed walk |

Not tried yet, in order of value per risk:

- **Bypass the framework IIR audio filter** (`sys/audio_out.sv`, needs an
  `ifdef` in the framework file): ~420 ALMs. Costs the OSD "audio filter"
  option only.
- `MISTER_DISABLE_ALSA` alone (−276): safe if nobody feeds Linux audio into
  the core's mix.
- The CPU core's 17.6k registers are the elephant; anything there is
  Alan/apolkosnik territory and out of scope for the CD work.

## 3. What CD-ROM + CD audio + Toolbox cost in MacLC (fit report, 2026-08-26)

| MacLC entity | ALMs | of which |
|---|---:|---|
| `ncr5380` (5380 + 2 disks + CD) | 7,813 | |
| `scsi:cdrom_target` | 5,681 | self 2,123 (command layer, ring, MODE SELECT parser, ~120 lines of JTAG debug regs) |
| `cd_audio` inside it | 2,966 | self 1,741; **~1,200 in twelve 256×8 MLAB tables** (`cd_sdp_mlab`: resp/t43/t2 planes) |
| `scsi:target[0]` (disk + Toolbox) | 1,162 | |
| `scsi:target[1]` (plain disk) | 607 | |

## 4. The plan that fits, with the numbers

Free after the CLUT fix: **8,900 ALMs**. Design the SCSI side for area
rather than copying `scsi.v` three times:

| piece | estimate | how |
|---|---:|---|
| multi-ID target contexts in `ncr53c96` (2 HDs + CD), shared data engine | +400 | one sector buffer / FIFO path, per-ID state only |
| CD-ROM command layer (2048-byte blocks as 4×512 HPS blocks, TOC, AppleCD INQUIRY/sense, mode pages, MODE SELECT 0x0E) | +1,000 | ported from `scsi.v` without its bus layer or debug snapshots |
| BlueSCSI Toolbox file transport + CD changer transport (two control-only hps_io slots, 512 B / 4 KB buffers in M10K) | +600 | port of the `tb_*` FSM; HPS side already in the Main fork (`support/mac/`), add `macquadra800` to `is_mac_scsi_family()` |
| `cd_audio.sv` with the twelve MLAB tables moved to M10K | +1,800 | 12 more M10Ks (129 spare) |
| `hps_io` VDNUM 1 → 6, audio mix | +250 | |
| **total** | **≈ +4,050** | → ~37,050 ALMs, **~88 %** |

That leaves ~4,800 ALMs of margin, which is what the fitter needs to keep
closing 33 MHz at seed-walk cost rather than by surgery. If it gets tight,
the IIR bypass (−420) and dropping the JTAG debug from the ported CD code
are the next two levers; CD audio itself does not need to be cut.

Order of work, each step regressed on both guests: (1) multi-ID with two
hard disks; (2) CD-ROM data + Toolbox + changer + Main change; (3) CD audio.

## 5. The CD-ROM target after the ARM offload (phase 1, 2026-09-16)

`optimize-SCSI`, build `1eae0fb7` (seed 21, timing met at +0.247 ns; the
release recipe of section 4 plus Alan's checkpoint-15 CPU). The CD-ROM
target's SCSI responses (INQUIRY, MODE SENSE, READ TOC, the Apple/Sony
status commands) now come from Main through window reads of the CD slot,
and MODE SELECT / eject / resets are forwarded through a command-block
write; playback is still in the RTL (`docs/scsi-hps-offload-plan.md`).
Fitter "ALMs needed" by entity, against the shipped `20260915` (seed 22):

| entity | 20260915 | phase 1 | delta |
|---|---:|---:|---:|
| whole design | 38,711 (92 %) | **38,128 (91 %)** | **-583** |
| `ncr53c96` (controller + 3 targets) | 2,870 | 2,568 (self 1,569) | -302 |
| of which `cd_audio` | 1,346 | 999 | -347 |
| `scsi_cache` | 854 | 854 | 0 |
| `iosb` (incl. the SCSI) | | 4,827 | |
| `quadra800` (the machine) | | 29,880 | |
| `wombat_cpu` (AP68040 + wrapper) | | 23,414 | |
| RAM blocks | 497 | 491 | -6 |
| DSP blocks | 64 | 59 | -5 |
| registers | 25,605 | 25,659 | +54 |

The three response-table planes and the builders left `cd_audio`
(Analysis & Synthesis 2,566 -> 1,535 ALUTs); the `ncr53c96` self cost went
up by the window/forward sequencer (the serialized forwards `f612084`).
Phase 2 (playback on the ARM, `d5442fe`): Analysis & Synthesis puts
`cd_audio` at 371 ALUTs / 320 registers (from 1,535 / 707), `ncr53c96` self
at 2,329 (from 2,571), the target with its engine at 2,700 (from 4,106),
and the design's DSP blocks at 43 (from 59); the blob RAM (one M10K) is
gone too.  The fitted numbers follow with the phase-2 build.
