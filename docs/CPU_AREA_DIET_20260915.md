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
+0.186 ns (RAM clock), HDMI +0.353, CPU +0.569; RBF
`5c88b7ea9845ba16...`.  Hardware run of that build: pending (expected
identical to checkpoint 14's 0.830; the run also confirms the machine
boots and benchmarks without the two blocks).

Still on the table if more is needed: the SCC's second channel and its
FIFOs (400 to 600 ALMs, needs the boot's serial probing checked), the
sound chip (308, risky), and `MISTER_DEBUG_NOHDMI` (the scaler, 1,800)
only if the hardware runs move to a capture that does not need the
framebuffer.
