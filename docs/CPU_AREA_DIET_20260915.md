# Area diet for the development profile (2026-09-15)

Why: the device sat at 94 % (39,413 ALMs of 41,910 at checkpoint 14) and
routing closed on about one seed in four; doubled fitter effort did not
help (`CPU_DECODE_HISTOGRAM2_20260915.md`).  The decode-overlap work
needs headroom, and every candidate needs a seed walk otherwise.

What is outside the CPU (checkpoint 12 fit, per entity): the HDMI scaler
1,803 ALMs, the Mac I/O block (SCC, VIAs, SCSI, RTC) 3,100, the audio
path (audio_out with its IIR filters, mixers, DC blockers, I2S and SPDIF
encoders) about 850, the video measurement block 259, the sound chip
308, the HPS interface, VRAM buffers, video controller, ADB and SDRAM
path about 2,300.  The scaler stays (the hardware runs' screenshots read
its framebuffer), SCSI, the VIAs and ADB are the boot and the keyboard,
the sound chip is probed by the ROM.

Taken, as macros in `configs/cpu_development.tcl` only (the release
recipe keeps everything):

- `MISTER_DISABLE_AUDIO_OUT` (sys/sys_top.v): no `audio_out` instance;
  the HDMI audio pins idle, the analog outputs are silent, SPDIF idle.
- `MISTER_DISABLE_VIDEO_CALC` (sys/hps_io.sv): no `video_calc`; the OSD's
  video information and the vsync_adjust source read zeros.

Measured: checkpoint 14's RTL fits at seed 22 with **38,482 ALMs
(91.8 %)**, 931 fewer than without the diet, all TNS zero, worst slack
+0.186 ns (CPU clock), HDMI +0.353, RAM clock +0.569; RBF
`5c88b7ea9845ba16...`.  Hardware, two sets on that build
(`scratch/perf_diet_seed22_20260915`, `_set2`): 0.824 / invalid / 0.826
and 0.824 / 0.826 / 0.826, five valid runs, mean **0.825**, against
0.829 / 0.831 / 0.831 for the identical CPU in the checkpoint 14 build.
The machine boots and benchmarks normally without audio and video
measurement.  The one invalid run is the known negative-time anomaly
(1 of 6 here).

The 0.5 % is uniform across all ten tests (Dhrystones 9409 against
9461/s, KWhetstones 619 against 624/s, Towers 1.230 against 1.223 s) with
cycle-identical CPU logic, so it is a property of the bitstream, not of
the RTL: the likeliest place is the 33 to 99 MHz SDRAM handoff, whose
latency on some transfers can depend on placement if a crossing is not
constrained as a fixed multi-cycle path (the cross-domain survey of
2026-09-14 looked at its margin against the negative-time runs, not
against throughput).  Two consequences: comparisons across bitstreams
carry about half a percent of placement noise (the memory-source
lookahead's 0.6 % hardware loss at checkpoint 9 was inside it), and the
diet base's own baseline is **0.825**, which is what candidates built on
it compare against.  The handoff itself is worth a look as a candidate
in its own right: a deterministic crossing would recover the half
percent on unlucky placements and remove one source of the anomaly.

Still on the table if more is needed: the SCC's second channel and its
FIFOs (400 to 600 ALMs, needs the boot's serial probing checked), the
sound chip (308, risky), and `MISTER_DEBUG_NOHDMI` (the scaler, 1,800)
only if the hardware runs move to a capture that does not need the
framebuffer.

## Second round: the OSD overlays (2026-09-15)

The one-clock-hit candidate (`docs/CPU_FAST_READ_20260914.md`) failed
routing or the CPU clock on 13 seeds at 38.65 to 38.87 K ALMs.  Per
entity in the checkpoint 15 fit, the framework still carries two OSD
overlay instances, `osd:hdmi_osd` 545 ALMs and `osd:vga_osd` 533, that
the hardware runs never open (the screenshots read the scaler's
framebuffer, upstream of the overlay; the guard deploys by `load_core`,
not through the OSD).  `MISTER_DISABLE_HDMI_OSD` and
`MISTER_DISABLE_VGA_OSD` (sys/sys_top.v) replace each instance by a
pass-through of its video and tie the OSD-open status to zero; both are
now in `configs/cpu_development.tcl` and never in a release build.
Other candidates seen in the same table, kept for now: `scsi_cache`
842 (disk slots would need a pass-through mode; the CD slot has one),
`pll_hdmi_adj` + `pll_cfg_hdmi` 727 (the runtime HDMI PLL
reconfiguration; stubbing it fixes the HDMI mode at the compile-time
default, untested), `scc` 635, `easc` 242.  Fits of the candidate with
the OSDs out at seeds 22 and 20 running.
