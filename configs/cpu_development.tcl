# Optional FPGA-headroom profile. Source from MacQuadra800.qsf to enable.
# These are compile-time removals, not OSD settings. Comment out individual
# assignments to restore that feature. Rebuild and check timing afterwards.
# CPU, MMU, FPU, caches, disks, EASC, SCC, ADB and Mac video remain intact.
set_global_assignment -name VERILOG_MACRO "CDROM_OFF=1"
set_global_assignment -name VERILOG_MACRO "MISTER_DISABLE_YC=1"
set_global_assignment -name VERILOG_MACRO "MISTER_DISABLE_MT32PI=1"
set_global_assignment -name VERILOG_MACRO "MISTER_DISABLE_SHADOWMASK=1"
set_global_assignment -name VERILOG_MACRO "MISTER_BYPASS_AUDIO_FILTER=1"

# Area lever adopted 2026-09-14 (write-path checkpoint): drops the 512x384
# monitor option, about 360 ALMs. Required for the merge candidate to fit.
set_global_assignment -name VERILOG_MACRO "VIDEO_512_OFF=1"

# Area levers adopted 2026-09-15 (decode-overlap preparation, the device
# was at 94 %): no audio path (about 850 ALMs) and no video measurement
# (about 260 ALMs). Neither touches what the Speedometer runs use.
set_global_assignment -name VERILOG_MACRO "MISTER_DISABLE_AUDIO_OUT=1"
set_global_assignment -name VERILOG_MACRO "MISTER_DISABLE_VIDEO_CALC=1"
# 2026-09-15: no OSD overlays in the development profile (about 1,080 ALMs); the
# hardware runs never open the OSD and the screenshots read the scaler's framebuffer.
set_global_assignment -name VERILOG_MACRO "MISTER_DISABLE_HDMI_OSD=1"
set_global_assignment -name VERILOG_MACRO "MISTER_DISABLE_VGA_OSD=1"
